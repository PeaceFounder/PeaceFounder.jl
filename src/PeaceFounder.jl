module PeaceFounder

# ToDo
# - Add a maintainer port which would receive tookens. 
# - Couple thoose tookens with registration. So only a memeber with it can register. Make the server to issue the certificates on the members.
# - Write the server.jl file. Make it automatically generate the server key.
# - The server id will also be the uuid of the community subfolder. Need to extend PeaceVote so it woul support such generics. (keychain already has accounts. Seems only ledger would be necessary to be supported with id.)
# - A configuration file must be created during registration. So one could execute braid! and vote commands with keychain. That also means we need an account keyword for the keychain.
# - Test that the user can register if IP addreess, SERVER_ID and tooken is provided.


### Perhaps I could have a package CommunityUtils
using Synchronizers: Synchronizer, Ledger, sync

using PeaceVote
import PeaceVote.save
using PeaceVote: datadir

import PeaceVote: register, braid!, vote, propose

const ThisDeme = PeaceVote.DemeType(@__MODULE__)

include("Crypto/Crypto.jl")
include("Braiders/Braiders.jl")
include("Certifiers/Certifiers.jl") 
include("DataFormat/DataFormat.jl") 
include("Ledgers/Ledgers.jl") 
include("BraidChains/BraidChains.jl") 
include("MaintainerTools/MaintainerTools.jl") ### A thing which maintainer would use to set up the server, DemeSpec file, some interactivity, logging and etc. 


### Not sure if thoose generics should belong to PeaceVote
#function load end 


braid!(deme::ThisDeme,voter::Signer,signer::Signer) = Braiders.braid!(deme,voter,signer)


include("debug.jl")

export register, braid!, propose, vote, braidchain, members, count, sync!, Ledger

end # module
