import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:milleservices/controllers/authController.dart';
import 'package:milleservices/controllers/prestatairesController.dart';
import 'package:milleservices/providers/userProvider.dart';
import 'package:milleservices/screens/welcome.dart';
import 'package:milleservices/services/pick_file_name.dart';
import 'package:milleservices/services/sizeConfig.dart';
import 'package:milleservices/services/utilities.dart';
import 'package:provider/provider.dart';

/// Écran affiché au prestataire tant que ses documents sont en cours de validation.
/// Il n'a pas encore accès à son tableau de bord ni aux recherches.
/// Cet écran interroge le backend pour connaître le statut réel :
/// - si le profil ou au moins un document est REFUSE -> redirige vers PrestataireDocumentsRefuses
/// - sinon -> affiche simplement le message "en cours de validation".
class PrestataireValidateProfil extends StatefulWidget {
  const PrestataireValidateProfil({super.key});

  @override
  State<PrestataireValidateProfil> createState() =>
      _PrestataireValidateProfilState();
}

class _PrestataireValidateProfilState extends State<PrestataireValidateProfil> {
  bool _checkingStatus = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVerificationStatus();
    });
  }

  Future<void> _checkVerificationStatus() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final data = await userProvider.refreshVerificationStatus();
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
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => const PrestataireDocumentsRefuses(),
          ),
        );
        return;
      }
    }

    setState(() {
      _checkingStatus = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    final utilities = Utilities();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: SizeConfig.blockSizeHorizontal * 24,
                height: SizeConfig.blockSizeHorizontal * 24,
                decoration: BoxDecoration(
                  color: utilities.colorBlueLight.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(
                    SizeConfig.blockSizeHorizontal * 6,
                  ),
                ),
                child: Center(
                  child: _checkingStatus
                      ? SpinKitCircle(
                          color: utilities.colorBlueDark,
                          size: SizeConfig.blockSizeHorizontal * 10,
                        )
                      : Icon(
                          Icons.hourglass_top_outlined,
                          size: SizeConfig.blockSizeHorizontal * 10,
                          color: utilities.colorBlueDark,
                        ),
                ),
              ),
              SizedBox(height: SizeConfig.blockSizeVertical * 4),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: SizeConfig.blockSizeHorizontal * 10,
                ),
                child: Text(
                  'validate_docs_pending'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: SizeConfig.fontSize(
                      SizeConfig.blockSizeHorizontal * 4,
                    ),
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
              SizedBox(height: SizeConfig.blockSizeVertical * 2),
              Text(
                'validate_take_24h'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: SizeConfig.fontSize(
                    SizeConfig.blockSizeHorizontal * 3.2,
                  ),
                  color: utilities.colorGreyDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Écran affiché quand au moins un document a été invalidé par l'admin.
/// Le prestataire peut renvoyer des documents plus lisibles.
class PrestataireDocumentsRefuses extends StatefulWidget {
  const PrestataireDocumentsRefuses({super.key});

  @override
  State<PrestataireDocumentsRefuses> createState() =>
      _PrestataireDocumentsRefusesState();
}

class _PrestataireDocumentsRefusesState
    extends State<PrestataireDocumentsRefuses> {
  final Map<String, PlatformFile?> _files = {};
  List<Map<String, dynamic>> _refusedDocs = [];
  bool _loadingDocs = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRefusedDocs();
    });
  }

  Future<void> _loadRefusedDocs() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final data = await userProvider.refreshVerificationStatus();
    if (!mounted) return;

    final docs = (data != null && data['documents'] is List)
        ? (data['documents'] as List)
              .whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .toList()
        : <Map<String, dynamic>>[];

    final refused = docs.where((d) {
      final s = d['statut']?.toString().toUpperCase() ?? '';
      return s == 'REFUSE';
    }).toList();

    setState(() {
      _refusedDocs = refused;
      _loadingDocs = false;
    });
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
        title: Text(
          'validate_doc_title'.tr(),
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            tooltip: 'Déconnexion',
            onPressed: () async {
              await context.read<UserProvider>().logout();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const Welcome()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: SizeConfig.blockSizeHorizontal * 6,
            vertical: SizeConfig.blockSizeVertical * 3,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: SizeConfig.blockSizeHorizontal * 32,
                height: SizeConfig.blockSizeHorizontal * 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    SizeConfig.blockSizeHorizontal * 4,
                  ),
                  border: Border.all(color: Colors.redAccent, width: 2),
                  color: Colors.redAccent.withOpacity(0.05),
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: SizeConfig.blockSizeHorizontal * 18,
                  color: Colors.redAccent,
                ),
              ),
              SizedBox(height: SizeConfig.blockSizeVertical * 3),
              Text(
                'validate_docs_unreadable'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: SizeConfig.fontSize(
                    SizeConfig.blockSizeHorizontal * 4,
                  ),
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: SizeConfig.blockSizeVertical * 1.5),
              Text(
                'validate_send_clearer'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: SizeConfig.fontSize(
                    SizeConfig.blockSizeHorizontal * 3.2,
                  ),
                  color: utilities.colorGreyDark,
                ),
              ),
              SizedBox(height: SizeConfig.blockSizeVertical * 4),
              if (_loadingDocs)
                Padding(
                  padding: EdgeInsets.only(
                    top: SizeConfig.blockSizeVertical * 2,
                  ),
                  child: SpinKitCircle(
                    color: utilities.colorBlueDark,
                    size: SizeConfig.blockSizeHorizontal * 8,
                  ),
                )
              else if (_refusedDocs.isEmpty)
                Padding(
                  padding: EdgeInsets.only(
                    top: SizeConfig.blockSizeVertical * 2,
                  ),
                  child: Text(
                    'validate_docs_in_progress'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: SizeConfig.fontSize(
                        SizeConfig.blockSizeHorizontal * 3.4,
                      ),
                      color: utilities.colorGreyDark,
                    ),
                  ),
                )
              else ...[
                for (final doc in _refusedDocs) ...[
                  _buildUploadSection(
                    context: context,
                    typeCode: (doc['typeCode'] ?? '').toString(),
                    title: _labelForDoc(doc),
                    hint: _hintForDoc(doc),
                    motifRefus: doc['motifRefus']?.toString(),
                    isPdf: _isPdfDoc(doc),
                    file: _files[(doc['typeCode'] ?? '').toString()],
                    onTap: () => _pickFileFor(
                      (doc['typeCode'] ?? '').toString(),
                      _isPdfDoc(doc),
                    ),
                  ),
                  SizedBox(height: SizeConfig.blockSizeVertical * 3),
                ],
              ],
              SizedBox(height: SizeConfig.blockSizeVertical * 5),
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
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'validate_resend'.tr(),
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
    required BuildContext context,
    required String typeCode,
    required String title,
    required String hint,
    String? motifRefus,
    required bool isPdf,
    required PlatformFile? file,
    required VoidCallback onTap,
  }) {
    final utilities = Utilities();
    final motifText = motifRefus?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.w600,
            fontSize: SizeConfig.fontSize(SizeConfig.blockSizeHorizontal * 3.4),
          ),
        ),
        if (motifText != null && motifText.isNotEmpty) ...[
          SizedBox(height: SizeConfig.blockSizeVertical * 1),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: SizeConfig.blockSizeHorizontal * 3,
              vertical: SizeConfig.blockSizeVertical * 1.4,
            ),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(
                SizeConfig.blockSizeHorizontal * 2,
              ),
              border: Border.all(color: Colors.redAccent.withOpacity(0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'validate_refusal_reason'.tr(),
                  style: TextStyle(
                    color: Colors.redAccent.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: SizeConfig.fontSize(
                      SizeConfig.blockSizeHorizontal * 3,
                    ),
                  ),
                ),
                SizedBox(height: SizeConfig.blockSizeVertical * 0.6),
                Text(
                  motifText,
                  style: TextStyle(
                    color: utilities.colorGreyDark,
                    height: 1.35,
                    fontSize: SizeConfig.fontSize(
                      SizeConfig.blockSizeHorizontal * 3.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        SizedBox(height: SizeConfig.blockSizeVertical * 1.2),
        InkWell(
          onTap: onTap,
          child: CustomPaint(
            painter: _DashedBorderPainter(
              color: Colors.redAccent,
              strokeWidth: 1.5,
              dashWidth: 6,
              dashSpace: 4,
            ),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                vertical: SizeConfig.blockSizeVertical * 2.4,
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
                        color: Colors.redAccent,
                      ),
                      SizedBox(width: SizeConfig.blockSizeHorizontal * 2.5),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hint,
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w600,
                              fontSize: SizeConfig.fontSize(
                                SizeConfig.blockSizeHorizontal * 3.2,
                              ),
                            ),
                          ),
                          if (file != null) ...[
                            SizedBox(
                              height: SizeConfig.blockSizeVertical * 0.6,
                            ),
                            SizedBox(
                              width: SizeConfig.blockSizeHorizontal * 40,
                              child: Text(
                                file.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: utilities.colorGreyDark,
                                  fontSize: SizeConfig.fontSize(
                                    SizeConfig.blockSizeHorizontal * 2.8,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  Text(
                    'validate_file'.tr(),
                    style: TextStyle(
                      color: Colors.redAccent,
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

  Future<void> _pickFileFor(String typeCode, bool isPdf) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (!mounted || result == null || result.files.isEmpty) return;
    setState(() {
      _files[typeCode] = result.files.first;
    });
  }

  Future<void> _onSubmit() async {
    if (_refusedDocs.isEmpty) {
      Utilities().showMesage(
        context,
        'error',
        'validate_no_doc_to_resend'.tr(),
      );
      return;
    }

    // Vérifier que chaque document refusé a bien un nouveau fichier sélectionné.
    for (final doc in _refusedDocs) {
      final typeCode = (doc['typeCode'] ?? '').toString();
      final file = _files[typeCode];
      if (file == null) {
        Utilities().showMesage(
          context,
          'error',
          'validate_select_file_for'.tr(
            namedArgs: {'label': _labelForDoc(doc)},
          ),
        );
        return;
      }
    }

    if (_files.isEmpty) {
      Utilities().showMesage(
        context,
        'error',
        'validate_select_at_least_one'.tr(),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final documents = <Map<String, String>>[];

      for (final doc in _refusedDocs) {
        final typeCode = (doc['typeCode'] ?? '').toString();
        final file = _files[typeCode];
        if (file == null) continue;

        final up = await Authcontroller.instance.uploadDocument(
          path: file.path,
          bytes: file.bytes?.isNotEmpty == true ? file.bytes : null,
          name: safePickFileName(file),
        );
        if (up.url == null || up.url!.isEmpty) {
          Utilities().showMesage(
            context,
            'error',
            up.error ??
                'validate_upload_failed'.tr(
                  namedArgs: {'label': _labelForDoc(doc)},
                ),
          );
          return;
        }
        documents.add({
          'typeCode': typeCode,
          'fichierUrl': up.url!,
          'nomFichier': file.name,
        });
      }

      final res1 = await PrestatairesController.instance.updateMyDocuments(
        token: userProvider.token ?? '',
        documents: documents,
      );
      var res = res1;

      // Si le token a expiré, on tente un refresh puis on rejoue la requête.
      if (res.status == 401) {
        await userProvider.refreshToken();
        res = await PrestatairesController.instance.updateMyDocuments(
          token: userProvider.token ?? '',
          documents: documents,
        );
      }

      if (!mounted) return;

      if (res.success == true) {
        Utilities().showMesage(context, 'success', 'validate_docs_sent'.tr());
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => const PrestataireValidateProfil(),
          ),
        );
      } else {
        final msg = (res.message?.toString().trim().isNotEmpty ?? false)
            ? res.message
            : 'validate_send_failed'.tr();
        Utilities().showMesage(
          context,
          'error',
          msg ?? 'validate_send_failed_short'.tr(),
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

  String _labelForDoc(Map<String, dynamic> doc) {
    final code = (doc['typeCode'] ?? '').toString().toLowerCase();
    final libelle = doc['typeLibelle']?.toString();
    if (code.contains('cni') || code.contains('passport')) {
      return 'validate_doc_cni'.tr();
    }
    if (code.contains('casier') || code.contains('certificat')) {
      return 'validate_doc_casier'.tr();
    }
    return libelle?.isNotEmpty == true ? libelle! : 'validate_doc_default'.tr();
  }

  String _hintForDoc(Map<String, dynamic> doc) {
    return 'validate_upload_hint'.tr();
  }

  bool _isPdfDoc(Map<String, dynamic> doc) {
    final code = (doc['typeCode'] ?? '').toString().toLowerCase();
    return code.contains('casier') ||
        code.contains('certificat') ||
        code.contains('pdf');
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

    final topLeft = Offset(0, 0);
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
