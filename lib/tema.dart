import 'package:flutter/material.dart';

/// Färger efter den svenska P-skylten: skyltblått, och vägmarkeringsgult
/// sparsamt för det man ska trycka på.
@immutable
class Farger extends ThemeExtension<Farger> {
  const Farger({
    required this.skylt,
    required this.accent,
    required this.paAccent,
    required this.kort,
    required this.dampad,
    required this.ok,
  });

  /// P-skyltens blå.
  final Color skylt;

  /// Vägmarkeringsgul: Öppna-knappen och förstavalet.
  final Color accent;
  final Color paAccent;

  /// Bakgrund för appkorten.
  final Color kort;

  /// Text som är mindre viktig.
  final Color dampad;

  /// Märket "Installerad".
  final Color ok;

  static const ljus = Farger(
    skylt: Color(0xFF0B4EA2),
    accent: Color(0xFFE8A400),
    paAccent: Color(0xFF1A1300),
    kort: Color(0xFFFFFFFF),
    dampad: Color(0xFF5A6577),
    ok: Color(0xFF1F8A4C),
  );

  static const mork = Farger(
    skylt: Color(0xFF2F74D0),
    accent: Color(0xFFF2B72C),
    paAccent: Color(0xFF1A1300),
    kort: Color(0xFF1B2639),
    dampad: Color(0xFF9AA6BA),
    ok: Color(0xFF7FE0A6),
  );

  static Farger av(BuildContext context) =>
      Theme.of(context).extension<Farger>()!;

  @override
  Farger copyWith() => this;

  @override
  Farger lerp(Farger? other, double t) => t < 0.5 ? this : (other ?? this);
}

ThemeData tema(Brightness ljushet) {
  final ljus = ljushet == Brightness.light;
  final f = ljus ? Farger.ljus : Farger.mork;
  final bakgrund = ljus ? const Color(0xFFF4F6F9) : const Color(0xFF0F1726);
  final text = ljus ? const Color(0xFF142033) : const Color(0xFFEEF2F8);
  final schema = ColorScheme.fromSeed(seedColor: f.skylt, brightness: ljushet)
      .copyWith(
        primary: f.skylt,
        onPrimary: Colors.white,
        surface: bakgrund,
        onSurface: text,
        surfaceContainerLow: f.kort,
      );
  final bas = ThemeData(
    colorScheme: schema,
    useMaterial3: true,
    scaffoldBackgroundColor: bakgrund,
    extensions: [f],
  );
  return bas.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: bakgrund,
      foregroundColor: text,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: bas.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        color: text,
        letterSpacing: -0.2,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: f.accent,
        foregroundColor: f.paAccent,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        visualDensity: VisualDensity.compact,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: text,
        side: BorderSide(color: text.withValues(alpha: 0.3)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
        visualDensity: VisualDensity.compact,
      ),
    ),
  );
}

/// Den blå P-skylten, som märke i rubriker.
class PSkylt extends StatelessWidget {
  const PSkylt({super.key, this.storlek = 30});

  final double storlek;

  @override
  Widget build(BuildContext context) {
    final f = Farger.av(context);
    return Container(
      width: storlek,
      height: storlek,
      decoration: BoxDecoration(
        color: f.skylt,
        borderRadius: BorderRadius.circular(storlek * 0.16),
        border: Border.all(color: Colors.white, width: storlek * 0.07),
        boxShadow: [BoxShadow(color: f.skylt, spreadRadius: 1)],
      ),
      alignment: Alignment.center,
      child: Text(
        'P',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: storlek * 0.62,
          height: 1,
        ),
      ),
    );
  }
}
