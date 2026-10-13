// Kontrollerar att uppgifterna i assets/data fortfarande stämmer med
// källorna. Körs varje vecka av .github/workflows/veckokontroll.yml, som gör
// ett GitHub-ärende av varje kommun eller app med problem.
//
//   dart run tool/kontrollera_kallor.dart [--json resultat.json]
//
// Kontrollerar för varje kontrollerad kommun:
//   - att källan svarar,
//   - att kommunens appar fortfarande nämns (annars kan avtalet ha upphört),
//   - att inga andra appar ur katalogen har börjat nämnas (kan vara en ny app,
//     eller att en avgiftsfri kommun har infört avgift). Appar som källan
//     nämner av andra skäl står under "namnsOcksa" och räknas inte,
//   - att en avgiftsfri kommuns källa fortfarande säger att det är gratis,
//   - att en kommande ändring ("kommande") inte har passerat sitt datum.
// Och för apparna: att de finns kvar på Google Play och i App Store, och att
// universella länkar finns kvar i appens apple-app-site-association.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:parkeringsvaljaren/logic/normalisera.dart';
import 'package:parkeringsvaljaren/models/katalog.dart';

const userAgent =
    'Parkeringsvaljaren-kontroll/1.0 (+https://github.com/KKandenas/parkeringsvaljaren)';

/// Problem per kommun eller app, i den ordning de hittades.
final problem = <String, List<String>>{};

void rapportera(String vad, String text) =>
    (problem[vad] ??= []).add(text);

Future<void> main(List<String> args) async {
  final appsJson = File('assets/data/apps.json').readAsStringSync();
  final kommunerJson = File('assets/data/kommuner.json').readAsStringSync();
  final katalog = Katalog.fromJsonStrings(
    apps: appsJson,
    kommuner: kommunerJson,
    operatorer: File('assets/data/operatorer.json').readAsStringSync(),
  );

  // Andra namn som en källa kan använda för appen, t.ex. "Aimo".
  final namn = {
    for (final a in (json.decode(appsJson) as Map)['appar'] as List)
      a['id'] as String: [
        a['namn'] as String,
        ...?(a['alias'] as List?)?.cast<String>(),
      ],
  };

  // Uppgifter om källorna som bara kontrollen behöver.
  final kallInfo = <String, Map<String, dynamic>>{
    for (final k in (json.decode(kommunerJson) as Map)['kommuner'] as List)
      for (final kalla in (k['kallor'] as List? ?? const []))
        kalla['url'] as String: kalla as Map<String, dynamic>,
  };

  final idag = DateTime.now().toIso8601String().substring(0, 10);

  for (final kommun in katalog.kommuner) {
    if (!kommun.arKontrollerad) continue;
    final rubrik = '${kommun.namn} (${kommun.kod})';
    final kommande = kommun.kommande;
    if (kommande != null && kommande.fran.compareTo(idag) <= 0) {
      rapportera(
        rubrik,
        'Den kommande ändringen från ${kommande.fran} gäller nu. För in den '
        'i "gatuparkering" och ta bort "kommande".',
      );
    }
    // Appar som är väntade på sidan: kommunens nuvarande och kommande.
    final vantade = {...kommun.appar, ...?kommande?.appar};
    for (final kalla in kommun.kallor) {
      final info = kallInfo[kalla.url] ?? const {};
      final bara = info['kraverJavascript'] == true;
      final ocksa = {...?(info['namnsOcksa'] as List?)?.cast<String>()};
      List<String> fel = const [];
      // Webbplatser svarar ibland tillfälligt med en annan sida. Försök en
      // gång till innan det räknas som ett problem.
      for (var forsok = 0; forsok < 2; forsok++) {
        final svar = await hamta(kalla.url);
        fel = svar == null
            ? ['Källan svarar inte: ${kalla.url}']
            // Sidor som bara visar innehållet med JavaScript kan inte läsas
            // här. Där räcker det att sidan svarar.
            : bara
            ? const []
            : granska(
                kommun,
                normalisera(sidtext(svar)),
                vantade,
                ocksa,
                katalog,
                namn,
                kalla.url,
              );
        if (fel.isEmpty) break;
        await Future<void>.delayed(const Duration(seconds: 5));
      }
      for (final f in fel) {
        rapportera(rubrik, f);
      }
    }
  }

  for (final app in katalog.appar.values) {
    final rubrik = 'Appen ${app.namn}';
    if (app.playUrl != null &&
        await hamta('${app.playUrl}&hl=sv&gl=se') == null) {
      rapportera(rubrik, 'Finns inte på Google Play (${app.android}).');
    }
    if (app.appStoreId != null) {
      final svar = await hamta(
        'https://itunes.apple.com/lookup?id=${app.appStoreId}&country=se',
      );
      final antal = svar == null
          ? 0
          : (json.decode(svar) as Map)['resultCount'];
      if (antal == 0) {
        rapportera(rubrik, 'Finns inte i App Store (${app.appStoreId}).');
      }
    }
    for (final lank in [?app.universellLank, ?app.iosAppLank]) {
      final uri = Uri.parse(lank);
      final aasa = await hamta(
        'https://${uri.host}/.well-known/apple-app-site-association',
      );
      if (aasa == null || !aasa.contains(uri.path)) {
        rapportera(
          rubrik,
          '${uri.host} tar inte längre emot ${uri.path} som universell länk.',
        );
      }
    }
  }

  final ut = args.indexOf('--json');
  if (ut >= 0 && ut + 1 < args.length) {
    File(args[ut + 1]).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert([
        for (final e in problem.entries) {'rubrik': e.key, 'problem': e.value},
      ]),
    );
  }

  if (problem.isEmpty) {
    stdout.writeln('Alla källor stämmer.');
    return;
  }
  stdout.writeln('Problem i ${problem.length} kommuner eller appar:');
  for (final e in problem.entries) {
    stdout.writeln('- ${e.key}');
    for (final p in e.value) {
      stdout.writeln('    $p');
    }
  }
  // Med --json gör jobbet ärenden av problemen och ska inte misslyckas.
  if (ut < 0) exitCode = 1;
}

