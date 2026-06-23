import 'package:milleservices/models/prestataire_document.dart';

/// Documents requis pour passer en validation admin (CNI recto + verso).
const kPrestataireValidationDocTypeCodes = <String>[
  'cni_recto',
  'cni_verso',
];

/// Documents complémentaires (optionnels pour la validation).
const kPrestataireOptionalDocTypeCodes = <String>[
  'certificat_residence',
  'diplome',
];

/// Tous les types gérés dans l'app.
const kPrestataireAllDocTypeCodes = <String>[
  ...kPrestataireValidationDocTypeCodes,
  ...kPrestataireOptionalDocTypeCodes,
];

const kPrestataireDocLabels = <String, String>{
  'cni_recto': 'CNI / Passeport (recto)',
  'cni_verso': 'CNI / Passeport (verso)',
  'certificat_residence': 'Certificat de résidence',
  'diplome': 'Diplôme',
};

List<Map<String, String>> _catalogFor(Iterable<String> codes) => codes
    .map(
      (code) => {
        'typeCode': code,
        'label': kPrestataireDocLabels[code] ?? code,
      },
    )
    .toList();

List<Map<String, String>> get prestataireValidationDocsCatalog =>
    _catalogFor(kPrestataireValidationDocTypeCodes);

List<Map<String, String>> get prestataireAllDocsCatalog =>
    _catalogFor(kPrestataireAllDocTypeCodes);

/// Alias historique : catalogue complet (écran complétion profil).
List<Map<String, String>> get prestataireRequiredDocsCatalog =>
    prestataireAllDocsCatalog;

bool isPrestataireValidationRequiredDocType(String typeCode) =>
    kPrestataireValidationDocTypeCodes.contains(typeCode);

bool prestataireHasValidationDocuments(
  Iterable<PrestataireDocument> documents,
) {
  final present = documents
      .where((d) => d.fichierUrl.trim().isNotEmpty)
      .map((d) => d.typeCode)
      .toSet();
  return kPrestataireValidationDocTypeCodes.every(present.contains);
}

bool prestataireHasAllDocuments(Iterable<PrestataireDocument> documents) {
  final present = documents
      .where((d) => d.fichierUrl.trim().isNotEmpty)
      .map((d) => d.typeCode)
      .toSet();
  return kPrestataireAllDocTypeCodes.every(present.contains);
}

/// Documents requis pour quitter l'écran upload et passer en validation admin.
bool prestataireHasAllRequiredDocuments(
  Iterable<PrestataireDocument> documents,
) =>
    prestataireHasAllDocuments(documents);
