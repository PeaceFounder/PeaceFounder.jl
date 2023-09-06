# PeaceFounder.jl
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://PeaceFounder.github.io/PeaceFounder.jl/dev)
![](https://github.com/PeaceFounder/PeaceFounder.github.io/blob/master/_assets/vision.png?raw=true)

A major hurdle in mainstream E2E (end-to-end) e-voting system designs is a multiparty protocol ceremony coordination required for initiating a threshold decryption key and performing decryption at the end of the vote. The voter's anonymity demands independence of the involved parties, which introduces a risk of sabotage where election results could be left undecrypted and unannounced. Moreover, due to the need to encode ballot selection in a group element, only a limited number of ballot types can be supported and face challenges, for instance, for cardinal and budget planning ballots. This is even more restrictive when a homomorphic counting procedure is employed.

An alternative approach is to anonymise voter's credentials instead of the votes. The idea has been explored with blind signature schemes, but auditing the authority's issuance of signatures and detecting key leaks remains unresolved. A subsequent method, proposed by Haenni & Spycher, leverages ElGamal re-encryption to verifiably exponentiate voters' public keys in tandem with a generator using zero-knowledge proofs. Together with a history tree bulletin board implementation, it forms the foundation for the design of the PeaceFounder voting system.

The PeaceFounder voting system builds upon the foundational work of Haenni & Spycher, serving as a practical implementation of their proposal. Nevertheless, PeaceFounder introduces several key features:

- A scalable bulletin board design with thin-member clients ensuring the immutability of all published records without replication;
- A registration protocol for new members that catches them up with the current relative generator;
- Mechanisms to handle uncooperative bulletin boards through auditors/proxies while preventing potential exploitation by coercers and bribers with time-restricted receipt freeness and revoting;
- A system allowing a member's device to detect private key leaks coming from spyware or bad cryptography via sequence numbers and bitmasks;
- A malware detection mechanism post-voting, where the device displayed receipt, is compared to a bulletin board while not being deceived into verifying another voter's vote.

Furthermore, PeaceFounder demonstrates that a single maintainer can feasibly deploy the system. That is possible due to the lack of a multi-party ceremony and member device accountability of the bulletin board. It also offers seamless integration opportunities with existing infrastructure and political environment for supporting different ways proposals are put to the ballot box, and member authenticity is verified and later audited. Additionally, the PeaceFounder showcases user experience for the voter, minimising their exposure to complex byte strings while maintaining cryptographic soundness along with other usability improvements. 

## Demo

For a demo, go to the `PeaceFounderDemo` repository. A 10-minute YouTube demonstration is available here:

[![IMAGE ALT TEXT HERE](https://img.youtube.com/vi/L7M0FG50ulU/maxresdefault.jpg)](https://www.youtube.com/watch?v=L7M0FG50ulU)

## References

- Rolf Haenni and Oliver Spycher. *Secure internet voting on limited devices with anonymized DSA public keys.* 2011
- Scott A. Crosby and Dan S. Wallach. *Efficient data structures for tamper-evident logging.* 2009
- Björn Terelius and Douglas Wikström. *Proofs of restricted shuffles.* 2010.
