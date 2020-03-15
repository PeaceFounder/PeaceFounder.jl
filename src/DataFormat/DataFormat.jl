module DataFormat

using Pkg.TOML

using Base: UUID
import ..Types: SystemConfig, Sealed, CertifierConfig, BraiderConfig, RecorderConfig, Port, AddressRecord, ip
using PeaceVote: Notary, DemeSpec, Deme, datadir, Signer
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

function serialize(deme::Deme,config::SystemConfig,signer::Signer)
    @assert deme.spec.maintainer==signer.id
    fname = configfname(deme.spec.uuid)
    mkpath(dirname(fname))
    
    sealedconfig = Sealed{SystemConfig}(config,signer)
    
    dict = Dict(sealedconfig)
    
    open(fname, "w") do io
        TOML.print(io, dict)
    end
end


function deserialize(deme::Deme,::Type{SystemConfig})
    fname = configfname(deme.spec.uuid)
    @assert isfile(fname) "Config file not found!"

    dict = TOML.parsefile(fname)
    sc = Sealed{SystemConfig}(dict,deme.notary)

    id = deme.notary.verify("$(sc.data)",sc.signature) 

    @assert id==deme.spec.maintainer
    return sc.data
end


export binary, loadbinary, serialize, deserialize

end