/// Problemen på sidan. text är normaliserad (gemener, ord åtskilda av ett
/// mellanslag).
List<String> granska(
  Kommun kommun,
  String text,
  Set<String> vantade,
  Set<String> ocksa,
  Katalog katalog,
  Map<String, List<String>> namn,
  String url,
) {
  final fel = <String>[];
  if (kommun.status == KommunStatus.avgiftsfri) {
    final hel = text.replaceAll(' ', '');
    if (!fritt.any(hel.contains)) {
      fel.add('Källan säger inte längre att parkeringen är avgiftsfri: $url');
    }
  } else {
    final saknas = [
      for (final id in kommun.appar)
        if (!namn[id]!.any((n) => nams(text, n))) katalog.appar[id]!.namn,
    ];
    if (saknas.isNotEmpty) {
      fel.add(
        '${saknas.join(', ')} nämns inte längre (avtalet kan ha upphört): $url',
      );
    }
  }
  final nya = [
    for (final id in katalog.appar.keys)
      if (!vantade.contains(id) &&
          !ocksa.contains(id) &&
          namn[id]!.any((n) => nams(text, n)))
        katalog.appar[id]!.namn,
  ];
  if (nya.isNotEmpty) {
    fel.add(
      kommun.status == KommunStatus.avgiftsfri
          ? 'Källan nämner ${nya.join(', ')}. Har kommunen infört avgift? $url'
          : 'Källan nämner ${nya.join(', ')}, som inte finns i listan. Ny app? $url',
    );
  }
  return fel;
}

/// Om appnamnet står som eget ord i texten. "ePARK" ska hittas i "ePARK"
/// och "E-park" men inte i "Limepark", och genitiv ("EasyParks") räknas.
bool nams(String text, String appnamn) {
  // Mellanslag får finnas eller saknas mellan tecknen: "E-park", "Epark"
  // och "Easy Park" blir "e park", "epark" och "easy park".
  final tecken = normalisera(appnamn).replaceAll(' ', '').split('');
  final monster = tecken.map(RegExp.escape).join(' ?');
  return RegExp('(^| )${monster}s?( |\$)').hasMatch(text);
}

/// Ord som visar att en källa beskriver avgiftsfri parkering. Jämförs utan
/// mellanslag.
final fritt = [
  'avgiftsfri',
  'gratis',
  'kostar inget',
  'ingenting',
  'tas inte ut',
  'tar inte ut',
  'inte betala någon parkeringsavgift',
  'kostnadsfri',
  'ingen avgift',
  'utan avgift',
  'inte lägga på någon parkeringsavgift',
  'inga parkeringsavgifter',
  'p-skiva',
  'parkeringsskiva',
].map((o) => normalisera(o).replaceAll(' ', '')).toList();

String sidtext(String html) => html
    .replaceAll(RegExp(r'<script.*?</script>', dotAll: true), ' ')
    .replaceAll(RegExp(r'<style.*?</style>', dotAll: true), ' ')
    .replaceAll(RegExp(r'<[^>]+>'), ' ');

/// Sidans innehåll, eller null om den inte svarar 200 ens efter ett nytt
/// försök.
Future<String?> hamta(String url) async =>
    await _hamta(url) ?? await _hamta(url);

/// Väntar en sekund efter varje anrop för att inte belasta någon.
Future<String?> _hamta(String url) async {
  final client = HttpClient()
    ..userAgent = userAgent
    ..connectionTimeout = const Duration(seconds: 20);
  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close().timeout(const Duration(seconds: 30));
    final body = await response
        // Vissa sidor har tecken som inte är giltig UTF-8.
        .transform(const Utf8Decoder(allowMalformed: true))
        .join()
        .timeout(const Duration(seconds: 30));
    return response.statusCode == 200 ? body : null;
  } on Exception {
    return null;
  } finally {
    client.close(force: true);
    await Future<void>.delayed(const Duration(seconds: 1));
  }
}
