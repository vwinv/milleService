import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:milleservices/services/utilities.dart';
import 'package:permission_handler/permission_handler.dart';

enum _DocumentPickChoice { gallery, camera, file }

/// Choisir un document : galerie, appareil photo ou fichier (PDF / image).
class DocumentPickerHelper {
  DocumentPickerHelper._();

  static final ImagePicker _picker = ImagePicker();

  static Future<PlatformFile?> pickDocument(
    BuildContext context, {
    bool allowPdf = true,
  }) async {
    final choice = await showModalBottomSheet<_DocumentPickChoice>(
      context: context,
      backgroundColor: Colors.white,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text('image_gallery'.tr()),
                onTap: () => Navigator.of(ctx).pop(_DocumentPickChoice.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: Text('image_camera'.tr()),
                onTap: () => Navigator.of(ctx).pop(_DocumentPickChoice.camera),
              ),
              if (allowPdf)
                ListTile(
                  leading: const Icon(Icons.insert_drive_file_outlined),
                  title: Text('doc_pick_file'.tr()),
                  onTap: () => Navigator.of(ctx).pop(_DocumentPickChoice.file),
                ),
            ],
          ),
        );
      },
    );
    if (choice == null || !context.mounted) return null;

    switch (choice) {
      case _DocumentPickChoice.gallery:
        return _pickFromImageSource(context, ImageSource.gallery);
      case _DocumentPickChoice.camera:
        return _pickFromImageSource(context, ImageSource.camera);
      case _DocumentPickChoice.file:
        return _pickFromFileExplorer();
    }
  }

  static Future<PlatformFile?> _pickFromImageSource(
    BuildContext context,
    ImageSource source,
  ) async {
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (context.mounted) {
          Utilities().showMesage(
            context,
            'error',
            'image_camera_permission'.tr(),
          );
        }
        return null;
      }
    }

    final xFile = await _picker.pickImage(
      source: source,
      maxWidth: 2000,
      imageQuality: 88,
    );
    if (xFile == null) return null;
    return platformFileFromXFile(xFile);
  }

  static Future<PlatformFile?> _pickFromFileExplorer() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    return result.files.first;
  }

  static Future<PlatformFile> platformFileFromXFile(XFile xFile) async {
    final bytes = await xFile.readAsBytes();
    var name = xFile.name.trim();
    if (name.isEmpty) {
      final path = xFile.path;
      if (path != null && path.contains('.')) {
        name = path.split('/').last;
      } else {
        name = 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      }
    }
    if (!name.contains('.')) {
      name = '$name.jpg';
    }
    return PlatformFile(
      name: name,
      size: bytes.length,
      bytes: bytes,
      path: xFile.path,
    );
  }
}
