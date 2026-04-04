import 'dart:convert';

class Offre {
  final id;
  final code;
  final libelle;
  final description;
  final prix;
  final dureeMois;

  Offre({
    required this.id,
    required this.code,
    required this.libelle,
    required this.description,
    required this.prix,
    required this.dureeMois,
  });
  @override
  String toString() {
    return '{${this.id}, ${this.code}, ${this.libelle}, ${this.description}, ${this.prix}, ${dureeMois}}';
  }

  // ignore: missing_return

  factory Offre.fromJson(dynamic json) {
    return Offre(
      id: json["id"],
      code: json["code"],
      libelle: json["libelle"],
      description: json["description"],
      prix: json["prix"],
      dureeMois: json["dureeMois"],
    );
  }

  static Map<String, dynamic> toMap(Offre data) => {
    'id': data.id,
    'code': data.code,
    'libelle': data.libelle,
    'description': data.description,
    'prix': data.prix,
    'dureeMois': data.dureeMois,
  };

  static String encode(Offre offre) => json.encode(Offre.toMap(offre));

  static Offre decode(String data) =>
      Offre.fromJson(json.decode(data.toString()));
}
