module DataFormat

using Pkg.TOML

using Base: UUID
import ..Types: SystemConfig, CertifierConfig, BraiderConfig, RecorderConfig, Port, AddressRecord, ip, PFID, Vote, Proposal, Braid, TookenID, AbstractLedger, BraidChain, record!, records
using PeaceVote.DemeNet: Notary, DemeSpec, Deme, datadir, Signer, Certificate, Contract, Intent, Consensus, Envelope, ID, DemeID, AbstractID
using ..Crypto

#using PeaceVote.Plugins: record!, records #, loadrecord
#import ..Types: load

import Base.Dict

configfname(uuid::UUID) = datadir(uuid) * "/PeaceFounder.toml" # In future could be PeaceFounder.toml

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


include("chaintypes.jl")
include("systemconfig.jl")
include("serialization.jl")
include("ledgers.jl")

export binary, loadbinary, serialize, deserialize

end
