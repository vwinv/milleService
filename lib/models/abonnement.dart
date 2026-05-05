import 'dart:convert';

class Abonnement {
  final id;
  final prestataireId;
  final offreId;
  final dateDebut;
  final dateFin;
  final statut;

  Abonnement({
    required this.id,
    required this.prestataireId,
    required this.offreId,
    required this.dateDebut,
    required this.dateFin,
    required this.statut,
  });
  @override
  String toString() {
    return '{${this.id}, ${this.prestataireId}, ${this.offreId}, ${this.dateDebut}, ${this.dateFin}, ${statut}}';
  }

  // ignore: missing_return

  factory Abonnement.fromJson(dynamic json) {
    final m =
        json is Map ? Map<String, dynamic>.from(json) : <String, dynamic>{};
    final offre = m['offre'];
    dynamic offreId = m['offreId'];
    if ((offreId == null || '$offreId'.isEmpty) && offre is Map) {
      offreId = offre['id'];
    }
    return Abonnement(
      id: m['id'],
      prestataireId: m['prestataireId'],
      offreId: offreId,
      dateDebut: m['dateDebut'],
      dateFin: m['dateFin'],
      statut: m['statut'],
    );
  }

  static Map<String, dynamic> toMap(Abonnement data) => {
    'id': data.id,
    'prestataireId': data.prestataireId,
    'offreId': data.offreId,
    'dateDebut': data.dateDebut,
    'dateFin': data.dateFin,
    'statut': data.statut,
  };

  static String encode(Abonnement abonnement) =>
      json.encode(Abonnement.toMap(abonnement));

  static Abonnement decode(String data) =>
      Abonnement.fromJson(json.decode(data.toString()));
}
