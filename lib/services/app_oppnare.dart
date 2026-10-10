import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/katalog.dart';

/// Ser vilka appar som finns och öppnar dem.
///
/// Android: via MainActivity (kanalen "parkering/appar"). Appen startas med
/// paketnamnet. Saknas den öppnas Google Play.
/// Webben: en webbsida kan inte se vilka appar som är installerade. På
/// iPhone öppnas appens universella länk om den har en, annars App Store,
/// där det står "Öppna" om appen redan finns.
class AppOppnare {
  AppOppnare({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('parkering/appar');

  final MethodChannel _channel;

  static bool get arAndroidApp =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Paketnamnen bland packages som är installerade, eller null där det
  /// inte går att veta.
  Future<Set<String>?> installerade(Iterable<String> packages) async {
    if (!arAndroidApp) return null;
    try {
      final svar = await _channel.invokeListMethod<String>('installerade', {
        'packages': packages.toList(),
      });
      return {...?svar};
    } on PlatformException catch (e) {
      debugPrint('Kunde inte läsa installerade appar: $e');
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Öppnar appen, eller butiken om den saknas. Returnerar false om inget
  /// gick att öppna.
  Future<bool> oppna(ParkeringsApp app) async {
    if (arAndroidApp && app.android != null) {
      try {
        final oppnad = await _channel.invokeMethod<bool>('oppna', {
          'package': app.android,
          'url': app.universellLank,
        });
        if (oppnad == true) return true;
      } on PlatformException catch (e) {
        debugPrint('Kunde inte öppna ${app.namn}: $e');
      } on MissingPluginException {
        // Inte i Android-appen (t.ex. tester).
      }
      return await _lank('market://details?id=${app.android}') ||
          await _lank(app.playUrl);
    }
    return _lank(lankForWebben(app, defaultTargetPlatform));
  }

  /// Vart webbversionen skickar användaren för appen. Safari på iPad
  /// utger sig för att vara en Mac, så macOS behandlas som iPhone.
  static String? lankForWebben(ParkeringsApp app, TargetPlatform plattform) =>
      switch (plattform) {
        TargetPlatform.iOS || TargetPlatform.macOS =>
          app.universellLank ?? app.appStoreUrl ?? app.webb,
        TargetPlatform.android => app.playUrl ?? app.webb,
        _ => app.webb ?? app.appStoreUrl ?? app.playUrl,
      };

  static Future<bool> _lank(String? url) async {
    if (url == null) return false;
    try {
      return await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }
}
