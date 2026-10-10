import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkeringsvaljaren/models/katalog.dart';
import 'package:parkeringsvaljaren/screens/hem_skarm.dart';
import 'package:parkeringsvaljaren/services/mina_appar.dart';
import 'package:parkeringsvaljaren/services/uppslag.dart';
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
    expect(find.text('Kalmar kommun'), findsOneWidget);
    expect(find.text('Gäller här'), findsOneWidget);
    expect(find.text('Mobill'), findsOneWidget);
    expect(find.textContaining('kontrollerad'), findsOneWidget);
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
    final forsta = tester.widget<ListTile>(find.byType(ListTile).first);
    expect((forsta.title as Text).data, 'Q-Park');
    expect(
      find.text('Driver parkeringen enligt OpenStreetMap'),
      findsOneWidget,
    );
  });
}
