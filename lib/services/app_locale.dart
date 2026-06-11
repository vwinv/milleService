import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:milleservices/providers/settings_provider.dart';

/// Persiste la langue et aligne EasyLocalization (`.tr()`).
Future<void> applyAppLanguage(
  BuildContext context,
  SettingsProvider settings,
  String languageCode,
) async {
  await settings.setLocaleFromCode(languageCode);
  if (!context.mounted) return;
  final locale = Locale(languageCode);
  if (context.locale.languageCode != locale.languageCode) {
    await context.setLocale(locale);
  }
}

/// Pré-sélection fr/en à partir de la langue du téléphone (sans persister).
String deviceLanguagePreselection(Locale deviceLocale) {
  return deviceLocale.languageCode == 'en' ? 'en' : 'fr';
}
