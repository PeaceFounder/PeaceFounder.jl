using PeaceVote
using PeaceFounder

### No need to save anything
# function reset(deme::ThisDeme)
#     uuid = deme.spec.uuid
#     dir = PeaceVote.datadir(uuid)
#     isdir(dir) && rm(dir,recursive=true)
# end

### First we need to define a Notary

crypto = quote
G = CryptoGroups.Scep256k1Group()
hash(x::AbstractString) = parse(BigInt,Nettle.hexdigest("sha256",x),base=16)

Signer() = CryptoSignatures.Signer(G)
Signature(x::AbstractString,signer) = CryptoSignatures.DSASignature(hash(x),signer)
verify(data,signature) = CryptoSignatures.verify(signature,G) && hash(data)==signature.hash ? hash("$(signature.pubkey)") : nothing

(Signer,Signature,verify,hash)
end

deps = Symbol[:Nettle,:CryptoGroups,:CryptoSignatures]

notary = Notary(crypto,deps)
demespec = DemeSpec("PeaceDeme",crypto,deps,:PeaceFounder,notary)
save(demespec) ### Necessary to connect with Mixer

deme = Deme(demespec,notary,nothing)

### Now we can configure our server

uuid = demespec.uuid

### Somewhere far far away
mixer = PeaceVote.Signer(uuid,notary,"mixer")
mixerserver = PeaceFounder.Mixer(1999,notary,mixer)

### 
server = PeaceVote.Signer(uuid,notary,"server")

MIXER_ID = mixer.invoke.id
SERVER_ID = server.invoke.id

config = PeaceFounder.BraiderConfig(1998,1999,3,SERVER_ID,(uuid,MIXER_ID))

braider = PeaceFounder.Braider(config,notary,server)

for i in 1:3
    account = "account$i"
    member = Signer(deme,account * "/member")
    push!(braider.voters,member.invoke.id)
end

# ### Users do:

@sync for i in 1:3
    @async begin
        account = "account$i"
        member = Signer(deme,account * "/member")
        voter = Signer(deme,account * "/voters/$(member.invoke.id)")
        braid!(config,notary,voter,member)
    end
end

### After that gatekeeper gets ballot

@show take!(braider)

