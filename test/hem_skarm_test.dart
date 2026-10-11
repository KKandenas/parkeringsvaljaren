import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkeringsvaljaren/models/katalog.dart';
import 'package:parkeringsvaljaren/screens/hem_skarm.dart';
import 'package:parkeringsvaljaren/services/mina_appar.dart';
import 'package:parkeringsvaljaren/services/osm.dart';
import 'package:parkeringsvaljaren/services/uppslag.dart';
import 'package:parkeringsvaljaren/tema.dart';
import 'package:parkeringsvaljaren/widgets/app_rad.dart';
import 'package:parkeringsvaljaren/widgets/varning.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'hjalp.dart';

/// Ger en färdig plats utan position eller nätverk.
class FastUppslag extends Uppslag {
  FastUppslag(super.katalog, this.plats);
  final Plats plats;
  @override
  Stream<Plats> har() => Stream.value(plats);
}

void main() {
  final katalog = riktigKatalog();
  Kommun kommunMedKod(String kod) =>
      katalog.kommuner.firstWhere((k) => k.kod == kod);

  Future<MinaAppar> minaAppar(Map<String, Object> varden) async {
    SharedPreferences.setMockInitialValues(varden);
    return MinaAppar.las();
  }

  Future<void> visa(WidgetTester tester, Plats plats, MinaAppar mina) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: tema(Brightness.light),
        home: HemSkarm(
          katalog: katalog,
          minaAppar: mina,
          uppslag: FastUppslag(katalog, plats),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('verifierad kommun: appar, källa och varning', (tester) async {
    await visa(
      tester,
      Plats(adress: 'Tullslätten, Kalmar', kommun: kommunMedKod('0880')),
      await minaAppar({}),
    );
    expect(find.text(Varning.text), findsOneWidget);
    expect(find.text('Kalmar kommun · gatuparkering'), findsOneWidget);
    expect(find.text('Du står vid'), findsOneWidget);
    expect(find.text('Gäller här'), findsOneWidget);
    expect(find.text('Mobill'), findsOneWidget);
    expect(find.textContaining('kontrollerad'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Det här stämmer inte'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Det här stämmer inte'), findsOneWidget);
  });

  testWidgets('okänd kommun: alla appar och en uppmaning', (tester) async {
    final okand = katalog.kommuner.firstWhere(
      (k) => k.status == KommunStatus.okand,
    );
    await visa(tester, Plats(kommun: okand), await minaAppar({}));
    expect(find.textContaining('inte kontrollerat'), findsOneWidget);
    expect(find.text('Alla appar'), findsOneWidget);
    expect(find.text('Gäller här'), findsNothing);
  });

  testWidgets('dolda appar syns inte', (tester) async {
    await visa(
      tester,
      Plats(kommun: kommunMedKod('0880')),
      await minaAppar({
        'dolda': ['mobill'],
      }),
    );
    expect(find.text('Mobill'), findsNothing);
    expect(find.text('Parking Time'), findsOneWidget);
  });

  testWidgets('operatörens app först', (tester) async {
    await visa(
      tester,
      Plats(kommun: kommunMedKod('0180'), operatorApp: 'qpark'),
      await minaAppar({}),
    );
    final forsta = tester.widget<AppRad>(find.byType(AppRad).first);
    expect(forsta.forslag.app.namn, 'Q-Park');
    expect(forsta.forstaval, isTrue);
    expect(find.text('Bolagets egen app'), findsOneWidget);
  });

  testWidgets('privat parkering: bolaget och "Fel bolag?"', (tester) async {
    await visa(
      tester,
      Plats(
        kommun: kommunMedKod('0180'),
        parkering: const OsmParkering(
          namn: 'Zenit',
          operator: 'Q-Park',
          avstand: 12,
        ),
        operatorApp: 'qpark',
      ),
      await minaAppar({}),
    );
    expect(find.text('Zenit'), findsOneWidget);
    expect(find.text('Närmaste parkering · 12 m'), findsOneWidget);
    expect(find.textContaining('Drivs av Q-Park'), findsOneWidget);
    expect(find.text('Fel bolag? Rätta här.'), findsOneWidget);
  });

  test('initialer i stället för loggor', () {
    expect(initialer('EasyPark'), 'EP');
    expect(initialer('Aimo Park'), 'AP');
    expect(initialer('Mobill'), 'Mo');
    expect(initialer('ePARK'), 'eP');
    expect(initialer('Q-Park'), 'QP');
  });

  testWidgets('avgiftsfri kommun: besked och hopfälld lista', (tester) async {
    await visa(
      tester,
      Plats(kommun: kommunMedKod('1383')),
      await minaAppar({}),
    );
    expect(
      find.textContaining('Gatuparkeringen är avgiftsfri'),
      findsOneWidget,
    );
    expect(find.text('Gäller här'), findsNothing);
    expect(find.text('Alla appar'), findsOneWidget);
    // Listan är hopfälld, så inga appkort syns.
    expect(find.byType(AppRad), findsNothing);
  });
}
