# PeaceFounder.jl
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://PeaceFounder.github.io/PeaceFounder.jl/dev)
![](https://github.com/PeaceFounder/PeaceFounder.github.io/blob/master/_assets/vision.png?raw=true)

PeaceFounder is a centralised E2E verifiable e-voting system that leverages pseudonym braiding and history trees. The immutability of the bulletin board is maintained replication-free by voter’s client devices with locally stored consistency-proof chains. Meanwhile, pseudonym braiding done via an exponentiation mix before the vote allows anonymisation to be transactional with a single braider at a time. In contrast to existing E2E verifiable e-voting systems, it is much easier to deploy as the system is fully centralised, free from threshold decryption ceremonies, trusted setup phases and bulletin board replication. Furthermore, the body of a vote is signed with a braided pseudonym, enabling unlimited ballot types.

## Introduction

everal end-to-end (E2E) verifiable e-voting systems exist, such as Helios, Scytl, Belenios, ElectionGuard, Estonia's system, and Verificatum, with many available under open-source licences. They all encrypt and mix votes through a re-encryption shuffle and use a threshold decryption ceremony. This allows voters to track their encrypted votes and the public to verify the final tally. However, it depends on the integrity of the bulletin board and the coordination of the threshold decryption ceremony, presenting challenges for smaller communities and organisations.

To make a point, let's consider a Helios voting system. The vote in Helios is stored in a group element, encrypted and signed by a digital signature provider, and then submitted to the bulletin board. When the vote closes, votes go through the reencryption shuffle and are decrypted in the threshold decryption ceremony. Voters can ensure that their vote has been counted by finding their encrypted vote within the list of inputs of the mix cascade. Furthermore, everyone can verify the final tally by counting the decrypted votes and verifying supplemented zero-knowledge proofs without compromising privacy. In this way, the integrity of the election result can be assured.

However, issues like forced abstention and potential vote substitution of unverified votes can happen if authorities are corrupt and auditing/monitoring does not occur. Publishing vote-casting signatures can alleviate many of those issues, but that violates participation privacy. The threshold decryption ceremony further compounds the system's complexity; if more than a few are corrupt, votes can remain encrypted, while a low threshold risks privacy breaches. These factors, coupled with the technical intricacies of deployment, make Helios less feasible for small to medium-sized communities, leading to a preference for simpler black box systems to prevent questions from being asked, which can foster trust at the expense of trustworthiness.

A significant improvement over Helios is the Selene system, which offers a voter-assigned tracking number and shows their votes next to them after the vote. Recent usability studies with Selene have demonstrated that voters appreciate the ability to verify their vote in plaintext. This allows them to discard their trust in advanced cryptography as they can see how their vote is counted. As the tracking number is not published before the vote and is deniable, it is also coercion-resistant. In addition to clever cryptography, it can also detect malware interference. However, the threshold decryption ceremony still needs to be deployed along with the bulletin board and thus would generally suit only state-like elections.

Haenni & Spycher proposed a system using exponentiation mixes to anonymise voters' pseudonyms, eliminating the need for a threshold decryption ceremony. However, the benefits of such a system have yet to be reaped as it requires a trusted bulletin board that does not discard unfavourable votes; thus, deployment of such a system needs to be distributed and hence offers minor deployment improvements over Helios. Furthermore, over 13 years, a single open-source system has yet to be implemented.

The innovative approach by PeaceFounder combines pseudonym braiding developed by Haenni & Spycher with a history trees-enabled bulletin board (Crosby & Wallach). When voters cast their vote, their devices receive inclusion proof of the vote, which can later be verified to be binding to the tally with consistency proof. By having only a few voters who request their device to check the proofs, the immutability of the bulletin board is guaranteed. Thus, once the server has assured that the vote is recorded, there is no way for it to be removed. This allows the system to be fully centralised and, thus, makes it easy to self-host.

However, such a system poses many challenges compared to the orthodox approach. To protect against a corrupt server that discards unfavourable votes, voters must have the option to route the vote through proxy/monitor, which adds a challenge with coercion/bribery. To reap the benefits of braiding pseudonyms with any other community/organisation worldwide, the voters must be registered long before the vote starts, which would produce a bad user experience. Therefore, disengaging anonymisation from voting requires long-standing accounts, which poses an issue for continuous member registration and termination; on top of that, the votes need to be delivered over an anonymous channel not to be traceable by a corrupt authority. All of them are addressed with the PeaceFounder project in innovative ways.

## Demo

An 8-minute YouTube demonstration is available here:

[![IMAGE ALT TEXT HERE](https://img.youtube.com/vi/3asNuNMlHhY/maxresdefault.jpg)](https://www.youtube.com/watch?v=3asNuNMlHhY)

## References

- Rolf Haenni and Oliver Spycher. *Secure internet voting on limited devices with anonymized DSA public keys.* 2011
- Scott A. Crosby and Dan S. Wallach. *Efficient data structures for tamper-evident logging.* 2009
- Björn Terelius and Douglas Wikström. *Proofs of restricted shuffles.* 2010.
