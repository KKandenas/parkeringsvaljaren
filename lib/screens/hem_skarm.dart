import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../logic/app_urval.dart';
import '../logic/rattelse.dart';
import '../models/katalog.dart';
import '../services/app_oppnare.dart';
import '../services/mina_appar.dart';
import '../services/uppslag.dart';
import '../tema.dart';
import '../widgets/app_rad.dart';
import '../widgets/varning.dart';
import 'mina_appar_skarm.dart';
import 'valj_kommun_skarm.dart';

class HemSkarm extends StatefulWidget {
  const HemSkarm({
    super.key,
    required this.katalog,
    required this.minaAppar,
    required this.uppslag,
    this.oppnare,
  });

  final Katalog katalog;
  final MinaAppar minaAppar;
  final Uppslag uppslag;
  final AppOppnare? oppnare;

  @override
  State<HemSkarm> createState() => _HemSkarmState();
}

class _HemSkarmState extends State<HemSkarm> with WidgetsBindingObserver {
  late final AppOppnare _oppnare = widget.oppnare ?? AppOppnare();
  Plats? _plats;
  Object? _fel;
  bool _letar = false;

  /// Kommunen är vald för hand, inte efter positionen.
  bool _forHand = false;

  /// Räknas upp vid varje uppslag och val, så att ett gammalt uppslag som
  /// blir klart sent inte skriver över ett nyare.
  int _uppslagNr = 0;
  Set<String>? _installerade;

