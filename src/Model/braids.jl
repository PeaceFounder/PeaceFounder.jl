
import ShuffleProofs
import ShuffleProofs: Braid, Simulator, BraidProof, ProtocolSpec
import CryptoGroups
import CryptoGroups: PGroup, ECGroup, ECP, MODP, Group

struct BraidBroker end # ToDo

#(::G)(g::Generator) where G <: Group = G(g.data)

_convert(::Type{G}, g::Generator) where G <: Group = G(g.data)
_convert(::Type{Vector{G}}, vect::Union{Vector{Pseudonym}, Set{Pseudonym}}) where G <: Group = G[G(i.pk) for i in vect]

group(spec::ECP) = CryptoGroups.specialize(ECGroup, spec)
#group(spec::ECP) = CryptoGroups.specialize(ECGroup, spec; name = :P_192)
group(spec::MODP) = CryptoGroups.specialize(PGroup, spec) 


struct BraidWork <: Transaction 
    braid::Simulator
    consumer::DemeSpec
    producer::DemeSpec
    approval::Union{Seal, Nothing}

    function BraidWork(braid::Simulator, consumer::DemeSpec, producer::DemeSpec)
        
        @assert braid.proposition isa Braid

        return new(braid, consumer, producer, nothing)
    end

    BraidWork(braid::Simulator, consumer::DemeSpec, producer::DemeSpec, ::Nothing) = BraidWork(braid, consumer, producer)

    BraidWork(braidwork::BraidWork, approval::Seal) = new(braidwork.braid, braidwork.consumer, braidwork.producer, approval)

    # Necessary for deserialization
    BraidWork(braid::Simulator, consumer::DemeSpec, producer::DemeSpec, approval) = new(braid, consumer, producer, approval)
end 


function braid(generator::Generator, members::Union{Vector{Pseudonym}, Set{Pseudonym}}, consumer::DemeSpec, producer::DemeSpec; verifier = (g) -> ProtocolSpec(; g))

    G = group(consumer.crypto.group)

    g = _convert(G, generator)
    m = _convert(Vector{G}, members)

    spec_g = G(consumer.crypto.generator.data)
    braid = ShuffleProofs.braid(g, m, verifier(spec_g))

    return BraidWork(braid, consumer, producer)
end


function approve(braidwork::BraidWork, braider::Signer)

    @assert pseudonym(braider) == braidwork.producer.braider
    @assert ShuffleProofs.verify(braidwork.braid) "Braid is not consistent."

    return BraidWork(braidwork, seal(braidwork, braider))
end


function braid(generator::Generator, members::Union{Vector{Pseudonym}, Set{Pseudonym}}, consumer::DemeSpec, producer::DemeSpec, braider::Signer)

    _braid = braid(generator, members, consumer, producer)
    _braid = approve(_braid, braider)

    return _braid
end


function verify(braidwork::BraidWork, crypto::CryptoSpec)

    @assert !isnothing(braidwork.approval) "Only signed braids can be verified"

    bytes = canonicalize(body(braidwork))
    verify(bytes, braidwork.approval, braidwork.producer.crypto) || return false

    pseudonym(braidwork.approval) == braidwork.producer.braider || return false

    ShuffleProofs.verify(braidwork.braid) || return false

    return true
end

input_generator(braidwork::BraidWork) = generator(ShuffleProofs.input_generator(braidwork.braid.proposition)) # |> Generator
input_members(braidwork::BraidWork) = Set(Pseudonym[pseudonym(i) for i in ShuffleProofs.input_members(braidwork.braid.proposition)])
output_generator(braidwork::BraidWork) = generator(ShuffleProofs.output_generator(braidwork.braid.proposition))
output_members(braidwork::BraidWork) = Set(Pseudonym[pseudonym(i) for i in ShuffleProofs.output_members(braidwork.braid.proposition)])


function Base.show(io::IO, braid::BraidWork)
    
    println(io, "BraidWork:")
    println(io, "  input_generator : $(string(input_generator(braid)))")
    #println(io, "  input_members : $(input_members(braid))")
    print(io, "  output_generator : $(string(output_generator(braid)))")
    #println(io, "  output_members : $(output_members(braid))")
    
end


function Base.push!(chain::BraidChain, braidwork::BraidWork)

    push!(chain.ledger, braidwork)
    push!(chain.tree, digest(braidwork, hasher(chain.spec)))

    chain.generator = output_generator(braidwork)
    chain.members = output_members(braidwork)

    return
end


function record!(chain::BraidChain, braidwork::BraidWork)

    @assert generator(chain) == input_generator(braidwork)
    @assert members(chain) == input_members(braidwork)

    @assert verify(braidwork, crypto(chain.spec)) "Braid is invalid"

    push!(chain, braidwork)

    return length(chain)
end
