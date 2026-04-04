import 'package:file_picker/file_picker.dart';

/// Nom de fichier sûr pour l’upload : le backend et Cloudinary détectent le PDF
/// via l’extension et le MIME. Sans extension, un PDF peut être traité comme
/// une image et apparaître vide ou corrompu.
String safePickFileName(PlatformFile file) {
  final rawName = file.name.trim();
  final ext = file.extension?.trim();
  final cleanExt = (ext != null && ext.isNotEmpty)
      ? ext.replaceFirst(RegExp(r'^\.+'), '')
      : '';

  if (rawName.isEmpty) {
    if (cleanExt.isNotEmpty) return 'document.$cleanExt';
    return 'document.bin';
  }
  if (rawName.contains('.')) return rawName;
  if (cleanExt.isNotEmpty) return '$rawName.$cleanExt';
  return rawName;
}
