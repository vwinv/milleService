import 'package:flutter/foundation.dart';

/// Étapes du contenu principal (sous la carte).
enum HomeContentStep {
  favoris,
  demanderService,
}

/// Sous-étapes pour la page "Demander un service" (extensible).
enum DemanderServiceStep {
  choixType,
  formulaire,
  recap,
}

class HomeContentProvider extends ChangeNotifier {
  HomeContentStep _step = HomeContentStep.favoris;
  DemanderServiceStep _demanderStep = DemanderServiceStep.choixType;

  HomeContentStep get step => _step;
  DemanderServiceStep get demanderStep => _demanderStep;

  bool get isFavoris => _step == HomeContentStep.favoris;
  bool get isDemanderService => _step == HomeContentStep.demanderService;

  void goToFavoris() {
    _step = HomeContentStep.favoris;
    notifyListeners();
  }

  void goToDemanderService() {
    _step = HomeContentStep.demanderService;
    _demanderStep = DemanderServiceStep.choixType;
    notifyListeners();
  }

  void nextDemanderStep() {
    final steps = DemanderServiceStep.values;
    final idx = steps.indexOf(_demanderStep);
    if (idx >= 0 && idx < steps.length - 1) {
      _demanderStep = steps[idx + 1];
      notifyListeners();
    }
  }

  void previousDemanderStep() {
    final steps = DemanderServiceStep.values;
    final idx = steps.indexOf(_demanderStep);
    if (idx > 0) {
      _demanderStep = steps[idx - 1];
      notifyListeners();
    } else {
      goToFavoris();
    }
  }

  void setDemanderStep(DemanderServiceStep s) {
    _demanderStep = s;
    notifyListeners();
  }
}
