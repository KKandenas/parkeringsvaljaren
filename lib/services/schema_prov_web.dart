import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Skickar Safari till url (t.ex. "parkster://") och väntar. Döljs sidan
/// har en app tagit emot adressen: då returneras true. Annars false efter
/// vanta, och den som anropar öppnar App Store i stället.
Future<bool> provaSchema(String url, Duration vanta) async {
  final klar = Completer<bool>();
  void dold(web.Event _) {
    if (web.document.visibilityState == 'hidden' && !klar.isCompleted) {
      klar.complete(true);
    }
  }

  final lyssnare = dold.toJS;
  web.document.addEventListener('visibilitychange', lyssnare);
  web.window.addEventListener('pagehide', lyssnare);
  final timer = Timer(vanta, () {
    if (!klar.isCompleted) klar.complete(false);
  });
  web.window.location.href = url;
  try {
    return await klar.future;
  } finally {
    timer.cancel();
    web.document.removeEventListener('visibilitychange', lyssnare);
    web.window.removeEventListener('pagehide', lyssnare);
  }
}
