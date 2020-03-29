module PeaceFounder

using PeaceVote
using Base: UUID

using PeaceVote: AbstractProposal, AbstractID, AbstractVote
import PeaceVote: register, braid!, vote, propose, BraidChain, sync!, load
import Base.count

include("Types/Types.jl")
include("Crypto/Crypto.jl")
include("DataFormat/DataFormat.jl") 
include("Braiders/Braiders.jl")
include("Certifiers/Certifiers.jl") 
include("Ledgers/Ledgers.jl") 
include("BraidChains/BraidChains.jl") 
include("Analysis/Analysis.jl") 
include("MaintainerTools/MaintainerTools.jl") ### A thing which maintainer would use to set up the server, DemeSpec file, some interactivity, logging and etc. 

using .Types: PFID, Port

SystemConfig(deme::Deme) = DataFormat.deserialize(deme,Types.SystemConfig)

### Theese are methods which are used from PeaceVote API

const ThisDeme = PeaceVote.DemeType(@__MODULE__)

PeaceVote.Ledger(::Type{ThisDeme},uuid::UUID) = Ledgers.Ledger(uuid)

load(ledger::Ledgers.Ledger) = DataFormat.load(ledger)

#BraidChain(deme::ThisDeme) = BraidChains.BraidChain(deme)
braid!(deme::ThisDeme,voter::Signer,signer::Signer) = Braiders.braid!(SystemConfig(deme).braider,deme,voter,signer)
register(deme::ThisDeme,cert::Certificate{T}) where T<:AbstractID = BraidChains.register(SystemConfig(deme).recorder,cert)
propose(deme::ThisDeme,proposal::AbstractProposal,signer::Signer) = BraidChains.propose(SystemConfig(deme).recorder,proposal,signer)
vote(deme::ThisDeme,option::AbstractVote,signer::Signer) = BraidChains.vote(SystemConfig(deme).recorder,option,signer)
count(index::Int,proposal::AbstractProposal,deme::ThisDeme) = Analysis.normalcount(index,proposal,deme)

sync!(deme::ThisDeme,syncport) = Ledgers.sync!(deme.ledger,syncport)

function sync!(deme::ThisDeme)
    config = SystemConfig(deme)
    sync!(deme,config.syncport)    
end

sync!(deme::ThisDeme,syncport::Dict) = sync!(deme,Port(syncport))

function register(deme::ThisDeme,id::PFID,tooken::Int)
    config = SystemConfig(deme).certifier
    @info "Spending tooken for a certificate"
    cert = Certifiers.certify(config,deme,id,tooken)
    @info "Registering the certificate in the ledger"
    register(deme,cert)
end

register(deme::ThisDeme,profile::Profile,id::ID,tooken::Int) = register(deme,PFID(profile.name,profile.date,id),tooken)

include("debug.jl")

export register, braid!, propose, vote, BraidChain, members, count, sync!, load

end # module
