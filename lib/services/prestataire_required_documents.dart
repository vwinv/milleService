import 'package:milleservices/models/prestataire_document.dart';

/// Types de documents obligatoires pour compléter le profil prestataire.
const kPrestataireRequiredDocTypeCodes = <String>[
  'cni_recto',
  'cni_verso',
  'certificat_residence',
  'diplome',
];

const kPrestataireRequiredDocLabels = <String, String>{
  'cni_recto': 'CNI / Passeport (recto)',
  'cni_verso': 'CNI / Passeport (verso)',
  'certificat_residence': 'Certificat de résidence',
  'diplome': 'Diplôme',
};

List<Map<String, String>> get prestataireRequiredDocsCatalog =>
    kPrestataireRequiredDocTypeCodes
        .map(
          (code) => {
            'typeCode': code,
            'label': kPrestataireRequiredDocLabels[code] ?? code,
          },
        )
        .toList();

bool prestataireHasAllRequiredDocuments(
  Iterable<PrestataireDocument> documents,
) {
  final present = documents
      .where((d) => d.fichierUrl.trim().isNotEmpty)
      .map((d) => d.typeCode)
      .toSet();
  return kPrestataireRequiredDocTypeCodes.every(present.contains);
}
