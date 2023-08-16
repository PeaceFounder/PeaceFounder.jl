# Overview

The foundation of the peacefounder system is an opportunity to issue digital signatures with the same private key for different relative generators without sacrificing key security. The signatures in such cases are supplemented by different public keys. They are not relatable to each other unless someone provides a mapping exponent between relative generators or a zero-knowledge proof of discrete logarithm equality. 

This unlinkability can be used to link multiple private keys together in a knot-like structure so that input pseudonyms public keys obtained through exponentiating relative generators with private keys are related to output pseudonyms while remaining unlikable if we have a trusted dealer who exponentiates relative generator and pseudonyms with the same secret exponential factor and shuffles the output pseudonyms in the result. We shall call this procedure braiding and the one who does it a braider for convenience and to distinguish that from mix and mixing. The input and output relative generator and pseudonyms form a knot-like primitive we shall call a braid. The output relative generator then can be used to issue signatures on the messages which are unlinkable to the input pseudonyms while they are in the eligibility set of output pseudonyms which are ideally applicable for voting.

A zero-knowledge proof of shuffle and decryption can be used to eliminate the assumption of a trusted dealer and prove that braids have been computed honestly without spoiling or replacing output pseudonyms with braider's variants. The zero-knowledge proof of shuffle has been successfully made widely available for ElGamal re-encryption with Verificatum, which offers proof with relatively standard cryptographic assumptions:

- Discrete Logarithm problem hard
- Decisional Diffie Hellman problem hard 

Combining Verificatum proof of shuffle with proof of decryption, it is possible to form a braid proof which proves to everyone that outputs have been obtained from inputs without revealing the secret exponentiation factor braider used, which can be forgotten after the proof is finished. The resulting braid primitive is available in the ShuffleProofs.jl package, which also reimplements Verificatum-compatible proof of shuffle. 

The braid primitive...

**To be continued...**

![](assets/model-dependencies.svg)

A more detailed diagram:

![](assets/model-responsabilities.svg)
