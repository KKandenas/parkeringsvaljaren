# Parkeringsväljaren

Visar vilka parkeringsappar som går att betala med där du står, och öppnar
den du väljer. En kodbas i Flutter för Android (APK) och webben (PWA för
iPhone och iPad).

> Uppgifterna kan vara fel. Skylten på platsen gäller.

## Så fungerar det

1. Telefonen ger positionen en gång, när appen öppnas eller när man trycker
   på sikteskorset. Positionen sparas inte.
2. **Nominatim** (OpenStreetMap) ger adress och kommun. Kommunen matchas mot
   `osmNamn` i `assets/data/kommuner.json`.
3. **Overpass** (OpenStreetMap) ger parkeringar inom 60 meter. Har den
   närmaste en `operator` som finns i `assets/data/operatorer.json` visas det
   bolagets app först. Privata parkeringar (`access=private`) hoppas över.
4. Kommunens appar för gatuparkering kommer från `kommuner.json`.
5. Sortering (`lib/logic/app_urval.dart`): operatörens app, favoriter,
   installerade appar och sedan resten i kommunens ordning. Dolda appar visas
   aldrig. Övriga appar ligger under "Andra appar".

Positionen skickas bara till Nominatim och Overpass. Svaren sparas i minnet
så länge appen är öppen och aldrig på disk. "Det här stämmer inte" öppnar
ett ifyllt GitHub-ärende med kommunen och apparna, men utan position eller
adress, eftersom ärenden är offentliga.

### Öppna en app

- **Android:** `MainActivity.kt` startar appen med paketnamnet (`setPackage`
  med appens universella länk om den har en, annars appens startpunkt).
  Saknas appen öppnas Google Play. Alla paketnamn måste stå under
  `<queries>` i `AndroidManifest.xml`, och det kontrolleras av ett test.
- **iPhone/iPad (webben):** En webbsida kan inte se vilka appar som är
  installerade. Det finns därför fyra vägar, i den här ordningen:
  1. `universellLank`: öppnar appen, och utan appen App Store
     (Parkster, `parkster.se/app`).
  2. `iosAppLank`: universell länk som bara används när man har appen,
     eftersom den annars öppnar en webbsida (Mobill, `mobill.se/qr`).
  3. `iosSchema`: URL-schema som provas i 2,5 sekunder. Döljs inte sidan
     öppnas App Store (EasyPark, `easypark://`).
  4. App Store, där det står "Öppna" om appen redan finns.

  Under Mina appar markerar man "Jag har appen". Appar som har öppnats
  härifrån markeras automatiskt. Scheman och länkar läggs in först när de
  har prövats på en riktig iPhone med `web/lanktest.html`. Prövat
  2026-10-10–11: Parkering Göteborg svarade inte på något schema.

## Kör

```bash
flutter pub get
flutter run -d chrome
```

För Android: anslut telefonen och kör `flutter run`.

Obs: `flutter analyze` kraschar på `ä` i mappnamnet (en bugg i
analysservern). Använd `dart analyze`, som fungerar.

## Testa

```bash
flutter test
```

Testerna täcker:

- `kommun_resolver_test`: position till kommun, med riktiga svar från
  Nominatim i `test/fixtures`.
- `operator_matcher_test`: OSM-operatör till app.
- `app_urval_test`: kommun till appar och sorteringen.
- `osm_test`: tolkning av Overpass, cache och högst ett anrop per sekund
  till Nominatim, samt att kommunen visas även när Overpass är nere.
- `data_test`: datafilerna. Alla 290 kommuner, belägg för varje verifierad
  kommun, kända app-id och paketnamnen i AndroidManifest.
- `hem_skarm_test`: startsidan, varningen, dolda appar och operatören först.

## Var uppgifterna kommer ifrån

| Fil | Innehåll | Källa |
|---|---|---|
| `assets/data/kommuner.json` | Alla 290 kommuner: kod, namn, OSM-namn | SCB (api.scb.se, tabell BefolkningNy) och OpenStreetMap (`ref:scb`) |
| samma fil, `gatuparkering` | Appar för kommunal gatuparkering | Kommunens eller dess parkeringsbolags webbplats, med adress, citat och datum |
| `assets/data/apps.json` | Apparna | Paketnamn från Google Play, App Store-id från Apples sök-API, universella länkar från appens `apple-app-site-association` |
| `assets/data/operatorer.json` | OSM-operatör till app | Bara bolag som själva ger ut appen |

