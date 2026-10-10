import 'package:flutter/material.dart';

import '../tema.dart';

/// Syns alltid längst ner.
class Varning extends StatelessWidget {
  const Varning({super.key});

  static const text = 'Uppgifterna kan vara fel. Skylten på platsen gäller.';

  @override
  Widget build(BuildContext context) {
    final f = Farger.av(context);
    return Material(
      color: f.kort,
      shape: Border(top: BorderSide(color: f.accent, width: 3)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: f.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
