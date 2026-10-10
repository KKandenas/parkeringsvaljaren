import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Favoriter och dolda appar. Sparas på enheten.
class MinaAppar extends ChangeNotifier {
  MinaAppar(this._prefs)
    : favoriter = {...?_prefs.getStringList(_favoriterNyckel)},
      dolda = {...?_prefs.getStringList(_doldaNyckel)};

  static const _favoriterNyckel = 'favoriter';
  static const _doldaNyckel = 'dolda';

  final SharedPreferences _prefs;
  final Set<String> favoriter;
  final Set<String> dolda;

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
