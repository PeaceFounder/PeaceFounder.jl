### Cryptographic definitions
using CryptoGroups
using Random
using Serialization: serialize, deserialize
using DiffieHellman

using PeaceVote: Notary
import PeaceVote


### Currently, a following cryptographic definitions are fixed
# - Cryptographic group
# - Random number generator 
# - SecureSocket.
### Theese are all definitions which are used to construct DH object. 

#import CryptoSignatures 

# Theese are Diffie-Hellman definitions. A choice could be given and specified at the config file. 

function str(x)
    io = IOBuffer()
    serialize(io,x)
    bytes = take!(io)
    return String(bytes)
end

function rngint(len::Integer)
    max_n = ( BigInt(1) << len ) - 1
    if len > 2
        min_n = BigInt(1) << (len - 1)
        return rand(min_n:max_n)
    end
    return rand(1:max_n)
end


#G = CryptoGroups.MODP160Group()
const G = CryptoGroups.Scep256k1Group() 

# I could simply define Notary for this namespace to be a union type.

sign(data::AbstractString,signer::Signer) = signer.sign(data)
sign(data::Int,signer::Signer) = PeaceVote.sign("$data",signer)
sign(data,signer::Signer) = sign(str(data),signer)

verify(data::AbstractString,signature,deme::Notary) = deme.verify(data,signature)
verify(data::Int,signature,deme::Notary) = PeaceVote.verify("$data",signature,deme)
verify(data,signature,deme::Notary) = verify(str(data),signature,deme)

hash(data::AbstractString,deme::Notary) = deme.hash(data)
hash(data::Int,deme::Notary) = PeaceVote.hash("$data",deme)
hash(data,deme::Notary) = hash(str(data),deme)

hash(envelopeA,envelopeB,key,deme::Notary) = PeaceVote.hash("$envelopeA $envelopeB $key",deme)

#Signer() = CryptoSignatures.Signer(G)

#id(s) = hash(s.pubkey)

#Signature(x,signer) = CryptoSignatures.DSASignature(hash(x),signer)

# verify(signature) = CryptoSignatures.verify(signature,G)
# verify(data,signature) = verify(signature) && hash(data)==signature.hash

# I need wrap and unwrap methods


### Need to extend thoose definitions so the would first convert data to a string and wrap back.

function unwrap(envelope,notary::Notary)
    data, signature = envelope
    id = verify(data,signature,notary)
    return data, id
end

import DiffieHellman.DH


DHsym(notary::Notary,signer::Signer) = DH(data->(data,sign(data,signer)),x->unwrap(x,notary),G,(x,y,z)->hash(x,y,z,notary),()->rngint(100))
DHasym(notary::Notary) = DH(identity,x->unwrap(x,notary),G,(x,y,z)->hash(x,y,z,notary),()->rngint(100))
DHasym(notary::Notary,signer::Signer) = DH(data->(data,sign(data,signer)),x->(x,nothing),G,(x,y,z)->hash(x,y,z,notary),()->rngint(100))
