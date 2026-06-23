import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:milleservices/controllers/authController.dart';
import 'package:milleservices/controllers/prestatairesController.dart';
import 'package:milleservices/models/prestataire_document.dart';
import 'package:milleservices/providers/userProvider.dart';
import 'package:milleservices/services/document_picker_helper.dart';
import 'package:milleservices/services/pick_file_name.dart';
import 'package:milleservices/services/prestataire_required_documents.dart';
import 'package:milleservices/services/sizeConfig.dart';
import 'package:milleservices/services/utilities.dart';
import 'package:milleservices/widgets/keyboard_dismiss.dart';
import 'package:provider/provider.dart';

/// Complétion des documents depuis le profil prestataire (tous types, statuts visibles).
class PrestataireCompleteDocuments extends StatefulWidget {
  const PrestataireCompleteDocuments({super.key});

  @override
  State<PrestataireCompleteDocuments> createState() =>
      _PrestataireCompleteDocumentsState();
}

class _PrestataireCompleteDocumentsState
    extends State<PrestataireCompleteDocuments> {
  final Map<String, PlatformFile?> _pickedFiles = {};
  final Map<String, PrestataireDocument> _existingByType = {};
  bool _isSubmitting = false;
  bool _loading = true;

  List<Map<String, String>> get _allDocs => prestataireAllDocsCatalog;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDocuments());
  }

  Future<void> _loadDocuments() async {
    final userProvider = context.read<UserProvider>();
    await userProvider.syncPrestataireVerificationIfNeeded();
    if (!mounted) return;
    final existing = <String, PrestataireDocument>{};
    for (final doc in userProvider.prestataireDocuments) {
      if (doc.fichierUrl.trim().isEmpty) continue;
      existing[doc.typeCode] = doc;
    }
    setState(() {
      _existingByType
        ..clear()
        ..addAll(existing);
      _loading = false;
    });
  }

  PrestataireDocument? _existing(String typeCode) => _existingByType[typeCode];

  String? _displayFileName(String typeCode) {
    final picked = _pickedFiles[typeCode];
    if (picked != null && picked.name.isNotEmpty) return picked.name;
    final existing = _existing(typeCode);
    final name = existing?.nomFichier?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (existing != null) return 'presta_doc_uploaded'.tr();
    return null;
  }

  bool _isValidated(String typeCode) =>
      _existing(typeCode)?.statut.toString().toUpperCase() == 'VALIDE';

  bool _canPick(String typeCode) {
    if (_isValidated(typeCode)) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    final utilities = Utilities();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'presta_complete_docs_title'.tr(),
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : KeyboardDismissScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: SizeConfig.blockSizeHorizontal * 6,
                  vertical: SizeConfig.blockSizeVertical * 3,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'presta_complete_docs_subtitle'.tr(),
                      style: TextStyle(
                        fontSize: SizeConfig.fontSize(
                          SizeConfig.blockSizeHorizontal * 3.5,
                        ),
                        color: utilities.colorGreyDark,
                      ),
                    ),
                    SizedBox(height: SizeConfig.blockSizeVertical * 3),
                    for (final doc in _allDocs) ...[
                      _buildDocumentSection(
                        typeCode: doc['typeCode']!,
                        title: doc['label']!,
                        optional: !isPrestataireValidationRequiredDocType(
                          doc['typeCode']!,
                        ),
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
                                'presta_complete_docs_save'.tr(),
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

  Widget _buildDocumentSection({
    required String typeCode,
    required String title,
    required bool optional,
  }) {
    final utilities = Utilities();
    final existing = _existing(typeCode);
    final statut = existing?.statut.toString().toUpperCase() ?? '';
    final isRefused = statut == 'REFUSE';
    final canPick = _canPick(typeCode);
    final fileName = _displayFileName(typeCode);
    final hasFile = fileName != null;
    final fieldBorderColor =
        isRefused ? Colors.red.shade400 : utilities.colorGreyDark;
    final fieldAccentColor =
        isRefused ? Colors.red.shade700 : utilities.colorBlueDark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isRefused ? Colors.red.shade700 : Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: SizeConfig.fontSize(
                    SizeConfig.blockSizeHorizontal * 3.4,
                  ),
                ),
              ),
            ),
            if (optional)
              Padding(
                padding: EdgeInsets.only(
                  left: SizeConfig.blockSizeHorizontal * 2,
                ),
                child: Text(
                  'presta_doc_optional'.tr(),
                  style: TextStyle(
                    color: utilities.colorGreyDark,
                    fontSize: SizeConfig.fontSize(
                      SizeConfig.blockSizeHorizontal * 2.8,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (existing != null && !isRefused) ...[
          SizedBox(height: SizeConfig.blockSizeVertical * 0.8),
          _buildStatusChip(statut),
        ] else if (existing == null) ...[
          SizedBox(height: SizeConfig.blockSizeVertical * 0.8),
          Text(
            'presta_doc_missing'.tr(),
            style: TextStyle(
              color: utilities.colorGreyDark,
              fontSize: SizeConfig.fontSize(
                SizeConfig.blockSizeHorizontal * 3.0,
              ),
            ),
          ),
        ],
        if (canPick) ...[
          SizedBox(height: SizeConfig.blockSizeVertical * 1.1),
          InkWell(
            onTap: () => _pickFileFor(typeCode),
            child: CustomPaint(
              painter: _DashedBorderPainter(
                color: fieldBorderColor,
                strokeWidth: isRefused ? 2 : 1.5,
                dashWidth: 6,
                dashSpace: 4,
              ),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  vertical: SizeConfig.blockSizeVertical * 2.2,
                  horizontal: SizeConfig.blockSizeHorizontal * 4,
                ),
                color: isRefused ? Colors.red.shade50 : Colors.white,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.cloud_upload_outlined,
                          color: fieldAccentColor,
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
                                  ? (isRefused
                                      ? Colors.red.shade800
                                      : Colors.black87)
                                  : fieldAccentColor,
                              fontSize: SizeConfig.fontSize(
                                SizeConfig.blockSizeHorizontal * 3.0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'presta_doc_pick_file'.tr(),
                      style: TextStyle(
                        color: fieldAccentColor,
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
        ] else if (hasFile) ...[
          SizedBox(height: SizeConfig.blockSizeVertical * 0.8),
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade600, size: 18),
              SizedBox(width: SizeConfig.blockSizeHorizontal * 1.5),
              Expanded(
                child: Text(
                  fileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: SizeConfig.fontSize(
                      SizeConfig.blockSizeHorizontal * 3.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildStatusChip(String statut) {
    late final Color bg;
    late final Color fg;
    late final String label;
    switch (statut) {
      case 'VALIDE':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        label = 'presta_doc_status_valid'.tr();
        break;
      case 'REFUSE':
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        label = 'presta_doc_status_refused'.tr();
        break;
      case 'EN_ATTENTE':
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade900;
        label = 'presta_doc_status_pending'.tr();
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade800;
        label = statut.isEmpty ? 'presta_doc_status_unknown'.tr() : statut;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w600,
          fontSize: SizeConfig.fontSize(SizeConfig.blockSizeHorizontal * 2.8),
        ),
      ),
    );
  }

  Future<void> _pickFileFor(String typeCode) async {
    final file = await DocumentPickerHelper.pickDocument(context);
    if (!mounted || file == null) return;
    setState(() => _pickedFiles[typeCode] = file);
  }

  Future<void> _showDocumentSentDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'presta_complete_docs_success_title'.tr(),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'presta_complete_docs_saved'.tr(),
          style: TextStyle(
            fontSize: SizeConfig.fontSize(SizeConfig.blockSizeHorizontal * 3.5),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'presta_complete_docs_success_ok'.tr(),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Utilities().colorBlueDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onSubmit() async {
    if (_pickedFiles.isEmpty) {
      Utilities().showMesage(
        context,
        'error',
        'presta_complete_docs_nothing_to_save'.tr(),
      );
      return;
    }

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final documents = <Map<String, String>>[];

    for (final entry in _pickedFiles.entries) {
      final typeCode = entry.key;
      final picked = entry.value;
      if (picked == null) continue;
      final up = await Authcontroller.instance.uploadDocument(
        path: picked.path,
        bytes: picked.bytes?.isNotEmpty == true ? picked.bytes : null,
        name: safePickFileName(picked),
      );
      if (up.url == null || up.url!.isEmpty) {
        if (!mounted) return;
        final label =
            kPrestataireDocLabels[typeCode] ?? typeCode;
        Utilities().showMesage(
          context,
          'error',
          up.error ?? 'Échec de l\'upload: $label',
        );
        return;
      }
      documents.add({
        'typeCode': typeCode,
        'fichierUrl': up.url!,
        'nomFichier': picked.name,
      });
    }

    setState(() => _isSubmitting = true);
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
          for (final doc in userProvider.prestataireDocuments) {
            if (doc.fichierUrl.trim().isEmpty) continue;
            _existingByType[doc.typeCode] = doc;
          }
        });
        await _showDocumentSentDialog();
        if (!mounted) return;
        context.pop();
      } else {
        Utilities().showMesage(
          context,
          'error',
          res.message ?? 'presta_complete_docs_save_failed'.tr(),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
