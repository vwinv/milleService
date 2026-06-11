import 'package:flutter/foundation.dart';

/// Coordination du splash au démarrage (durée minimale, fluidité).
class AppBootstrapNotifier extends ChangeNotifier {
  AppBootstrapNotifier() {
    final remaining = minSplashDuration - DateTime.now().difference(_startedAt);
    Future<void>.delayed(
      remaining.isNegative ? Duration.zero : remaining,
      () {
        if (!_minSplashElapsed) {
          _minSplashElapsed = true;
          notifyListeners();
        }
      },
    );
  }

  static final DateTime _startedAt = DateTime.now();

  static const Duration minSplashDuration = Duration(milliseconds: 700);

  bool _minSplashElapsed = false;

  bool get minSplashElapsed => _minSplashElapsed;
}
