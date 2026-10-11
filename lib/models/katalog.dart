import 'dart:convert';

/// En parkeringsapp ur assets/data/apps.json.
class ParkeringsApp {
  const ParkeringsApp({
    required this.id,
    required this.namn,
    this.android,
    this.appStoreId,
    this.universellLank,
    this.iosSchema,
    this.iosAppLank,
    this.webb,
  });

  final String id;
  final String namn;

  /// Paketnamnet på Google Play.
  final String? android;

  /// Appens id i App Store (siffrorna i apps.apple.com/se/app/id…).
  final String? appStoreId;

  /// Adress som öppnar appen på iPhone, enligt appens
  /// apple-app-site-association. Saknas den öppnas App Store i stället.
  final String? universellLank;

  /// Eget URL-schema som öppnar appen på iPhone, t.ex. "parkster" för
  /// parkster://. Bara scheman som har prövats på en riktig iPhone
  /// (web/lanktest.html) får stå här.
  final String? iosSchema;

  /// Universell länk som öppnar appen men som utan appen leder till en
  /// webbsida i stället för App Store. Används bara när man har appen.
  final String? iosAppLank;

  final String? webb;

  String? get playUrl => android == null
      ? null
      : 'https://play.google.com/store/apps/details?id=$android';

  String? get appStoreUrl =>
      appStoreId == null ? null : 'https://apps.apple.com/se/app/id$appStoreId';

  factory ParkeringsApp.fromJson(Map<String, dynamic> json) => ParkeringsApp(
    id: json['id'] as String,
    namn: json['namn'] as String,
    android: json['android'] as String?,
    appStoreId: json['appStoreId'] as String?,
    universellLank: json['universellLank'] as String?,
    iosSchema: json['iosSchema'] as String?,
    iosAppLank: json['iosAppLank'] as String?,
    webb: json['webb'] as String?,
  );
}

/// Varifrån en uppgift om en kommun kommer.
class Kalla {
  const Kalla({
    required this.url,
    required this.titel,
    required this.citat,
    required this.hamtad,
  });

  final String url;
  final String titel;

  /// Kort ordagrant utdrag ur sidan som belägg.
  final String citat;

  /// När sidan lästes, ÅÅÅÅ-MM-DD.
  final String hamtad;

  factory Kalla.fromJson(Map<String, dynamic> json) => Kalla(
    url: json['url'] as String,
    titel: json['titel'] as String,
    citat: json['citat'] as String,
    hamtad: json['hamtad'] as String,
  );
}

enum KommunStatus {
  /// Ingen har kontrollerat än.
  okand,

  /// Apparna står på kommunens eller dess parkeringsbolags webbplats.
  verifierad,

  /// Kommunen skriver att gatuparkeringen är avgiftsfri (ofta med
  /// p-skiva). Ingen app behövs på kommunens gator.
  avgiftsfri,
}

/// En kommun ur assets/data/kommuner.json.
class Kommun {
  const Kommun({
    required this.kod,
    required this.namn,
    required this.osmNamn,
    required this.status,
    this.appar = const [],
    this.anmarkning,
    this.kallor = const [],
    this.kontrollerad,
  });

  /// SCB:s kommunkod, fyra siffror.
  final String kod;

  /// Namnet enligt SCB, t.ex. "Falun".
  final String namn;

  /// Namnet i OpenStreetMap och Nominatim, t.ex. "Falu kommun".
  final String osmNamn;

  final KommunStatus status;

  /// Kontrollerad mot en källa, med appar eller som avgiftsfri.
  bool get arKontrollerad => status != KommunStatus.okand;

  /// Appar för kommunal gatuparkering, i kommunens ordning.
  final List<String> appar;

  final String? anmarkning;
  final List<Kalla> kallor;

  /// När uppgifterna senast kontrollerades, ÅÅÅÅ-MM-DD.
  final String? kontrollerad;

  factory Kommun.fromJson(Map<String, dynamic> json) {
    final gata = json['gatuparkering'] as Map<String, dynamic>?;
    return Kommun(
      kod: json['kod'] as String,
      namn: json['namn'] as String,
      osmNamn: json['osmNamn'] as String,
      status: KommunStatus.values.byName(json['status'] as String),
      appar: [...?(gata?['appar'] as List?)?.cast<String>()],
      anmarkning: gata?['anmarkning'] as String?,
      kallor: [
        for (final k in (json['kallor'] as List? ?? const []))
          Kalla.fromJson(k as Map<String, dynamic>),
      ],
      kontrollerad: json['kontrollerad'] as String?,
    );
  }
}

/// Kopplar operator-taggen i OpenStreetMap till en app.
class OperatorRegel {
  const OperatorRegel({required this.monster, required this.app});

  /// Normaliserade ord som ska finnas i operator-värdet, t.ex. "aimo".
  final List<String> monster;
  final String app;

  factory OperatorRegel.fromJson(Map<String, dynamic> json) => OperatorRegel(
    monster: (json['monster'] as List).cast<String>(),
    app: json['app'] as String,
  );
}

/// Alla uppgifter appen bygger på, inlästa från assets/data.
class Katalog {
  Katalog({
    required List<ParkeringsApp> appar,
    required this.kommuner,
    required this.operatorer,
  }) : appar = {for (final a in appar) a.id: a};

  /// Apparna efter id, i samma ordning som i apps.json.
  final Map<String, ParkeringsApp> appar;
  final List<Kommun> kommuner;
  final List<OperatorRegel> operatorer;

  factory Katalog.fromJsonStrings({
    required String apps,
    required String kommuner,
    required String operatorer,
  }) => Katalog(
    appar: [
      for (final a in (json.decode(apps) as Map)['appar'] as List)
        ParkeringsApp.fromJson(a as Map<String, dynamic>),
    ],
    kommuner: [
      for (final k in (json.decode(kommuner) as Map)['kommuner'] as List)
        Kommun.fromJson(k as Map<String, dynamic>),
    ],
    operatorer: [
      for (final o in (json.decode(operatorer) as Map)['operatorer'] as List)
        OperatorRegel.fromJson(o as Map<String, dynamic>),
    ],
  );
}
