import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:milleservices/controllers/authController.dart';
import 'package:milleservices/controllers/prestatairesController.dart';
import 'package:milleservices/providers/settings_provider.dart';
import 'package:milleservices/providers/userProvider.dart';
import 'package:milleservices/navigation/app_navigation.dart';
import 'package:milleservices/router/app_redirect.dart';
import 'package:milleservices/router/app_routes.dart';
import 'package:milleservices/models/prestataire_document.dart';
import 'package:milleservices/services/prestataire_required_documents.dart';
import 'package:milleservices/services/document_picker_helper.dart';
import 'package:milleservices/services/pick_file_name.dart';
import 'package:milleservices/services/sizeConfig.dart';
import 'package:milleservices/services/utilities.dart';
import 'package:milleservices/widgets/keyboard_dismiss.dart';
import 'package:provider/provider.dart';

class PrestataireUploadDocuments extends StatefulWidget {
  const PrestataireUploadDocuments({super.key});

  @override
  State<PrestataireUploadDocuments> createState() =>
      _PrestataireUploadDocumentsState();
}

class _PrestataireUploadDocumentsState
    extends State<PrestataireUploadDocuments> with WidgetsBindingObserver {
  static const _pollInterval = Duration(seconds: 10);

  final Map<String, PlatformFile?> _pickedFiles = {};
  final Map<String, PrestataireDocument> _existingByType = {};
  bool _isSubmitting = false;
  bool _checkingExisting = true;
  bool _statusRequestInFlight = false;
  Timer? _pollTimer;

  List<Map<String, String>> get _allDocs => prestataireAllDocsCatalog;

  bool get _hasAllDocsLocally =>
      _allDocs.every((doc) => _hasFileFor(doc['typeCode']!));

  int get _docsDoneCount =>
      _allDocs.where((doc) => _hasFileFor(doc['typeCode']!)).length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVerificationStatus(initialLoad: true);
    });
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      _checkVerificationStatus();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkVerificationStatus();
    }
  }

  Future<void> _checkVerificationStatus({bool initialLoad = false}) async {
    if (_statusRequestInFlight) return;
    _statusRequestInFlight = true;

    final userProvider = context.read<UserProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final data = await userProvider.refreshVerificationStatus();
    _statusRequestInFlight = false;
    if (!mounted) return;

    if (data != null) {
      final statut =
          (data['statutVerification']?.toString().toUpperCase() ?? '');
      final docs = (data['documents'] is List)
          ? data['documents'] as List
          : <dynamic>[];
      final hasRefusedDoc = docs.any((d) {
        final s = d is Map ? d['statut']?.toString().toUpperCase() : null;
        return s == 'REFUSE';
      });

      if (statut == 'REFUSE' || hasRefusedDoc) {
        context.go(AppRoutes.prestataireDocumentsRefused);
        return;
      }
      if (statut == 'VERIFIE') {
        await userProvider.syncPrestataireAbonnementIfNeeded();
        if (!mounted) return;
        context.go(
          homePathForUser(
            userProvider: userProvider,
            settingsProvider: settingsProvider,
          ),
        );
        return;
      }
      if (isPrestatairePastDocumentValidation(userProvider)) {
        context.go(
          homePathForUser(
            userProvider: userProvider,
            settingsProvider: settingsProvider,
          ),
        );
        return;
      }
      if (userProvider.hasAllRequiredPrestataireDocuments ||
          _hasAllDocsLocally) {
        context.go(AppRoutes.prestataireValidation);
        return;
      }
    }

    final existing = <String, PrestataireDocument>{};
    for (final doc in userProvider.prestataireDocuments) {
      if (doc.fichierUrl.trim().isEmpty) continue;
      existing[doc.typeCode] = doc;
    }
    setState(() {
      _existingByType
        ..clear()
        ..addAll(existing);
      if (initialLoad) {
        _checkingExisting = false;
      }
    });
  }

  String? _displayFileName(String typeCode) {
    final picked = _pickedFiles[typeCode];
    if (picked != null && picked.name.isNotEmpty) return picked.name;
    final existing = _existingByType[typeCode];
    final name = existing?.nomFichier?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (existing != null) return 'Document déjà envoyé';
    return null;
  }

  bool _hasFileFor(String typeCode) =>
      _pickedFiles[typeCode] != null || _existingByType.containsKey(typeCode);

  bool _isPendingUpload(String typeCode) => _pickedFiles[typeCode] != null;

  void _syncExistingFromProvider(UserProvider userProvider) {
    final existing = <String, PrestataireDocument>{};
    for (final doc in userProvider.prestataireDocuments) {
      if (doc.fichierUrl.trim().isEmpty) continue;
      existing[doc.typeCode] = doc;
    }
    _existingByType
      ..clear()
      ..addAll(existing);
  }

  List<String> _missingDocLabels() => _allDocs
      .where((doc) => !_hasFileFor(doc['typeCode']!))
      .map((doc) => doc['label']!)
      .toList();

  void _mergeUploadedDocumentsLocally(List<Map<String, String>> uploaded) {
    for (final doc in uploaded) {
      final typeCode = doc['typeCode']?.trim();
      final fichierUrl = doc['fichierUrl']?.trim();
      if (typeCode == null || typeCode.isEmpty) continue;
      if (fichierUrl == null || fichierUrl.isEmpty) continue;
      final previous = _existingByType[typeCode];
      _existingByType[typeCode] = PrestataireDocument(
        id: previous?.id ?? '',
        typeCode: typeCode,
        typeLibelle: previous?.typeLibelle ??
            kPrestataireDocLabels[typeCode] ??
            typeCode,
        obligatoire: isPrestataireValidationRequiredDocType(typeCode),
        statut: previous?.statut ?? 'EN_ATTENTE',
        fichierUrl: fichierUrl,
        nomFichier: doc['nomFichier'],
        motifRefus: previous?.motifRefus,
        updatedAt: previous?.updatedAt,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingExisting) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    SizeConfig().init(context);
    final utilities = Utilities();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          'Uploader vos documents',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            tooltip: 'Déconnexion',
            onPressed: () async {
              await AppNavigation.signOut(context);
              if (!context.mounted) return;
              AppNavigation.goWelcome(context);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: KeyboardDismissScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: SizeConfig.blockSizeHorizontal * 6,
            vertical: SizeConfig.blockSizeVertical * 3,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'presta_onboarding_docs_intro'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: SizeConfig.fontSize(
                    SizeConfig.blockSizeHorizontal * 3.5,
                  ),
                  color: utilities.colorGreyDark,
                ),
              ),
              SizedBox(height: SizeConfig.blockSizeVertical * 1.5),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: SizeConfig.blockSizeHorizontal * 4,
                  vertical: SizeConfig.blockSizeVertical * 1.4,
                ),
                decoration: BoxDecoration(
                  color: _hasAllDocsLocally
                      ? Colors.green.shade50
                      : utilities.colorBlueLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _hasAllDocsLocally
                        ? Colors.green.shade200
                        : utilities.colorGreyLightDark,
                  ),
                ),
                child: Text(
                  _hasAllDocsLocally
                      ? 'presta_upload_ready_validation'.tr()
                      : 'presta_upload_progress'.tr(
                          namedArgs: {
                            'done': _docsDoneCount.toString(),
                            'total': _allDocs.length.toString(),
                          },
                        ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: SizeConfig.fontSize(
                      SizeConfig.blockSizeHorizontal * 3.1,
                    ),
                    color: _hasAllDocsLocally
                        ? Colors.green.shade800
                        : utilities.colorBlueDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(height: SizeConfig.blockSizeVertical * 3),
              for (final doc in _allDocs) ...[
                _buildUploadSection(
                  typeCode: doc['typeCode']!,
                  title: _titleForDoc(doc),
                  fileName: _displayFileName(doc['typeCode']!),
                  hasFile: _hasFileFor(doc['typeCode']!),
                  isPending: _isPendingUpload(doc['typeCode']!),
                  isSaved: _existingByType.containsKey(doc['typeCode']!) &&
                      !_isPendingUpload(doc['typeCode']!),
                  onTap: () => _pickFileFor(doc['typeCode']!),
                ),
                SizedBox(height: SizeConfig.blockSizeVertical * 2.4),
              ],
              SizedBox(height: SizeConfig.blockSizeVertical * 1.5),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: utilities.colorBlueDark,
                    padding: EdgeInsets.symmetric(
                      vertical: SizeConfig.blockSizeVertical * 1.8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        SizeConfig.blockSizeHorizontal * 6,
                      ),
                    ),
                  ),
                  onPressed: _isSubmitting ? null : _onSubmit,
                  child: _isSubmitting
                      ? SizedBox(
                          height: SizeConfig.blockSizeHorizontal * 4.5,
                          width: SizeConfig.blockSizeHorizontal * 4.5,
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Envoyer',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: SizeConfig.fontSize(
                              SizeConfig.blockSizeHorizontal * 3.8,
                            ),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _titleForDoc(Map<String, String> doc) {
    final label = doc['label']!;
    if (isPrestataireValidationRequiredDocType(doc['typeCode']!)) {
      return label;
    }
    return '$label (${'presta_doc_optional'.tr()})';
  }

  Widget _buildUploadSection({
    required String typeCode,
    required String title,
    required String? fileName,
    required bool hasFile,
    required bool isPending,
    required bool isSaved,
    required VoidCallback onTap,
  }) {
    final utilities = Utilities();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: SizeConfig.fontSize(SizeConfig.blockSizeHorizontal * 3.4),
          ),
        ),
        if (isPending) ...[
          SizedBox(height: SizeConfig.blockSizeVertical * 0.5),
          Text(
            'presta_upload_pending_hint'.tr(),
            style: TextStyle(
              color: Colors.orange.shade800,
              fontSize: SizeConfig.fontSize(
                SizeConfig.blockSizeHorizontal * 2.8,
              ),
            ),
          ),
        ] else if (isSaved) ...[
          SizedBox(height: SizeConfig.blockSizeVertical * 0.5),
          Text(
            'presta_upload_saved_hint'.tr(),
            style: TextStyle(
              color: Colors.green.shade700,
              fontSize: SizeConfig.fontSize(
                SizeConfig.blockSizeHorizontal * 2.8,
              ),
            ),
          ),
        ],
        SizedBox(height: SizeConfig.blockSizeVertical * 1.1),
        InkWell(
          onTap: onTap,
          child: CustomPaint(
            painter: _DashedBorderPainter(
              color: utilities.colorGreyDark,
              strokeWidth: 1.5,
              dashWidth: 6,
              dashSpace: 4,
            ),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                vertical: SizeConfig.blockSizeVertical * 2.2,
                horizontal: SizeConfig.blockSizeHorizontal * 4,
              ),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.cloud_upload_outlined,
                        color: utilities.colorBlueDark,
                      ),
                      SizedBox(width: SizeConfig.blockSizeHorizontal * 2.5),
                      SizedBox(
                        width: SizeConfig.blockSizeHorizontal * 45,
                        child: Text(
                          fileName ?? 'doc_pick_hint'.tr(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: hasFile
                                ? Colors.black87
                                : utilities.colorGreyDark,
                            fontSize: SizeConfig.fontSize(
                              SizeConfig.blockSizeHorizontal * 3.0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Fichier',
                    style: TextStyle(
                      color: utilities.colorBlueDark,
                      fontWeight: FontWeight.w500,
                      fontSize: SizeConfig.fontSize(
                        SizeConfig.blockSizeHorizontal * 3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickFileFor(String typeCode) async {
    final file = await DocumentPickerHelper.pickDocument(context);
    if (!mounted || file == null) return;
    setState(() {
      _pickedFiles[typeCode] = file;
    });
  }

  Future<void> _onSubmit() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    final documents = <Map<String, String>>[];

    for (final doc in _allDocs) {
      final typeCode = doc['typeCode']!;
      final picked = _pickedFiles[typeCode];
      if (picked == null) continue;
      final up = await Authcontroller.instance.uploadDocument(
        path: picked.path,
        bytes: picked.bytes?.isNotEmpty == true ? picked.bytes : null,
        name: safePickFileName(picked),
      );
      if (up.url == null || up.url!.isEmpty) {
        if (!mounted) return;
        Utilities().showMesage(
          context,
          'error',
          up.error ?? 'Échec de l\'upload: ${doc['label']}',
        );
        return;
      }
      documents.add({
        'typeCode': typeCode,
        'fichierUrl': up.url!,
        'nomFichier': picked.name,
      });
    }

    if (documents.isEmpty) {
      if (!mounted) return;
      if (userProvider.hasAllRequiredPrestataireDocuments ||
          _hasAllDocsLocally) {
        context.go(AppRoutes.prestataireValidation);
        return;
      }
      Utilities().showMesage(
        context,
        'error',
        'presta_upload_nothing_selected'.tr(),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });
    try {
      var res = await PrestatairesController.instance.updateMyDocuments(
        token: userProvider.token ?? '',
        documents: documents,
      );
      if (res.status == 401) {
        await userProvider.refreshToken();
        res = await PrestatairesController.instance.updateMyDocuments(
          token: userProvider.token ?? '',
          documents: documents,
        );
      }
      if (!mounted) return;
      if (res.success == true) {
        await userProvider.refreshVerificationStatus();
        if (!mounted) return;
        setState(() {
          _pickedFiles.clear();
          _syncExistingFromProvider(userProvider);
          _mergeUploadedDocumentsLocally(documents);
        });
        final readyForValidation = _hasAllDocsLocally ||
            userProvider.hasAllRequiredPrestataireDocuments;
        final missing = _missingDocLabels();
        if (readyForValidation) {
          Utilities().showMesage(
            context,
            'success',
            'Documents envoyés. Vérification en cours.',
          );
          context.go(AppRoutes.prestataireValidation);
        } else {
          Utilities().showMesage(
            context,
            'success',
            'presta_upload_saved_partial'.tr(
              namedArgs: {'missing': missing.join(', ')},
            ),
          );
        }
      } else {
        Utilities().showMesage(
          context,
          'error',
          res.message?.toString().trim().isNotEmpty == true
              ? res.message.toString()
              : 'Envoi impossible',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;

  _DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.dashWidth = 6,
    this.dashSpace = 4,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final topLeft = const Offset(0, 0);
    final topRight = Offset(size.width, 0);
    final bottomRight = Offset(size.width, size.height);
    final bottomLeft = Offset(0, size.height);

    _drawDashedLine(canvas, paint, topLeft, topRight);
    _drawDashedLine(canvas, paint, topRight, bottomRight);
    _drawDashedLine(canvas, paint, bottomRight, bottomLeft);
    _drawDashedLine(canvas, paint, bottomLeft, topLeft);
  }

  void _drawDashedLine(Canvas canvas, Paint paint, Offset start, Offset end) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance == 0) return;
    final direction = Offset(dx / distance, dy / distance);
    double progress = 0;
    while (progress < distance) {
      final currentDashWidth = progress + dashWidth < distance
          ? dashWidth
          : distance - progress;
      final dashStart = start + direction * progress;
      final dashEnd = start + direction * (progress + currentDashWidth);
      canvas.drawLine(dashStart, dashEnd, paint);
      progress += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
