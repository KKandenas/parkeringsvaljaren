import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Favoriter, dolda appar och appar som har öppnats härifrån. Sparas på
/// enheten.
class MinaAppar extends ChangeNotifier {
  MinaAppar(this._prefs)
    : favoriter = {...?_prefs.getStringList(_favoriterNyckel)},
      dolda = {...?_prefs.getStringList(_doldaNyckel)},
      harAppen = {...?_prefs.getStringList(_harAppenNyckel)};

  static const _favoriterNyckel = 'favoriter';
  static const _doldaNyckel = 'dolda';
  static const _harAppenNyckel = 'har_appen';

  final SharedPreferences _prefs;
  final Set<String> favoriter;
  final Set<String> dolda;

  /// Appar som webbversionen har öppnat, och som alltså finns på enheten.
  final Set<String> harAppen;

  Future<void> markeraHarAppen(String id) => satHarAppen(id, true);

  /// "Jag har appen" i Mina appar. Behövs på iPhone, där webbsidan inte
  /// själv kan se vilka appar som finns.
  Future<void> satHarAppen(String id, bool pa) async {
    if (pa ? !harAppen.add(id) : !harAppen.remove(id)) return;
    notifyListeners();
    await _prefs.setStringList(_harAppenNyckel, harAppen.toList()..sort());
  }

  static Future<MinaAppar> las() async =>
      MinaAppar(await SharedPreferences.getInstance());

  /// En favorit kan inte vara dold, och tvärtom.
  Future<void> satFavorit(String id, bool pa) async {
    if (pa) {
      favoriter.add(id);
      dolda.remove(id);
    } else {
      favoriter.remove(id);
    }
    await _spara();
  }

  Future<void> satDold(String id, bool pa) async {
    if (pa) {
      dolda.add(id);
      favoriter.remove(id);
    } else {
      dolda.remove(id);
    }
    await _spara();
  }

  Future<void> _spara() async {
    notifyListeners();
    await _prefs.setStringList(_favoriterNyckel, favoriter.toList()..sort());
    await _prefs.setStringList(_doldaNyckel, dolda.toList()..sort());
  }
}
