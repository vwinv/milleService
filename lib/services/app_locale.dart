import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:milleservices/providers/settings_provider.dart';

/// Persiste la langue dans [SettingsProvider] et aligne EasyLocalization (`.tr()`).
Future<void> applyAppLanguage(
  BuildContext context,
  SettingsProvider settings,
  String languageCode,
) async {
  await settings.setLocaleFromCode(languageCode);
  if (!context.mounted) return;
  await context.setLocale(Locale(languageCode));
}
