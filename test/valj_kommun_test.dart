import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkeringsvaljaren/logic/normalisera.dart';
import 'package:parkeringsvaljaren/screens/hem_skarm.dart';
import 'package:parkeringsvaljaren/screens/valj_kommun_skarm.dart';
import 'package:parkeringsvaljaren/services/mina_appar.dart';
import 'package:parkeringsvaljaren/services/uppslag.dart';
import 'package:parkeringsvaljaren/tema.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'hjalp.dart';

/// Positionen är avstängd.
class UtanPosition extends Uppslag {
  UtanPosition(super.katalog);
  @override
  Stream<Plats> har() =>
      Stream.error(const PositionFel('Appen får inte använda din position.'));
}

void main() {
  test('svensk bokstavsordning', () {
    final namn = [
      'Örebro',
      'Ale',
      'Åre',
      'Ängelholm',
      'Östersund',
      'Övertorneå',
    ]..sort(svenskOrdning);
    expect(namn, [
      'Ale',
      'Åre',
      'Ängelholm',
      'Örebro',
      'Östersund',
      'Övertorneå',
    ]);
  });

  test('sökning efter kommun', () {
    final alla = riktigKatalog().kommuner;
    List<String> sok(String s) => [
      for (final k in sokKommuner(alla, s)) k.namn,
    ];
    expect(sok('ör').first, 'Örebro');
    expect(sok('ör'), isNot(contains('Bengtsfors')));
    expect(sok('orebro'), ['Örebro']);
    expect(sok('göte'), ['Göteborg', 'Götene']);
    // Namn som börjar med texten först.
    expect(sok('sala').first, 'Sala');
    expect(sok(''), hasLength(290));
  });

  testWidgets('välj kommun när positionen är avstängd', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final katalog = riktigKatalog();
    await tester.pumpWidget(
      MaterialApp(
        theme: tema(Brightness.light),
        home: HemSkarm(
          katalog: katalog,
          minaAppar: await MinaAppar.las(),
          uppslag: UtanPosition(katalog),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Appen får inte använda din position.'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Välj kommun'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'orebro');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Örebro'));
    await tester.pumpAndSettle();

    expect(find.text('Vald kommun'), findsOneWidget);
    expect(find.text('Örebro kommun'), findsOneWidget);
    expect(find.text('EasyPark'), findsOneWidget);
    expect(find.text('Använd min position'), findsOneWidget);
  });
}
