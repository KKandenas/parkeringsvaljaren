import 'dart:convert';
import 'dart:io';

import 'package:parkeringsvaljaren/models/katalog.dart';

/// De riktiga datafilerna i assets/data.
Katalog riktigKatalog() => Katalog.fromJsonStrings(
  apps: File('assets/data/apps.json').readAsStringSync(),
  kommuner: File('assets/data/kommuner.json').readAsStringSync(),
  operatorer: File('assets/data/operatorer.json').readAsStringSync(),
);

Map<String, dynamic> fixtur(String namn) =>
    json.decode(File('test/fixtures/$namn').readAsStringSync())
        as Map<String, dynamic>;

ParkeringsApp app(String id, {String? android}) =>
    ParkeringsApp(id: id, namn: id.toUpperCase(), android: android ?? 'se.$id');

Kommun kommun(List<String> appar) => Kommun(
  kod: '9999',
  namn: 'Testby',
  osmNamn: 'Testby kommun',
  status: KommunStatus.verifierad,
  appar: appar,
);
