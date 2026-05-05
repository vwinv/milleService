import 'package:milleservices/models/prestataire.dart';

/// Modèle d'une prestation (créée par le particulier, acceptée/terminée par le prestataire).
class Prestation {
  final String id;
  final String statut;
  final String? typeDeTache;
  final String? description;
  final String? imageUrl;
  final double? budget;
  final String? adresse;
  final String? codePostal;
  final String? ville;
  final String? noteParticulier;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final PrestationParticulier? particulier;
  final Prestataire? prestataire;
  final PrestationService? service;

  Prestation({
    required this.id,
    required this.statut,
    this.typeDeTache,
    this.description,
    this.imageUrl,
    this.budget,
    this.adresse,
    this.codePostal,
    this.ville,
    this.noteParticulier,
    this.acceptedAt,
    this.completedAt,
    this.createdAt,
    this.particulier,
    this.prestataire,
    this.service,
  });

  factory Prestation.fromJson(Map<String, dynamic> json) {
    return Prestation(
      id: json['id']?.toString() ?? '',
      statut: json['statut']?.toString() ?? 'EN_ATTENTE',
      typeDeTache: json['typeDeTache']?.toString(),
      description: json['description']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      budget: _parseDouble(json['budget']),
      adresse: json['adresse']?.toString(),
      codePostal: json['codePostal']?.toString(),
      ville: json['ville']?.toString(),
      noteParticulier: json['noteParticulier']?.toString(),
      acceptedAt: json['acceptedAt'] != null
          ? DateTime.tryParse(json['acceptedAt'].toString())
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'].toString())
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      particulier: json['particulier'] is Map
          ? PrestationParticulier.fromJson(
              json['particulier'] as Map<String, dynamic>,
            )
          : null,
      prestataire: json['prestataire'] is Map
          ? Prestataire.fromJson(json['prestataire'] as Map<String, dynamic>)
          : null,
      service: json['service'] is Map
          ? PrestationService.fromJson(json['service'] as Map<String, dynamic>)
          : null,
    );
  }

  bool get isEnAttente => statut == 'EN_ATTENTE';
  bool get isAcceptee => statut == 'ACCEPTEE';
  bool get isRefusee => statut == 'REFUSEE';
  bool get isEnCours => statut == 'EN_COURS';
  bool get isTerminee => statut == 'TERMINEE';
  bool get isPayee => statut == 'PAYEE';
  bool get isAnnulee => statut == 'ANNULEE';

  String get statutLibelle {
    switch (statut) {
      case 'EN_ATTENTE':
        return 'En attente d\'acceptation';
      case 'ACCEPTEE':
        return 'Acceptée';
      case 'REFUSEE':
        return 'Refusée';
      case 'EN_COURS':
        return 'En cours';
      case 'TERMINEE':
        return 'Terminée';
      case 'PAYEE':
        return 'Payée';
      case 'ANNULEE':
        return 'Annulée';
      default:
        return statut;
    }
  }
}

class PrestationParticulier {
  final String? prenom;
  final String? nom;
  final String? telephone;
  final double? latitude;
  final double? longitude;

  PrestationParticulier({
    this.prenom,
    this.nom,
    this.telephone,
    this.latitude,
    this.longitude,
  });

  factory PrestationParticulier.fromJson(Map<String, dynamic> json) {
    return PrestationParticulier(
      prenom: json['prenom']?.toString(),
      nom: json['nom']?.toString(),
      telephone: json['telephone']?.toString(),
      latitude: _parseDouble(json['latitude'] ?? json['lat']),
      longitude: _parseDouble(json['longitude'] ?? json['lng'] ?? json['lon']),
    );
  }

  String get displayName =>
      [prenom, nom].where((e) => e != null && e.isNotEmpty).join(' ').trim();
}

double? _parseDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

class PrestationService {
  final String? id;
  final String? libelle;
  final double? tarifHoraire;

  PrestationService({this.id, this.libelle, this.tarifHoraire});

  factory PrestationService.fromJson(Map<String, dynamic> json) {
    return PrestationService(
      id: json['id']?.toString(),
      libelle: json['libelle']?.toString(),
      tarifHoraire: _parseDouble(
        json['tarifHoraire'] ?? json['tarif_horaire'],
      ),
    );
  }
}
