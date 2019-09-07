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


## Mehānisms cīņai pret balsu pirkšanu un ietekmēšanu.

Kā zināms balss parakstu veido parakstāmais ziņojums ar patvaļīgu skaitļu virkni un tā šifrējums ar privāto atslēgu. Šeit aprakstīšu metodi, kura nodotu patvaļīgo skaitļu virkni drošības iestādēm tā ļauļot tām atpazīt iezīmētās balsis.

+ Lietotājs dodās PMLP nodaļu. Tajā atrastos iekārta, kura:
  - Ģenerēs patvaļīgu virkni.
  - Pievienos to ID kartei
  - Izdrukās aktivizācijas PIN2 kodu un nodos to lietotājam
  - Reģistrēs patvaļīgo virkni drošības iestāžu datubāzē ar identitāti.
+ Pēc tā soļi 4. punktā var tikt izdarīti veiksmīgi ar PIN2 kodu. Pieņemsim, ka tas tā tiek izdarīts.
+ Drošības iestādes atrod publisko atslēgu ar kuru veikts paraksts. Ja izmantotā patvaļīgā skaitļu virkne atrodama viņu datubāzē, tiek konstatēts noziedzīgs nodarījums. Tālakais ir iestāžu operatīvā rīcība un iespējams aizsardzība trauksmes cēlāja formā.

Pozitīvais aspekts ir tāds, ka nav nepieciešama skaitīšana CVK arhīvā ar derīgajām publiskajām atslēgām, jo visas CVK publicētās publiskās atslēgas būtu derīgas un ar PMLP nodaļu personām apstiprinātas. Tomēr pieņemot, ka balsu pircējs ir attapīgs, tas nepirks balsis ar jau balsojušām publiskajām atslēgām. Tāpat nauda varētu tikt pārskaitīta tikai pēc konstatēšanas par pareizu pieskaitīšanu.

Risinājums ir ļaut mainīt balsi iezīmētajām balsīm pēc naudas saņemšanas. Lai neatklātu publisko atslēgu, kura nodarbojās ar aktīvismu, tas notiek aizklāti nosūtot balsi drošības iestādēm, kuri publicē kopsavilkumu.

## Zināmie ierobežojumi

Vienas paraksta atšifrēšanai ir nepieciešamas 100 ms. Tādēļ vienai balsij cikla iziešanai 5.a pie 2 miljoniem vēlētāju aizņemtu divas CPU dienas. Risinājums - lietotājs ar parakstam pievieno pirmos simbolus no publiskās atslēgas.

