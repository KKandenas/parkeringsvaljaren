// Kontrollerar datafilerna i assets/data. Körs i CI, så att en felaktig
// ändring av kommunlistan inte går igenom.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkeringsvaljaren/logic/normalisera.dart';
import 'package:parkeringsvaljaren/models/katalog.dart';

import 'hjalp.dart';

void main() {
  final katalog = riktigKatalog();
  final datum = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  test('alla 290 kommuner, unika koder och namn', () {
    expect(katalog.kommuner, hasLength(290));
    expect({for (final k in katalog.kommuner) k.kod}, hasLength(290));
    expect({for (final k in katalog.kommuner) k.osmNamn}, hasLength(290));
    for (final k in katalog.kommuner) {
      expect(k.kod, matches(RegExp(r'^\d{4}$')));
    }
  });

  test('verifierade kommuner har appar och belägg', () {
    for (final k in katalog.kommuner) {
      final namn = '${k.kod} ${k.namn}';
      if (k.status == KommunStatus.okand) {
        expect(k.appar, isEmpty, reason: '$namn är okänd men har appar');
        continue;
      }
      if (k.status == KommunStatus.avgiftsfri) {
        expect(k.appar, isEmpty, reason: '$namn är avgiftsfri men har appar');
      } else {
        expect(k.appar, isNotEmpty, reason: namn);
      }
      expect(k.appar.toSet(), hasLength(k.appar.length), reason: namn);
      expect(k.kallor, isNotEmpty, reason: '$namn saknar källa');
      expect(k.kontrollerad, matches(datum), reason: namn);
      for (final kalla in k.kallor) {
        expect(Uri.parse(kalla.url).scheme, 'https', reason: namn);
        expect(kalla.citat.trim(), isNotEmpty, reason: namn);
        expect(kalla.hamtad, matches(datum), reason: namn);
      }
      for (final id in k.appar) {
        expect(katalog.appar, contains(id), reason: '$namn: okänd app $id');
      }
    }
  });

  test('kommande ändringar och namnsOcksa pekar på kända appar', () {
    final rader =
        (json.decode(File('assets/data/kommuner.json').readAsStringSync())
                as Map)['kommuner']
            as List;
    for (final k in rader) {
      final namn = '${k['kod']} ${k['namn']}';
      final kommande = k['kommande'] as Map?;
      if (kommande != null) {
        expect(kommande['fran'], matches(datum), reason: namn);
        for (final id in kommande['appar'] as List) {
          expect(katalog.appar, contains(id), reason: '$namn: okänd app $id');
        }
      }
      for (final kalla in (k['kallor'] as List? ?? const [])) {
        for (final id in (kalla['namnsOcksa'] as List? ?? const [])) {
          expect(katalog.appar, contains(id), reason: '$namn: okänd app $id');
        }
      }
    }
  });

  test('apparna har unika id och paketnamn', () {
    final rader =
        (json.decode(File('assets/data/apps.json').readAsStringSync())
                as Map)['appar']
            as List;
    expect(katalog.appar, hasLength(rader.length), reason: 'dubblett-id');
    final paket = [
      for (final a in katalog.appar.values)
        if (a.android != null) a.android,
    ];
    expect(paket.toSet(), hasLength(paket.length));
    for (final a in katalog.appar.values) {
      expect(a.android != null || a.appStoreId != null, isTrue, reason: a.id);
      // Bara schemats namn, utan "://".
      if (a.iosSchema != null) {
        expect(
          a.iosSchema,
          matches(RegExp(r'^[a-z][a-z0-9.+-]*$')),
          reason: a.id,
        );
      }
    }
  });

  test('AndroidManifest frågar efter alla paket', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    for (final a in katalog.appar.values) {
      if (a.android == null) continue;
      expect(
        manifest,
        contains('<package android:name="${a.android}"/>'),
        reason: 'Lägg till ${a.android} under <queries>',
      );
    }
  });

  test('operatörsreglerna pekar på kända appar och är normaliserade', () {
    for (final r in katalog.operatorer) {
      expect(katalog.appar, contains(r.app));
      for (final m in r.monster) {
        expect(normalisera(m), m);
      }
    }
  });

  test('bolagslistan: en rad per app, i operatorer.json-ordning', () {
    expect(
      [for (final a in katalog.bolag) a.id],
      [
        'aimo',
        'qpark',
        'apcoa',
        'easypark',
        'parkster',
        'parkering-goteborg',
        'linpark',
        'parkit',
      ],
    );
  });
}
