import 'package:flutter/material.dart';
import 'package:milleservices/services/utilities.dart';

/// Écran de chargement Flutter aligné sur le splash natif et l'écran Welcome.
class AppLaunchScreen extends StatelessWidget {
  const AppLaunchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final blue = Utilities().colorBlueDark;
    return ColoredBox(
      color: blue,
      child: SafeArea(
        child: Center(
          child: Image.asset(
            '${Utilities().imagePath}logo.png',
            width: 160,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
