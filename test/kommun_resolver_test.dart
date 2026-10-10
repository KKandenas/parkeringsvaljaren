import 'package:flutter_test/flutter_test.dart';
import 'package:parkeringsvaljaren/logic/kommun_resolver.dart';
import 'package:parkeringsvaljaren/services/osm.dart';

import 'hjalp.dart';

void main() {
  final resolver = KommunResolver(riktigKatalog().kommuner);

  Map<String, dynamic> adress(String? kommun, {String land = 'se'}) => {
    'municipality': ?kommun,
    'country_code': land,
  };

  test('Kalmar enligt ett riktigt svar från Nominatim', () {
    final svar = Adress.fromJson(fixtur('nominatim_kalmar.json'))!;
    expect(resolver.resolve(svar.address)?.kod, '0880');
  });

  test('Stockholm enligt ett riktigt svar från Nominatim', () {
    final svar = Adress.fromJson(fixtur('nominatim_stockholm.json'))!;
    expect(resolver.resolve(svar.address)?.kod, '0180');
  });

  test('oregelbundna namn i OpenStreetMap', () {
    expect(resolver.resolve(adress('Falu kommun'))?.namn, 'Falun');
    expect(resolver.resolve(adress('Göteborgs Stad'))?.namn, 'Göteborg');
    expect(resolver.resolve(adress('Gotlands kommun'))?.namn, 'Gotland');
  });

  test('namn som skrivs lite annorlunda', () {
    expect(resolver.resolve(adress('Stockholms stad'))?.kod, '0180');
    expect(resolver.resolve(adress('KALMAR KOMMUN'))?.kod, '0880');
    expect(resolver.resolve(adress('Malmö'))?.kod, '1280');
  });

  test('utanför Sverige eller utan kommun', () {
    expect(resolver.resolve(adress('Oslo kommune', land: 'no')), isNull);
    expect(resolver.resolve(adress(null)), isNull);
    expect(resolver.resolve(adress('Påhittad kommun')), isNull);
  });
}
