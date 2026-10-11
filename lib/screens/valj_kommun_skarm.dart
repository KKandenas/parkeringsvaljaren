import 'package:flutter/material.dart';

import '../logic/normalisera.dart';
import '../models/katalog.dart';
import '../tema.dart';

/// Välj kommun för hand, utan position. Returnerar den valda kommunen.
class ValjKommunSkarm extends StatefulWidget {
  const ValjKommunSkarm({super.key, required this.kommuner});

  final List<Kommun> kommuner;

  @override
  State<ValjKommunSkarm> createState() => _ValjKommunSkarmState();
}

class _ValjKommunSkarmState extends State<ValjKommunSkarm> {
  var _sok = '';

  @override
  Widget build(BuildContext context) {
    final f = Farger.av(context);
    final text = Theme.of(context).textTheme;
    final kommuner = sokKommuner(widget.kommuner, _sok);
    final antalKlara = widget.kommuner
        .where((k) => k.status == KommunStatus.verifierad)
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('Välj kommun')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Sök kommun',
                filled: true,
                fillColor: f.kort,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _sok = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Apparna är kontrollerade för $antalKlara av '
              '${widget.kommuner.length} kommuner. Övriga visar alla appar.',
              style: text.bodySmall?.copyWith(color: f.dampad),
            ),
          ),
          Expanded(
            child: kommuner.isEmpty
                ? Center(
                    child: Text(
                      'Ingen kommun heter så.',
                      style: text.bodyMedium?.copyWith(color: f.dampad),
                    ),
                  )
                : ListView.builder(
                    itemCount: kommuner.length,
                    itemBuilder: (context, i) {
                      final k = kommuner[i];
                      final klar = k.status == KommunStatus.verifierad;
                      return ListTile(
                        title: Text(k.namn),
                        subtitle: Text(
                          klar
                              ? '${k.appar.length} ${k.appar.length == 1 ? 'app' : 'appar'} · kontrollerad ${k.kontrollerad}'
                              : 'Inte kontrollerad än',
                          style: text.bodySmall?.copyWith(color: f.dampad),
                        ),
                        trailing: klar
                            ? Icon(Icons.verified, color: f.ok)
                            : null,
                        onTap: () => Navigator.of(context).pop(k),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Kommuner som matchar sökningen. Namn som börjar med texten kommer
/// först. Skriver man å, ä eller ö jämförs de exakt ("ör" ger Örebro men
/// inte Bengtsfors), annars räcker bokstaven utan prickar ("orebro").
List<Kommun> sokKommuner(List<Kommun> kommuner, String sok) {
  final text = sok.trim().toLowerCase();
  final exakt = RegExp('[åäöéü]').hasMatch(text);
  String jamfor(String namn) => exakt ? namn.toLowerCase() : normalisera(namn);
  final nyckel = exakt ? text : normalisera(text);
  final traffar = [
    for (final k in kommuner)
      if (nyckel.isEmpty || jamfor(k.namn).contains(nyckel)) k,
  ];
  int borjar(Kommun k) => jamfor(k.namn).startsWith(nyckel) ? 0 : 1;
  return traffar..sort((a, b) {
    final r = borjar(a) - borjar(b);
    return r != 0 ? r : svenskOrdning(a.namn, b.namn);
  });
}
