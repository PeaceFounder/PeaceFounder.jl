# Simple startup script

import QML 
include("src/GUI.jl")

GUI.load_view() do

    GUI.setHome()

end
