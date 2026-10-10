import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../logic/app_urval.dart';
import '../logic/rattelse.dart';
import '../models/katalog.dart';
import '../services/app_oppnare.dart';
import '../services/mina_appar.dart';
import '../services/uppslag.dart';
import '../widgets/app_rad.dart';
import '../widgets/varning.dart';
import 'mina_appar_skarm.dart';

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
  Set<String>? _installerade;

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

  Future<void> _lasInstallerade() async {
    final paket = [
      for (final a in widget.katalog.appar.values)
        if (a.android != null) a.android!,
    ];
    final svar = await _oppnare.installerade(paket);
    if (mounted) setState(() => _installerade = svar);
  }

  Future<void> _leta() async {
    setState(() {
      _letar = true;
      _fel = null;
    });
    try {
      await for (final plats in widget.uppslag.har()) {
        if (mounted) setState(() => _plats = plats);
      }
    } catch (e) {
      if (mounted) setState(() => _fel = e);
    } finally {
      if (mounted) setState(() => _letar = false);
    }
  }

  Future<void> _oppna(ParkeringsApp app) async {
    final ok = await _oppnare.oppna(app);
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kunde inte öppna ${app.namn}.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final plats = _plats;
    final urval = valjAppar(
      katalog: widget.katalog,
      kommun: plats?.kommun,
      operatorAppar: [?plats?.operatorApp],
      favoriter: widget.minaAppar.favoriter,
      dolda: widget.minaAppar.dolda,
      installerade: _installerade,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parkeringsväljaren'),
        actions: [
          IconButton(
            tooltip: 'Leta igen',
            onPressed: _letar ? null : _leta,
            icon: const Icon(Icons.my_location),
          ),
          IconButton(
            tooltip: 'Mina appar',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MinaApparSkarm(
                  katalog: widget.katalog,
                  minaAppar: widget.minaAppar,
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
            _platsKort(context, plats),
            if (urval.galler.isNotEmpty) ...[
              _rubrik(context, 'Gäller här'),
              for (final f in urval.galler)
                AppRad(forslag: f, onOppna: () => _oppna(f.app)),
            ],
            if (urval.andra.isNotEmpty)
              ExpansionTile(
                key: ValueKey(urval.galler.isEmpty),
                initiallyExpanded: urval.galler.isEmpty,
                title: Text(
                  urval.galler.isEmpty ? 'Alla appar' : 'Andra appar',
                ),
                children: [
                  for (final f in urval.andra)
                    AppRad(forslag: f, onOppna: () => _oppna(f.app)),
                ],
              ),
            if (plats != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Det här stämmer inte'),
                  onPressed: () => launchUrl(
                    rattelseLank(
                      kommun: plats.kommun,
                      operator: plats.parkering?.operator,
                      visade: [for (final f in urval.galler) f.app],
                    ),
                    mode: LaunchMode.externalApplication,
                  ),
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
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rubrik(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );

  Widget _platsKort(BuildContext context, Plats? plats) {
    final textTema = Theme.of(context).textTheme;
    final List<Widget> rader;
    if (_letar && plats == null) {
      rader = const [
        Row(
          children: [
            SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Letar efter din position …'),
          ],
        ),
      ];
    } else if (_fel != null) {
      rader = [
        Text(
          _fel is PositionFel ? '$_fel' : 'Kunde inte slå upp platsen. Kontrollera nätet och försök igen.',
        ),
        const SizedBox(height: 8),
        FilledButton(onPressed: _leta, child: const Text('Försök igen')),
      ];
    } else if (plats != null) {
      final kommun = plats.kommun;
      final parkering = plats.parkering;
      rader = [
        if (plats.adress != null && plats.adress!.isNotEmpty)
          Text(plats.adress!, style: textTema.titleMedium),
        Text(
          kommun == null ? 'Kommunen är okänd' : '${kommun.namn} kommun',
          style: textTema.bodyLarge,
        ),
        const SizedBox(height: 8),
        if (kommun == null)
          const Text('Vi kunde inte avgöra kommunen här.')
        else if (kommun.status == KommunStatus.verifierad) ...[
          if (kommun.anmarkning != null) Text(kommun.anmarkning!),
          for (final k in kommun.kallor)
            InkWell(
              onTap: () => launchUrl(
                Uri.parse(k.url),
                mode: LaunchMode.externalApplication,
              ),
              child: Text(
                'Gatuparkering enligt ${k.titel}, kontrollerad ${k.hamtad}',
                style: textTema.bodySmall?.copyWith(
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
        ] else
          Text(
            'Vi har inte kontrollerat vilka appar som gäller i '
            '${kommun.namn} kommun än. Titta på skylten.',
          ),
        if (parkering != null) ...[
          const SizedBox(height: 8),
          Text(
            'Parkeringen ${parkering.namn != null ? '"${parkering.namn}" ' : ''}'
            'drivs av ${parkering.operator} enligt OpenStreetMap'
            '${plats.operatorApp == null ? '. Vi vet inte vilken app bolaget använder.' : '.'}',
          ),
        ] else if (plats.letarOperator) ...[
          const SizedBox(height: 8),
          Text(
            'Frågar OpenStreetMap vem som driver parkeringen …',
            style: textTema.bodySmall,
          ),
        ] else if (plats.operatorFel) ...[
          const SizedBox(height: 8),
          Text(
            'Kunde inte fråga OpenStreetMap om privata parkeringar.',
            style: textTema.bodySmall,
          ),
        ],
      ];
    } else {
      rader = const [];
    }
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rader,
        ),
      ),
    );
  }
}
