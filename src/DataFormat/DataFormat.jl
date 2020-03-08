module DataFormat

using Base: UUID
using ..Types: SystemConfig
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

configfname(uuid::UUID) = datadir(uuid) * "/PeaceFounder" # In future could be PeaceFounder.toml

function deserialize(deme::Deme,::Type{SystemConfig})
    fname = configfname(deme.spec.uuid)
    @assert isfile(fname) "Config file not found!"
    config, signature = Serialization.deserialize(fname)
    id = verify(config,signature,deme.notary) 
    @assert id==deme.spec.maintainer
    return config
end

### I could call this thing serialize
# serialize(fname::AbstractString,config::SystemConfig,signer::Signer)
# I could use AbstractLedger type with record! method. Passing deme would also be desirable as one could check that the signer of the config file is in the demespec. 
function serialize(deme::Deme,config::SystemConfig,signer::Signer)
    @assert deme.spec.maintainer==signer.id
    fname = configfname(deme.spec.uuid)
    mkpath(dirname(fname))
    signature = sign(config,signer)
    Serialization.serialize(fname,(config,signature))
end


export binary, loadbinary, serialize, deserialize

end
