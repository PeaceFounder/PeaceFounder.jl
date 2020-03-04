module Ledgers

# At the moment seems reasonable that the layout of data is independent of BraidChains. Perhaps one coul make a ledger which is human readable and other which uses some compression algorithm knowing what kind of data to expect. Also BraidChains are already complex, but this submodule is simple. The only necessity is to define the types of elements which would sit in the BraidChain. Thus both BraidChains and Ledgers would need to depend on the PeaceFounder. That seems perfectly fine since theese packages are used independently, but together with PeaceFounder.

using ..DataFormat

using Base: UUID
using PeaceVote: AbstractLedger, datadir
import PeaceVote: record!, records, loadrecord

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


#using Synchronizers: Ledger # I can use AbstractLedger from PeaceVote. On the other hand at the present stage I could leave such a raw dependencies until I gte everything up and running.
# This module wraps Synchronizers for defining the storafge format for a different types of data 



import Synchronizers.Record
Record(fname::AbstractString,x) = Record(fname,binary(x))

### Theese ones one can define as AbstractLedger interface (for simplicity one imports them from PeaceFounder until better names comes in.
record!(ledger::Ledger,fname::AbstractString,data) = push!(ledger.ledger,Record(fname,data))
records(ledger::Ledger) = ledger.ledger.records # One can pass that 

import Base: dirname, basename
dirname(record::Record) = dirname(record.fname)
basename(record::Record) = basename(record.fname)

loadrecord(record::Record) = loadbinary(record.data)

export Ledger, record!, loadrecord, dirname, basename

end
