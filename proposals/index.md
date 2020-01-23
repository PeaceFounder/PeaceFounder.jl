# DemocracyCredit

A utopian idea to build collective trust from smaller units of trust by a decentralized, transparent and anonymous electronic voting scheme. Also a place people donate and vote anonymously on the things which matter most.

Activism, which is a necessary element of a working democracy, is a subject to a free-rider problem which diminishes its power. In the environment we live in, we have a limited capability to finance public goods such as media, open-source projects and political parties. Subscription model just does not cut it. Thus we rely on the state or from the advertisement model. Here I propose an alternative fundraising strategy based on transparent, anonymous, user verifiable electronic voting scheme.

The first step is to establish a git-based repository, where proposals, resulting votes and public keys would sit in. The contributors with merge rights would fill the role of the state, which ensures that all votes are being counted and has executive powers to deliver the result of the democratic choice. For example, ensuring that participating parties transfer funds according to a promise. 

The promise of parties to finance the voted proposals is the credit for the democracy. It is thus natural to give the rights of merging motions, votes, and new members to the participating parties as that gives them the power to purge disobeying parties or to fork and purge the ruthless majority as their member entrusted capital depends on their responsible actions. 

## Establishing a Credit

+ A git repo with a set of democracy rules and goals is established
+ The author of the repository looks for support from activist groups or political parties who are willing to collect and keep funds for the democracy and so establishing credit for the democracy
+ The activist group or political party is added to the board of members with merge rights.

## Establishing a voters registry

+ A potential member founds the website of democracy. In this website, he sees organizations and parties who collect funds for this democracy.
+ He selects the organization which he trusts most and transfer funds to this organization with a note that it is intended for the organization.
+ The person now generates a private/public key pair and gives the public key to the organization, which is responsible for keeping his identity secret.
+ In a batch (could start with 10) the organization creates a merge request for the voter's registry. The information contains:
  - List of identities.
  - List of public keys.
+ Members of democracy check if identities are real and can be found in donation list hosted by the merging organization. In case of issues makes comments.
+ A voting process for a proposal to add those members to the group begins. If 51% had been collected the merge request is executed by the board. 

## Vote on a proposal:

+ A merge request is made by one of the parties on a particular proposal. The proposal contains the question, voting options and possibly specifics on the time period.
+ The merge request is accepted by other members of the board or returned for improvement.
+ If approved the voting process begins.
+ After the vote, the signed options are collected by the board members.
+ The board counts the valid votes for everyone testing if those are signed with a public key from the registry. 
+ The board makes a merge to the repo with votes after the count, gives a summary of public opinion and executes the will of members.

## References

>  Envisioning Real Utopias by Erik Olin Wright

>  Public Opinion by Walter Lippmann

>  Why Men Fight by Bertrand Russell

>  The Worldly Philosophers by Robert L. Heilbroner
