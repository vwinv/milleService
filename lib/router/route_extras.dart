import 'package:milleservices/models/prestataire.dart';
import 'package:milleservices/models/prestation.dart';

/// Arguments pour [ConfirmPrestation].
class ConfirmPrestationExtra {
  const ConfirmPrestationExtra({
    required this.prestataire,
    this.prestataireServiceId,
    this.serviceLibelle,
    this.adresseParticulier,
  });

  final Prestataire prestataire;
  final String? prestataireServiceId;
  final String? serviceLibelle;
  final String? adresseParticulier;
}

/// Liste passée à [Historique].
class HistoriqueExtra {
  const HistoriqueExtra({
    required this.prestations,
    this.refreshFilter,
  });

  final List<Prestation> prestations;

  /// `en_attente` ou `terminee` : la liste se recharge et retire les prestations
  /// qui ne correspondent plus (ex. annulée par le client).
  final String? refreshFilter;
}

/// Acceptation / refus prestataire (prestation en attente).
class PrestataireConfirmPrestationExtra {
  const PrestataireConfirmPrestationExtra({required this.prestation});

  final Prestation prestation;
}
