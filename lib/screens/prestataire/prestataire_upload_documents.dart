import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:milleservices/controllers/authController.dart';
import 'package:milleservices/controllers/prestatairesController.dart';
import 'package:milleservices/providers/userProvider.dart';
import 'package:milleservices/screens/prestataire/prestataire_validate_profil.dart';
import 'package:milleservices/services/pick_file_name.dart';
import 'package:milleservices/services/sizeConfig.dart';
import 'package:milleservices/services/utilities.dart';
import 'package:provider/provider.dart';

class PrestataireUploadDocuments extends StatefulWidget {
  const PrestataireUploadDocuments({super.key});

  @override
  State<PrestataireUploadDocuments> createState() =>
      _PrestataireUploadDocumentsState();
}

class _PrestataireUploadDocumentsState extends State<PrestataireUploadDocuments> {
  final Map<String, PlatformFile?> _files = {};
  bool _isSubmitting = false;

  static const _requiredDocs = <Map<String, String>>[
    {'typeCode': 'cni_recto', 'label': 'CNI / Passeport (recto)'},
    {'typeCode': 'cni_verso', 'label': 'CNI / Passeport (verso)'},
    {'typeCode': 'casier_judiciaire', 'label': 'Casier judiciaire'},
    {
      'typeCode': 'certificat_bonne_moeurs',
      'label': 'Certificat de bonne mœurs',
    },
  ];

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
          'Uploader vos documents',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
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
              Text(
                'Pour activer votre compte prestataire, merci de déposer tous les documents requis.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: SizeConfig.fontSize(SizeConfig.blockSizeHorizontal * 3.5),
                  color: utilities.colorGreyDark,
                ),
              ),
              SizedBox(height: SizeConfig.blockSizeVertical * 3),
              for (final doc in _requiredDocs) ...[
                _buildUploadSection(
                  typeCode: doc['typeCode']!,
                  title: doc['label']!,
                  file: _files[doc['typeCode']!],
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
    required PlatformFile? file,
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
              color: utilities.colorBlueDark,
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
                          file?.name ?? 'Choisir un fichier (PDF/JPG/PNG)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: file == null
                                ? utilities.colorGreyDark
                                : Colors.black87,
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
    for (final doc in _requiredDocs) {
      if (_files[doc['typeCode']!] == null) {
        Utilities().showMesage(
          context,
          'error',
          'Merci de sélectionner tous les documents requis.',
        );
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final documents = <Map<String, String>>[];

      for (final doc in _requiredDocs) {
        final file = _files[doc['typeCode']!]!;
        final up = await Authcontroller.instance.uploadDocument(
          path: file.path,
          bytes: file.bytes?.isNotEmpty == true ? file.bytes : null,
          name: safePickFileName(file),
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
          'typeCode': doc['typeCode']!,
          'fichierUrl': up.url!,
          'nomFichier': file.name,
        });
      }

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
        Utilities().showMesage(
          context,
          'success',
          'Documents envoyés. Vérification en cours.',
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => const PrestataireValidateProfil(),
          ),
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
