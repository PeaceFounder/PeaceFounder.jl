module Model
# All interesting stuff

# A patch to Base. An alternative is to patch JSON3.jl 

using StructHelpers

using JSON3, StructTypes # used temporaraly for canonicalize

using Nettle
using Dates
using Setfield

using HistoryTrees

using Infiltrator

# Proposals and Braids can be treated the same way as they are in a blockchain as proofs of work.


# I could implement that in the library
using HistoryTrees: InclusionProof, ConsistencyProof
@batteries InclusionProof
@batteries ConsistencyProof

# Note that admission is within a member as it's necessary to 


function Base.show(io::IO, proof::InclusionProof)

    println(io, "InclusionProof:")
    println(io, "  index : $(proof.index)")
    println(io, "  leaf : $(string(proof.leaf))")
    print(io, "  path : $([string(i) for i in proof.path])")

end

function Base.show(io::IO, proof::ConsistencyProof)

    println(io, "ConsistencyProof:")
    println(io, "  index : $(proof.index)")
    println(io, "  root : $(string(proof.root))")
    print(io, "  path : $([string(i) for i in proof.path])")

end



function show_string(x)

    buffer = IOBuffer()
    show(buffer, x)
    str = String(take!(buffer))
    
    indended_str = "  " * join(split(str, "\n"), "\n  ")

    return indended_str
end


include("crypto.jl")
include("admissions.jl")
include("braidchains.jl")
include("proposals.jl")
include("dealer.jl")
include("braids.jl")
include("seal.jl") # Defines how values should be canonicalized. Could contain means for a signer with a state.


struct Deme
    uuid::UUID
    title::String
    guardian::Pseudonym
    crypto::Crypto
    cert # TLS certificate used for communication
    #seal::Union{Seal, Nothing}
end

Base.:(==)(x::Deme, y::Deme) = x.uuid == y.uuid && x.title == y.title && x.guardian == y.guardian && x.crypto == y.crypto && x.cert == y.cert

Deme(title::String, guardian::Pseudonym, crypto::Crypto) = Deme(UUID(rand(1:10000)), title, guardian, crypto, nothing)

function Base.show(io::IO, deme::Deme)

    println(io, "Deme:")
    println(io, "  title : $(deme.title)")
    println(io, "  uuid : $(deme.uuid)")
    println(io, "  guardian : $(string(deme.guardian))")
    println(io, "  cert : $(deme.cert)")
    print(io, show_string(deme.crypto))

end

crypto(deme::Deme) = deme.crypto
hasher(deme::Deme) = hasher(deme.crypto)

isbinding(ack::AckInclusion{ChainState}, deme::Deme) = issuer(ack) == deme.guardian
isbinding(record::Transaction, ack::AckInclusion{ChainState}, deme::Deme) = isbinding(ack, deme) && isbinding(record, ack, hasher(deme))

isbinding(admission::Admission, deme::Deme) = issuer(admission) == deme.guardian

isbinding(commit::Commit{ChainState}, deme::Deme) = issuer(commit) == deme.guardian


end
