import 'package:flutter/material.dart';

import 'models/katalog.dart';
import 'screens/hem_skarm.dart';
import 'services/mina_appar.dart';
import 'services/uppslag.dart';
import 'tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final katalog = await lasKatalog();
  final minaAppar = await MinaAppar.las();
  runApp(Parkeringsvaljaren(katalog: katalog, minaAppar: minaAppar));
}

class Parkeringsvaljaren extends StatelessWidget {
  const Parkeringsvaljaren({
    super.key,
    required this.katalog,
    required this.minaAppar,
    this.uppslag,
  });

  final Katalog katalog;
  final MinaAppar minaAppar;

  /// Kan bytas ut i tester.
  final Uppslag? uppslag;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parkeringsväljaren',
      debugShowCheckedModeBanner: false,
      locale: const Locale('sv', 'SE'),
      theme: tema(Brightness.light),
      darkTheme: tema(Brightness.dark),
      home: HemSkarm(
        katalog: katalog,
        minaAppar: minaAppar,
        uppslag: uppslag ?? Uppslag(katalog),
      ),
    );
  }
}
