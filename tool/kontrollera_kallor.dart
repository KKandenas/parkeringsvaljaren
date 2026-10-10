// Kontrollerar att uppgifterna i assets/data fortfarande stämmer med
// källorna. Körs varje vecka av .github/workflows/veckokontroll.yml, och
// misslyckas jobbet mejlar GitHub.
//
//   dart run tool/kontrollera_kallor.dart
//
// Kontrollerar:
//   - att varje källa för en verifierad kommun svarar och fortfarande nämner
//     kommunens appar,
//   - att apparna finns kvar på Google Play och i App Store,
//   - att universella länkar finns kvar i appens apple-app-site-association.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:parkeringsvaljaren/logic/normalisera.dart';
import 'package:parkeringsvaljaren/models/katalog.dart';

const userAgent =
    'Parkeringsvaljaren-kontroll/1.0 (+https://github.com/KKandenas/parkeringsvaljaren)';

final problem = <String>[];

Future<void> main() async {
  final katalog = Katalog.fromJsonStrings(
    apps: File('assets/data/apps.json').readAsStringSync(),
    kommuner: File('assets/data/kommuner.json').readAsStringSync(),
    operatorer: File('assets/data/operatorer.json').readAsStringSync(),
  );

  // Andra namn som en källa kan använda för appen, t.ex. "Aimo".
  final alias = {
    for (final a
        in (json.decode(File('assets/data/apps.json').readAsStringSync())
                as Map)['appar']
            as List)
      a['id'] as String: [
        a['namn'] as String,
        ...?(a['alias'] as List?)?.cast<String>(),
      ],
  };

  for (final kommun in katalog.kommuner) {
    if (kommun.status != KommunStatus.verifierad) continue;
    for (final kalla in kommun.kallor) {
      final svar = await hamta(kalla.url);
      if (svar == null) {
        problem.add('${kommun.namn}: källan svarar inte: ${kalla.url}');
        continue;
      }
      final text = utanMellanslag(sidtext(svar));
      final saknas = [
        for (final id in kommun.appar)
          if (!alias[id]!.any((namn) => text.contains(utanMellanslag(namn))))
            katalog.appar[id]!.namn,
      ];
      if (saknas.isNotEmpty) {
        problem.add(
          '${kommun.namn}: ${saknas.join(', ')} nämns inte längre på ${kalla.url}',
        );
      }
    }
  }

  for (final app in katalog.appar.values) {
    if (app.playUrl != null &&
        await hamta('${app.playUrl}&hl=sv&gl=se') == null) {
      problem.add('${app.namn}: finns inte på Google Play (${app.android})');
    }
    if (app.appStoreId != null) {
      final svar = await hamta(
        'https://itunes.apple.com/lookup?id=${app.appStoreId}&country=se',
      );
      final antal = svar == null
          ? 0
          : (json.decode(svar) as Map)['resultCount'];
      if (antal == 0) {
        problem.add('${app.namn}: finns inte i App Store (${app.appStoreId})');
      }
    }
    final lank = app.universellLank;
    if (lank != null) {
      final uri = Uri.parse(lank);
      final aasa = await hamta(
        'https://${uri.host}/.well-known/apple-app-site-association',
      );
      if (aasa == null || !aasa.contains(uri.path)) {
        problem.add(
          '${app.namn}: ${uri.host} tar inte längre emot ${uri.path} som universell länk',
        );
      }
    }
  }

  if (problem.isEmpty) {
    stdout.writeln('Alla källor stämmer.');
    return;
  }
  stderr.writeln('${problem.length} problem:');
  for (final p in problem) {
    stderr.writeln('- $p');
  }
  exitCode = 1;
}

String utanMellanslag(String text) => normalisera(text).replaceAll(' ', '');

String sidtext(String html) => html
    .replaceAll(RegExp(r'<script.*?</script>', dotAll: true), ' ')
    .replaceAll(RegExp(r'<style.*?</style>', dotAll: true), ' ')
    .replaceAll(RegExp(r'<[^>]+>'), ' ');

/// Sidans innehåll, eller null om den inte svarar 200. Väntar en sekund
/// efter varje anrop för att inte belasta någon.
Future<String?> hamta(String url) async {
  final client = HttpClient()
    ..userAgent = userAgent
    ..connectionTimeout = const Duration(seconds: 20);
  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close().timeout(const Duration(seconds: 30));
    final body = await response
        .transform(utf8.decoder)
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
