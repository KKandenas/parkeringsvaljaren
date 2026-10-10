import 'package:flutter/material.dart';

import '../logic/app_urval.dart';

/// En app i listan, med knapp som öppnar den (eller butiken).
class AppRad extends StatelessWidget {
  const AppRad({super.key, required this.forslag, required this.onOppna});

  final Forslag forslag;
  final VoidCallback onOppna;

  @override
  Widget build(BuildContext context) {
    final f = forslag;
    final etiketter = [
      if (f.skal == Skal.operator) 'Driver parkeringen enligt OpenStreetMap',
      if (f.favorit) 'Favorit',
      if (f.installerad == true) 'Installerad',
    ];
    final saknas = f.installerad == false;
    return ListTile(
      leading: CircleAvatar(child: Text(f.app.namn.characters.first)),
      title: Text(f.app.namn),
      subtitle: etiketter.isEmpty ? null : Text(etiketter.join(' · ')),
      trailing: saknas
          ? OutlinedButton(onPressed: onOppna, child: const Text('Hämta'))
          : FilledButton(onPressed: onOppna, child: const Text('Öppna')),
    );
  }
}
