import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Identifierar appen mot OpenStreetMaps tjänster, som deras regler kräver.
/// Webbläsare får inte sätta User-Agent. Där identifierar Referer appen.
const userAgent =
    'Parkeringsvaljaren/1.0 (+https://github.com/KKandenas/parkeringsvaljaren)';

Map<String, String> get _headers =>
    kIsWeb ? const {} : {'User-Agent': userAgent};

/// Adressen till en punkt enligt Nominatim.
class Adress {
  const Adress({required this.visas, required this.address});

  /// Gata och ort att visa, t.ex. "Tullslätten, Kalmar".
  final String visas;

  /// Nominatims address-fält, som KommunResolver läser.
  final Map<String, dynamic> address;

  static Adress? fromJson(Map<String, dynamic> json) {
    final address = json['address'];
    if (address is! Map<String, dynamic>) return null;
    final gata = [
      address['road'],
      address['house_number'],
    ].whereType<String>().join(' ');
    final ort =
        (address['city'] ??
                address['town'] ??
                address['village'] ??
                address['hamlet'] ??
                address['suburb'])
            as String?;
    return Adress(
      visas: [gata, ort].where((s) => s != null && s.isNotEmpty).join(', '),
      address: address,
    );
  }
}

/// Omvänd geokodning via Nominatim. Högst ett anrop per sekund, och svaren
/// sparas i minnet så länge appen är öppen. Inget sparas på disk, eftersom
/// positionen bara får användas i stunden.
class NominatimClient {
  NominatimClient({
    http.Client? client,
    this.minstaMellanrum = const Duration(seconds: 1),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration minstaMellanrum;
  final _cache = <String, Adress?>{};
  DateTime? _senaste;

  /// Punkter inom ungefär tio meter räknas som samma.
  static String cacheNyckel(double lat, double lon) =>
      '${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}';

  Future<Adress?> reverse(double lat, double lon) async {
    final nyckel = cacheNyckel(lat, lon);
    if (_cache.containsKey(nyckel)) return _cache[nyckel];

    final senaste = _senaste;
    if (senaste != null) {
      final vanta = minstaMellanrum - DateTime.now().difference(senaste);
      if (vanta > Duration.zero) await Future<void>.delayed(vanta);
    }
    _senaste = DateTime.now();

    final url = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'format': 'jsonv2',
      'lat': '$lat',
      'lon': '$lon',
      'zoom': '18',
      'addressdetails': '1',
      'accept-language': 'sv',
    });
    final response = await _client
        .get(url, headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Nominatim svarade ${response.statusCode}',
        url,
      );
    }
    final adress = Adress.fromJson(
      json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
    return _cache[nyckel] = adress;
  }
}

/// En parkering i OpenStreetMap.
class OsmParkering {
  const OsmParkering({
    required this.namn,
    required this.operator,
    required this.avstand,
    this.access,
  });

  final String? namn;
  final String? operator;
  final String? access;

  /// Bara för boende, anställda och liknande.
  bool get arPrivat => access == 'private' || access == 'no';

  /// Meter från positionen.
  final double avstand;
}

/// Parkeringar nära en punkt, via Overpass.
class OverpassClient {
  OverpassClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final _cache = <String, List<OsmParkering>>{};

  static const _url = 'https://overpass-api.de/api/interpreter';

  /// Hur långt bort en parkering får ligga för att räknas som "här".
  static const radie = 60;

  static String fraga(double lat, double lon) =>
      '[out:json][timeout:10];'
      'nwr(around:$radie,$lat,$lon)[amenity=parking];'
      'out tags center;';

  /// Närmaste först. Kastar vid fel. Den som anropar visar då bara
  /// kommunens appar.
  Future<List<OsmParkering>> nara(double lat, double lon) async {
    final nyckel = NominatimClient.cacheNyckel(lat, lon);
    final sparad = _cache[nyckel];
    if (sparad != null) return sparad;

    final response = await _client
        .post(
          Uri.parse(_url),
          headers: _headers,
          body: {'data': fraga(lat, lon)},
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw http.ClientException('Overpass svarade ${response.statusCode}');
    }
    return _cache[nyckel] = tolka(
      json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      lat,
      lon,
    );
  }

  static List<OsmParkering> tolka(
    Map<String, dynamic> svar,
    double lat,
    double lon,
  ) {
    final parkeringar = <OsmParkering>[];
    for (final e in svar['elements'] as List? ?? const []) {
      final tags = (e['tags'] as Map?)?.cast<String, dynamic>() ?? const {};
      final punkt = (e['center'] ?? e) as Map;
      final plat = (punkt['lat'] as num?)?.toDouble();
      final plon = (punkt['lon'] as num?)?.toDouble();
      if (plat == null || plon == null) continue;
      parkeringar.add(
        OsmParkering(
          namn: tags['name'] as String?,
          operator: tags['operator'] as String?,
          access: tags['access'] as String?,
          avstand: avstand(lat, lon, plat, plon),
        ),
      );
    }
    return parkeringar..sort((a, b) => a.avstand.compareTo(b.avstand));
  }
}

/// Avstånd i meter mellan två punkter (haversine).
double avstand(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0;
  double rad(double g) => g * pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a =
      pow(sin(dLat / 2), 2) +
      cos(rad(lat1)) * cos(rad(lat2)) * pow(sin(dLon / 2), 2);
  return 2 * r * asin(sqrt(a));
}
