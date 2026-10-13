import 'package:flutter/material.dart';

import '../logic/app_urval.dart';
import '../models/katalog.dart';
import '../tema.dart';

/// Två bokstäver som ersätter appens logga: "EasyPark" → "EP",
/// "Aimo Park" → "AP", "Mobill" → "Mo". Riktiga loggor används inte.
String initialer(String namn) {
  final ord = namn.split(RegExp(r'[\s-]+')).where((o) => o.isNotEmpty).toList();
  if (ord.length > 1) return '${ord[0][0]}${ord[1][0]}'.toUpperCase();
  final stor = RegExp(r'[A-ZÅÄÖ]').firstMatch(namn.substring(1));
  if (stor != null && stor.start < 4) return '${namn[0]}${stor.group(0)}';
  return namn.length < 2 ? namn : namn.substring(0, 2);
}

// Neutrala färger, valda efter app-id så att samma app alltid får samma.
const _loggfarger = [
  Color(0xFF2E6F95),
  Color(0xFF5A49C9),
  Color(0xFF0B8A5F),
  Color(0xFFB4532A),
  Color(0xFF8E3B8E),
  Color(0xFF3E6B2E),
  Color(0xFF7A5C12),
  Color(0xFF9B2F45),
];

class AppLogga extends StatelessWidget {
  const AppLogga({super.key, required this.app});

  final ParkeringsApp app;

  @override
  Widget build(BuildContext context) {
    final farg =
        _loggfarger[app.id.codeUnits.fold(0, (a, b) => a + b) %
            _loggfarger.length];
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: farg,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        initialer(app.namn),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 15,
        ),
      ),
    );
  }
}

/// Litet märke efter namnet, t.ex. INSTALLERAD.
class Marke extends StatelessWidget {
  const Marke(this.text, {super.key, required this.farg});

  final String text;
  final Color farg;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: farg.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        color: farg,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    ),
  );
}

/// En app som kort, med knapp som öppnar den (eller butiken).
class AppRad extends StatelessWidget {
  const AppRad({
    super.key,
    required this.forslag,
    required this.onOppna,
    this.forstaval = false,
    this.viaAppStore = false,
  });

  final Forslag forslag;
  final VoidCallback onOppna;

  /// Det bästa valet här: markeras med en gul ram.
  final bool forstaval;

  /// Appen finns men kan bara öppnas via App Store (iPhone utan direktlänk).
  final bool viaAppStore;

  static String? beskrivning(Forslag f) => switch (f.skal) {
    Skal.operator => 'Bolagets egen app',
    Skal.kommun =>
      f.favorit ? 'Favorit · kommunens app' : 'Kommunens gatuparkering',
    null => f.favorit ? 'Favorit' : null,
  };

  @override
  Widget build(BuildContext context) {
    final f = Farger.av(context);
    final text = Theme.of(context).textTheme;
    final saknas = forslag.installerad == false;
    final viaButik = viaAppStore && forslag.installerad == true;
    final om = [
      ?beskrivning(forslag),
      if (viaButik) 'öppnas via App Store',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: f.kort,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: forstaval
              ? BorderSide(color: f.accent, width: 2)
              : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              AppLogga(app: forslag.app),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          forslag.app.namn,
                          style: text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (forslag.installerad == true)
                          Marke('Installerad', farg: f.ok),
                        if (saknas) Marke('Hämta', farg: f.dampad),
                      ],
                    ),
                    if (om.isNotEmpty)
                      Text(
                        om,
                        style: text.bodySmall?.copyWith(color: f.dampad),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              saknas || viaButik
                  ? OutlinedButton(
                      onPressed: onOppna,
                      child: Text(saknas ? 'Hämta' : 'App Store'),
                    )
                  : FilledButton(
                      onPressed: onOppna,
                      child: const Text('Öppna'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
