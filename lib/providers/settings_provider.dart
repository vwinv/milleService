import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Clé SharedPreferences partagée avec [main] pour démarrer EasyLocalization au bon locale.
const String kAppSelectedLocalePrefKey = 'selected_locale';

class SettingsProvider extends ChangeNotifier {
  Locale? _locale;
  bool _loaded = false;

  Locale? get locale => _locale;
  bool get isLoaded => _loaded;

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
    _loaded = true;
    notifyListeners();
  }

  /// Définit la langue de l'application et la persiste.
  /// Passer [null] pour revenir à la langue du système.
  Future<void> setLocale(Locale? newLocale) async {
    if (_locale == newLocale) return;
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
