

# Client

The PeaceFounder client can be installed on all major desktop platforms by simply downloading a bundle for your particular platform from the [PeaceFounderClient release page](https://github.com/PeaceFounder/PeaceFounderClient/releases/tag/v0.0.2). Currently, for demonstration purposes, the application does not save a state. Also, errors should be appropriately handled. For instance, receiving an incorrect receipt or proof from the bulletin board will crash the application. This will be solved in future versions of the client.

In the future, the focus will be on mobile applications for iOS and Android. Unfortunately, in the current state, deploying mobile applications with Julia is not possible due to JIT compilation. This is why the client backend is planned to be rewritten in Rust while keeping the QML facade already written. This will be a significant time investment; thus, I would be eager to test the PeaceFounder voting system in practice with the desktop GUI client only to gauge people's needs.

### For Developers

The PeaceFounder client is implemented in a QML and is available on all major desktop platforms. To run the client, install a recent Julia version on your computer, clone a `https://github.com/PeaceFounder/PeaceFounderGUI` repository, and run the GUI application with the following:

```bash
julia --load main.jl
```

## Registration to a Deme

The first step for the peacefounder voting system as a potential voter is to enrol in a deme. A deme is an organisational body that maintains the electoral roll of its members and puts proposals to members for a vote. After the person has enrolled and become a member, they can access proposals. It is, however, crucial that only proposals announced after the member registration are available for a vote as the registered member's pseudonym needs to be anonymised first through braiders with other members[^1]. 

[^1]: This could be amended in future versions of the PeaceFounder if this becomes a significant dealbreaker for usability. In such a scenario, a member who registers late would sign votes with their identity pseudonym, and the votes could be tallied together with pseudonymously signed ones but never published on the bulletin board. 

```@raw html
<figure>
    <img src="../assets/registration.png" alt='' />
    <figcaption>Left: an example invite email sent by the <code>Recruiters.jl</code> service. Right: PeaceFounder <code>QML</code> client application at the home screen where the invite can be used to register as member to the Deme. On mobile, a QR code could be scanned instead.</figcaption>
</figure>
```

The registration procedure starts with requesting an invite. The invite can be requested from an organisation website, which could show it on the screen, or it can be sent to the email as shown in the figure above. The invite is then scanned in the PeaceFounder client application, which does heavy registration work - generates private and public key pairs, spends an assigned token, authorises the public key, and gets a corresponding admission certificate, which finally is used to catch up with a current relative generator and issue a member certificate which is submitted to the braidchain for inclusion. Since the invite contains a hash digest of the demespec file, registration can be performed under an unsecured channel, making TLS certificate setup redundant for the PeaceFounder service.

## Voting on a proposal

The member’s identity is represented as a row index in the braidchain storing the member record. This avoids presenting users with overwhelming public keys and lets them grasp their registration status. It also indicates to the voter the minimum anchor index at which the new member can vote on the proposal.

```@raw html
<figure>
    <img src="../assets/proposals.png" alt='' />
    <figcaption>Left: a deme view where member’s identity is 21 and the current braidchain state is 89. Two proposals are listed with different states. Right: A selected proposal view. This time, it is not votable by the member as the proposal anchor is 4, whereas the member index is 21. (Images need to be updated for consistency)</figcaption>
</figure>
```

When a voter enters the proposal within the specified time window, it can go to ballot view by pressing Vote Now. The ballot view depends on the kind of Ballot used in the proposal. Since the votes are plaintext messages signed with pseudonyms, there are unlimited types of ballots that PeaceFounder can support, like - cardinal, preferential or budget-constrained ballots, some of which are planned to be implemented in the future.

A guard report is shown to the voter when the vote is cast. The guard contains three categories:

- Ballot Box: the deme UUID and a proposal’s record index on the braidchain, after which the elections can be found online.
- A receipt contains the pseudonym hash with which the vote is being cast, the timestamp on when it was recorded in the ballot box, and the cast record gives an index at which the vote is recorded in the ledger.
- A commit contains a current Merkle tree root and index of the collector signed chain. This is also an index at which consistency proof is being checked so that votes can only be removed from the ballot box after they are added with evidence.

```@raw html
<figure>
    <img src="../assets/vote.png" alt='' />
    <figcaption>Left: a view for multiple question ballot. Right: a guard view where the voter sees ballot box identifier, a receipt for casting a vote and a commit of the current state of the ballot box.</figcaption>
</figure>
```

The Merkle tree inclusion and consistency proof as a receipt to make a tamper-resistant bulletin board monitored by voters. So that undesirable votes can not be discarded when they have been recorded.

After the elections, each voter's client device checks whether the last cast vote is included in the final tally, together with a sequence number on the vote that prevents an adversary that has obtained the voter's private key from casting votes on voters' behalf without being noticed. This is done automatically as long as the client's device acts honestly, i.e., is not infected with malware.

In the case of malware, the fairness property maintained by the election authority and a timestamp on the casting receipt prevent malware on the voter's client from pointing to a substitute vote. Whereas the vote is cast as intended and counted as cast (important for revoting), a voter can check on the bulletin board with another computer using the receipt. If the malware is detected, the voter takes appropriate action for his device.

