import 'package:flutter/material.dart';
import 'package:milleservices/services/sizeConfig.dart';
import 'package:milleservices/services/utilities.dart';

/// Zone d'upload avec bordure en pointillés.
/// [title] : libellé principal (ex. "Recto")
/// [subtitle] : libellé secondaire optionnel (ex. "CNI ou Passeport")
/// [fileName] : nom du fichier sélectionné (si null, affiche un message d'ajout)
/// [onTap] : appelé au clic pour ouvrir le sélecteur de fichier
class DashedUploadZone extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? fileName;
  final VoidCallback onTap;

  const DashedUploadZone({
    super.key,
    required this.title,
    this.subtitle,
    this.fileName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: SizeConfig.blockSizeHorizontal * 85,
        padding: EdgeInsets.symmetric(
          vertical: SizeConfig.blockSizeVertical * 2,
          horizontal: SizeConfig.blockSizeHorizontal * 3,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(SizeConfig.blockSizeHorizontal * 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(SizeConfig.blockSizeHorizontal * 2),
          child: CustomPaint(
            painter: _DashedBorderPainter(),
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: SizeConfig.blockSizeVertical * 2.5,
                horizontal: SizeConfig.blockSizeHorizontal * 4,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (subtitle != null) ...[
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: Utilities().colorGreyDark,
                        fontSize: SizeConfig.blockSizeHorizontal * 2.8,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: SizeConfig.blockSizeVertical * 0.5),
                  ],
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: SizeConfig.blockSizeHorizontal * 3.2,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: SizeConfig.blockSizeVertical * 1),
                  Icon(
                    fileName != null ? Icons.check_circle : Icons.add_photo_alternate_outlined,
                    color: fileName != null
                        ? Colors.green
                        : Utilities().colorGreyDark.withOpacity(0.8),
                    size: SizeConfig.blockSizeHorizontal * 8,
                  ),
                  SizedBox(height: SizeConfig.blockSizeVertical * 0.5),
                  Text(
                    fileName ?? "Ajouter un fichier",
                    style: TextStyle(
                      color: fileName != null
                          ? Colors.green.shade700
                          : Utilities().colorGreyDark,
                      fontSize: SizeConfig.blockSizeHorizontal * 2.6,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Utilities().colorGreyDark.withOpacity(0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashWidth = 6.0;
    const dashSpace = 4.0;

    void drawDashedRect(Rect rect) {
      final path = Path();
      // Top
      for (double x = 0; x < rect.width; x += dashWidth + dashSpace) {
        final endX = (x + dashWidth).clamp(0.0, rect.width);
        if (endX > x) {
          path.moveTo(rect.left + x, rect.top);
          path.lineTo(rect.left + endX, rect.top);
        }
      }
      // Right
      for (double y = 0; y < rect.height; y += dashWidth + dashSpace) {
        final endY = (y + dashWidth).clamp(0.0, rect.height);
        if (endY > y) {
          path.moveTo(rect.right, rect.top + y);
          path.lineTo(rect.right, rect.top + endY);
        }
      }
      // Bottom
      for (double x = rect.width; x > 0; x -= dashWidth + dashSpace) {
        final startX = (x - dashWidth).clamp(0.0, rect.width);
        if (x > startX) {
          path.moveTo(rect.left + x, rect.bottom);
          path.lineTo(rect.left + startX, rect.bottom);
        }
      }
      // Left
      for (double y = rect.height; y > 0; y -= dashWidth + dashSpace) {
        final startY = (y - dashWidth).clamp(0.0, rect.height);
        if (y > startY) {
          path.moveTo(rect.left, rect.top + y);
          path.lineTo(rect.left, rect.top + startY);
        }
      }
      canvas.drawPath(path, paint);
    }

    drawDashedRect(Rect.fromLTWH(1, 1, size.width - 2, size.height - 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
