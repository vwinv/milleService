class PrestatairePhoto {
  final String id;
  final String prestataireId;
  final String url;
  final String? titre;
  final String? description;
  final int ordre;
  final String? createdAt;

  PrestatairePhoto({
    required this.id,
    required this.prestataireId,
    required this.url,
    this.titre,
    this.description,
    required this.ordre,
    this.createdAt,
  });

  factory PrestatairePhoto.fromJson(Map<String, dynamic> json) {
    return PrestatairePhoto(
      id: json['id']?.toString() ?? '',
      prestataireId: json['prestataireId']?.toString() ??
          json['prestataire_id']?.toString() ??
          '',
      url: json['url']?.toString() ?? '',
      titre: json['titre']?.toString(),
      description: json['description']?.toString(),
      ordre: (json['ordre'] is num)
          ? (json['ordre'] as num).toInt()
          : int.tryParse(json['ordre']?.toString() ?? '0') ?? 0,
      createdAt: json['createdAt']?.toString() ??
          json['created_at']?.toString(),
    );
  }
}

