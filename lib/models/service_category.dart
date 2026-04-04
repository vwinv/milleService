import 'dart:convert';

class ServiceCategory {
  final id;
  final libelle;
  final slug;

  ServiceCategory({
    required this.id,
    required this.libelle,
    required this.slug,
  });
  @override
  String toString() {
    return '{${this.id}, ${this.libelle}, ${this.slug}}';
  }

  // ignore: missing_return

  factory ServiceCategory.fromJson(dynamic json) {
    return ServiceCategory(
      id: json["id"],
      libelle: json["libelle"],
      slug: json["slug"],
    );
  }

  static Map<String, dynamic> toMap(ServiceCategory data) => {
    'id': data.id,
    'libelle': data.libelle,
    'slug': data.slug,
  };

  static String encode(ServiceCategory serviceCategory) =>
      json.encode(ServiceCategory.toMap(serviceCategory));

  static ServiceCategory decode(String data) =>
      ServiceCategory.fromJson(json.decode(data.toString()));
}
