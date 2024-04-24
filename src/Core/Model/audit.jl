function state(ledger::BraidChainLedger, N::Int)

    spec::DemeSpec = ledger[1]
    tree = HistoryTree(Digest, hasher(spec))

    _root = root(ledger, N)

    local member_count = 0
    local g::Generator = generator(spec) # Thus if a braidreceipt is not present it is set to original

    for record in view(ledger, N:-1:1)
        
        if record isa Membership

            member_count += 1

        elseif record isa BraidReceipt

            member_count += length(output_members(record))
            record.reset || (g = output_generator(record)) # if reset original generator is taken
            break

        elseif record isa Termination

            member_count -= 1

        end
    end

    _termination_bitmask = termination_bitmask(ledger, N)

    return ChainState(N, _root, g, member_count, _termination_bitmask)
end

state(ledger::BraidChainLedger) = state(ledger, length(ledger))

function isbinding(ledger::BraidChainLedger, commit::Commit{ChainState})

    state(commit) == state(ledger, index(commit)) || return false

    # findlast does not have specilaization with view
    spec_index = index(commit) - findfirst(x -> x isa DemeSpec, view(ledger, index(commit):-1:1)) + 1 
    spec = ledger[spec_index]

    issuer(commit) == spec.recorder || return false

    return true
end


function audit_seals(ledger::BraidChainLedger)
    
    (; crypto) = ledger[1]::DemeSpec

    for record in ledger
        if record isa BraidReceipt
            verify(record, crypto; skip_braid = true) || return false            
        else
            verify(record, crypto) || return false
        end
    end
    
    return true
end


function audit_braids(ledger::BraidChainLedger)

    for record in ledger
        if record isa BraidReceipt
            ShuffleProofs.verify(record.braid) || return false
        end
    end

    return true
end


function audit_roles(ledger::BraidChainLedger)

    local spec::DemeSpec = ledger[1]

    for record in ledger

        if record isa DemeSpec

            issuer(record) == issuer(spec) || return false
            spec = record

        elseif record isa Membership
            
            issuer(record.admission) == spec.registrar || return false
            
        elseif record isa Proposal

            issuer(record) == spec.proposer || return false
            record.collector == spec.collector || return false

        elseif record isa Termination
            
            issuer(record) == spec.registrar || return false

        elseif record isa BraidReceipt

            if record.reset # only a braider can reset braiding from the start

                crypto(record.producer) == crypto(spec) || return false
                issuer(record.approval) == spec.braider || return false
                
            end
        end
    end
    
    return true
end


function audit_members(ledger::BraidChainLedger)

    # ticketid is unique
    spec::DemeSpec = ledger[1]

    local g::Generator = generator(spec)
    
    tickets = Set{TicketID}()
    identities = Set{Pseudonym}() # Will be necessary for a reset
    blacklist = Set{Pseudonym}() # ensures that membership record can't be put back 

    local members::Set{Pseudonym} = Set{Pseudonym}()

    for (index, record) in enumerate(ledger)
        if record isa Membership

            record.admission.ticketid in tickets && return false
            record.admission.id in identities && return false
            record.pseudonym in members && return false
            id(record) in blacklist && return false # to prevent reissuing of membership

            push!(tickets, record.admission.ticketid)
            push!(identities, id(record))
            push!(members, record.pseudonym)
            
        elseif record isa BraidReceipt
            
            if record.reset
                input_generator(record) == generator(spec) || return false
                Set(input_members(record)) == identities || return false
            else
                input_generator(record) == g || return false
                Set(input_members(record)) == members || return false
            end

            g = output_generator(record)
            members = Set(output_members(record))

        elseif record isa Termination

            record.identity in blacklist && return false # can't have two termination records for the same identity
            push!(blacklist, record.identity)

            if record.index == 0 

                record.identity in identities && return false # membership is not registered

            else

                1 < record.index < index || return false  # can't point to future records
                member_cert = ledger[record.index]
                member_cert isa Membership || return false # must point to a Membership record
                issuer(member_cert) == record.identity || return false # must be consistent
                pop!(identities, issuer(member_cert))

            end
        end
    end

    return true
