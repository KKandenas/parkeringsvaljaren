import '../models/katalog.dart';

/// Varför en app visas under "Gäller här".
enum Skal {
  /// Bolaget driver parkeringen enligt OpenStreetMap.
  operator,

  /// Kommunen tar emot appen för gatuparkering.
  kommun,
}

class Forslag {
  const Forslag({
    required this.app,
    required this.skal,
    required this.favorit,
    required this.installerad,
  });

  final ParkeringsApp app;

  /// Null för appar under "Andra appar".
  final Skal? skal;
  final bool favorit;

  /// Null när det inte går att veta (webbversionen).
  final bool? installerad;
}

class Urval {
  const Urval({required this.galler, required this.andra});

  /// Apparna som gäller här, bästa först.
  final List<Forslag> galler;

  /// Övriga appar som inte är dolda.
  final List<Forslag> andra;
}

/// Väljer och sorterar apparna.
///
/// Under "Gäller här": operatörens app först, sedan favoriter, installerade
/// och resten. Inom varje grupp gäller operatörens, sedan kommunens ordning.
/// Under "Andra appar": favoriter, installerade, sedan efter namn. Dolda
/// appar visas aldrig.
Urval valjAppar({
  required Katalog katalog,
  Kommun? kommun,
  List<String> operatorAppar = const [],
  Set<String> favoriter = const {},
  Set<String> dolda = const {},
  Set<String>? installerade,
}) {
  Forslag forslag(ParkeringsApp app, Skal? skal) => Forslag(
    app: app,
    skal: skal,
    favorit: favoriter.contains(app.id),
    installerad: installerade == null
        ? null
        : app.android != null && installerade.contains(app.android),
  );

  final galler = <String, Forslag>{};
  for (final (ids, skal) in [
    (operatorAppar, Skal.operator),
    (kommun?.appar ?? const <String>[], Skal.kommun),
  ]) {
    for (final id in ids) {
      final app = katalog.appar[id];
      if (app == null || dolda.contains(id) || galler.containsKey(id)) continue;
      galler[id] = forslag(app, skal);
    }
  }

  int rang(Forslag f) => f.skal == Skal.operator
      ? 0
      : f.favorit
      ? 1
      : f.installerad == true
      ? 2
      : 3;

  // List.sort är inte stabil, så den ursprungliga ordningen får avgöra.
  final ordning = galler.keys.toList();
  final gallerLista = galler.values.toList()
    ..sort((a, b) {
      final r = rang(a).compareTo(rang(b));
      return r != 0 ? r : ordning.indexOf(a.app.id) - ordning.indexOf(b.app.id);
    });

  final andra =
      [
        for (final app in katalog.appar.values)
          if (!galler.containsKey(app.id) && !dolda.contains(app.id))
            forslag(app, null),
      ]..sort((a, b) {
        final r = rang(a).compareTo(rang(b));
        return r != 0
            ? r
            : a.app.namn.toLowerCase().compareTo(b.app.namn.toLowerCase());
      });

  return Urval(galler: gallerLista, andra: andra);
}
