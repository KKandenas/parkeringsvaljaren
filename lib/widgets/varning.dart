import 'package:flutter/material.dart';

/// Syns alltid längst ner.
class Varning extends StatelessWidget {
  const Varning({super.key});

  static const text = 'Uppgifterna kan vara fel. Skylten på platsen gäller.';

  @override
  Widget build(BuildContext context) {
    final farger = Theme.of(context).colorScheme;
    return Material(
      color: farger.tertiaryContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: farger.onTertiaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: farger.onTertiaryContainer,
                    fontWeight: FontWeight.w600,
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
