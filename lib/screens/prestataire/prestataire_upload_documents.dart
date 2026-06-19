import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:milleservices/controllers/authController.dart';
import 'package:milleservices/controllers/prestatairesController.dart';
import 'package:milleservices/providers/userProvider.dart';
import 'package:milleservices/navigation/app_navigation.dart';
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
    extends State<PrestataireUploadDocuments> {
  final Map<String, PlatformFile?> _pickedFiles = {};
  final Map<String, PrestataireDocument> _existingByType = {};
  bool _isSubmitting = false;
  bool _checkingExisting = true;

  List<Map<String, String>> get _requiredDocs => prestataireRequiredDocsCatalog;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExistingDocuments();
    });
  }

  Future<void> _loadExistingDocuments() async {
    final userProvider = context.read<UserProvider>();
    await userProvider.syncPrestataireVerificationIfNeeded();
    if (!mounted) return;
    if (userProvider.hasAllRequiredPrestataireDocuments) {
      context.go(AppRoutes.prestataireValidation);
      return;
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
      _checkingExisting = false;
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
                'Pour activer votre compte prestataire, merci de déposer les 4 documents requis.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: SizeConfig.fontSize(
                    SizeConfig.blockSizeHorizontal * 3.5,
                  ),
                  color: utilities.colorGreyDark,
                ),
              ),
              SizedBox(height: SizeConfig.blockSizeVertical * 3),
              for (final doc in _requiredDocs) ...[
                _buildUploadSection(
                  typeCode: doc['typeCode']!,
                  title: doc['label']!,
                  fileName: _displayFileName(doc['typeCode']!),
                  hasFile: _hasFileFor(doc['typeCode']!),
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

  Widget _buildUploadSection({
    required String typeCode,
    required String title,
    required String? fileName,
    required bool hasFile,
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
    final missing = _requiredDocs
        .where((doc) => !_hasFileFor(doc['typeCode']!))
        .map((doc) => doc['label']!)
        .toList();
    if (missing.isNotEmpty) {
      Utilities().showMesage(
        context,
        'error',
        'Veuillez fournir les 4 documents requis.',
      );
      return;
    }

    final documents = <Map<String, String>>[];

    for (final doc in _requiredDocs) {
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
      context.go(AppRoutes.prestataireValidation);
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
        Utilities().showMesage(
          context,
          'success',
          'Documents envoyés. Vérification en cours.',
        );
        context.go(
          userProvider.hasAllRequiredPrestataireDocuments
              ? AppRoutes.prestataireValidation
              : AppRoutes.prestataireDocuments,
        );
      } else {
        Utilities().showMesage(
          context,
          'error',
          res.message ?? 'Envoi impossible',
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
