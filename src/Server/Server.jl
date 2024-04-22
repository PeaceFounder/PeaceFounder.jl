module Server

import ..Core
import ..StaticSets
import ..Authorization
import ..Schedulers
import ..TempAccessCodes

include("Controllers/Controllers.jl")
import .Controllers

include("Mapper.jl") # Server
import .Mapper

include("Service.jl") # Server
import .Service

end