end


function audit_proposal_anchors(ledger::BraidChainLedger)

    # I could think of it as that every braid has an associated ChainState
    spec::DemeSpec = ledger[1]
    
    tree = HistoryTree(Digest, hasher(spec))
    anchor_states = ChainState[]

    termination_bitmask = BitVector(false for i in 1:length(ledger))

    for (index, record) in enumerate(ledger)

        push!(tree, digest(record, hasher(spec)))

        if record isa BraidReceipt

            generator = output_generator(record)
            member_count = length(output_members(record))
            _root = HistoryTrees.root(tree)
            
            push!(anchor_states, ChainState(index, _root, generator, member_count, termination_bitmask[1:index]))

        elseif record isa Termination
            termination_bitmask[record.index] = true
        end
    end

    for record in ledger
        if record isa Proposal
            record.anchor in anchor_states || return false
        end
    end

    return true
end


function audit_proposal_uuids(ledger::BraidChainLedger)

    uuids = Set{UUID}()

    for record in ledger
        if record isa Proposal
            
            record.uuid in uuids && return false
            push!(uuids, record.uuid)

        end
    end

    return true
end


function audit_proposals(ledger::BraidChainLedger)

    audit_proposal_uuids(ledger) || return false
    audit_proposal_anchors(ledger) || return false

    return true
end


function audit(ledger::BraidChainLedger)

    audit_roles(ledger) || return false
    audit_members(ledger) || return false
    audit_proposals(ledger) || return false
    audit_seals(ledger) || return false
    audit_braids(ledger) || return false

    return true
end


function audit_seals(ledger::BallotBoxLedger)

    (; crypto) = ledger.spec
    g = generator(ledger.proposal)

    for record in ledger
        verify(record, g, crypto) || return false
    end

    return true
end


function audit_seeds(ledger::BallotBoxLedger)

    length(ledger) == 0 && return true

    _seed = seed(ledger[1])
    
    for record in ledger
        _seed == seed(record) || return false
    end
    
    return true
end

function audit(ledger::BallotBoxLedger)

    audit_seals(ledger) || return false
    audit_seeds(ledger) || return false

    return true
end

function isbinding(chain::BraidChainLedger, bbox::BallotBoxLedger)

    # records must be part of the chain
    bbox.proposal in chain || return false # Proposal does not exist
    bbox.spec in chain || return false # DemeSpec does not exist
    
    braid_index = bbox.proposal.anchor.index
    braid_receipt = chain[braid_index]::BraidReceipt

    # Checking aliases. This also checks membership
    members = output_members(braid_receipt)

    for record in bbox
        1 <= record.alias <= length(members) || return false
        members[record.alias] == issuer(record.vote) || return false
    end

    return true
end

function isbinding(chain::BallotBoxLedger, commit::Commit{BallotBoxState})
    
    issuer(commit) == chain.proposal.collector || return false

    with_tally = isnothing(state(commit).tally) ? false : true
    state(chain, index(commit); with_tally, seed=seed(commit)) == state(commit) || return false

    return true
end

function audit(chain::BraidChainLedger, bbox::BallotBoxLedger, commit::Commit{BallotBoxState}) 

    isbinding(bbox, commit) || return false
    audit(bbox) || return false

    isbinding(chain, bbox) || return false

    audit(chain) || return false
    
    return true
end

function audit(chain::BraidChainLedger, bbox::BallotBoxLedger, checksum::Digest, N::Int = length(bbox)) 

    root(bbox, N) == checksum || return false
    audit(bbox) || return false

    isbinding(chain, bbox) || return false

    audit(chain) || return false
    
    return true
end

