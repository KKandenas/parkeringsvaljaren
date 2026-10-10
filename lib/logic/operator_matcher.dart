import '../models/katalog.dart';
import 'normalisera.dart';

/// Vilken app hör till operator-värdet på en parkering i OpenStreetMap?
class OperatorMatcher {
  const OperatorMatcher(this.regler);

  final List<OperatorRegel> regler;

  /// App-id, eller null om operatören inte är känd. Mönstret måste stå som
  /// hela ord, så att "aimo" inte träffar t.ex. "Kaimon".
  String? appFor(String operator) {
    final text = ' ${normalisera(operator)} ';
    for (final regel in regler) {
      if (regel.monster.every((m) => text.contains(' $m '))) return regel.app;
    }
    return null;
  }
}
