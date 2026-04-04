import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:milleservices/models/prestataire_photo.dart';
import 'package:milleservices/services/utilities.dart';
import 'package:milleservices/widgets/prestataire_catalogue_photo_viewer.dart';

/// Liste complète du catalogue photos (particulier ou prestataire connecté).
void showPrestataireCatalogueBottomSheet(
  BuildContext context,
  List<PrestatairePhoto> photos,
) {
  if (photos.isEmpty) return;
  final sorted = List<PrestatairePhoto>.from(photos)
    ..sort((a, b) => a.ordre.compareTo(b.ordre));

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final bottomInset = MediaQuery.paddingOf(ctx).bottom;
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        builder: (_, scrollController) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 4, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'presta_catalog'.tr(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + bottomInset),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: sorted.length,
                  itemBuilder: (_, i) {
                    final p = sorted[i];
                    return GestureDetector(
                      onTap: () => showPrestataireCataloguePhotoViewer(
                        ctx,
                        sorted,
                        initialIndex: i,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          p.url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => ColoredBox(
                            color: Utilities().colorGreyLightDark,
                            child: Icon(
                              Icons.image_not_supported,
                              color: Utilities().colorGreyDark,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
