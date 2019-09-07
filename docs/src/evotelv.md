# E-vēlēšanu utopija ar asimetrisko kriptogrāfiju ar viltus identitātēm

## Pamats

+ Pilsoņa īpašumā ir ID karte ar PIN kodu speciāli vēlēšanām.
+ Uz ID kartes atrodās privātā atslēga. Publiskā atslēga atrodās divās datubāzēs.
+ Slēgtā datubāze sasaistot personas datus ar attiecīgo atslēgu. Ieraksts tajā var tikt veikts vienīgi kartes izgatavošanas brīdī.
+ Publiskā datubāze ar derīgām atslēgām, bez saistības ar identitāti.  

+ID kartes izmantošanai lietotājam ir palīgierīce, kura nav savienota ar internetu. Šajai palīgierīcei ir ievades tastatūra un ekrāns (piem ciparu).
+ Balss parakstīšana notiktu pēc šādiem soļiem
  - PIN koda ievade
  - Ievada vēlēšanu izvēles nospiedumu piem. skaitļu virkne.
  - ID karte izrēķina balss nospiedumu (hash summu) balsij + patvaļīga virkne (iešūta ID kartes izgatavošanas brīdī).
  - ID karte paraksta rezultējušo nospiedumu ar privāto atslēgu un izvada divas skaitļu virknes uz ekrāna. 
  - Lietotājs anaonīmi nodod šīs divas ciparu virknes, kādā no iecirkņu datubāzēm. Vai vairākās drošības pēc. 
  - Lietotājs pārliecinās, ka šie balsu vācēji ir veiksmīgi nodevuši ziņojumu CVK datubāzē, kura publicē visus ziņojumus.

+ Balss pārbaude.
    - No malas:
    ```    
    balss = (230402394023, 0234023904)
    publiskās_atslēgas = [2342394890,2394034234,234234234,6575675]
    
    nospiedums, paraksts = balss
    
    for pubj in publiskās_atslēgas
        if decrypt(paraksts,pubj)==nospiedums
            println(“Derīga balss!”)
        end
    end
    ```
    - CVK papildus veic papildu pāŗbaudi vai atšifrētās publiskās atslēgas ir atrodamas slēgtajā datubāzē vai arhīvā. 
    - Pārbaudi veic arī drošības iestādes saskaitot nederīgās balsis un tās atņemot no punkta a. rezultāta. Rezultātām godīgu vēlēšanu procesu gadījumā jāsakrīt ar punktu c.

## Viltus identitāte, lai cīnītos ar varmākām.
+ Vispirms lietotājs reģistrē viltus identitāti dodoties uz PMLP nodaļu. Tajā atrastos iekārta, kas:
  - Kura ģenerēs patvaļīgu un drošu privāto atslēgu
  - Pievienos to ID kartei
  - Izdrukās aktivizācijas PIN2 kodu un nodos to lietotājam
  - Reģistrēs publisko atslēgu, derīgo publisko atslēgu listē un drošības iestāžu datubāzē ar identitāti.

+ Pēc tā soļi 4. punktā var tikt izdarīti veiksmīgi ar PIN2 kodu. Pieņemsim, ka tas tā tiek izdarīts. Drošības iestādes atrod publisko atslēgu ar kuru veikts paraksts. Ja publiskā atslēga atrodama viņu datubāzē, tiek konstatēts noziedzīgs nodarījums. Tālakais ir iestāžu operatīvā rīcība un iespējams aizsardzība trauksmes cēlāja formā.
+ (Bonuss) Drosmīgs indivīds varētu piereģistrēt vairākas viltus identitātes, kuras izmantot peļņas nolūkos tā samazinot cenu, par kuru kāds varētu vēlēties tavu balsi pirkt.

## Zināmie ierobežojumi
Vienas paraksta atšifrēšanai ir nepieciešamas 100 ms. Tādēļ vienai balsij cikla iziešanai 5.a pie 2 miljoniem vēlētāju aizņemtu divas CPU dienas. Risinājums - lietotājs ar parakstam pievieno pirmos simbolus no publiskās atslēgas.

## Zināmie scenāriji

+ Ir notikusi personas privātās atslēgas zādzība, tās izgatavošanas brīdī. Ar to tiek parakstīta balss. Persona konstatē, ka publiskā atslēga ir jau izmantota redzot to atšifrētu kopīgajā reģistrā.
  - Persona dodās uz PMLP nodaļu
  - Ar savu PIN kodu atļauļ ieraudzīt kartes parakstu log failu.
  - Ziņo drošības iestādēm par nederīgu balsi, kuras uzsāk kriminālprocessu.
  - Personai izsniedz jaunu ID karti.
+ Ir noplūdusi viltus identitāšu datubāze no drošības dienastiem. Tā atļauļ balsu uzpircējiem justies droši savā arodā.
  - Faktu konstatē aktīvisti un drošības dienasts, dodoties meklēt savas viltus identitāšu uzpircējus. 
  - Aktīvisti un drošības dienasti reģistrē jaunas viltus identitātes.
  - Lai mazinātu mērogu, viltus datubāze tiek fragmentēta un decentralizēta.
+ Ir noplūdisi derīgo publisko atslēgu datubāze bez saistības ar identitātēm. 
  - Faktu konstatē aktīvisti un drošības dienasts pēc pieņēmuma, ka noplūdusi viltus identitāšu datubāze mēģinot balsis nopirkt ar jaunām viltus identitātēm.
  - Drošības dienasts reģistrē viltus balsis - t. i. balsis, kuras parakstītas ar derīgajām identitātēm, un publicē reģistru pēc vēlēšanām. (Drošības dienasta darbinieki veic balsojumus pēdējie.) 
  - Jāizsniedz no jauna visas ID kartes.
  - Lai balsu pircējiem vel processu apgrūtinātu, izvēli var mainīt līdz vēlēšanu oficiālajām beigām.
+ Īstās identitātes publiskā atslēga nonākusi viltus identitāšu datubāzē.
  - Faktu konstatē pēc CVK balsu skaitīšanas un rezultātu salīdzināšanas.
  - Lai noteiktu, kad tas noticis viltus identitāšu datubāzes tiek šifrētas pa gabaliem, atslēgā iekļauļot nospiedumu no iperiekšējā gabala, un bloki izplatīti jebkuram lejuplādei.
  - Novērotāji ar IT pieredzi un izpratni par processu tiek pielaisti klāt datubāzei, lai atrastu, kad un kā atslēga nonākusi drošības dienastu datubāzē.
  - Īstās identitātes publiskā atslēga nonākusi viltus identitāšu datubāzē un īstā identitāte iznīcināta no CVK arhīva/datubāzes.
  - Arhīva kartītes ir savstarpēji saķēdētas tām esot parakstītām ar katras iepriekšējās ID kartes privāto atslēgu pirms tā tiek nodzēsta. 
  - Faktu konstatē uzturot arhīvu, veicot izlases tipa pārbaudes. 
+ Ir saražotas piebalsošanas ID kartes.
  - Lai šo processu apgrūtinātu, PMLP nodaļas tur izdoto ID karšu publisko atslēgu arhīvu un veic skaitīšanu pa PMLP nodaļām. Tas šādā affērā liktu iesaistīt vairāk cilvēku. Karšu izsniegšanu piemēram filmē.
  - Esošie preventīvie pasākumi un pieredze.
+ ID kartes nešifrē pēc PMLP nodaļā saņemtās publiskās atslēgas. 
  - Faktu konstatē veicot testa parakstu un pārbaudot tās derīgumu ar saņemto publisko atslēgu.