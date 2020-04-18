module PeaceFounder

### Internal modules
include("BraidChains/BraidChains.jl")


### The rest of the code

include("types.jl")
include("serialization.jl")
include("tools.jl")

import .BraidChains: record
record(config::PeaceFounderConfig,data) = record(config.braidchain,data)

using .BraidChains: BraidChain
import ..BraidChains: sync!
sync!(chain::BraidChain,config::PeaceFounderConfig) = sync!(chain,config.braidchain.syncport)



end # module
