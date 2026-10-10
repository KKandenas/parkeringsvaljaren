import 'package:flutter_test/flutter_test.dart';
import 'package:parkeringsvaljaren/logic/normalisera.dart';
import 'package:parkeringsvaljaren/logic/operator_matcher.dart';

import 'hjalp.dart';

void main() {
  final matcher = OperatorMatcher(riktigKatalog().operatorer);

  test('normalisera', () {
    expect(normalisera('Q-Park Sverige AB'), 'q park sverige ab');
    expect(
      normalisera('  Göteborgs Stads Parkerings AB '),
      'goteborgs stads parkerings ab',
    );
  });

  test('stavningar som finns i OpenStreetMap', () {
    expect(matcher.appFor('Q-Park'), 'qpark');
    expect(matcher.appFor('QPark'), 'qpark');
    expect(matcher.appFor('Aimo Park Sweden AB'), 'aimo');
    expect(matcher.appFor('APCOA PARKING'), 'apcoa');
    expect(matcher.appFor('Parkering Göteborg'), 'parkering-goteborg');
    // De vanligaste värdena i Sverige enligt taginfo.
    expect(matcher.appFor('Göteborgs Stads Parkerings AB'), 'parkering-goteborg');
    expect(matcher.appFor('Aimopark'), 'aimo');
    expect(matcher.appFor('Biskopen / Aimo Park'), 'aimo');
    expect(matcher.appFor('Q-Park AB'), 'qpark');
    expect(matcher.appFor('Europark'), 'apcoa');
  });

  test('bara hela ord', () {
    expect(matcher.appFor('Kaimon Fastigheter'), isNull);
  });

  test('okända operatörer', () {
    expect(matcher.appFor('Stockholms Stads Parkerings AB'), isNull);
    expect(matcher.appFor('Bostadsrättsföreningen Eken'), isNull);
  });
}
