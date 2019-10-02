# Electronic voting based on asymmetric cryptography

I am a theoretical physicist (a PhD candidate) and try to learn about cryptography as a hobby. One of the interesting aspects I had found is that many respectable scientists say that electronic voting is not safe, and so I started to follow the arguments which they use. For example, submitting the trust to authority to do their job honestly or sacrificing anonymity. Or impossibility to deal with anonymous bribers on the internet. However, a formal proof for that did not exist, so was interested if I could design a better e-voting system which would be anonymous, transparent and had a mechanism to fight bribery and coercion.

## The setup

-   The citizen receives an ID card with PIN code
-   The card holds a private key and a random string burned in during the production of the card. Additionally the card has a log file for the signatures which had been made. (needed to prevent identity theft).
-   The public key is made public without relation to identity during the delivery of the card to the person. For preventing tampering of the ledger, the person would sign a previous newest public key from the public key list. In the process, the citizen checks if the device contains the correct private key and the algorithm. To prevent unauthorized keys to be registered within the ledger, the person's ID data like a name, place of residence (like a town without specific address), first digits from a phone number is submitted to another database, which would be made public. That would allow citizens to check the legitimacy and enable an option to choose a paper bailout. Also another preventative option is that the key is signed by a public key already in the ledger.

## Voting

The citizen has a device with display and numpad, which interfaces the ID card. No internet connection is allowed to prohibit malware. The voting for a user happens after the following steps:

-   User unlocks the card with his PIN code
-   User inputs the information about the vote to be cast.
-   The ID card calculates the hash sum from the information.
-   The message contains a hash sum and a random number (generated during the software burning process).
-   A private key signs the message. The signature contains the full message and its encryption.
-   The person sends the message anonymously (for example using Tor) to one of many vote collecting sites or a physical bailout box. (necessary to prevent DDOS attacks).
-   The voter checks anonymously that the vote had been delivered and recognized as valid in a centralized public ledger.

## Counting

The public ledger contains signatures. On the other ledger, we have public keys which must have been used for a valid vote. So the steps are as follows:

-   For each signature it is checked if a valid public key is provided which can be found in anonymous public key ledger.
-   The valid signatures are published to a centralized public ledger with a corresponding public key.
-   Then - count. A protocol for changing the vote can be implemented.

## Antibribery and anti-coercion mechanism

The power of anonymity on the internet is the greatest weakness for many electronic voting schemes as it is so easy to buy votes without dealing with consequences. Here I propose a defence based on activists will to look for the bribery places and to sell their votes so in the process depleting bribers capital. Afterwards, when the transaction is made, activists submit their real ballots. That could be done in secrecy to prevent bribers from gaining the knowledge of the list of activists for the next elections.

To distinguish real votes from the fake votes another login for ID card can be made where the random string added to the message would be known to the department which keeps order. The activist could have been given a choice to select the police department, which he trusts that would not leak the information to the bribers. The steps to set up such system thus are:

-   The activist creates a new login to the ID card and chooses a PIN2 code for that.
-   A new login also requires to input the random string which the card adds for the message before signing. That the activist generates on the local computer to have a cryptographic strength.
-   He then generates another random number and makes a signature on this random number.

The activist goes to the police department, which he trusts and gives the signature to them for safekeeping.

-   The police department puts the signature in a secure database.
-   Then they generate a hash sum of the signature which they put in a public ledger.
-   The activist gets a certificate in a paper form in case the police department fails to recognize the right to change the vote after the elections.

Now to perform a fake vote, the citizen does all the steps from the voting section, but only with the PIN2 code. The police department would scan the ledger continuously for the random strings and would do it's duty when the vote would have been found. It is also pretty clear that no one would dare exploit social relations to collect card and PIN code as there is no way to distinguish real one from the fake one.
