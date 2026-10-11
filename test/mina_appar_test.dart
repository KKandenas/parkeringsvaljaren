import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkeringsvaljaren/screens/mina_appar_skarm.dart';
import 'package:parkeringsvaljaren/services/mina_appar.dart';
import 'package:parkeringsvaljaren/tema.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'hjalp.dart';

void main() {
  Future<MinaAppar> tom() async {
    SharedPreferences.setMockInitialValues({});
    return MinaAppar.las();
  }

  test('favorit och dold utesluter varandra', () async {
    final mina = await tom();
    await mina.satFavorit('a', true);
    await mina.satDold('a', true);
    expect(mina.favoriter, isEmpty);
    expect(mina.dolda, {'a'});
    await mina.satFavorit('a', true);
    expect(mina.dolda, isEmpty);
  });

  test('"Jag har appen" sparas', () async {
    final mina = await tom();
    await mina.satHarAppen('mobill', true);
    final igen = await MinaAppar.las();
    expect(igen.harAppen, {'mobill'});
    await igen.satHarAppen('mobill', false);
    expect((await MinaAppar.las()).harAppen, isEmpty);
  });

  Future<void> visa(WidgetTester tester, MinaAppar mina) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: tema(Brightness.light),
        home: MinaApparSkarm(katalog: riktigKatalog(), minaAppar: mina),
      ),
    );
  }

  testWidgets('reglaget "Jag har appen" finns på iPhone', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final mina = await tom();
      await visa(tester, mina);
      expect(find.text('Jag har appen'), findsWidgets);
      await tester.tap(find.text('Jag har appen').first);
      await tester.pump();
      // Listan är i bokstavsordning, så den första är Aimo Park.
      expect(mina.harAppen, {'aimo'});
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('men inte i Android-appen, som ser det själv', (tester) async {
    await visa(tester, await tom());
    expect(find.text('Jag har appen'), findsNothing);
  });
}
