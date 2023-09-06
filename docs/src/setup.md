# Setup

In the PeaceFounder, communities are referred to as demes. To start a deme, we first need to initialise the cryptographic specification and generate a key for the election authority, which we shall refer to as the guardian. The guardian can further delegate a recorder, recruiter, braider, proposer and collector for the votes specified in the `DemeSpec` fields.

In this example, the cryptographic parameters are specified in the crypto variable and are further used to initialise the keys on the server for a recruiter, braider, collector and recorder with `Mapper.initialize!(crypto)` call. The identities are retrieved with `Mapper.system_roles()` call and are used to fill fields in the `DemeSpec` record. Afterwards, it is signed by the guardian and is submitted to the server with `Mapper.capture!(demespec)`, which finalises the server configuration, after which the server can be started.

```julia
import PeaceFounder: Model, Mapper, Service, id, approve
import PeaceFounder.Model: TicketID, CryptoSpec, DemeSpec, Signer
import HTTP

crypto = CryptoSpec("sha256", "EC: P_192")

GUARDIAN = Model.generate(Signer, crypto)
PROPOSER = Model.generate(Signer, crypto)

Mapper.initialize!(crypto)
roles = Mapper.system_roles()

demespec = DemeSpec(; 
                    uuid = Base.UUID(121432),
                    title = "A local democratic community",
                    crypto = crypto,
                    guardian = id(GUARDIAN),
                    recorder = roles.recorder,
                    recruiter = roles.recruiter,
                    braider = roles.braider,
                    proposer = id(PROPOSER),
                    collector = roles.collector
) |> approve(GUARDIAN) 

Mapper.capture!(demespec)

HTTP.serve(Service.ROUTER, "0.0.0.0", 80)
```

The second part is to set up the entry for registration within the deme. This is up to the guardian to decide how new members are added to the deme and how their identity is being tracked and made transparent so that members would be assured that someone has created fake identities to vote multiple times.

```@raw html
<figure>
    <img src="../assets/registration_sequence.svg" alt='' />
    <figcaption>Sequence diagram illustrating client registration with a deme. The process begins when the client requests an invitation from the registrar and concludes when a certified pseudonym is submitted to the Braidchain ledger. The protocol serves multiple goals: 1) It simplifies integration by requiring only a hash function for authorization of new member requests. 2) It prevents inconsistencies between the client's device and the braidchain by allowing repetition of the final step. 3) It ensures that registration can continue even when the chain is temporarily locked for new members, by allowing catch-up with the current relative generator. Future updates aim to combine the last two steps to reduce the number of communication rounds required.</figcaption>
</figure>
```

That would best be done within the organisation's website, where members can log in and get an invite as a string or QR code scanned in the PeaceFounder client application. To facilitate that, the PeaceFounder service offers a recruiter endpoint from which invites can be obtained and accessed, knowing `ROUTE = "0.0.0.0:80"` and recruiter symmetric key `KEY = Mapper.get_recruit_key()`. That makes it relatively easy to integrate into the webpage as it only needs the ability to read some JSON and sha256 hash functions used to authenticate and compute registration tokens at the endpoints. That also makes it redundant to add a TLS certificate for the PeaceFoudner service. 

## Registrar setup

```@raw html
<figure>
    <img src="../assets/recruit_form.png" alt='' />
    <figcaption>A registration form available from Recruiters.jl. When a user puts in his name and email address, a unique invite is automatically sent to the user at the provided email address for registration with the deme.</figcaption>
</figure>
```

To make it easier to start using the peacefounder, a simple registrar facade, as shown in the image above, is available in `Recruiters.jl`. When a user puts in his name and email address, a unique invite is automatically sent to the email with which the user can register. This can also serve as a starting point to make a custom registrar facade and see the involved components, which makes it work. To set it up, we first need to export variables for the deme:

```bash
export DEME_ROUTE='http://0.0.0.0:80'
export DEME_HASHER='sha256'
export DEME_RECRUIT_KEY='THE_RECRUIT_KEY'
```

And also for the SMTP service with which recruit emails are going to be sent. This is specified in the following variables:

```bash
export RECRUIT_SMTP='smtps://mail.inbox.lv:465'
export RECRUIT_EMAIL='demerecruit@inbox.lv'
export RECRUIT_PASSWORD='THE_EMAIL_PASSWORD'
```

After these environment variables are set, the recruiter service can be started as:

```julia
using Recruiters

title = "Local Democratic Community"
pitch = """
<p> Are you looking for a way to get involved in local politics and make a difference in your community? Do you want to connect with like-minded individuals who share your values and beliefs? If so, we invite you to join our Local Democratic Community.</p>

<p> Our community is a group of individuals who are passionate about promoting progressive values and creating positive change in our neighborhoods and towns. We believe that by working together, we can build a more just and equitable society for everyone. As a member of our community, you will have the opportunity to attend events, participate in volunteer activities, and engage in meaningful discussions about the issues that matter most to you.</p>
"""

Recruiters.serve(title, pitch)
```

By default, the `serve` function reads in the environment variables, but if necessary, those can be specified manually by a set of keyword arguments. See docs for further use of those. 

## Braiding

Braiding is a method in which the mix server shuffles input member public keys and raises that to the power of a secret exponent $x$, resulting in a new set of public keys with relative generator $h = g^x$. This procedure must be executed honestly, which can be verified with zero-knowledge proofs.

In particular, ElGamal re-encryption shuffle is done first on the elements $(a, b) \leftarrow (1, Y_i)$ for which a zero knowledge of proof compatible with the Verificatum verifier is produced. Then, a proof of decryption for $c'_{i} \leftarrow {b'}_{i}^x$ and $h \leftarrow g^x$ is produced. That then is used to calculate the resulting member public keys as $Y'_i \leftarrow c'/a'$.

In PeaceFounder, this operation can be executed with the following lines of code:

```julia
input_generator = Mapper.get_generator()
input_members = Mapper.get_members()

# This line is executed on an independent mix
braidwork = Model.braid(input_generator, input_members, demespec, demespec, Mapper.BRAIDER[]) 
Mapper.submit_chain_record!(braidwork)
```

The first `demespec` contains cryptographic parameters for the group specification for `input_generator` and `input_members`. The second `demespec` is added by the braider, which signs the resulting braid and assures that an independent entity endorsed by a different deme provides assurances to the voter that his vote remains private from the guardian.

## Proposal announcement

A proposal to the PeaceFounder service can be added with a `PROPOSER` key as follows:

```julia
commit = Mapper.get_chain_commit()

proposal = Proposal(
    uuid = Base.UUID(23445325),
    summary = "Should the city ban \
    all personal automotive vehicle usage?",
    description = "",
    ballot = Ballot(["yes", "no"]),
    open = Dates.now(),
    closed = Dates.now() + Dates.Second(2),
    collector = roles.collector,

state = state(commit)

) |> approve(PROPOSER)


ack = Mapper.submit_chain_record!(proposal) 
```


Notice that `state(commit)` is added to the proposal. This anchors the relative generator on which the votes are cast.
