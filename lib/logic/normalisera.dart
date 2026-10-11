const _bokstaver = {
  'å': 'a',
  'ä': 'a',
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ö': 'o',
  'ø': 'o',
  'ó': 'o',
  'ô': 'o',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'ü': 'u',
  'ú': 'u',
  'í': 'i',
  'æ': 'ae',
};

/// Gemener utan accenter, och allt som inte är bokstäver eller siffror blir
/// ett mellanslag. "Q-Park Sverige AB" → "q park sverige ab".
String normalisera(String text) {
  final buffer = StringBuffer();
  for (final tecken in text.toLowerCase().split('')) {
    buffer.write(_bokstaver[tecken] ?? tecken);
  }
  return buffer.toString().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

/// Jämför namn i svensk bokstavsordning: Å, Ä och Ö efter Z, i den ordningen.
int svenskOrdning(String a, String b) => _nyckel(a).compareTo(_nyckel(b));

String _nyckel(String s) => s
    .toLowerCase()
    .replaceAll('å', '{0')
    .replaceAll('ä', '{1')
    .replaceAll('æ', '{1')
    .replaceAll('ö', '{2')
    .replaceAll('ø', '{2');