  /// Bolaget man själv valt efter skylten på en privat parkering.
  String? _valtBolag;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.minaAppar.addListener(_andrat);
    _lasInstallerade();
    _leta();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.minaAppar.removeListener(_andrat);
    super.dispose();
  }

  // Man kan ha installerat en app i butiken och kommit tillbaka.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _lasInstallerade();
  }

  void _andrat() => setState(() {});

  /// Android vet vilka appar som finns. Webben vet bara om appar som har
  /// öppnats härifrån, och resten är okända.
  /// iPhone: appen kan bara öppnas via App Store.
  bool _viaAppStore(ParkeringsApp app) =>
      AppOppnare.arIphoneWebb &&
      !AppOppnare.kanOppnasDirekt(
        app,
        defaultTargetPlatform,
        harAppen: widget.minaAppar.harAppen.contains(app.id),
      );

  bool? _arInstallerad(ParkeringsApp app) {
    if (AppOppnare.arAndroidApp) {
      return _installerade?.contains(app.android);
    }
    return widget.minaAppar.harAppen.contains(app.id) ? true : null;
  }

  Future<void> _lasInstallerade() async {
    final paket = [
      for (final a in widget.katalog.appar.values)
        if (a.android != null) a.android!,
    ];
    final svar = await _oppnare.installerade(paket);
    if (mounted) setState(() => _installerade = svar);
  }

  Future<void> _leta() async {
    final nr = ++_uppslagNr;
    setState(() {
      _letar = true;
      _forHand = false;
      _fel = null;
      _valtBolag = null;
    });
    try {
      await for (final plats in widget.uppslag.har()) {
        if (mounted && nr == _uppslagNr) setState(() => _plats = plats);
      }
    } catch (e) {
      if (mounted && nr == _uppslagNr) setState(() => _fel = e);
    } finally {
      if (mounted && nr == _uppslagNr) setState(() => _letar = false);
    }
  }

  Future<void> _valjKommun() async {
    final kommun = await Navigator.of(context).push<Kommun>(
      MaterialPageRoute(
        builder: (_) => ValjKommunSkarm(kommuner: widget.katalog.kommuner),
      ),
    );
    if (kommun == null || !mounted) return;
    _uppslagNr++;
    setState(() {
      _plats = Plats(kommun: kommun);
      _forHand = true;
      _letar = false;
      _fel = null;
      _valtBolag = null;
      _fel = null;
    });
  }

  Future<void> _oppna(ParkeringsApp app) async {
    final svar = await _oppnare.oppna(
      app,
      harAppen: widget.minaAppar.harAppen.contains(app.id),
    );
    // På webben är det enda sättet att veta att appen finns.
    if (svar == Oppnat.appen && !AppOppnare.arAndroidApp) {
      await widget.minaAppar.markeraHarAppen(app.id);
    }
    if (svar == Oppnat.misslyckades && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kunde inte öppna ${app.namn}.')));
    }
  }

  void _rapportera(Plats? plats, List<Forslag> visade) => launchUrl(
    rattelseLank(
      kommun: plats?.kommun,
      operator: plats?.parkering?.operator,
      visade: [for (final f in visade) f.app],
    ),
    mode: LaunchMode.externalApplication,
  );

  @override
  Widget build(BuildContext context) {
    final plats = _plats;
    final urval = valjAppar(
      katalog: widget.katalog,
      kommun: plats?.kommun,
      operatorAppar: [?_valtBolag, ?plats?.operatorApp],
      favoriter: widget.minaAppar.favoriter,
      dolda: widget.minaAppar.dolda,
      installerad: _arInstallerad,
    );
    final f = Farger.av(context);
    final avgiftsfri = plats?.kommun?.status == KommunStatus.avgiftsfri;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const Row(
          children: [
            PSkylt(storlek: 28),
            SizedBox(width: 12),
            Text('Parkeringsväljaren'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Leta igen',
            onPressed: _letar ? null : _leta,
            icon: const Icon(Icons.my_location),
          ),
          IconButton(
            tooltip: 'Välj kommun',
            onPressed: _valjKommun,
            icon: const Icon(Icons.location_city),
          ),
          IconButton(
            tooltip: 'Mina appar',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MinaApparSkarm(
                  katalog: widget.katalog,
                  minaAppar: widget.minaAppar,
                  onRapportera: () => _rapportera(plats, urval.galler),
                ),
              ),
            ),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      bottomNavigationBar: const Varning(),
      body: RefreshIndicator(
        onRefresh: _leta,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _var(context, plats),
            if (plats?.parkering != null) _privat(context, plats!),
            if (urval.galler.isNotEmpty) ...[
              _rubrik(context, 'Gäller här'),
              for (final (i, forslag) in urval.galler.indexed)
                AppRad(
                  viaAppStore: _viaAppStore(forslag.app),
                  forslag: forslag,
                  forstaval: i == 0,
                  onOppna: () => _oppna(forslag.app),
                ),
            ],
            if (plats != null) _bolagsknapp(),
            if (urval.andra.isNotEmpty)
              Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  // Hopfälld där ingen app behövs.
                  key: ValueKey((urval.galler.isEmpty, avgiftsfri)),
                  initiallyExpanded: urval.galler.isEmpty && !avgiftsfri,
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                  title: Text(
                    urval.galler.isEmpty ? 'Alla appar' : 'Andra appar',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  children: [
                    for (final forslag in urval.andra)
                      AppRad(
                        viaAppStore: _viaAppStore(forslag.app),
                        forslag: forslag,
                        onOppna: () => _oppna(forslag.app),
                      ),
                  ],
                ),
              ),
            if (plats != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Det här stämmer inte'),
                  onPressed: () => _rapportera(plats, urval.galler),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: InkWell(
                onTap: () => launchUrl(
                  Uri.parse('https://www.openstreetmap.org/copyright'),
                  mode: LaunchMode.externalApplication,
                ),
                child: Text(
                  'Adresser och parkeringar: © OpenStreetMaps bidragsgivare',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: f.dampad),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rubrik(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w700),
    ),
  );

  /// "Du står vid": adress, kommun och var uppgiften om kommunen kommer ifrån.
  Widget _var(BuildContext context, Plats? plats) {
    final text = Theme.of(context).textTheme;
    final f = Farger.av(context);
    final dampad = text.bodyMedium?.copyWith(color: f.dampad);
    final List<Widget> rader;
    if (_letar && plats == null) {
      rader = [
        Row(
          children: [
            const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text('Letar efter din position …', style: dampad),
          ],
        ),
      ];
    } else if (_fel != null) {
      rader = [
        Text(
          _fel is PositionFel ? '$_fel' : 'Kunde inte slå upp platsen. Kontrollera nätet och försök igen.',
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(onPressed: _leta, child: const Text('Försök igen')),
            OutlinedButton.icon(
              onPressed: _valjKommun,
              icon: const Icon(Icons.location_city),
              label: const Text('Välj kommun'),
            ),
          ],
        ),
      ];
    } else if (plats != null) {
      final kommun = plats.kommun;
      final rubrik = text.headlineSmall?.copyWith(fontWeight: FontWeight.w800);
      rader = [
        if (_forHand && kommun != null) ...[
          Text('Vald kommun', style: dampad),
          Text(kommun.osmNamn, style: rubrik),
          Text('Gatuparkering · ingen position används', style: dampad),
        ] else ...[
          Text('Du står vid', style: dampad),
          Text(
            plats.adress?.isNotEmpty == true ? plats.adress! : 'Okänd adress',
            style: rubrik,
          ),
          Text(
            kommun == null
                ? 'Kommunen är okänd'
                : '${kommun.osmNamn} · gatuparkering',
            style: dampad,
          ),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: _forHand ? _leta : _valjKommun,
            icon: Icon(
              _forHand ? Icons.my_location : Icons.location_city,
              size: 18,
            ),
            label: Text(_forHand ? 'Använd min position' : 'Välj kommun'),
          ),
        ),
        if (kommun == null)
          const Text('Vi kunde inte avgöra kommunen här.')
        else if (kommun.arKontrollerad) ...[
          if (kommun.status == KommunStatus.avgiftsfri) _avgiftsfri(context),
          if (kommun.anmarkning != null) Text(kommun.anmarkning!),
          for (final k in kommun.kallor)
            InkWell(
              onTap: () => launchUrl(
                Uri.parse(k.url),
                mode: LaunchMode.externalApplication,
              ),
              child: Text(
                'Källa: ${k.titel}, kontrollerad ${k.hamtad}',
                style: text.bodySmall?.copyWith(
                  color: f.dampad,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
        ] else
          Text(
            'Vi har inte kontrollerat vilka appar som gäller i '
            '${kommun.osmNamn} än. Titta på skylten.',
          ),
        if (plats.letarOperator) ...[
          const SizedBox(height: 6),
          Text(
            'Frågar OpenStreetMap vem som driver parkeringen …',
            style: text.bodySmall?.copyWith(color: f.dampad),
          ),
        ] else if (plats.operatorFel) ...[
          const SizedBox(height: 6),
          Text(
            'Kunde inte fråga OpenStreetMap om privata parkeringar.',
            style: text.bodySmall?.copyWith(color: f.dampad),
          ),
        ],
      ];
    } else {
      rader = const [];
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rader,
      ),
    );
  }

  Widget _avgiftsfri(BuildContext context) {
    final f = Farger.av(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: f.ok.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: f.ok),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Gatuparkeringen är avgiftsfri enligt kommunen. Kontrollera '
              'skylten, p-skiva kan krävas.',
            ),
          ),
        ],
      ),
    );
  }

  String _drivsAv(Plats plats) {
    final p = plats.parkering!;
    final bolag = widget.katalog.appar[plats.operatorApp]?.namn;
    if (p.operator == null) {
      return 'Namnet tyder på $bolag (enligt OpenStreetMap)';
    }
    final drivs = 'Drivs av ${p.operator} (enligt OpenStreetMap)';
    return switch ((bolag, plats.operatorFranNamn)) {
      (null, _) => '$drivs. Vi vet inte vilken app bolaget använder.',
      (_, true) => '$drivs. Namnet tyder på $bolag.',
      _ => drivs,
    };
  }

  /// För privata parkeringar som OpenStreetMap inte känner till: man väljer
  /// bolaget på skylten och får dess app överst.
  Widget _bolagsknapp() {
    final valt = widget.katalog.appar[_valtBolag];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.local_parking),
          label: Text(
            valt == null
                ? 'Privat parkering? Välj bolag'
                : 'Bolag på skylten: ${valt.namn} · ändra',
          ),
          onPressed: _valjBolag,
        ),
      ),
    );
  }

  Future<void> _valjBolag() async {
    final text = Theme.of(context).textTheme;
    final f = Farger.av(context);
    // Tom sträng betyder "inget bolag".
    final val = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vilket bolag står på skylten?',
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Bolagets app hamnar överst. Står bolaget inte här, '
                    'följ skylten.',
                    style: text.bodySmall?.copyWith(color: f.dampad),
                  ),
                ],
              ),
            ),
            for (final app in widget.katalog.bolag)
              ListTile(
                leading: AppLogga(app: app),
                title: Text(app.namn),
                selected: app.id == _valtBolag,
                trailing: app.id == _valtBolag ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(context).pop(app.id),
              ),
            if (_valtBolag != null)
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Inget bolag'),
                onTap: () => Navigator.of(context).pop(''),
              ),
          ],
        ),
      ),
    );
    if (val == null || !mounted) return;
    setState(() => _valtBolag = val.isEmpty ? null : val);
  }

  /// Närmaste parkering i OpenStreetMap som har en operatör.
  Widget _privat(BuildContext context, Plats plats) {
    final text = Theme.of(context).textTheme;
    final f = Farger.av(context);
    final p = plats.parkering!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Material(
        color: f.kort,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Närmaste parkering · ${p.avstand.round()} m',
                style: text.bodySmall?.copyWith(color: f.dampad),
              ),
              Text(
                p.namn ?? 'Parkering utan namn',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                _drivsAv(plats),
                style: text.bodyMedium?.copyWith(color: f.dampad),
              ),
              const SizedBox(height: 4),
              InkWell(
                onTap: () => _rapportera(plats, const []),
                child: Text(
                  'Fel bolag? Rätta här.',
                  style: text.bodySmall?.copyWith(
                    color: f.dampad,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
