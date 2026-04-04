import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:milleservices/controllers/authController.dart';
import 'package:milleservices/controllers/prestationsController.dart';
import 'package:milleservices/models/prestation.dart';
import 'package:milleservices/models/prestataire.dart';
import 'package:milleservices/providers/userProvider.dart';
import 'package:milleservices/screens/deroulement_prestation.dart';
import 'package:milleservices/services/image_helper.dart';
import 'package:milleservices/services/sizeConfig.dart';
import 'package:milleservices/services/utilities.dart';
import 'package:milleservices/widgets/customButton.dart';
import 'package:provider/provider.dart';

/// Écran intermédiaire : le particulier remplit la description de la prestation
/// puis confirme pour créer la prestation et aller au déroulement.
class ConfirmPrestation extends StatefulWidget {
  final Prestataire prestataire;
  final String prestataireServiceId;
  final String serviceLibelle;
  final String? adresseParticulier;

  const ConfirmPrestation({
    super.key,
    required this.prestataire,
    required this.prestataireServiceId,
    required this.serviceLibelle,
    this.adresseParticulier,
  });

  @override
  State<ConfirmPrestation> createState() => _ConfirmPrestationState();
}

class _ConfirmPrestationState extends State<ConfirmPrestation> {
  final _formKey = GlobalKey<FormState>();
  final _typeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _budgetController = TextEditingController();
  final _adresseController = TextEditingController();

  static final _prestationsController = PrestationsController.instance;
  final ImagePicker _imagePicker = ImagePicker();
  bool _isSubmitting = false;
  bool _uploadingDemandeImage = false;
  /// URL Cloudinary après upload — facultatif, uniquement pour illustrer la demande du particulier.
  String? _demandeImageUrl;

  @override
  void initState() {
    super.initState();
    _typeController.text = widget.serviceLibelle;
    final adresse = widget.adresseParticulier?.toString().trim();
    if (adresse != null && adresse.isNotEmpty) {
      _adresseController.text = adresse;
    }
  }

  @override
  void dispose() {
    _typeController.dispose();
    _descriptionController.dispose();
    _budgetController.dispose();
    _adresseController.dispose();
    super.dispose();
  }

  double? _parseBudget(String value) {
    if (value.trim().isEmpty) return null;
    final cleaned = value
        .replaceAll(RegExp(r'[\s\u00A0]'), '')
        .replaceAll(',', '.');
    return double.tryParse(cleaned);
  }

