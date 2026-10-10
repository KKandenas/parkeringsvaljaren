import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkeringsvaljaren/models/katalog.dart';
import 'package:parkeringsvaljaren/services/app_oppnare.dart';

void main() {
  const medSchema = ParkeringsApp(
    id: 'x',
    namn: 'X',
    appStoreId: '1',
    iosSchema: 'xapp',
  );
  const medLank = ParkeringsApp(
    id: 'y',
    namn: 'Y',
    appStoreId: '2',
    universellLank: 'https://y.se/app',
    iosSchema: 'yapp',
  );
  const utan = ParkeringsApp(id: 'z', namn: 'Z', appStoreId: '3');

  test('schemat provas bara på iPhone och iPad', () {
    expect(
      AppOppnare.schemaForWebben(medSchema, TargetPlatform.iOS),
      'xapp://',
    );
    // Safari på iPad säger sig vara en Mac.
    expect(
      AppOppnare.schemaForWebben(medSchema, TargetPlatform.macOS),
      'xapp://',
    );
    expect(
      AppOppnare.schemaForWebben(medSchema, TargetPlatform.android),
      isNull,
    );
  });

  test('universell länk går före schemat', () {
    expect(AppOppnare.schemaForWebben(medLank, TargetPlatform.iOS), isNull);
    expect(
      AppOppnare.lankForWebben(medLank, TargetPlatform.iOS),
      'https://y.se/app',
    );
  });

  test('utan schema eller länk: App Store', () {
    expect(AppOppnare.schemaForWebben(utan, TargetPlatform.iOS), isNull);
    expect(
      AppOppnare.lankForWebben(utan, TargetPlatform.iOS),
      'https://apps.apple.com/se/app/id3',
    );
  });
}
