import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapMarkerBadge {
  MapMarkerBadge._();

  static Future<BitmapDescriptor> create({
    required String label,
    required Color borderColor,
    required Color fillColor,
    required Color textColor,
  }) async {
    const double width = 162;
    const double height = 76;
    const double bubbleTop = 6;
    const double bubbleHeight = 30;
    const double bubbleRadius = 16;
    const double locationIconSize = 30;
    const double locationTopGap = 2;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final rect = RRect.fromLTRBR(
      8,
      bubbleTop,
      width - 8,
      bubbleTop + bubbleHeight,
      const Radius.circular(bubbleRadius),
    );
    final fillPaint = Paint()..color = fillColor;
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawRRect(rect, fillPaint);
    canvas.drawRRect(rect, borderPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: label.length > 24 ? '${label.substring(0, 24)}...' : label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
      ellipsis: '...',
    )..layout(maxWidth: width - 40);

    final textOffset = Offset(
      (width - textPainter.width) / 2,
      bubbleTop + (bubbleHeight - textPainter.height) / 2,
    );
    textPainter.paint(canvas, textOffset);

    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.location_on.codePoint),
        style: TextStyle(
          fontSize: locationIconSize,
          color: borderColor,
          fontFamily: Icons.location_on.fontFamily,
          package: Icons.location_on.fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final iconOffset = Offset(
      (width - iconPainter.width) / 2,
      bubbleTop + bubbleHeight + locationTopGap,
    );
    iconPainter.paint(canvas, iconOffset);

    final image = await recorder.endRecording().toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData?.buffer.asUint8List();
    if (bytes == null || bytes.isEmpty) {
      return BitmapDescriptor.defaultMarker;
    }
    return BitmapDescriptor.bytes(bytes);
  }
}