`status` är något av:

- `verifierad`: kommunens egen webbplats, eller dess parkeringsbolags,
  räknar upp apparna.
- `avgiftsfri`: kommunen skriver att gatuparkeringen är avgiftsfri, ofta
  med p-skiva. `appar` är då tom, och appen visar "Gatuparkeringen är
  avgiftsfri enligt kommunen". Veckokontrollen kontrollerar att källan
  fortfarande säger det.
- `okand`: inte kontrollerad. Appen säger att uppgiften saknas och att
  skylten gäller.

En källa som bara visar innehållet med JavaScript märks
`"kraverJavascript": true`. Veckokontrollen kontrollerar då bara att sidan
svarar.

## Uppdatera kommunlistan

**Grunddata** (om kommuner slås ihop eller byter namn):

```bash
dart run tool/uppdatera_kommuner.dart
```

Skriptet hämtar från SCB och Overpass och behåller de handgjorda
uppgifterna.

**En kommuns appar:** hitta kommunens sida om att betala parkering och lägg
till i `kommuner.json`:

```json
"status": "verifierad",
"gatuparkering": { "appar": ["easypark", "parkster"], "anmarkning": "valfri" },
"parkeringssida": "https://…",
"kallor": [{ "url": "https://…", "titel": "…", "citat": "kort ordagrant utdrag", "hamtad": "ÅÅÅÅ-MM-DD" }],
"kontrollerad": "ÅÅÅÅ-MM-DD"
```

En ny app läggs in i `apps.json` och under `<queries>` i
`AndroidManifest.xml`. Kör sedan `flutter test`.

**Veckokontroll:** `.github/workflows/veckokontroll.yml` kör
`tool/kontrollera_kallor.dart` varje måndag. För varje kontrollerad kommun
läser den om källorna och letar efter:

- källor som inte svarar,
- appar i listan som inte längre nämns (avtalet kan ha upphört),
- appar ur katalogen som har börjat nämnas (en ny app, eller att en
  avgiftsfri kommun har infört avgift),
- avgiftsfria kommuner vars källa inte längre säger att det är gratis,
- kommande ändringar vars datum har passerat.

Den kontrollerar också att apparna finns kvar i butikerna och att deras
universella länkar fungerar. `tool/skapa_arenden.sh` gör ett GitHub-ärende
med etiketten `veckokontroll` per kommun eller app med problem. GitHub
mejlar om nya ärenden, och ärenden stängs av sig själva när problemet är
borta. Kör lokalt:

```bash
dart run tool/kontrollera_kallor.dart
```

**När en källa nämner en app av ett annat skäl,** till exempel Aimo Park som
sköter parkeringsövervakningen eller Flowbird som tillverkar automaterna,
lägg appens id under `"namnsOcksa"` för källan, så att den inte larmar.

**Kommande ändringar** som kommunen har aviserat läggs in i förväg:

```json
"kommande": { "fran": "ÅÅÅÅ-MM-DD", "appar": ["easypark", "mobill"], "anmarkning": "valfri" }
```

Appen byter till de nya apparna samma dag. Veckokontrollen påminner sedan om
att föra in ändringen i `gatuparkering` och ta bort `kommande`.

## Publicera

Inget är publicerat än. Det görs först efter beslut.

- **Webben (PWA):** `flutter build web --release` och lägg upp `build/web`,
  till exempel på GitHub Pages eller Firebase Hosting (gratisplanen Spark).
- **Android:** `flutter build apk --release`. Planen är att lägga APK-filen
  som en release i ett publikt GitHub-projekt och låta appen uppdatera sig
  själv därifrån, som Kandenäs Stream gör.

## Användningsregler för OpenStreetMap

- Egen User-Agent (`lib/services/osm.dart`). I webbläsaren identifierar
  Referer appen, eftersom webbläsare inte låter sidor sätta User-Agent.
- Högst ett anrop per sekund till Nominatim, och svaren sparas för samma
  punkt.
- Data © OpenStreetMaps bidragsgivare, ODbL.
