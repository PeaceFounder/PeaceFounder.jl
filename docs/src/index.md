# The PeaceFounder's project

Online voting systems had been active research problem since the discovery of asymmetric cryptography. However, none to my knowledge is trustworthy. It is easy to imagine a software-independent system where anonymity is disregarded by having a public ledger to which one submits their signed votes. But the anonymity is essential to the integrity of elections! Or one imagines a software which is perfect and so preserves anonymity while being secure. However, what if a villain takes over the server and replaces the software with its own?

There are many metrics which had been introduced for measuring the trustworthiness of the electronic voting system. I propose to group them into three categories - transparency, security and anonymity. Which are easy to remember through existing technologies:

+ security + anonymity: Trust the system X doing Y. Most electronic voting systems fit into this category, for example, the Estonian system. Their Achilles heel is the software dependance.
+ security + transparency: Trust the voter X being independent of Y. Such a voting system makes sense when X is representative of Y. However, for ordinary citizens, this is inappropriate as that enables easy coercion, shaming and bribery. 
+ transparency + anonymity: Trust X not doing Y. These are all voting systems to which you can authorize with anonymous means. The best example would be a privately generated bitcoin by a PoW which acts as a token for a vote to be transferred to an account A, B and C representing a choice.

More specifically, I propose to fix the definitions for anonymity, transparency and security as follows:

### Transparency:

+ Open source and open participation
+ Software independence. If someone hacks in the system and replaces that with his own, he shall not be able to change an election outcome without being detected. (I apply this notion here as that the collected data would not change, so it does not overlap with verifiability.)
+ Individual verifiability. See proof how you voted and that you were counted.
+ Universal verifiability. Fairness and accurateness can be proved from publically available data.

### Security:

+ Legitimacy. All participating members are real and verified. 
+ Accountable. Misbehaving individuals can be isolated. 
+ The publically available data can not be tampered with to change the election outcome. (cryptographically secure)
+ No single attackable entity (phone, server, cryptographic protocol, ....) which can significantly change the election outcome. (There is always a possibility of malware. I assume that it is a minority and the detection and prevention of that is the Vendor's responsibility whose reputation would be at stake.)

### Anonymity:

+ Privacy: Noone knows how you voted without your cooperation.
+ Secrecy: You can not prove how you voted for another person, even with your cooperation, also known as receipt freeness and secret ballot. I don't use those definitions because the voting system can have a receipt, but it might not be the only one. 

Secrecy can be implemented with software by giving the citizen a choice to vote in a traditional voting ceremony which would override the online voting receipt while not revealing whether he/she did so to the public. In such a case, the system needs a trusted auditor who produces a compensated tally. It seems reasonable to assume that the secret ballot would be much smaller than a public (not open) ballot thus universal verifiability would still hold. However, before, that is reasonable to implement one needs to prevent such a simple thing as identity selling which one could achieve with hardware (see the PeaceCard project). 

The focus thus for PeaceVote is voluntarily democracies. It is the democracies of communities where members get engaged by making a significant change in their surroundings and so would want to protect their democracy. The privacy would make decisions less group biased and more thoughtful by individuals themselves for the community. The democracy could also be a great tool to unite audiences of two opposing divisions of the society by giving them the ability to delegate representatives for a discussion.  The system is also useful for anonymous questionnaires where the minority members do not feel safe to be publically known. Or for whistleblowers who do feel that their integrity had been intact. The last part is essential to punish those members who are documented to sell their votes on the field or sell their representative power within the community. 

# The design of PeaceFounder

The Julia PeaceFounder is aiming to be a universal swiss knife for deme maintainers. It aims to be the module from which demes take first the backend methods for the server and second the frontend methods defining how members register, propose, vote and braid. This package is successful if every line which you write for the community represents a political decision. A declarative API is a goal.