class PrestataireServiceItem {
  final String id;
  /// ID de la ligne PrestataireService (pour créer une prestation).
  final String? prestataireServiceId;
  final String libelle;
  final String slug;
  final double? tarifHoraire;
  final String? description;

  PrestataireServiceItem({
    required this.id,
    this.prestataireServiceId,
    required this.libelle,
    required this.slug,
    this.tarifHoraire,
    this.description,
  });

  factory PrestataireServiceItem.fromJson(Map<String, dynamic> json) {
    return PrestataireServiceItem(
      id: json['id']?.toString() ?? '',
      prestataireServiceId: json['prestataireServiceId']?.toString(),
      libelle: json['libelle']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      tarifHoraire: json['tarifHoraire'] != null
          ? (json['tarifHoraire'] as num).toDouble()
          : null,
      description: json['description']?.toString(),
    );
  }
}

class Prestataire {
  final String id;
  final String nom;
  final String? telephone;
  final String? bio;
  final String? avatarUrl;
  final String? adresse;
  final List<String> zoneIntervention;
  final String statutVerification;
  final double noteMoyenne;
  final int noteSur;
  final int nbAvis;
  final int distanceMetres;
  final double? latitude;
  final double? longitude;
  final List<PrestataireServiceItem> services;

  Prestataire({
    required this.id,
    required this.nom,
    this.telephone,
    this.bio,
    this.avatarUrl,
    this.adresse,
    required this.zoneIntervention,
    required this.statutVerification,
    required this.noteMoyenne,
    required this.noteSur,
    required this.nbAvis,
    required this.distanceMetres,
    this.latitude,
    this.longitude,
    this.services = const [],
  });

  factory Prestataire.fromJson(Map<String, dynamic> json) {
    final zones = json['zoneIntervention'];
    final servicesJson = json['services'];

    return Prestataire(
      id: json['id']?.toString() ?? '',
      nom: json['nom']?.toString() ?? '',
      telephone: json['telephone']?.toString(),
      bio: json['bio']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      adresse: json['adresse']?.toString(),
      zoneIntervention: zones is List
          ? zones.map((e) => e.toString()).toList()
          : [],
      statutVerification:
          json['statutVerification']?.toString() ?? 'NON_VERIFIE',
      noteMoyenne: (json['noteMoyenne'] ?? 0).toDouble(),
      noteSur: json['noteSur'] ?? 5,
      nbAvis: json['nbAvis'] ?? 0,
      distanceMetres: json['distanceMetres'] ?? 0,
      latitude: json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : null,
      services: servicesJson is List
          ? servicesJson
                .whereType<Map<String, dynamic>>()
                .map((e) => PrestataireServiceItem.fromJson(e))
                .toList()
          : const [],
    );
  }

  String get zoneAffichage =>
      zoneIntervention.isEmpty ? '' : zoneIntervention.join(', ');

  String get distanceAffichage => 'À ${distanceMetres}m';

  /// Tarif horaire minimum parmi les services du prestataire (pour affichage "à partir de").
  double? get tarifMinimum {
    final tarifs = services
        .map((s) => s.tarifHoraire)
        .whereType<double>()
        .toList();
    if (tarifs.isEmpty) return null;
    return tarifs.reduce((a, b) => a < b ? a : b);
  }
}
