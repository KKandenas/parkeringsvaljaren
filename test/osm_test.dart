import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parkeringsvaljaren/services/osm.dart';
import 'package:parkeringsvaljaren/services/uppslag.dart';

import 'hjalp.dart';

void main() {
  const sergel = (59.3326, 18.0649);

  test('adressen ur Nominatims svar', () {
    final a = Adress.fromJson(fixtur('nominatim_kalmar.json'))!;
    expect(a.visas, 'Tullslätten, Kalmar');
    expect(a.address['municipality'], 'Kalmar kommun');
  });

  test('parkeringar ur Overpass, närmaste först', () {
    final p = OverpassClient.tolka(
      fixtur('overpass_stockholm.json'),
      sergel.$1,
      sergel.$2,
    );
    expect(p, isNotEmpty);
    for (var i = 1; i < p.length; i++) {
      expect(p[i].avstand, greaterThanOrEqualTo(p[i - 1].avstand));
    }
    // Ytor (way) har sin mittpunkt i center.
    expect(p.where((x) => x.namn == null), isNotEmpty);
    expect(p.firstWhere((x) => x.namn == 'Oxtorget').arPrivat, isTrue);
  });

  test('avstånd', () {
    // En hundradels grad latitud är ungefär 1 112 meter.
    expect(avstand(59.0, 18.0, 59.01, 18.0), closeTo(1112, 2));
  });

  group('Nominatim', () {
    test('identifierar appen, frågar en gång per punkt', () async {
      final anrop = <http.Request>[];
      final client = NominatimClient(
        client: MockClient((r) async {
          anrop.add(r);
          return http.Response.bytes(
            utf8.encode(json.encode(fixtur('nominatim_kalmar.json'))),
            200,
          );
        }),
      );
      await client.reverse(56.66341, 16.35681);
      await client.reverse(56.66342, 16.35679);
      expect(anrop, hasLength(1));
      expect(
        anrop.single.headers['User-Agent'],
        startsWith('Parkeringsvaljaren/'),
      );
      expect(anrop.single.url.queryParameters['accept-language'], 'sv');
    });

    test('högst ett anrop per sekund', () async {
      final tider = <DateTime>[];
      final client = NominatimClient(
        minstaMellanrum: const Duration(milliseconds: 300),
        client: MockClient((r) async {
          tider.add(DateTime.now());
          return http.Response('{"address": {}}', 200);
        }),
      );
      await client.reverse(56.0, 16.0);
      await client.reverse(57.0, 16.0);
      expect(
        tider[1].difference(tider[0]),
        greaterThanOrEqualTo(const Duration(milliseconds: 290)),
      );
    });
  });

  group('Uppslag', () {
    Uppslag uppslag({bool overpassFel = false}) => Uppslag(
      riktigKatalog(),
      nominatim: NominatimClient(
        client: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(json.encode(fixtur('nominatim_stockholm.json'))),
            200,
          ),
        ),
      ),
      overpass: OverpassClient(
        client: MockClient(
          (_) async => overpassFel
              ? http.Response('busy', 504)
              : http.Response.bytes(
                  utf8.encode(json.encode(fixtur('overpass_stockholm.json'))),
                  200,
                ),
        ),
      ),
    );

    test('kommun och närmaste operatör som inte är privat', () async {
      final steg = await uppslag().slaUpp(sergel.$1, sergel.$2).toList();
      expect(steg, hasLength(2));
      expect(steg.first.letarOperator, isTrue);
      expect(steg.first.kommun?.namn, 'Stockholm');
      final plats = steg.last;
      expect(plats.letarOperator, isFalse);
      expect(plats.kommun?.namn, 'Stockholm');
      expect(plats.adress, contains('Stockholm'));
      expect(plats.parkering?.operator, isNotNull);
      expect(plats.parkering!.arPrivat, isFalse);
      expect(plats.operatorFel, isFalse);
    });

    test('kommunen fungerar även när Overpass är nere', () async {
      final plats = await uppslag(overpassFel: true)
          .slaUpp(sergel.$1, sergel.$2)
          .last;
      expect(plats.kommun?.namn, 'Stockholm');
      expect(plats.parkering, isNull);
      expect(plats.operatorFel, isTrue);
    });
  });
}
