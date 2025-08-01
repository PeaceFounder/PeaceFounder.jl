import ShuffleProofs
import ShuffleProofs: Braid, Simulator, BraidProof, ProtocolSpec
import CryptoGroups
import CryptoGroups: PGroup, ECGroup, ECP, MODP, Group


_convert(::Type{G}, g::Generator) where G <: Group = G(g.data)
_convert(::Type{Vector{G}}, vect::Union{Vector{Pseudonym}, Set{Pseudonym}}) where G <: Group = G[G(i.pk) for i in vect]


group(spec::ECP) = CryptoGroups.concretize_type(ECGroup, spec)
group(spec::MODP) = CryptoGroups.concretize_type(PGroup, spec) 

#group(spec::ECP) = CryptoGroups.specialize(ECGroup, spec)
#group(spec::MODP) = CryptoGroups.specialize(PGroup, spec) 

"""
    struct BraidReceipt <: Transaction
        braid::Simulator
        reset::Bool
        producer::DemeSpec
        approval::Union{Seal, Nothing}
    end

Represents a braider's computation which is supported with zero knowledge proof of shuffle and decryption assuring it's corectness
stored in a `braid` field; `producer` denotes a deme where the braid is made. To assert latter the the braider signs the 
braidwork and stores that in the `aproval` field. See a [`braid`](@ref) method.

**Interface:** [`approve`](@ref), [`verify`](@ref), [`input_generator`](@ref), [`input_members`](@ref), [`output_generator`](@ref), [`output_members`](@ref)
"""
struct BraidReceipt <: Transaction 
    braid::Simulator
    reset::Bool
    producer::Union{DemeSpec, Nothing}
    approval::Union{Seal, Nothing}

    #function BraidReceipt(braid::Simulator, consumer::DemeSpec, producer::DemeSpec)
    function BraidReceipt(braid::Simulator, reset::Bool = false)
        
        @assert braid.proposition isa Braid

        return new(braid, reset, nothing, nothing)
    end

    BraidReceipt(braidwork::BraidReceipt, producer::DemeSpec, approval::Seal) = new(braidwork.braid, braidwork.reset, producer, approval)

    BraidReceipt(braid::Simulator, reset::Bool, producer::DemeSpec, approval::Seal) = new(braid, reset, producer, approval)
end 

@batteries BraidReceipt

issuer(braid::BraidReceipt) = issuer(braid.approval)

@doc raw"""
    braid(generator::Generator, members::Union{Vector{Pseudonym}, Set{Pseudonym}}, consumer::DemeSpec, producer::DemeSpec; verifier = (g) -> ProtocolSpec(; g))

Selects a private exponent `x` at random and computes a new generator $g' = g^x$ and $member_i'=member_i^x$ 
returns the latter in a sorted order and provides a zero knowledge proof that all operations have been performed honestly. 
In partucular, not including/droping new member pseudonyms in the process. `consumer` attributes are necessary to 
interepret generator and pseudonym group elements with which the computation is performed. 

By default a Verificatum compatable verifier is used for performing reencryption proof of shuffle

A verifier can be configured with a keyword argument. By default a Verificatum compatable verifier for a proof of shuffle is used.
"""
function braid(generator::Generator, members::Union{Vector{Pseudonym}, Set{Pseudonym}}, crypto::CryptoSpec; verifier = (g) -> ProtocolSpec(; g), reset = false)

    G = group(crypto.group)

    g = _convert(G, generator)
    m = _convert(Vector{G}, members)

    spec_g = G(crypto.generator.data)
    #braid = ShuffleProofs.braid(g, m, verifier(spec_g))
    braid = ShuffleProofs.braid(m, g, verifier(spec_g))

    return BraidReceipt(braid, reset)#, consumer, producer)
end

"""
    approve(braid::BraidReceipt, spec::DemeSpec, braider::Signer)

Sign a braidwork with a braider. Throws an error if braider is not in the `producer` demespec.
"""
function approve(braidwork::BraidReceipt, spec::DemeSpec, braider::Signer)

    @assert pseudonym(braider) == spec.braider
    @assert ShuffleProofs.verify(braidwork.braid) "Braid is not consistent."

    return BraidReceipt(braidwork, spec, seal(braidwork, braider))
end


function braid(generator::Generator, members::Union{Vector{Pseudonym}, Set{Pseudonym}}, crypto::CryptoSpec, origin::DemeSpec, braider::Signer; reset = false)

    _braid = braid(generator, members, crypto; reset)
    _braid = approve(_braid, origin, braider)

    return _braid
end


"""
    verify(braid::BraidReceipt, crypto::CryptoSpec)

Verifies a braid approval and then it's zero knowledge proofs. A `crypto` argument is 
provided to avoid downgrading attacks. 
"""
function verify(braidwork::BraidReceipt, crypto::CryptoSpec; skip_braid::Bool = false) 

    @assert !isnothing(braidwork.approval) "Only signed braids can be verified"

    _digest = digest(body(braidwork), crypto)
    verify(bytes(_digest), braidwork.approval, braidwork.producer.crypto) || return false

    # Theese hings perhaps should be within a constructor of each type!
    pseudonym(braidwork.approval) == braidwork.producer.braider || return false
    
    braidwork.braid.verifier == ProtocolSpec(g = braidwork.braid.verifier.g) || return false
    typeof(braidwork.braid.verifier.g) == group(crypto.group) || return false

    if !skip_braid
        ShuffleProofs.verify(braidwork.braid) || return false
    end

    return true
end

"""
    input_generator(braid::BraidReceipt)

Return input generator of the braid.
"""
input_generator(braidwork::BraidReceipt) = generator(ShuffleProofs.input_generator(braidwork.braid.proposition)) # |> Generator

"""
    input_members(braid::BraidReceipt)

Return input member pseudonyms of the braid at provided input generator. See [`input_generator`](@ref)
"""
input_members(braidwork::BraidReceipt) = Pseudonym[pseudonym(i) for i in ShuffleProofs.input_members(braidwork.braid.proposition)]

"""
    output_generator(braid::BraidReceipt)

Return output genertor of the braid.
"""
output_generator(braidwork::BraidReceipt) = generator(ShuffleProofs.output_generator(braidwork.braid.proposition))

"""
    output_members(braid::BraidReceipt)

Return output member pseudonyms of the braid at a resulting output generator. See [`output_generator`](@ref)
"""
output_members(braidwork::BraidReceipt) = Pseudonym[pseudonym(i) for i in ShuffleProofs.output_members(braidwork.braid.proposition)]


function Base.show(io::IO, braid::BraidReceipt)
    
    println(io, "BraidReceipt:")
    println(io, "  input_generator : $(string(input_generator(braid)))")
    #println(io, "  input_members : $(input_members(braid))")
    print(io, "  output_generator : $(string(output_generator(braid)))")
    #println(io, "  output_members : $(output_members(braid))")
    
end




