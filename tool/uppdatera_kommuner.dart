// Bygger om grunden i assets/data/kommuner.json: alla kommuner med SCB:s
// kommunkod och namn, och namnet som OpenStreetMap (och därmed Nominatim)
// använder. De handgjorda uppgifterna om parkering lämnas orörda.
//
//   dart run tool/uppdatera_kommuner.dart
//
// Källor:
//   SCB:  Region i tabellen BefolkningNy (api.scb.se), koder med fyra siffror.
//   OSM:  relationer med boundary=administrative, admin_level=7 och ref:scb,
//         via Overpass.
import 'dart:convert';
import 'dart:io';

const userAgent =
    'Parkeringsvaljaren/0.1 (+https://github.com/KKandenas/parkeringsvaljaren)';
const scbUrl =
    'https://api.scb.se/OV0104/v1/doris/sv/ssd/BE/BE0101/BE0101A/BefolkningNy';
// Overpass svarar ibland 504 när servern är hårt belastad. Försök igen och
// prova en annan server.
const overpassUrls = [
  'https://overpass-api.de/api/interpreter',
  'https://overpass.private.coffee/api/interpreter',
];
const overpassQuery =
    '[out:json][timeout:90];'
    'rel[boundary=administrative][admin_level=7]["ref:scb"];out tags;';

final file = File('assets/data/kommuner.json');

Future<void> main() async {
  final scb = await hamtaScb();
  final osm = await hamtaOsm();

  final saknas = scb.keys.where((kod) => !osm.containsKey(kod)).toList();
  if (scb.length < 290 || saknas.isNotEmpty) {
    stderr.writeln(
      'Avbryter: SCB gav ${scb.length} kommuner, '
      'saknas i OSM: ${saknas.join(', ')}',
    );
    exit(1);
  }

  final data = file.existsSync()
      ? json.decode(file.readAsStringSync()) as Map<String, dynamic>
      : <String, dynamic>{};
  final tidigare = {
    for (final k in (data['kommuner'] as List? ?? const []))
      (k as Map<String, dynamic>)['kod'] as String: k,
  };

  final koder = scb.keys.toList()..sort();
  final kommuner = [
    for (final kod in koder)
      {
        // Ordningen på nycklarna gör filen lätt att läsa och jämföra.
        'kod': kod,
        'namn': scb[kod],
        'osmNamn': osm[kod],
        'status': 'okand',
        ...?tidigare[kod]
          ?..remove('kod')
          ..remove('namn')
          ..remove('osmNamn'),
      },
  ];
  final borta = tidigare.keys.where((kod) => !scb.containsKey(kod));
  if (borta.isNotEmpty) {
    stderr.writeln('Varning: kommunkoder som inte längre finns: $borta');
  }

  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert({
      'schemaVersion': 1,
      'grunddata': {'kalla': 'Kommunkoder och namn: SCB (api.scb.se, tabell BefolkningNy). '
          'osmNamn: OpenStreetMap, relationer med ref:scb.', 'hamtad': DateTime.now().toIso8601String().substring(0, 10)},
      'kommuner': kommuner,
    })}\n',
  );
  stdout.writeln('${kommuner.length} kommuner skrivna till ${file.path}.');
}

Future<Map<String, String>> hamtaScb() async {
  final svar = json.decode(await hamta(Uri.parse(scbUrl))) as Map;
  final region = (svar['variables'] as List).firstWhere(
    (v) => v['code'] == 'Region',
  );
  final koder = (region['values'] as List).cast<String>();
  final namn = (region['valueTexts'] as List).cast<String>();
  return {
    for (var i = 0; i < koder.length; i++)
      if (koder[i].length == 4) koder[i]: namn[i],
  };
}

Future<Map<String, String>> hamtaOsm() async {
  late String body;
  for (var forsok = 0; ; forsok++) {
    final url = overpassUrls[forsok % overpassUrls.length];
    try {
      body = await hamta(
        Uri.parse(url),
        post: 'data=${Uri.encodeQueryComponent(overpassQuery)}',
      );
      break;
    } on HttpException catch (e) {
      if (forsok == 5) rethrow;
      stderr.writeln('$e, försöker igen');
      await Future<void>.delayed(Duration(seconds: 10 * (forsok + 1)));
    }
  }
  final element = (json.decode(body) as Map)['elements'] as List;
  return {
    for (final e in element)
      (e['tags']['ref:scb'] as String): e['tags']['name'] as String,
  };
}

Future<String> hamta(Uri url, {String? post}) async {
  final client = HttpClient()..userAgent = userAgent;
  try {
    final request = post == null
        ? await client.getUrl(url)
        : await client.postUrl(url);
    if (post != null) {
      request.headers.contentType = ContentType(
        'application',
        'x-www-form-urlencoded',
        charset: 'utf-8',
      );
      request.write(post);
    }
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      throw HttpException('${response.statusCode} från $url');
    }
    return body;
  } finally {
    client.close();
  }
}
