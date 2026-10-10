import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../logic/kommun_resolver.dart';
import '../logic/operator_matcher.dart';
import '../models/katalog.dart';
import 'osm.dart';

Future<Katalog> lasKatalog([AssetBundle? bundle]) async {
  final b = bundle ?? rootBundle;
  return Katalog.fromJsonStrings(
    apps: await b.loadString('assets/data/apps.json'),
    kommuner: await b.loadString('assets/data/kommuner.json'),
    operatorer: await b.loadString('assets/data/operatorer.json'),
  );
}

/// Vad appen vet om platsen. Koordinaterna sparas inte här: de används
/// bara under själva uppslaget.
class Plats {
  const Plats({
    this.adress,
    this.kommun,
    this.parkering,
    this.operatorApp,
    this.operatorFel = false,
    this.letarOperator = false,
  });

  final String? adress;
  final Kommun? kommun;

  /// Närmaste parkering i OpenStreetMap som har en operatör.
  final OsmParkering? parkering;

  /// Appen som hör till operatören, om den är känd.
  final String? operatorApp;

  /// Overpass svarade inte, så privata parkeringar är okända.
  final bool operatorFel;

  /// Overpass har inte svarat än.
  final bool letarOperator;
}

class PositionFel implements Exception {
  const PositionFel(this.meddelande);
  final String meddelande;
  @override
  String toString() => meddelande;
}

/// Hämtar positionen och slår upp adress, kommun och parkeringsoperatör.
class Uppslag {
  Uppslag(this.katalog, {NominatimClient? nominatim, OverpassClient? overpass})
    : _nominatim = nominatim ?? NominatimClient(),
      _overpass = overpass ?? OverpassClient(),
      _resolver = KommunResolver(katalog.kommuner),
      _operatorer = OperatorMatcher(katalog.operatorer);

  final Katalog katalog;
  final NominatimClient _nominatim;
  final OverpassClient _overpass;
  final KommunResolver _resolver;
  final OperatorMatcher _operatorer;

  /// Ger först adress och kommun, sedan samma plats med operatören när
  /// Overpass har svarat (den tjänsten är ofta långsam).
  Stream<Plats> har() async* {
    final position = await _position();
    yield* slaUpp(position.latitude, position.longitude);
  }

  Stream<Plats> slaUpp(double lat, double lon) async* {
    // Nominatim och Overpass är olika tjänster och kan frågas samtidigt.
    final parkeringar = _overpass
        .nara(lat, lon)
        .then<List<OsmParkering>?>(
          (p) => p,
          onError: (Object e) {
            debugPrint('Overpass: $e');
            return null;
          },
        );
    final adress = await _nominatim.reverse(lat, lon);
    final grund = Plats(
      adress: adress?.visas,
      kommun: adress == null ? null : _resolver.resolve(adress.address),
      letarOperator: true,
    );
    yield grund;

    final nara = await parkeringar;
    OsmParkering? parkering;
    String? app;
    for (final p in nara ?? const <OsmParkering>[]) {
      if (p.operator == null || p.arPrivat) continue;
      parkering = p;
      app = _operatorer.appFor(p.operator!);
      break;
    }
    yield Plats(
      adress: grund.adress,
      kommun: grund.kommun,
      parkering: parkering,
      operatorApp: app,
      operatorFel: nara == null,
    );
  }

  static Future<Position> _position() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const PositionFel('Platstjänster är avstängda.');
    }
    var tillstand = await Geolocator.checkPermission();
    if (tillstand == LocationPermission.denied) {
      tillstand = await Geolocator.requestPermission();
    }
    if (tillstand == LocationPermission.denied ||
        tillstand == LocationPermission.deniedForever) {
      throw const PositionFel('Appen får inte använda din position.');
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
  }
}
