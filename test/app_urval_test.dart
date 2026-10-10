import 'package:flutter_test/flutter_test.dart';
import 'package:parkeringsvaljaren/logic/app_urval.dart';
import 'package:parkeringsvaljaren/models/katalog.dart';

import 'hjalp.dart';

void main() {
  final katalog = Katalog(
    appar: [app('a'), app('b'), app('c'), app('d'), app('e'), app('op')],
    kommuner: const [],
    operatorer: const [],
  );
  List<String> ids(List<Forslag> f) => [for (final x in f) x.app.id];

  test('kommunens ordning när inget annat gäller', () {
    final u = valjAppar(katalog: katalog, kommun: kommun(['c', 'a', 'b']));
    expect(ids(u.galler), ['c', 'a', 'b']);
    expect(ids(u.andra), ['d', 'e', 'op']);
  });

  test('operatör, favorit, installerad, övriga', () {
    final u = valjAppar(
      katalog: katalog,
      kommun: kommun(['a', 'b', 'c', 'd']),
      operatorAppar: ['op'],
      favoriter: {'c'},
      installerad: (a) => a.id == 'd',
    );
    expect(ids(u.galler), ['op', 'c', 'd', 'a', 'b']);
    expect(u.galler.first.skal, Skal.operator);
    expect(u.galler[1].favorit, isTrue);
    expect(u.galler[2].installerad, isTrue);
    expect(u.galler[3].installerad, isFalse);
  });

  test('operatören går före en favorit', () {
    final u = valjAppar(
      katalog: katalog,
      kommun: kommun(['a']),
      operatorAppar: ['op'],
      favoriter: {'a'},
    );
    expect(ids(u.galler), ['op', 'a']);
  });

  test('operatörens app som också är kommunens visas en gång', () {
    final u = valjAppar(
      katalog: katalog,
      kommun: kommun(['a', 'b']),
      operatorAppar: ['b'],
    );
    expect(ids(u.galler), ['b', 'a']);
    expect(u.galler.first.skal, Skal.operator);
  });

  test('dolda appar visas aldrig', () {
    final u = valjAppar(
      katalog: katalog,
      kommun: kommun(['a', 'b']),
      operatorAppar: ['op'],
      dolda: {'b', 'op', 'e'},
    );
    expect(ids(u.galler), ['a']);
    expect(ids(u.andra), ['c', 'd']);
  });

  test('okänd kommun: allt under andra, favoriter först', () {
    final u = valjAppar(
      katalog: katalog,
      favoriter: {'e'},
      installerad: (a) => a.id == 'c',
    );
    expect(u.galler, isEmpty);
    expect(ids(u.andra), ['e', 'c', 'a', 'b', 'd', 'op']);
  });

  test('på iPhone är bara bekräftade appar kända', () {
    final u = valjAppar(
      katalog: katalog,
      kommun: kommun(['a', 'b']),
      installerad: (a) => a.id == 'b' ? true : null,
    );
    expect(ids(u.galler), ['b', 'a']);
    expect(u.galler.last.installerad, isNull);
  });

  test('installerad är okänt på webben', () {
    final u = valjAppar(katalog: katalog, kommun: kommun(['a']));
    expect(u.galler.single.installerad, isNull);
  });

  test('okända app-id hoppas över', () {
    final u = valjAppar(katalog: katalog, kommun: kommun(['finns-inte', 'a']));
    expect(ids(u.galler), ['a']);
  });
}
