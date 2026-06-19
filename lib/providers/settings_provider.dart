import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Clé SharedPreferences partagée avec [main] pour démarrer EasyLocalization au bon locale.
const String kAppSelectedLocalePrefKey = 'selected_locale';
const String kGuestOnboardingDonePrefKey = 'guest_onboarding_done';

class SettingsProvider extends ChangeNotifier {
  Locale? _locale;
  bool _loaded = false;
  bool _guestOnboardingDone = false;

  Locale? get locale => _locale;
  bool get isLoaded => _loaded;
  bool get guestOnboardingDone => _guestOnboardingDone;

  /// Langue choisie par l'utilisateur, ou null = langue du système.
  Locale? get selectedLocale => _locale;

  SettingsProvider() {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(kAppSelectedLocalePrefKey);
    if (code != null && code.isNotEmpty) {
      _locale = Locale(code);
    } else {
      _locale = null;
    }
    _guestOnboardingDone = prefs.getBool(kGuestOnboardingDonePrefKey) ?? false;
    _loaded = true;
    notifyListeners();
  }

  /// Mémorise le parcours particulier (après connexion / inscription).
  Future<void> markGuestOnboardingDone() async {
    if (_guestOnboardingDone) return;
    _guestOnboardingDone = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kGuestOnboardingDonePrefKey, true);
    if (_loaded) {
      notifyListeners();
    }
  }

  /// Réinitialise le parcours invité (ex. déconnexion).
  Future<void> clearGuestOnboardingDone() async {
    if (!_guestOnboardingDone) {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(kGuestOnboardingDonePrefKey) ?? false)) return;
    }
    _guestOnboardingDone = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kGuestOnboardingDonePrefKey);
    if (_loaded) {
      notifyListeners();
    }
  }

  /// Définit la langue de l'application et la persiste.
  /// Passer [null] pour revenir à la langue du système.
  Future<void> setLocale(Locale? newLocale) async {
    if (_locale?.languageCode == newLocale?.languageCode) return;
    _locale = newLocale;
    final prefs = await SharedPreferences.getInstance();
    if (newLocale != null) {
      await prefs.setString(kAppSelectedLocalePrefKey, newLocale.languageCode);
    } else {
      await prefs.remove(kAppSelectedLocalePrefKey);
    }
    notifyListeners();
  }

  /// Raccourci : définir par code langue ("fr", "en").
  Future<void> setLocaleFromCode(String? languageCode) async {
    if (languageCode == null || languageCode.isEmpty) {
      await setLocale(null);
      return;
    }
    await setLocale(Locale(languageCode));
  }
}
