class PrestataireDocument {
  final String id;
  final String typeCode;
  final String typeLibelle;
  final bool obligatoire;
  final String statut;
  final String? motifRefus;
  final String fichierUrl;
  final String? nomFichier;
  final DateTime? updatedAt;

  PrestataireDocument({
    required this.id,
    required this.typeCode,
    required this.typeLibelle,
    required this.obligatoire,
    required this.statut,
    required this.fichierUrl,
    this.motifRefus,
    this.nomFichier,
    this.updatedAt,
  });

  factory PrestataireDocument.fromJson(Map<String, dynamic> json) {
    return PrestataireDocument(
      id: json['id']?.toString() ?? '',
      typeCode: json['typeCode']?.toString() ?? '',
      typeLibelle: json['typeLibelle']?.toString() ?? '',
      obligatoire: json['obligatoire'] == true,
      statut: json['statut']?.toString() ?? '',
      motifRefus: json['motifRefus']?.toString(),
      fichierUrl: json['fichierUrl']?.toString() ?? '',
      nomFichier: json['nomFichier']?.toString(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }
}