  Future<void> _onConfirm() async {
    if (!_formKey.currentState!.validate()) return;

    final userProvider = context.read<UserProvider>();
    final token = userProvider.token;
    if (token == null || token.isEmpty) {
      if (mounted) {
        Utilities().showMesage(
          context,
          'error',
          'confirm_need_login'.tr(),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);

    var result = await _prestationsController.createPrestation(
      token: token,
      prestataireId: widget.prestataire.id,
      prestataireServiceId: widget.prestataireServiceId,
      typeDeTache: _typeController.text.trim().isEmpty
          ? null
          : _typeController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      imageUrl: _demandeImageUrl,
      budget: _parseBudget(_budgetController.text),
      adresse: _adresseController.text.trim().isEmpty
          ? null
          : _adresseController.text.trim(),
    );

    if (result.status == 401 && mounted) {
      await userProvider.refreshToken();
      final newToken = userProvider.token;
      if (newToken != null && mounted) {
        result = await _prestationsController.createPrestation(
          token: newToken,
          prestataireId: widget.prestataire.id,
          prestataireServiceId: widget.prestataireServiceId,
          typeDeTache: _typeController.text.trim().isEmpty
              ? null
              : _typeController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          imageUrl: _demandeImageUrl,
          budget: _parseBudget(_budgetController.text),
          adresse: _adresseController.text.trim().isEmpty
              ? null
              : _adresseController.text.trim(),
        );
      }
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (!result.success) {
      Utilities().showMesage(
        context,
        'error',
        result.message?.isNotEmpty == true
            ? result.message!
            : 'confirm_create_failed'.tr(),
      );
      return;
    }

    final data = result.data;
    if (data is! Map<String, dynamic>) {
      Utilities().showMesage(context, 'error', 'confirm_invalid_response'.tr());
      return;
    }

    final prestation = Prestation.fromJson(data);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (context) => DeroulementPrestation(prestation: prestation),
      ),
    );
  }

  String _filenameFromXFile(XFile file) {
    final name = file.name.trim();
    if (name.isNotEmpty) return name;
    final path = file.path.replaceAll('\\', '/');
    final i = path.lastIndexOf('/');
    return i >= 0 && i < path.length - 1 ? path.substring(i + 1) : 'demande.jpg';
  }

  Future<void> _pickDemandeImage() async {
    final picked = await ImageHelper.pickImageWithChoice(context, _imagePicker);
    if (picked == null || !mounted) return;

    setState(() => _uploadingDemandeImage = true);
    final up = await Authcontroller.instance.uploadDocument(
      path: picked.path,
      name: _filenameFromXFile(picked),
    );
    if (!mounted) return;
    setState(() => _uploadingDemandeImage = false);

    if (up.url != null && up.url!.isNotEmpty) {
      setState(() => _demandeImageUrl = up.url);
    } else {
      Utilities().showMesage(
        context,
        'error',
        up.error ?? 'confirm_image_upload_error'.tr(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          color: Colors.black,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'confirm_title'.tr(),
          style: TextStyle(
            color: Colors.black,
            fontSize: SizeConfig.fontSize(SizeConfig.blockSizeHorizontal * 4),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: SizeConfig.blockSizeHorizontal * 5,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: SizeConfig.blockSizeVertical * 2),
              _label('confirm_type_label'.tr()),
              SizedBox(height: SizeConfig.blockSizeVertical * 0.5),
              TextFormField(
                controller: _typeController,
                decoration: _inputDecoration(hint: 'confirm_type_hint'.tr()),
                textInputAction: TextInputAction.next,
              ),
              SizedBox(height: SizeConfig.blockSizeVertical * 2),
              _label('confirm_description_label'.tr()),
              SizedBox(height: SizeConfig.blockSizeVertical * 0.5),
              TextFormField(
                controller: _descriptionController,
                decoration: _inputDecoration(hint: 'confirm_description_hint'.tr()),
                maxLines: 4,
                textInputAction: TextInputAction.next,
              ),
              SizedBox(height: SizeConfig.blockSizeVertical * 2),
              _label('confirm_image_label'.tr()),
              SizedBox(height: SizeConfig.blockSizeVertical * 0.4),
              Text(
                'confirm_image_hint'.tr(),
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: SizeConfig.fontSize(
                    SizeConfig.blockSizeHorizontal * 2.8,
                  ),
                  height: 1.35,
                ),
              ),
              SizedBox(height: SizeConfig.blockSizeVertical * 1),
              if (_demandeImageUrl != null && _demandeImageUrl!.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(
                        SizeConfig.blockSizeHorizontal * 3,
                      ),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          _demandeImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: Colors.grey.shade600,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _uploadingDemandeImage
                          ? null
                          : () => setState(() => _demandeImageUrl = null),
                      icon: const Icon(Icons.delete_outline, size: 20),
                      label: Text('confirm_image_remove'.tr()),
                    ),
                  ],
                )
              else
                GestureDetector(
                  onTap: _uploadingDemandeImage ? null : _pickDemandeImage,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      vertical: SizeConfig.blockSizeVertical * 3,
                      horizontal: SizeConfig.blockSizeHorizontal * 4,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.grey.shade400,
                        style: BorderStyle.solid,
                      ),
                      borderRadius: BorderRadius.circular(
                        SizeConfig.blockSizeHorizontal * 3,
                      ),
                    ),
                    child: _uploadingDemandeImage
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Utilities().colorBlueDark,
                                ),
                              ),
                              SizedBox(width: SizeConfig.blockSizeHorizontal * 3),
                              Text(
                                'confirm_image_uploading'.tr(),
                                style: TextStyle(
                                  color: Utilities().colorBlueDark,
                                  fontSize: SizeConfig.fontSize(
                                    SizeConfig.blockSizeHorizontal * 3.2,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                color: Utilities().colorBlueDark,
                                size: 24,
                              ),
                              SizedBox(width: SizeConfig.blockSizeHorizontal * 2),
                              Text(
                                'confirm_image_button'.tr(),
                                style: TextStyle(
                                  color: Utilities().colorBlueDark,
                                  fontSize: SizeConfig.fontSize(
                                    SizeConfig.blockSizeHorizontal * 3.2,
                                  ),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              SizedBox(height: SizeConfig.blockSizeVertical * 2),
              _label('confirm_budget_label'.tr()),
              SizedBox(height: SizeConfig.blockSizeVertical * 0.5),
              TextFormField(
                controller: _budgetController,
                decoration: _inputDecoration(hint: 'confirm_budget_hint'.tr()),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
              ),
              SizedBox(height: SizeConfig.blockSizeVertical * 2),
              _label('confirm_address_label'.tr()),
              SizedBox(height: SizeConfig.blockSizeVertical * 0.5),
              TextFormField(
                controller: _adresseController,
                decoration: _inputDecoration(hint: 'confirm_address_hint'.tr()),
                textInputAction: TextInputAction.done,
              ),
              SizedBox(height: SizeConfig.blockSizeVertical * 4),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: SizeConfig.blockSizeHorizontal * 5,
                ),
                child: CustomButton(
                  title: Center(
                    child: _isSubmitting
                        ? SizedBox(
                            width: SizeConfig.blockSizeHorizontal * 5,
                            height: SizeConfig.blockSizeHorizontal * 5,
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'confirm_button'.tr(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: SizeConfig.fontSize(
                                SizeConfig.blockSizeHorizontal * 3.5,
                              ),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  color: Utilities().colorBlueDark,
                  borderColor: Utilities().colorBlueDark,
                  borderRadius: SizeConfig.blockSizeHorizontal * 10,
                  width: SizeConfig.blockSizeHorizontal * 80,
                  height: SizeConfig.blockSizeVertical * 6,
                  onTap: _isSubmitting ? null : _onConfirm,
                ),
              ),
              SizedBox(height: SizeConfig.blockSizeVertical * 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.black87,
        fontSize: SizeConfig.fontSize(SizeConfig.blockSizeHorizontal * 3.2),
        fontWeight: FontWeight.w500,
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: Colors.grey.shade500,
        fontSize: SizeConfig.fontSize(SizeConfig.blockSizeHorizontal * 3),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SizeConfig.blockSizeHorizontal * 3),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SizeConfig.blockSizeHorizontal * 3),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SizeConfig.blockSizeHorizontal * 3),
        borderSide: BorderSide(color: Utilities().colorBlueDark, width: 1.5),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: SizeConfig.blockSizeHorizontal * 4,
        vertical: SizeConfig.blockSizeVertical * 1.5,
      ),
    );
  }
}
