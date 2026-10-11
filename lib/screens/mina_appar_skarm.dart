import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../logic/rattelse.dart';
import '../models/katalog.dart';
import '../services/app_oppnare.dart';
import '../services/mina_appar.dart';
import '../tema.dart';
import '../widgets/app_rad.dart';

/// Favoriter visas först, dolda appar visas inte alls. Under Rättelser kan
/// man rapportera fel och se vad andra har rapporterat.
class MinaApparSkarm extends StatefulWidget {
  const MinaApparSkarm({
    super.key,
    required this.katalog,
    required this.minaAppar,
    this.onRapportera,
  });

  final Katalog katalog;
  final MinaAppar minaAppar;

  /// Rapportera ett fel om platsen man står på.
  final VoidCallback? onRapportera;

  @override
  State<MinaApparSkarm> createState() => _MinaApparSkarmState();
}

class _MinaApparSkarmState extends State<MinaApparSkarm> {
  var _flik = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mina appar')),
    body: ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 0, label: Text('Mina appar')),
              ButtonSegment(value: 1, label: Text('Rättelser')),
            ],
            selected: {_flik},
            onSelectionChanged: (val) => setState(() => _flik = val.single),
          ),
        ),
        if (_flik == 0) ..._appar(context) else ..._rattelser(context),
      ],
    ),
  );

  List<Widget> _appar(BuildContext context) {
    final mina = widget.minaAppar;
    final f = Farger.av(context);
    final text = Theme.of(context).textTheme;
    final appar = widget.katalog.appar.values.toList()
      ..sort((a, b) => a.namn.toLowerCase().compareTo(b.namn.toLowerCase()));
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Text(
          AppOppnare.arAndroidApp
              ? 'Stjärnmärkta appar visas först. Dolda appar visas aldrig.'
              : 'Stjärnmärkta appar visas först. Dolda appar visas aldrig. '
                    'Markera de appar du har, så öppnas de direkt när det går '
                    'och hamnar högre upp.',
          style: text.bodyMedium?.copyWith(color: f.dampad),
        ),
      ),
      ListenableBuilder(
        listenable: mina,
        builder: (context, _) => Column(
          children: [
            for (final app in appar)
              _AppInstallning(
                app: app,
                favorit: mina.favoriter.contains(app.id),
                dold: mina.dolda.contains(app.id),
                onFavorit: (pa) => mina.satFavorit(app.id, pa),
                onDold: (pa) => mina.satDold(app.id, pa),
                // Android-appen ser själv vilka appar som finns.
                harAppen: AppOppnare.arAndroidApp
                    ? null
                    : mina.harAppen.contains(app.id),
                onHarAppen: (pa) => mina.satHarAppen(app.id, pa),
              ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _rattelser(BuildContext context) {
    final f = Farger.av(context);
    final text = Theme.of(context).textTheme;
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Har appen visat fel app för en plats? Skriv vad som står på '
              'skylten. Rättelserna granskas och läggs in i nästa '
              'uppdatering av listan.',
            ),
            const SizedBox(height: 8),
            Text(
              'Rättelserna är offentliga på GitHub. Din position skickas '
              'inte med, bara kommunen och apparna som visades.',
              style: text.bodySmall?.copyWith(color: f.dampad),
            ),
            const SizedBox(height: 16),
            if (widget.onRapportera != null)
              FilledButton.icon(
                icon: const Icon(Icons.flag_outlined),
                label: const Text('Rapportera fel här'),
                onPressed: widget.onRapportera,
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.list_alt),
              label: const Text('Se inskickade rättelser'),
              onPressed: () => launchUrl(
                Uri.https('github.com', '/$githubProjekt/issues', {
                  'q': 'label:rättelse',
                }),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ],
        ),
      ),
    ];
  }
}

class _AppInstallning extends StatelessWidget {
  const _AppInstallning({
    required this.app,
    required this.favorit,
    required this.dold,
    required this.onFavorit,
    required this.onDold,
    required this.harAppen,
    required this.onHarAppen,
  });

  final ParkeringsApp app;
  final bool favorit;
  final bool dold;
  final ValueChanged<bool> onFavorit;
  final ValueChanged<bool> onDold;

  /// Null där appen själv kan se vilka appar som finns (Android).
  final bool? harAppen;
  final ValueChanged<bool> onHarAppen;

  @override
  Widget build(BuildContext context) {
    final f = Farger.av(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: f.kort,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
          child: Row(
            children: [
              Opacity(
                opacity: dold ? 0.4 : 1,
                child: AppLogga(app: app),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.namn,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      favorit
                          ? 'Favorit · visas först'
                          : dold
                          ? 'Dold'
                          : 'Visas när den gäller',
                      style: text.bodySmall?.copyWith(color: f.dampad),
                    ),
                    if (harAppen != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: FilterChip(
                          label: const Text('Jag har appen'),
                          selected: harAppen!,
                          onSelected: onHarAppen,
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: favorit ? 'Ta bort favorit' : 'Gör till favorit',
                icon: Icon(
                  favorit ? Icons.star : Icons.star_border,
                  color: favorit ? f.accent : null,
                ),
                onPressed: () => onFavorit(!favorit),
              ),
              TextButton(
                onPressed: () => onDold(!dold),
                child: Text(dold ? 'Visa' : 'Dölj'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
