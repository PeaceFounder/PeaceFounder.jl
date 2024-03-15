module Core

include("Model/Model.jl") # Client, Server, Audit
import .Model

include("ProtocolSchema.jl") # Client, Server
import .ProtocolSchema

include("Parser.jl") # Client, Server, Audit
import .Parser # Could be split into RecordParser and ReplyParser

# include("LedgerStore.jl")
# import .LedgerStore

include("AuditTools.jl") # Audit
import .AuditTools

end
