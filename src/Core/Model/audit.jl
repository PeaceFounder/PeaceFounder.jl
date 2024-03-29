function state(ledger::BraidChainLedger, N::Int)

    spec::DemeSpec = ledger[1]
    tree = HistoryTree(Digest, hasher(spec))

    _root = root(ledger, N)

    local members_count = 0
    local g::Generator = generator(spec) # Thus if a braidreceipt is not present it is set to original
    
    for record in view(ledger, N:-1:1)
        
        if record isa Membership

            members_count += 1

        elseif record isa BraidReceipt

            members_count += length(output_members(record))
            g = output_generator(record)
            break
        end
    end

    return ChainState(index, _root, g, member_count)
end

state(ledger::BraidChainLedger) = state(ledger, length(ledger))



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

    local members::Set{Pseudonym} = Set{Pseudonym}()

    for record in ledger
        if record isa Membership

            record.admission.ticketid in tickets && return false
            record.admission.id in identities && return false
            record.pseudonym in members && return false

            push!(tickets, record.admission.ticketid)
            push!(identities, record.admission.id)
            push!(members, record.pseudonym)
            
        elseif record isa BraidReceipt

            g == input_generator(record) || return false
            members == Set(input_members(record)) || return false
            
            g = output_generator(record)
            members = Set(output_members(record))

        end
    end

    return true
end


function audit_proposal_anchors(ledger::BraidChainLedger)

    # I could think of it as that every braid has an associated ChainState
    spec::DemeSpec = ledger[1]
    
    tree = HistoryTree(Digest, hasher(spec))
    anchor_states = ChainState[]

    for (index, record) in enumerate(ledger)

        push!(tree, digest(record, hasher(spec)))

        if record isa BraidReceipt

            generator = output_generator(record)
            member_count = length(output_members(record))
            _root = HistoryTrees.root(tree)
            
            push!(anchor_states, ChainState(index, _root, generator, member_count))

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
