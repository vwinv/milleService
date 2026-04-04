import 'dart:convert';

class User {
  final id;
  final telephone;
  final prenom;
  final nom;
  final avatarUrl;
  final adresse;
  final email;
  final emailVerified;
  final bio;
  final zoneIntervention;
  final statutVerification;
  final createdAt;
  final updatedAt;
  final role;
  final latitude;
  final longitude;
  final statutVerificationPrestataire;

  User({
    required this.id,
    required this.telephone,
    required this.prenom,
    required this.nom,
    required this.avatarUrl,
    required this.adresse,
    required this.email,
    required this.emailVerified,
    required this.bio,
    required this.zoneIntervention,
    required this.statutVerification,
    required this.createdAt,
    required this.updatedAt,
    required this.role,
    this.latitude,
    this.longitude,
    required this.statutVerificationPrestataire,
  });
  @override
  String toString() {
    return '{${this.id}, ${this.telephone}, ${this.prenom}, ${this.nom}, ${this.avatarUrl}, ${adresse}, ${this.email}, ${this.bio}, ${this.zoneIntervention}, ${this.statutVerification}, ${this.createdAt}, ${this.updatedAt}, ${this.role}, ${this.statutVerificationPrestataire}}';
  }

  // ignore: missing_return

  factory User.fromJson(dynamic json) {
    final role = json['role']?.toString() ?? '';
    final isPrestataire = role == 'PRESTATAIRE';
    final part = json['particulier'];
    final prest = json['prestataire'];

    print(" json : ${json}");
    print(" json : ${json["particulier"]}");

    // Réponse API (objet imbriqué particulier/prestataire)
    if (part != null || prest != null) {
      print(" part : ${part.toString()}");
      final p = isPrestataire ? prest : part;
      print(" p : ${p.toString()}");
      return User(
        id: json["id"],
        telephone: p?['telephone'],
        prenom: p?['prenom'],
        nom: p?['nom'],
        avatarUrl: p?['avatarUrl'],
        adresse: p?['adresse'],
        email: json["email"],
        emailVerified: json["emailVerified"] ?? false,
        bio: prest?['bio'],
        zoneIntervention: prest?['zoneIntervention'],
        statutVerification: prest?['statutVerification'],
        createdAt: p?['createdAt'],
        updatedAt: p?['updatedAt'],
        role: role,
        latitude: (p ?? prest)?['latitude'] != null
            ? (p ?? prest)!['latitude'] as num
            : null,
        longitude: (p ?? prest)?['longitude'] != null
            ? (p ?? prest)!['longitude'] as num
            : null,
        statutVerificationPrestataire: prest?['statutVerificationPrestataire'],
      );
    }

    // Map plate (ex: formulaire d'inscription)
    return User(
      id: json["id"],
      telephone: json["telephone"],
      prenom: json["prenom"],
      nom: json["nom"],
      avatarUrl: json["avatarUrl"],
      adresse: json["adresse"],
      email: json["email"],
      emailVerified: json["emailVerified"] ?? false,
      bio: json["bio"],
      zoneIntervention: json["zoneIntervention"],
      statutVerification: json["statutVerification"],
      createdAt: json["createdAt"],
      updatedAt: json["updatedAt"],
      role: role,
      latitude: json["latitude"],
      longitude: json["longitude"],
      statutVerificationPrestataire: "",
    );
  }

  static Map<String, dynamic> toMap(User data) => {
    'id': data.id,
    'telephone': data.telephone,
    'prenom': data.prenom,
    'nom': data.nom,
    'avatarUrl': data.avatarUrl,
    'adresse': data.adresse,
    'email': data.email,
    'emailVerified': data.emailVerified,
    'bio': data.bio,
    'zoneIntervention': data.zoneIntervention,
    'statutVerification': data.statutVerification,
    'createdAt': data.createdAt,
    'updatedAt': data.updatedAt,
    'role': data.role,
    'latitude': data.latitude,
    'longitude': data.longitude,
    'statutVerificationPrestataire': data.statutVerificationPrestataire,
  };

  static String encode(User user) => json.encode(User.toMap(user));

  static User decode(String data) =>
      User.fromJson(json.decode(data.toString()));
}
