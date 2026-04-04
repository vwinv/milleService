import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:milleservices/services/utilities.dart';

/// Service pour traduire les textes dynamiques provenant du backend
/// (service.libelle, prestataire.bio, avis.commentaire, offre.description,
/// ResponseData.message, etc.) via Microsoft Translator (ou API équivalente).
class DynamicTranslationService {
  DynamicTranslationService._();
  static final DynamicTranslationService instance = DynamicTranslationService._();

  final Dio _dio = Dio(
    BaseOptions(
      // Exemple d'URL de Microsoft Translator :
      // https://api.cognitive.microsofttranslator.com
      baseUrl: Utilities().translatorEndpointBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  /// Cache simple en mémoire : clé = "$from|$to|$text"
  final Map<String, String> _cache = {};

  /// Traduit [original] vers la langue actuelle de l'application.
  ///
  /// [sourceLang] : code langue d'origine (par défaut 'fr').
  /// Si la langue cible est la même que la langue source, on retourne [original].
  Future<String> translate(
    BuildContext context,
    String original, {
    String sourceLang = 'fr',
  }) async {
    final targetLang = context.locale.languageCode;

    if (original.trim().isEmpty || sourceLang == targetLang) {
      return original;
    }

    final key = '$sourceLang|$targetLang|$original';
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    try {
      final utilities = Utilities();
      if (utilities.translatorSubscriptionKey == null ||
          utilities.translatorSubscriptionKey!.isEmpty ||
          utilities.translatorRegion == null ||
          utilities.translatorRegion!.isEmpty) {
        // Config incomplète : on ne tente pas de traduction.
        return original;
      }

      // Microsoft Translator Text API v3.0
      final response = await _dio.post(
        '/translate',
        queryParameters: <String, dynamic>{
          'api-version': '3.0',
          'from': sourceLang,
          'to': targetLang,
        },
        data: [
          {'Text': original},
        ],
        options: Options(
          headers: {
            'Ocp-Apim-Subscription-Key': utilities.translatorSubscriptionKey,
            'Ocp-Apim-Subscription-Region': utilities.translatorRegion,
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200 && response.data is List) {
        final List list = response.data as List;
        if (list.isNotEmpty &&
            list.first is Map &&
            (list.first as Map)['translations'] is List &&
            ((list.first as Map)['translations'] as List).isNotEmpty) {
          final firstTranslation =
              ((list.first as Map)['translations'] as List).first;
          final translated = (firstTranslation['text'] ?? '').toString();
          if (translated.trim().isNotEmpty) {
            _cache[key] = translated;
            return translated;
          }
        }
      }
    } catch (_) {
      // En cas d'erreur réseau ou autre, on retourne simplement le texte original.
    }

    return original;
  }
}

