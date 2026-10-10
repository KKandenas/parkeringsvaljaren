import '../models/katalog.dart';

/// Projektet där rättelser tas emot som ärenden.
const githubProjekt = 'KKandenas/parkeringsvaljaren';

/// Adress till ett ifyllt GitHub-ärende. Ärenden är offentliga, så varken
/// position eller adress skickas med: bara kommunen och vad appen visade.
Uri rattelseLank({
  required Kommun? kommun,
  required List<ParkeringsApp> visade,
  String? operator,
}) {
  final rader = [
    'Kommun: ${kommun == null ? 'okänd' : '${kommun.namn} (${kommun.kod})'}',
    if (operator != null) 'Operatör enligt OpenStreetMap: $operator',
    'Appen visade: ${visade.isEmpty ? 'inga appar' : visade.map((a) => a.namn).join(', ')}',
    '',
    'Vad står på skylten, och vad är fel?',
    '',
  ];
  return Uri.https('github.com', '/$githubProjekt/issues/new', {
    'title': 'Rättelse: ${kommun?.namn ?? 'okänd kommun'}',
    'labels': 'rättelse',
    'body': rader.join('\n'),
  });
}
