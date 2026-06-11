import 'package:flutter_test/flutter_test.dart';
import 'package:milleservices/models/abonnement.dart';

void main() {
  Abonnement abo({
    required String statut,
    required String dateFin,
  }) {
    return Abonnement.fromJson({
      'id': '1',
      'prestataireId': 'p1',
      'offreId': 'o1',
      'dateDebut': '2025-01-01',
      'dateFin': dateFin,
      'statut': statut,
    });
  }

  test('isValide returns true for ACTIF with future end date', () {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final fin = tomorrow.toIso8601String().split('T').first;
    expect(abo(statut: 'ACTIF', dateFin: fin).isValide, isTrue);
  });

  test('isValide returns false for EXPIRE statut', () {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final fin = tomorrow.toIso8601String().split('T').first;
    expect(abo(statut: 'EXPIRE', dateFin: fin).isValide, isFalse);
  });

  test('isValide returns false for ACTIF with past end date', () {
    expect(abo(statut: 'ACTIF', dateFin: '2020-01-01').isValide, isFalse);
  });
}
