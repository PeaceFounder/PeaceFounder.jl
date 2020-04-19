
### So I need to add some plugins for showing how stuff could work 

using DemeNet.Plugins: AbstractInitializer
import DemeNet.Plugins: Plugin


struct Init <: AbstractInitializer end

### This one is usefull by itself in the cases where the server chnges location. 
function init(::Init,deme::Deme,config::Dict) 
    error("ToDO")
end


### This command would 
function config(::Init,deme::Deme)
    ### Need to deserialize the config file for PeaceFounder
    error("ToDO")
end

### If I would store config with in the BraidChain I would not need to interface every method which is called. The same pattern then could be used for any kind of system


Plugin[@__MODULE__](type::Type{AbstractInitializer}) = Init
Plugin[@__MODULE__](type::Type{AbstractChain}) = BraidChain


