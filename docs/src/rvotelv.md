# E-vēlēšanas izmantojot saķēdētos gredzenu parakstus

Kādu laiku atpakaļ man ieinteresēja jautājums, kā Monero kriptovalūtas lietotāji var justies droši iegādājoties/pārdodot nelegālas preces un pakalpojumus. Tas, kas Monero atdala no citām kripto valūtām ir, ka tā izmanto gredzena parakstus (ring signatures). Šajai e-vēlēšanu utopijai man ir nepieciešams saķēdētā gredzenu shēma (linkable ring signatures).

Gredzenu paraksts ir tāds paraksts, kas var tikt veikts grupas vārdā, kura definēta ar publisko atslēgu sarakstu. Viena no šī paraksta būtiskākajām īpašībām ir, ka nevar pateikt, kurš no grupas konkrēti parakstu ir veicis. Tas piemēram var noderēt, lai nopludinātu ziņas ar autoratīvu spēku, kā Wikipēdija šai sakarā piemin “kads baltā nama pārstāvis”. 

Lai izmantotu šo parakstu, nepieciešama vēlviena īpašība - saķēdējums (linkability), kura nodrošina, ka viena grupas dalībnieka veiktie paraksti ir savstarpēji identificējami. Tas savukārt ir realizējams ar dzelzi, liekot tam parakstīt kartei unikālu sērijas nummuru, vai arī algoritmiski ar saķēdētā gredzenu parakstu shēmu. Tas ir būtiski, lai nepieļautu viena dalībnieka iespējas balsot vairākkārt. 

Šajā utopijā, pieņemsim, ka saķēdētā gredzenu parakstu shēma (LRS) ir kriptogrāfiski droša…

+ Pilsoņa īpašumā ir ID karte ar PIN kodu speciāli vēlēšanām.
+ Uz ID kartes atrodas privātā atslēga, visu grupas dalībnieku publiskās atslēgas, un saķēdēto parakstu algoritms LRS. Publiskā atslēga atrodās publiskā listē ar personas identificēšanas īpašībām.

+ ID kartes izmantošanai lietotājam ir palīgierīce, kura nav savienota ar internetu. Šajai palīgierīcei ir ievades tastatūra un ekrāns (piem ciparu). 
+ Balss parakstīsāna notiek pēc šādiem soļiem:
  - Ievada vēlēšanu izvēles nospiedumu piem. skaitļu virkne.
  - ID karte izrēķina balss nospiedumu (hash summu) balsij + patvaļīga virkne (iešūta ID kartes izgatavošanas brīdī).
  - ID karte paraksta rezultējušo nospiedumu ar privāto atslēgu un izvada divas skaitļu virknes uz ekrāna. 
  - Lietotājs anaonīmi nodod šīs divas ciparu virknes, kādā no iecirkņu datubāzēm. Vai vairākās.
  - Lietotājs pārliecinās, ka šie balsu vācēji ir veiksmīgi nodevuši ziņojumu CVK datubāzē, kura publicē visus ziņojumus un ka balss ir pieskaitīta pareizi.
  - Balsu pārbaude un saskaitīšana ir triviāla.

# Mehānisms cīņai pret balsu pirkšanu un ietekmēšanu.

Kā zināms balss parakstu veido parakstāmais ziņojums ar patvaļīgu skaitļu virkni un tā šifrējums ar privāto atslēgu. Šeit aprakstīšu metodi, kura nodotu patvaļīgo skaitļu virkni drošības iestādēm tā ļauļot tām atpazīt iezīmētās balsis.

+ Lietotājs dodās PMLP nodaļu. Tajā atrastos iekārta, kura:
  - Ģenerēs patvaļīgu virkni.
  - Pievienos to ID kartei
  - Izdrukās aktivizācijas PIN2 kodu un nodos to lietotājam
  - Reģistrēs patvaļīgo virkni drošības iestāžu datubāzē ar identitāti.
  - Pēc tā soļi 3. punktā var tikt izdarīti veiksmīgi ar PIN2 kodu. Pieņemsim, ka tas tā tiek izdarīts.
  - Drošības iestādes pārbaudot balsis atrod, ka ir izmantota patvaļīga virkne, kura atrodama drošības iestāžu datubāzē.
  - Pēc šīs virknes drošības iestādes atrod identitāti un uzsāk operatīvu rīcību. Tālakais ir iestāžu operatīvā rīcība un iespējams aizsardzība trauksmes cēlāja formā.


# Zināmās problēmas un risinājumi

+ LRS prasa no čipa kartes vairāk jaudas nekā no asimetriskās kriptogrāfijas. Iespējamais risinājums ir daļu no operācijām, novirzīt uz pievienotās papildierīces.
+ LRS paraksta garums aug lineāri ar grupas dalībnieku skaitu. Tas savukārt ierobežo anonimitātes pakāpi. Tomēr iepriekšējās Saemas vēlēšanās mazākais iecirknis bija ar 36 balsīm un vairākis svārstijās ap 100, tādēļ tā varbūt nav nepārvarama problēma.  
+ LRS nav vēl izturējis laika pāŗbaudi praktiskos pielietojumos.
+ Gudram balsu pircējam var nopārdot tikai vienu iezīmētu balsi, kuru pats vēlēšanu procesā nevarēsi izmantot. Tomēr pēc naudas saņemšanas un ziņošanas operatīvajām iestādēm, būtu iespēja mainīt savu izvēli. 

# Ieguvumi pār pliku asimetrisko shēmu

+ Ir iespējams redzēt, kas ir piedalījies vēlēšanās, izslēdzot šaubas par sadrukātām viltus identitātēm!
+ Iespējas to izmantot paralēli asimetriskajai šifrēšanai.