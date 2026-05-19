import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:milleservices/controllers/authController.dart';
import 'package:milleservices/controllers/prestationsController.dart';
import 'package:milleservices/models/prestation.dart';
import 'package:milleservices/models/prestataire.dart';
import 'package:milleservices/providers/userProvider.dart';
import 'package:milleservices/navigation/app_navigation.dart';
import 'package:milleservices/router/route_extras.dart';
import 'package:milleservices/services/device_location_service.dart';
import 'package:milleservices/services/image_helper.dart';
import 'package:milleservices/services/sizeConfig.dart';
import 'package:milleservices/services/utilities.dart';
import 'package:milleservices/widgets/customButton.dart';
import 'package:provider/provider.dart';

/// Écran intermédiaire : le particulier remplit la description de la prestation
/// puis confirme pour créer la prestation et aller au déroulement.
class ConfirmPrestation extends StatefulWidget {
  final Prestataire prestataire;
  final String? prestataireServiceId;
  final String? serviceLibelle;
  final String? adresseParticulier;

  const ConfirmPrestation({
    super.key,
    required this.prestataire,
    this.prestataireServiceId,
    this.serviceLibelle,
    this.adresseParticulier,
  });

  @override
  State<ConfirmPrestation> createState() => _ConfirmPrestationState();
}

