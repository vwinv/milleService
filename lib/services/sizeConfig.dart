import 'dart:math';

import 'package:flutter/cupertino.dart';

class SizeConfig {
  static MediaQueryData _mediaQueryData = const MediaQueryData();
  static double screenWidth = 0.0;
  static double screenHeight = 0.0;
  static double blockSizeHorizontal = 0.0;
  static double blockSizeVertical = 0.0;
  static double safeBlockHorizontal = 0.0;
  static double safeBlockVertical = 0.0;
  static double safeAreaHorizontal = 0.0;
  static double safeAreaVertical = 0.0;

  void init(BuildContext context) {
    _mediaQueryData = MediaQuery.of(context);
    screenWidth = _mediaQueryData.size.width;
    screenHeight = _mediaQueryData.size.height;
    safeAreaHorizontal =
        _mediaQueryData.padding.left + _mediaQueryData.padding.right;
    safeAreaVertical = _mediaQueryData.padding.top + _mediaQueryData.padding.bottom;
    blockSizeHorizontal = screenWidth / 100;
    blockSizeVertical = screenHeight / 100;
    safeBlockHorizontal = (screenWidth - safeAreaHorizontal) / 100;
    safeBlockVertical = (screenHeight - safeAreaVertical) / 100;
  }

  // Détection tablette basée sur shortestSide
  static bool isTablet() {
    return _mediaQueryData.size.shortestSide >= 600;
  }

  // Option diagonale plus précise (facultatif)
  static bool isTabletByDiagonal() {
    final diagonalInInches =
        sqrt(
          pow(screenWidth / _mediaQueryData.devicePixelRatio, 2) +
              pow(screenHeight / _mediaQueryData.devicePixelRatio, 2),
        ) /
        160;
    return diagonalInInches >= 7;
  }

  // Retourne une taille de texte adaptée pour les tablettes
  // Sur tablette, on réduit la taille pour éviter que les textes soient trop gros
  static double fontSize(double phoneSize) {
    if (isTablet()) {
      // Sur tablette, on réduit d'environ 25-30% pour garder une taille lisible mais plus grande
      // Facteur augmenté de 0.6 à 0.75 pour des textes plus grands sur iPad
      return phoneSize * 0.75;
    }
    return phoneSize;
  }
}
