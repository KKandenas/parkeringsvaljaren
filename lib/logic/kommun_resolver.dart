import '../models/katalog.dart';
import 'normalisera.dart';

/// Hittar kommunen i ett adressvar från Nominatim.
class KommunResolver {
  KommunResolver(List<Kommun> kommuner)
    : _efterOsmNamn = {for (final k in kommuner) k.osmNamn: k},
      _efterNamn = {
        for (final k in kommuner) ...{
          normalisera(k.namn): k,
          normalisera(k.osmNamn): k,
          normalisera(_utanKommun(k.osmNamn)): k,
        },
      };

  final Map<String, Kommun> _efterOsmNamn;
  final Map<String, Kommun> _efterNamn;

  /// address = fältet "address" i Nominatims svar (format=jsonv2).
  /// Returnerar null utanför Sverige eller om kommunen inte går att avgöra.
  Kommun? resolve(Map<String, dynamic> address) {
    if (address['country_code'] != 'se') return null;
    final namn = address['municipality'] as String?;
    if (namn == null) return null;
    return _efterOsmNamn[namn] ??
        _efterNamn[normalisera(namn)] ??
        _efterNamn[normalisera(_utanKommun(namn))];
  }

  /// "Stockholms kommun" → "Stockholms", "Göteborgs Stad" → "Göteborgs".
  static String _utanKommun(String namn) =>
      namn.replaceFirst(RegExp(r'\s+(kommun|stad)$', caseSensitive: false), '');
}
