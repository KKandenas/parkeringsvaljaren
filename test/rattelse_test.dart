import 'package:flutter_test/flutter_test.dart';
import 'package:parkeringsvaljaren/logic/rattelse.dart';

import 'hjalp.dart';

void main() {
  test('ärendet innehåller kommun och appar men ingen position', () {
    final lank = rattelseLank(
      kommun: kommun(['a']),
      visade: [app('a'), app('b')],
      operator: 'Q-Park',
    );
    expect(lank.host, 'github.com');
    expect(lank.path, '/$githubProjekt/issues/new');
    final text = lank.queryParameters['body']!;
    expect(text, contains('Testby (9999)'));
    expect(text, contains('A, B'));
    expect(text, contains('Q-Park'));
    expect(text, isNot(matches(RegExp(r'\d+\.\d{3,}'))));
  });

  test('okänd kommun', () {
    final lank = rattelseLank(kommun: null, visade: const []);
    expect(lank.queryParameters['title'], 'Rättelse: okänd kommun');
  });
}
