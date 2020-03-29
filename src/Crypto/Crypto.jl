module Crypto

using DiffieHellman
using PeaceVote: Notary, Cypher, Signer, Deme
import PeaceVote

using Pkg.TOML

### Currently, a following cryptographic definitions are fixed
# - Cryptographic group
# - Random number generator 
# - SecureSocket.
### Theese are all definitions which are used to construct DH object. 

#import CryptoSignatures 

# Theese are Diffie-Hellman definitions. A choice could be given and specified at the config file. 

str(x) = "$x"

# function rngint(len::Integer)
#     max_n = ( BigInt(1) << len ) - 1
#     if len > 2
#         min_n = BigInt(1) << (len - 1)
#         return rand(min_n:max_n)
#     end
#     return rand(1:max_n)
# end


# #G = CryptoGroups.MODP160Group()
# const G = CryptoGroups.Scep256k1Group() 

# I could simply define Notary for this namespace to be a union type.

import Base.sign

sign(data::AbstractString,signer::Signer) = signer.sign(data)
sign(data::Int,signer::Signer) = PeaceVote.sign("$data",signer)
sign(data,signer::Signer) = sign(str(data),signer)

verify(data::AbstractString,signature,deme::Notary) = deme.verify(data,signature)
verify(data::Int,signature,deme::Notary) = PeaceVote.verify("$data",signature,deme)
verify(data,signature,deme::Notary) = verify(str(data),signature,deme)

import Base.hash

hash(data::AbstractString,deme::Notary) = deme.hash(data)
hash(data::Int,deme::Notary) = PeaceVote.hash("$data",deme)
hash(data,deme::Notary) = hash(str(data),deme)


function hash(x,y,z,notary::Notary)
    inthash = notary.hash("$x $y $z")
    strhash = string(inthash,base=16)
    return Vector{UInt8}(strhash)
end


#hash(envelopeA,envelopeB,key,deme::Notary) = hash("$envelopeA $envelopeB $key",deme)

#Signer() = CryptoSignatures.Signer(G)

#id(s) = hash(s.pubkey)

#Signature(x,signer) = CryptoSignatures.DSASignature(hash(x),signer)

# verify(signature) = CryptoSignatures.verify(signature,G)
# verify(data,signature) = verify(signature) && hash(data)==signature.hash

# I need wrap and unwrap methods


### Need to extend thoose definitions so the would first convert data to a string and wrap back.

# function unwrap(envelope,notary::Notary)
#     data, signature = envelope
#     id = verify(data,signature,notary)
#     return data, id
#end


function wrapsigned(value::BigInt,signer::Signer)
    signature = sign(value,signer)
    signaturedict = Dict(signature)
    dict = Dict("value"=>string(value,base=16),"signature"=>signaturedict)
    io = IOBuffer()
    TOML.print(io,dict)
    return take!(io)
end

function unwrapsigned(envelope::Vector{UInt8},notary::Notary)
    dict = TOML.parse(String(copy(envelope)))
    value = parse(BigInt,dict["value"],base=16)
    signature = notary.Signature(dict["signature"])
    id = verify(value,signature,notary) ### The id is of ID type thus there shall be no problem
    return value, id
end

wrapmsg(value::BigInt) = Vector{UInt8}(string(value,base=16))
unwrapmsg(envelope::Vector{UInt8}) = parse(BigInt,String(copy(envelope)),base=16), nothing


# DHsym(cypher::Cypher,notary::Notary,signer::Signer) = DH(data->(data,sign(data,signer)),x->unwrap(x,notary),cypher.G,(x,y,z)->hash(x,y,z,notary),cypher.rng)
# DHasym(cypher::Cypher,notary::Notary) = DH(identity,x->unwrap(x,notary),cypher.G,(x,y,z)->hash(x,y,z,notary),cypher.rng)
# DHasym(cypher::Cypher,notary::Notary,signer::Signer) = DH(data->(data,sign(data,signer)),x->(x,nothing),cypher.G,(x,y,z)->hash(x,y,z,notary),cypher.rng)


DHsym(cypher::Cypher,notary::Notary,signer::Signer) = DH(value->wrapsigned(value,signer),x->unwrapsigned(x,notary),cypher.G,(x,y,z)->hash(x,y,z,notary),cypher.rng)
DHasym(cypher::Cypher,notary::Notary) = DH(wrapmsg,x->unwrapsigned(x,notary),cypher.G,(x,y,z)->hash(x,y,z,notary),cypher.rng)
DHasym(cypher::Cypher,notary::Notary,signer::Signer) = DH(value->wrapsigned(value,signer),unwrapmsg,cypher.G,(x,y,z)->hash(x,y,z,notary),cypher.rng)

DHsym(deme::Deme,signer::Signer) = DHsym(deme.cypher,deme.notary,signer)
DHasym(deme::Deme) = DHasym(deme.cypher,deme.notary)
DHasym(deme::Deme,signer::Signer) = DHasym(deme.cypher,deme.notary,signer)

export sign, verify, hash, unwrap, DHsym, DHasym

end 
