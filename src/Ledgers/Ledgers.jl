module Ledgers

#using ..Types: AbstractLedger
#using ..DataFormat

using Base: UUID
using DemeNet: datadir

#import ..Types: record!, records

import Synchronizers
using Synchronizers: Record

const SyncLedger = Synchronizers.Ledger

abstract type AbstractLedger end

### This part needs to be improved
#load(ledger::AbstractLedger) = error("Not impl") 
record!(ledger::AbstractLedger,fname::String,bytes::Vector{UInt8}) = error("Not impl")
records(ledger::AbstractLedger) = error("Not impl")


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


import DemeNet: serialize, deserialize

### An easy way to deal with stuff
configfname(uuid::UUID) = datadir(uuid) * "/PeaceFounder.toml" # In future could be PeaceFounder.toml

using Pkg.TOML
using Base: UUID
using ..Types: SystemConfig, CertifierConfig, BraiderConfig, RecorderConfig, Port, AddressRecord, ip, PFID, Vote, Proposal, Braid, BraidChain
using DemeNet: Notary, DemeSpec, Deme, datadir, Signer, Certificate, Contract, Intent, Consensus, Envelope, ID, DemeID, AbstractID


include("ledgers.jl")

function deserialize(chain::BraidChain,::Type{SystemConfig})
    sc = deserialize(chain.ledger,Certificate{SystemConfig})
    intent = Intent(sc,chain.deme.notary)
    @assert intent.reference==chain.deme.spec.maintainer
    return intent.document
end

serialize(deme::BraidChain,config::SystemConfig) = serialize(deme.ledger,config)


export Ledger, record!, dirname, basename

end
