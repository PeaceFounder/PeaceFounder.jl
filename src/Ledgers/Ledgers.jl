module Ledgers

using ..Types: AbstractLedger
using ..DataFormat

using Base: UUID
using PeaceVote.DemeNet: datadir

import ..Types: record!, records

import Synchronizers
using Synchronizers: Record

const SyncLedger = Synchronizers.Ledger

struct Ledger <: AbstractLedger
    dir::AbstractString
    ledger::SyncLedger
end

function Ledger(dir::AbstractString)
    ledger = SyncLedger(dir)
    return Ledger(dir,ledger)
end

Ledger(uuid::UUID) = Ledger(datadir(uuid))

record!(ledger::Ledger,fname::String,data::Vector{UInt8}) = push!(ledger.ledger,Record(fname,data))
records(ledger::Ledger) = ledger.ledger.records # One can pass that 

import Base: dirname, basename
dirname(record::Record) = dirname(record.fname)
basename(record::Record) = basename(record.fname)


serve(port,ledger::Ledger) = Synchronizers.serve(port,ledger.ledger)
sync!(ledger::Ledger,syncport) = Synchronizers.sync(Synchronizers.Synchronizer(syncport,ledger.ledger))

export Ledger, record!, dirname, basename

end
