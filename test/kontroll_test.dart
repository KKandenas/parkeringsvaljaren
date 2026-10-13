import 'package:flutter_test/flutter_test.dart';
import 'package:parkeringsvaljaren/logic/normalisera.dart';
import 'package:parkeringsvaljaren/models/katalog.dart';

import '../tool/kontrollera_kallor.dart';
import 'hjalp.dart';

void main() {
  String t(String s) => normalisera(s);

  test('appnamn hittas som egna ord', () {
    expect(nams(t('Betala med ePARK eller Mobill.'), 'ePARK'), isTrue);
    expect(nams(t('E-park och Parkster'), 'ePARK'), isTrue);
    expect(nams(t('Easy Park'), 'EasyPark'), isTrue);
    expect(nams(t("EasyParks app"), 'EasyPark'), isTrue);
    expect(nams(t('limepark.swarco-parking'), 'ePARK'), isFalse);
    expect(nams(t('Parking Time AB'), 'Parking Time'), isTrue);
    expect(nams(t('parkeringstiden'), 'Parking Time'), isFalse);
  });

  final katalog = riktigKatalog();
  final namn = {
    for (final a in katalog.appar.values) a.id: [a.namn],
  };

  test('ny app på sidan rapporteras', () {
    final fel = granska(
      kommun(['easypark']),
      t('Betala med EasyPark eller Mobill.'),
      {'easypark'},
      {},
      katalog,
      namn,
      'https://x.se',
    );
    expect(fel.single, contains('Mobill'));
    expect(fel.single, contains('Ny app?'));
  });

  test('app som försvunnit rapporteras', () {
    final fel = granska(
      kommun(['easypark', 'parkster']),
      t('Betala med EasyPark.'),
      {'easypark', 'parkster'},
      {},
      katalog,
      namn,
      'https://x.se',
    );
    expect(fel.single, contains('Parkster nämns inte längre'));
  });

  test('appar som nämns av andra skäl räknas inte', () {
    final fel = granska(
      kommun(['easypark']),
      t('Betala med EasyPark. Övervakningen sköts av Aimo Park.'),
      {'easypark'},
      {'aimo'},
      katalog,
      namn,
      'https://x.se',
    );
    expect(fel, isEmpty);
  });

  const fri = Kommun(
    kod: '9999',
    namn: 'Testby',
    osmNamn: 'Testby kommun',
    status: KommunStatus.avgiftsfri,
  );

  test('avgiftsfri kommun som börjar nämna appar', () {
    final fel = granska(
      fri,
      t('Parkeringen är avgiftsfri. Vid hamnen betalar du med Parkster.'),
      {},
      {},
      katalog,
      namn,
      'https://x.se',
    );
    expect(fel.single, contains('infört avgift'));
  });

  test('avgiftsfri kommun vars sida inte längre säger gratis', () {
    final fel = granska(
      fri,
      t('Parkeringsavgiften är 10 kronor per timme.'),
      {},
      {},
      katalog,
      namn,
      'https://x.se',
    );
    expect(fel.single, contains('inte längre att parkeringen är avgiftsfri'));
  });

  test('kommande ändring gäller från sitt datum', () {
    const k = Kommun(
      kod: '9999',
      namn: 'Testby',
      osmNamn: 'Testby kommun',
      status: KommunStatus.avgiftsfri,
      kommande: KommandeAndring(fran: '2026-11-01', appar: ['parkster']),
    );
    expect(k.pa('2026-10-31').appar, isEmpty);
    expect(k.pa('2026-10-31').status, KommunStatus.avgiftsfri);
    expect(k.pa('2026-11-01').appar, ['parkster']);
    expect(k.pa('2026-11-01').status, KommunStatus.verifierad);
  });
}
