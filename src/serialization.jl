########## Theese methods belong to configuration folder ############

using DemeNet: Certificate, Intent, Signer
import DemeNet: serialize, deserialize

using .BraidChains: BraidChain, Ledger, getrecord, record!

# Directory could be obtained with a method. 

function binary(x)
    io = IOBuffer()
    serialize(io,x)
    return take!(io)
end

# A dity hack
function serialize(ledger::Ledger,config::Certificate{PeaceFounderConfig})
    fname = "PeaceFounder.toml"
    bytes = binary(config)
    record!(ledger,fname,bytes,1)
    write(ledger.dir * "/" * fname, bytes)
end

#serialize(ledger,config,"PeaceFounder.toml")

serialize(ledger::Ledger,config::PeaceFounderConfig) = serialize(ledger,config,"PeaceFounder.toml")


function deserialize(ledger::Ledger,type::Type{Certificate{PeaceFounderConfig}})
    rec = getrecord(ledger,"PeaceFounder.toml") # I did not update the ledger I guess
    #println(String(copy(rec.data)))
    deserialize(rec,type)
end

function deserialize(ledger::Ledger,type::Type{PeaceFounderConfig})
    rec = getrecord(ledger,"PeaceFounder.toml")
    deserialize(rec,type)
end


function deserialize(chain::BraidChain,::Type{PeaceFounderConfig})
    sc = deserialize(chain.ledger,Certificate{PeaceFounderConfig})
    #@show sc #Is there a bug?
    #@show chain.deme.notary
    intent = Intent(sc,chain.deme.notary)
    @assert intent.reference==chain.deme.spec.maintainer
    return intent.document
end

serialize(deme::BraidChain,config::PeaceFounderConfig) = serialize(deme.ledger,config)


function certify(chain::BraidChain,signer::Signer)
    @assert chain.deme.spec.maintainer==signer.id "You are not eligible to certify PeaceFounder.toml for this deme"
    sc = deserialize(chain.ledger,PeaceFounderConfig)
    cert = Certificate(sc,signer)
    serialize(chain.ledger,cert)
end

