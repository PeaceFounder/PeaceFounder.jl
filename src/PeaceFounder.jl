module PeaceFounder

#using PeaceVote
using Base: UUID

using PeaceVote.Plugins: AbstractProposal, AbstractVote
using DemeNet: AbstractID, Deme, Signer, Profile, Certificate, ID, deserialize
#using Recruiters: certify,
import Recruiters
import PeaceVote: register, braid!, vote, propose, sync!, load
import Base.count

#include("Crypto/Crypto.jl")
include("Types/Types.jl")
#include("DataFormat/DataFormat.jl") 
include("Braiders/Braiders.jl")
include("Ledgers/Ledgers.jl") 
include("BraidChains/BraidChains.jl") 
include("Analysis/Analysis.jl") 
include("MaintainerTools/MaintainerTools.jl") ### A thing which maintainer would use to set up the server, DemeSpec file, some interactivity, logging and etc. 

using .Types: PFID, Port, BraidChain
#using .Ledgers: load

SystemConfig(deme::BraidChain) = deserialize(deme,Types.SystemConfig)

### Theese are methods which are used from PeaceVote API

#const ThisDeme = PeaceVote.DemeType(@__MODULE__)

#PeaceVote.Ledger(::Type{ThisDeme},uuid::UUID) = Ledgers.Ledger(uuid)

#load(ledger::Ledgers.Ledger) = DataFormat.load(ledger)

#load(braidchain::BraidChain) = 

#BraidChain(deme::ThisDeme) = BraidChains.BraidChain(deme)
braid!(chain::BraidChain,voter::Signer,signer::Signer) = Braiders.braid!(SystemConfig(chain).braider,chain.deme,voter,signer)

### I could rename thoose with a simple chain 
register(deme::BraidChain,cert::Certificate{T}) where T<:AbstractID = BraidChains.register(SystemConfig(deme).recorder,cert)
propose(chain::BraidChain,proposal::AbstractProposal,signer::Signer) = BraidChains.propose(SystemConfig(chain).recorder,proposal,signer)
vote(deme::BraidChain,option::AbstractVote,signer::Signer) = BraidChains.vote(SystemConfig(deme).recorder,option,signer)

load(chain::BraidChain) = Ledgers.load(chain.ledger)
count(index::Int,deme::BraidChain) = Analysis.normalcount(index,deme)
### I actually do not need to put in the proposal! It would be determined from the index!!!


sync!(deme::BraidChain,syncport) = Ledgers.sync!(deme.ledger,syncport)

function sync!(deme::BraidChain)
    config = SystemConfig(deme)
    sync!(deme,config.syncport)    
end

sync!(deme::BraidChain,syncport::Dict) = sync!(deme,Port(syncport))

### I will end up to put in the PeaceVote
# function register(invite::AbstractString,profile::Profile;account="")
#     Recruiters.register(invite,profile;account=account)
# end

# function register(chain::BraidChain,id::PFID,tooken::Int)
#     config = SystemConfig(chain).certifier
#     @info "Spending tooken for a certificate"
#     cert = certify(config,chain.deme,id,tooken)
#     @info "Registering the certificate in the ledger"
#     register(chain,cert)
# end

#register(deme::BraidChain,profile::Profile,id::ID,tooken::Int) = register(deme,PFID(profile.name,profile.date,id),tooken)

include("debug.jl")

export register, braid!, propose, vote, BraidChain, members, count, sync!, load

end # module
