########## Theese methods belong to configuration folder ############

using DemeNet: Certificate, Intent, Signer, Deme
import DemeNet: serialize, deserialize

using PeaceVote.BraidChains: BraidChain, Ledger, getrecord, record!, readbootrecord, writebootrecord

# Directory could be obtained with a method. 

function binary(x)
    io = IOBuffer()
    serialize(io,x)
    return take!(io)
end

# A dity hack
# function serialize(ledger::Ledger,config::Certificate{PeaceFounderConfig})
#     fname = "PeaceFounder.toml"
#     bytes = binary(config)
#     record!(ledger,fname,bytes,1)
#     write(ledger.dir * "/" * fname, bytes)
# end

serialize(ledger::Ledger,config::Certificate{PeaceFounderConfig}) = writebootrecord(ledger,config)
#     fname = "PeaceFounder.toml"
#     bytes = binary(config)
#     record!(ledger,fname,bytes,1)
#     write(ledger.dir * "/" * fname, bytes)
# end

#serialize(ledger,config,"PeaceFounder.toml")

#serialize(ledger::Ledger,config::PeaceFounderConfig) = serialize(ledger,config,"PeaceFounder.toml")

function serialize(deme::Deme,config::PeaceFounderConfig) # #writebootrecord(ledger,config)
    uuid = deme.spec.uuid
    fname = datadir(uuid) * "/PeaceFounder.toml"
    mkpath(dirname(fname))

    io = IOBuffer()
    serialize(io,config)
    bytes = take!(io)

    write(fname,bytes)
    # open(fname, "w") do io
    #     return serialize(io,config)
    # end
end


function readbytes(fname::AbstractString)
    file = open(fname,"r") 
    data = UInt8[]
    while !eof(file)
        push!(data,read(file,UInt8))
    end
    close(file)
    return data
end



### Did this one worked?
function deserialize(deme::Deme,config::Type{PeaceFounderConfig})
    fname = datadir(deme.spec.uuid) * "/PeaceFounder.toml" 

    bytes = readbytes(fname)
    return deserialize(IOBuffer(bytes),PeaceFounderConfig)

    # open(fname, "r") do io
    #     return cert = deserialize(io,PeaceFounderConfig)
    # end
end

function deserialize(deme::Deme,config::Type{Certificate{PeaceFounderConfig}})
    fname = datadir(deme.spec.uuid) * "/PeaceFounder.toml" 
    
    bytes = readbytes(fname)
    return deserialize(IOBuffer(bytes),Certificate{PeaceFounderConfig})
    # open(fname, "r") do io
    #     @show readavailable(io)

    #     return cert = deserialize(io,Certificate{PeaceFounderConfig})
    # end
end

### I could unite theese two methods into one
deserialize(ledger::Ledger,type::Type{Certificate{PeaceFounderConfig}}) = readbootrecord(ledger,type)
#     rec = 
#     #rec = getrecord(ledger,"PeaceFounder.toml") # I did not update the ledger I guess
#     #println(String(copy(rec.data)))
#     deserialize(rec,type)
# end

deserialize(ledger::Ledger,type::Type{PeaceFounderConfig}) = readbootrecord(ledger,type)

# function deserialize(ledger::Ledger,type::Type{PeaceFounderConfig})
#     rec = readbootrecord(ledger)
#     #rec = getrecord(ledger,"PeaceFounder.toml")
#     deserialize(rec,type)
# end

function deserialize(chain::BraidChain,::Type{PeaceFounderConfig})
    sc = deserialize(chain.ledger,Certificate{PeaceFounderConfig})
    #@show sc #Is there a bug?
    #@show chain.deme.notary
    intent = Intent(sc,chain.deme.notary)
    @assert intent.reference==chain.deme.spec.maintainer
    return intent.document
end

#serialize(deme::BraidChain,config::PeaceFounderConfig) = serialize(deme.ledger,config)


# function certify(chain::BraidChain,signer::Signer)
#     @assert chain.deme.spec.maintainer==signer.id "You are not eligible to certify PeaceFounder.toml for this deme"
#     #sc = deserialize(chain.ledger,PeaceFounderConfig)
#     sc = readbootrecord(chain.ledger,PeaceFounderConfig)
#     cert = Certificate(sc,signer)
#     #serialize(chain.ledger,cert)
#     writebootrecord(chain.ledger,cert)
# end

