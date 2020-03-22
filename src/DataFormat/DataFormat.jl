module DataFormat

using Pkg.TOML

using Base: UUID
import ..Types: SystemConfig, CertifierConfig, BraiderConfig, RecorderConfig, Port, AddressRecord, ip, PFID, Vote, Proposal, Braid
using PeaceVote: Notary, DemeSpec, Deme, datadir, Signer, Certificate, Contract, Intent, Consensus, Envelope, ID, DemeID
using ..Crypto

import Serialization


### Until the file fomrat is designed.
serialize(io::IO,x) = Serialization.serialize(io,x)
deserialize(io::IO) = Serialization.deserialize(io)
deserialize(io::IO,::Type) = deserialize(io)


configfname(uuid::UUID) = datadir(uuid) * "/PeaceFounder.toml" # In future could be PeaceFounder.toml


include("chaintypes.jl")
include("systemconfig.jl")


function Dict(config::Certificate)
    sdict = Dict(config.signature)
    dict = Dict(config.document)
    dict["signature"] = sdict
    return dict
end

function Certificate{T}(dict::Dict) where T <: Union{SystemConfig,PFID,Proposal,Vote}
    document = T(dict)
    signature = dict["signature"]
    return Certificate(document,signature)
end

function Dict(contract::Contract)
    dict = Dict(contract.document)

    signatures = Dict[]
    for s in contract.signatures
        push!(signatures,Dict(s))
    end
    dict["signatures"] = signatures
    
    return dict
end

function Contract{Braid}(dict::Dict)
    braid = Braid(dict)
    signatures = dict["signatures"]
    
    return Contract(braid,signatures)
end


function serialize(io::IOBuffer,x::Certificate{T}) where T<:Union{PFID,Proposal,Vote}
    dict = Dict(x)
    TOML.print(io, dict)
end

function deserialize(io::IOBuffer,::Type{Certificate{T}}) where T<:Union{PFID,Proposal,Vote}
    str = String(take!(io))
    dict = TOML.parse(str)
    return Certificate{T}(dict)
end


function serialize(io::IOBuffer,x::Contract{Braid}) 
    dict = Dict(x)
    TOML.print(io, dict)
end

function deserialize(io::IOBuffer,::Type{Contract{Braid}})
    str = String(take!(io))
    dict = TOML.parse(str)
    return Contract{Braid}(dict)
end


function serialize(deme::Deme,config::SystemConfig,signer::Signer)
    @assert deme.spec.maintainer==signer.id
    fname = configfname(deme.spec.uuid)
    mkpath(dirname(fname))
    
    sealedconfig = Certificate(config,signer)
    
    dict = Dict(sealedconfig)
    
    open(fname, "w") do io
        TOML.print(io, dict)
    end
end

### I could add function certify(deme::Deme,::Type{SystemConfig},maintainer::Signer) to load and add signature to the TOML file.


function deserialize(deme::Deme,::Type{SystemConfig})
    fname = configfname(deme.spec.uuid)
    @assert isfile(fname) "Config file not found!"

    dict = TOML.parsefile(fname)
    sc = Certificate{SystemConfig}(dict)

    intent = Intent(sc,deme.notary)
    #id = deme.notary.verify("$(sc.document)",sc.signature) 

    @assert intent.reference==deme.spec.maintainer
    return intent.document
end


export binary, loadbinary, serialize, deserialize

end
