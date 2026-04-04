class WalletModel {
  final String id;
  final String type; // GENERAL ou PRESTATAIRE
  final String? prestataireId;
  final double balance;
  final DateTime createdAt;
  final DateTime updatedAt;

  WalletModel({
    required this.id,
    required this.type,
    this.prestataireId,
    required this.balance,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'PRESTATAIRE',
      prestataireId: json['prestataireId']?.toString(),
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class WalletTransactionModel {
  final String id;
  final String walletId;
  final String type; // PRESTATION ou ABONNEMENT
  final double amount;
  final String? prestationId;
  final String? abonnementId;
  final String? offreId;
  final String? createdByUserId;
  final DateTime createdAt;
  final Map<String, dynamic>? meta;

  WalletTransactionModel({
    required this.id,
    required this.walletId,
    required this.type,
    required this.amount,
    required this.createdAt,
    this.prestationId,
    this.abonnementId,
    this.offreId,
    this.createdByUserId,
    this.meta,
  });

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    return WalletTransactionModel(
      id: json['id'] as String,
      walletId: json['walletId'] as String,
      type: json['type'] as String,
      amount: (json['amount'] as num).toDouble(),
      prestationId: json['prestationId'] as String?,
      abonnementId: json['abonnementId'] as String?,
      offreId: json['offreId'] as String?,
      createdByUserId: json['createdByUserId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      meta: json['meta'] is Map<String, dynamic> ? json['meta'] as Map<String, dynamic> : null,
    );
  }
}

