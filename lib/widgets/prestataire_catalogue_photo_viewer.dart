import 'package:flutter/material.dart';
import 'package:milleservices/models/prestataire_photo.dart';
import 'package:milleservices/services/utilities.dart';

/// Ouvre une photo du catalogue en plein écran (zoom pincer, balayage si plusieurs).
void showPrestataireCataloguePhotoViewer(
  BuildContext context,
  List<PrestatairePhoto> photos, {
  int initialIndex = 0,
}) {
  if (photos.isEmpty) return;
  final i = initialIndex.clamp(0, photos.length - 1);
  Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: true,
      pageBuilder: (context, animation, secondaryAnimation) =>
          _CataloguePhotoViewerPage(photos: photos, initialIndex: i),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}

class _CataloguePhotoViewerPage extends StatefulWidget {
  const _CataloguePhotoViewerPage({
    required this.photos,
    required this.initialIndex,
  });

  final List<PrestatairePhoto> photos;
  final int initialIndex;

  @override
  State<_CataloguePhotoViewerPage> createState() =>
      _CataloguePhotoViewerPageState();
}

class _CataloguePhotoViewerPageState extends State<_CataloguePhotoViewerPage> {
  late final PageController _pageController;
  late int _page;

  @override
  void initState() {
    super.initState();
    _page = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: widget.photos.length > 1
            ? Text(
                '${_page + 1} / ${widget.photos.length}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              )
            : null,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.photos.length,
              onPageChanged: (index) => setState(() => _page = index),
              itemBuilder: (_, index) {
                final url = widget.photos[index].url;
                return SizedBox.expand(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4,
                    boundaryMargin: const EdgeInsets.all(80),
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            color: Utilities().colorBlue,
                            strokeWidth: 2,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: Utilities().colorGreyLightDark,
                          size: 56,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (bottom > 0) SizedBox(height: bottom),
        ],
      ),
    );
  }
}
