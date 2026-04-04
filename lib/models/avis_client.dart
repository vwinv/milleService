class AvisClient {
  final String id;
  final String nomClient;
  final int note;
  final String? commentaire;

  AvisClient({
    required this.id,
    required this.nomClient,
    required this.note,
    this.commentaire,
  });

  factory AvisClient.fromJson(Map<String, dynamic> json) {
    return AvisClient(
      id: json['id']?.toString() ?? '',
      nomClient: json['nomClient']?.toString() ?? 'Client',
      note: (json['note'] is int) ? json['note'] as int : (json['note'] as num?)?.toInt() ?? 0,
      commentaire: json['commentaire']?.toString(),
    );
  }
}
