import 'package:flutter/material.dart';

import '../models/katalog.dart';
import '../services/mina_appar.dart';

/// Favoriter visas först, dolda appar visas inte alls.
class MinaApparSkarm extends StatelessWidget {
  const MinaApparSkarm({
    super.key,
    required this.katalog,
    required this.minaAppar,
  });

  final Katalog katalog;
  final MinaAppar minaAppar;

  @override
  Widget build(BuildContext context) {
    final appar = katalog.appar.values.toList()
      ..sort((a, b) => a.namn.toLowerCase().compareTo(b.namn.toLowerCase()));
    return Scaffold(
      appBar: AppBar(title: const Text('Mina appar')),
      body: ListenableBuilder(
        listenable: minaAppar,
        builder: (context, _) => ListView(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Stjärnmärkta appar visas först. Dolda appar visas aldrig.',
              ),
            ),
            for (final app in appar)
              ListTile(
                title: Text(app.namn),
                leading: IconButton(
                  tooltip: minaAppar.favoriter.contains(app.id)
                      ? 'Ta bort favorit'
                      : 'Gör till favorit',
                  icon: Icon(
                    minaAppar.favoriter.contains(app.id)
                        ? Icons.star
                        : Icons.star_border,
                  ),
                  onPressed: () => minaAppar.satFavorit(
                    app.id,
                    !minaAppar.favoriter.contains(app.id),
                  ),
                ),
                trailing: Switch(
                  value: !minaAppar.dolda.contains(app.id),
                  onChanged: (visa) => minaAppar.satDold(app.id, !visa),
                ),
                subtitle: minaAppar.dolda.contains(app.id)
                    ? const Text('Dold')
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}
