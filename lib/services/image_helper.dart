import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:milleservices/services/utilities.dart';
import 'package:permission_handler/permission_handler.dart';

class ImageHelper {
  /// Ouvre un choix \"Galerie\" / \"Appareil photo\" puis gère les permissions
  /// caméra si nécessaire. Retourne la photo choisie ou null si annulé.
  static Future<XFile?> pickImageWithChoice(
    BuildContext context,
    ImagePicker picker,
  ) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text('image_gallery'.tr()),
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text('image_camera'.tr()),
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );
    if (source == null) return null;

    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        Utilities().showMesage(
          context,
          'error',
          'image_camera_permission'.tr(),
        );
        return null;
      }
    }

    return picker.pickImage(source: source, maxWidth: 800, imageQuality: 85);
  }
}
