module PeaceFounder

# ToDo
# - Add a maintainer port which would receive tookens. 
# - Couple thoose tookens with registration. So only a memeber with it can register. Make the server to issue the certificates on the members.
# - Write the server.jl file. Make it automatically generate the server key.
# - The server id will also be the uuid of the community subfolder. Need to extend PeaceVote so it woul support such generics. (keychain already has accounts. Seems only ledger would be necessary to be supported with id.)
# - A configuration file must be created during registration. So one could execute braid! and vote commands with keychain. That also means we need an account keyword for the keychain.
# - Test that the user can register if IP addreess, SERVER_ID and tooken is provided.


### Perhaps I could have a package CommunityUtils
#using Synchronizers: Synchronizer, Ledger, sync

using PeaceVote
#import PeaceVote.save
#using PeaceVote: datadir
using Base: UUID

using PeaceVote: AbstractProposal, AbstractID, AbstractVote
import PeaceVote: register, braid!, vote, propose, BraidChain, sync!
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


SystemConfig(deme::Deme) = DataFormat.deserialize(deme,Types.SystemConfig)

### Theese are methods which are used from PeaceVote API

const ThisDeme = PeaceVote.DemeType(@__MODULE__)

PeaceVote.Ledger(::Type{ThisDeme},uuid::UUID) = Ledgers.Ledger(uuid)

BraidChain(deme::ThisDeme) = BraidChains.BraidChain(deme)
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


function register(deme::ThisDeme,id::AbstractID,tooken)
    config = SystemConfig(deme).certifier
    @info "Spending tooken for certificate"
    cert = Certifiers.certify(config,deme,id,tooken)
    @info "Registering the certificate in the ledger"
    register(deme,cert)
end


include("debug.jl")

export register, braid!, propose, vote, BraidChain, members, count, sync!

end # module