class _ConfirmPrestationState extends State<ConfirmPrestation> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _adresseController = TextEditingController();

  static final _prestationsController = PrestationsController.instance;
  final ImagePicker _imagePicker = ImagePicker();
  bool _isSubmitting = false;
  bool _uploadingDemandeImage = false;
  bool _locatingAddress = false;
  PrestataireServiceItem? _selectedService;
  /// URL Cloudinary après upload — facultatif, uniquement pour illustrer la demande du particulier.
  String? _demandeImageUrl;

  @override
  void initState() {
    super.initState();
    final preselectedId = widget.prestataireServiceId?.trim();
    final hasPreselected = preselectedId != null && preselectedId.isNotEmpty;
    if (hasPreselected) {
      for (final s in widget.prestataire.services) {
        if ((s.prestataireServiceId ?? '').trim() == preselectedId) {
          _selectedService = s;
          break;
        }
      }
    } else if (widget.prestataire.services.length == 1) {
      _selectedService = widget.prestataire.services.first;
    }

    final adresse = widget.adresseParticulier?.toString().trim();
    if (adresse != null && adresse.isNotEmpty) {
      _adresseController.text = adresse;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _adresseController.dispose();
    super.dispose();
  }

  Future<void> _onConfirm() async {
    if (!_formKey.currentState!.validate()) return;
    final resolvedServiceId = _resolvedPrestataireServiceId();
    if (resolvedServiceId == null || resolvedServiceId.isEmpty) {
      Utilities().showMesage(
        context,
        'error',
        'Veuillez choisir un service.',
      );
      return;
    }

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
      prestataireServiceId: resolvedServiceId,
      typeDeTache: _typeDeTacheForApi,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      imageUrl: _demandeImageUrl,
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
          prestataireServiceId: resolvedServiceId,
          typeDeTache: _typeDeTacheForApi,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          imageUrl: _demandeImageUrl,
          adresse: _adresseController.text.trim().isEmpty
              ? null
              : _adresseController.text.trim(),
        );
      }
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (!result.success) {
      final isDuplicate = result.status == 409;
      final msg = result.message?.trim();
      Utilities().showMesage(
        context,
        'error',
        msg != null && msg.isNotEmpty
            ? msg
            : isDuplicate
                ? 'confirm_duplicate_prestation'.tr()
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
    AppNavigation.goParticulierPrestation(context, prestation);
  }

  String? _resolvedPrestataireServiceId() {
    final selected = _selectedService?.prestataireServiceId?.trim();
    if (selected != null && selected.isNotEmpty) return selected;
    final fromWidget = widget.prestataireServiceId?.trim();
    if (fromWidget != null && fromWidget.isNotEmpty) return fromWidget;
    return null;
  }

  /// Libellé de la tâche envoyé à l’API (aligné sur le service catalogue choisi).
  String? get _typeDeTacheForApi {
    final lib = _selectedService?.libelle.trim();
    return (lib == null || lib.isEmpty) ? null : lib;
  }

  String _serviceLabel(PrestataireServiceItem s) {
    final tarif = s.tarifHoraire;
    if (tarif == null || tarif <= 0) return s.libelle;
    return '${s.libelle} - ${tarif.toStringAsFixed(0)} FCFA/h';
  }

  String _filenameFromXFile(XFile file) {
    final name = file.name.trim();
    if (name.isNotEmpty) return name;
    final path = file.path.replaceAll('\\', '/');
    final i = path.lastIndexOf('/');
    return i >= 0 && i < path.length - 1 ? path.substring(i + 1) : 'demande.jpg';
  }

  String _placemarkToAddressLine(Placemark p) {
    final parts = <String>[];
    void push(String? s) {
      final t = s?.trim() ?? '';
      if (t.isNotEmpty && !parts.contains(t)) parts.add(t);
    }

    final street = (p.street ?? '').trim();
    if (street.isEmpty) {
      push(p.name);
      push(p.thoroughfare);
    } else {
      push(p.street);
    }
    push(p.subLocality);
    push(p.locality);
    push(p.postalCode);
    push(p.administrativeArea);
    push(p.country);
    return parts.join(', ');
  }

  Future<void> _useCurrentLocationForAddress() async {
    if (_locatingAddress) return;
    setState(() => _locatingAddress = true);
    try {
      final latLng = await DeviceLocationService.getCurrentLatLngOrNull();
      if (!mounted) return;
      if (latLng == null) {
        Utilities().showMesage(
          context,
          'error',
          'confirm_address_location_denied'.tr(),
        );
        return;
      }
      List<Placemark> placemarks;
      try {
        placemarks =
            await placemarkFromCoordinates(latLng.latitude, latLng.longitude);
      } catch (_) {
        placemarks = [];
      }
      if (!mounted) return;
      if (placemarks.isEmpty) {
        Utilities().showMesage(
          context,
          'error',
          'confirm_address_reverse_failed'.tr(),
        );
        return;
      }
      final line = _placemarkToAddressLine(placemarks.first);
      if (line.isEmpty) {
        Utilities().showMesage(
          context,
          'error',
          'confirm_address_reverse_failed'.tr(),
        );
        return;
      }
      _adresseController.text = line;
    } finally {
      if (mounted) setState(() => _locatingAddress = false);
    }
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
          onPressed: () => AppNavigation.pop(context),
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
              if (widget.prestataire.services.isEmpty)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: SizeConfig.blockSizeVertical * 2,
                  ),
                  child: Text(
                    "Ce prestataire n'a aucun service proposé. Impossible de commander.",
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: SizeConfig.fontSize(
                        SizeConfig.blockSizeHorizontal * 3.2,
                      ),
                    ),
                  ),
                )
              else
                ButtonTheme(
                  alignedDropdown: true,
                  child: DropdownButtonFormField<PrestataireServiceItem>(
                    value: _selectedService,
                    isExpanded: true,
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(
                      SizeConfig.blockSizeHorizontal * 3,
                    ),
                    menuMaxHeight: SizeConfig.blockSizeVertical * 35,
                    decoration: _inputDecoration(
                      hint: 'confirm_type_hint'.tr(),
                    ),
                    items: widget.prestataire.services
                        .map(
                          (s) => DropdownMenuItem<PrestataireServiceItem>(
                            value: s,
                            child: SizedBox(
                              width: double.infinity,
                              child: Text(
                                _serviceLabel(s),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    validator: (value) {
                      if (widget.prestataire.services.isNotEmpty &&
                          value == null) {
                        return 'Veuillez choisir un type de tâche';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      setState(() => _selectedService = value);
                    },
                  ),
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
              _label('confirm_address_label'.tr()),
              SizedBox(height: SizeConfig.blockSizeVertical * 0.5),
              TextFormField(
                controller: _adresseController,
                decoration: _inputDecoration(hint: 'confirm_address_hint'.tr()),
                textInputAction: TextInputAction.done,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed:
                      _locatingAddress ? null : _useCurrentLocationForAddress,
                  icon: _locatingAddress
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Utilities().colorBlueDark,
                          ),
                        )
                      : Icon(
                          Icons.my_location,
                          size: 20,
                          color: Utilities().colorBlueDark,
                        ),
                  label: Text(
                    _locatingAddress
                        ? 'confirm_address_locating'.tr()
                        : 'confirm_address_use_current'.tr(),
                    style: TextStyle(
                      color: Utilities().colorBlueDark,
                      fontSize: SizeConfig.fontSize(
                        SizeConfig.blockSizeHorizontal * 3.2,
                      ),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
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
                  onTap: (_isSubmitting ||
                          widget.prestataire.services.isEmpty)
                      ? null
                      : _onConfirm,
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
        vertical: SizeConfig.blockSizeVertical * 1.5 < 14
            ? 14
            : SizeConfig.blockSizeVertical * 1.5,
      ),
      constraints: const BoxConstraints(minHeight: 48),
    );
  }
}
