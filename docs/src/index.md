# DemocracyCredit

An utopian idea to build collective trust from smaller units of trust by decentralized, transparent and anonymous e-vote scheme. Also a place people donate and vote anonymously on the thisngs which matters most.

Activism, which is necessary element of a working democracy, is a subject to a free rider problem which diminishes it's power. In environment we live in we have a limitted capability to finance public goods such as media, open source projects and political parties. Subscription model just does not cut it. Thus we rely on the state or from the advertisment model. Here I propose an alternative fundraising strategy based on transparenet, anonymous, user verifiable e-voting scheme.

The first step is to establish a git based repository, where proposals, resulting votes and public keys would sit in. The contributors with a merge rights would fill the role of the state which ensures that all votes are being counted and has executive rights to deliver the result of the vote. For example ensuring that funds are being transfered from participating parties according to a promise. 

The promise of parties to finance the voted proposals is a credit for the democracy. It is thus natural to give the rights of merging proposals, votes, and new members to the participating parties as that gives them power of excluding nonobeying parties or to fork and purge the ruthless majority as their member entrusted capital depends on their responsable actions. 


## Establishing a Credit

+ A git repo with a set of democracy rules and goals is established
+ The author of the repository looks for a support from activist groups or political parties who are willing to collect and keep funds for the democracy and so establishing a credit
+ The activist group or political party is added to the contributors list with merge rights.

## Establishing a voters registry

+ A potential memeber founds the website of democracy. In this website he sees organizations and parties who collects funds for the purpose of this democracy.
+ He selects the organization which he trusts most and transfer funds to this organization with a note that it is intended for the organization.
+ The person now generates private/public key pair and gives the public key to the organization, which is responsable for keeping his identity private.
+ In a batch (of 10) the organization creates a merge request for the voters registry. The information contains:
  - List of identities.
  - List of public keys.
+ People check if identities are real and can be found in donation registry of the organization. In a necessary case makes a comment.
+ A voting process for a proposal to add thoose memebers to the group begins. If 51% had been collected the merge request is executed by the board. 

## Vote on a proposal:

+ A merge request is made by one of the parties on a particular proposal. The proposal contains the question, voting options and possibly specifics on the time period.
+ The merge request is accepted by other members of the board or returned for improvement.
+ If accepted the voting process begins.
+ After the vote the signed options are collected by the board members.
+ The board counts the valid votes for every one testing if thoose are signed with a public key from the registry. 
+ The board makes a merge to the repo with votes after the count, gives vote summary and executes the will of members.

