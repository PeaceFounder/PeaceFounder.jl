module DataFormat

using Pkg.TOML

using Base: UUID
import ..Types: SystemConfig, CertifierConfig, BraiderConfig, RecorderConfig, Port, AddressRecord, ip
using PeaceVote: Notary, DemeSpec, Deme, datadir, Signer, Certificate, Contract, Intent, Consensus, Envelope, ID, DemeID
using ..Crypto
#using ...PeaceFounder: SystemConfig

#const PeaceFounder = parentmodule(@__MODULE__)
#using PeaceFounder: SystemConfig

import Serialization

function binary(x)
    io = IOBuffer()
    Serialization.serialize(io,x)
    return take!(io)
end

loadbinary(data) = Serialization.deserialize(IOBuffer(data))


### Until the file fomrat is designed.
serialize(io::IO,x) = Serialization.serialize(io,x)
deserialize(io::IO) = Serialization.deserialize(io)

configfname(uuid::UUID) = datadir(uuid) * "/PeaceFounder.toml" # In future could be PeaceFounder.toml


include("systemconfig.jl")

### Signer could acompine a Sealed, unsealed type. 

function Dict(config::Certificate)
    sdict = Dict(config.signature)
    dict = Dict(config.document)
    dict["signature"] = sdict
    return dict
end

### I could have a function unseal to get the config I want
function Certificate{SystemConfig}(dict::Dict,notary::Notary)
    systemconfig = SystemConfig(dict)
    signature = notary.Signature(dict["signature"])
    return Certificate(systemconfig,signature)
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
    sc = Certificate{SystemConfig}(dict,deme.notary)

    id = deme.notary.verify("$(sc.document)",sc.signature) 

    @assert id==deme.spec.maintainer
    return sc.document
end


export binary, loadbinary, serialize, deserialize

end
