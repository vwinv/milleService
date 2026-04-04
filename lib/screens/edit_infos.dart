import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:milleservices/controllers/authController.dart';
import 'package:milleservices/models/response.dart';
import 'package:milleservices/providers/userProvider.dart';
import 'package:milleservices/providers/prestatairesProvider.dart';
import 'package:milleservices/screens/welcome.dart';
import 'package:milleservices/services/image_helper.dart';
import 'package:milleservices/services/sizeConfig.dart';
import 'package:milleservices/services/utilities.dart';
import 'package:milleservices/widgets/customTextField.dart';
import 'package:milleservices/widgets/address_autocomplete_field.dart';
import 'package:provider/provider.dart';

class EditInfos extends StatefulWidget {
  const EditInfos({super.key});

  @override
  State<EditInfos> createState() => _EditInfosState();
}

class _EditInfosState extends State<EditInfos> {
  final ImagePicker _picker = ImagePicker();
  final Authcontroller _authController = Authcontroller();

  bool _isUploadingAvatar = false;
  bool _isSavingInfos = false;

  bool _openEntreprise = false;
  bool _openCni = false;
  bool _openCasier = false;
  bool _openTelephone = false;
  bool _openAdresse = false;
  bool _openServices = false;

  late TextEditingController nameController;
  late TextEditingController prenomController;
  late TextEditingController _bioController;
  late TextEditingController _cniController;
  late TextEditingController _casierController;
  late TextEditingController _telephoneController;
  late TextEditingController _adresseController;

  // Services sélectionnés (prestataire)
  final Set<String> _selectedServiceIds = {};

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController();
    prenomController = TextEditingController();
    _bioController = TextEditingController();
    _cniController = TextEditingController();
    _casierController = TextEditingController();
    _telephoneController = TextEditingController();
    _adresseController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = context.read<UserProvider>().user;
      if (user != null) {
        nameController.text = (user.nom ?? '').toString();
        prenomController.text = (user.prenom ?? '').toString();
        _bioController.text = (user.bio ?? '').toString();
        _telephoneController.text = (user.telephone ?? '').toString();
        _adresseController.text = (user.adresse ?? '').toString();
      }
      if ((user?.role ?? '') == 'PRESTATAIRE') {
        await _fetchServicesAndPrecheckPrestataireServices();
      }
    });
  }

  /// Charge la liste des services et pré-coche ceux déjà enregistrés pour le prestataire.
  Future<void> _fetchServicesAndPrecheckPrestataireServices() async {
    final prestatairesProvider = context.read<PrestatairesProvider>();
    final userProvider = context.read<UserProvider>();
    await prestatairesProvider.loadServicesIfNeeded();
    await prestatairesProvider.loadMyServiceIds(userProvider);
    if (!mounted) return;
    setState(() {
      _selectedServiceIds.clear();
      _selectedServiceIds.addAll(prestatairesProvider.myServiceIds);
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    prenomController.dispose();
    _bioController.dispose();
    _cniController.dispose();
    _casierController.dispose();
    _telephoneController.dispose();
    _adresseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    final userProvider = context.watch<UserProvider>();
    final prestatairesProvider = context.watch<PrestatairesProvider>();
    final user = userProvider.user;
    final avatarUrl = userProvider.avatarUrlForDisplay;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Text(
          'Compte',
          textAlign: TextAlign.left,
          style: TextStyle(
            color: Colors.black,
            fontSize: SizeConfig.fontSize(SizeConfig.blockSizeHorizontal * 4.2),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: SizeConfig.blockSizeHorizontal * 6,
          vertical: SizeConfig.blockSizeVertical * 2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: SizeConfig.blockSizeVertical * 2),
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Builder(
                    builder: (context) {
                      final r = SizeConfig.blockSizeHorizontal * 11;
                      final d = r * 2;
                      final hasPhoto = avatarUrl != null &&
                          avatarUrl.toString().trim().isNotEmpty;
                      return SizedBox(
                        width: d,
                        height: d,
                        child: ClipOval(
                          clipBehavior: Clip.antiAlias,
                          child: hasPhoto
                              ? Image.network(
                                  avatarUrl.toString(),
                                  width: d,
                                  height: d,
                                  fit: BoxFit.cover,
                                  alignment: Alignment.center,
                                  errorBuilder: (_, __, ___) =>
                                      ColoredBox(
                                    color: Utilities().colorGreyLight,
                                    child: Icon(
                                      Icons.person,
                                      size: SizeConfig.blockSizeHorizontal * 14,
                                      color: Utilities().colorGreyDark,
                                    ),
                                  ),
                                )
                              : ColoredBox(
                                  color: Utilities().colorGreyLight,
                                  child: Icon(
                                    Icons.person,
                                    size: SizeConfig.blockSizeHorizontal * 14,
                                    color: Utilities().colorGreyDark,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: _isUploadingAvatar ? null : _changeProfilePhoto,
                      child: CircleAvatar(
                        radius: SizeConfig.blockSizeHorizontal * 3.5,
                        backgroundColor: Utilities().colorBlue,
                        child: _isUploadingAvatar
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.edit,
                                size: 16,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: SizeConfig.blockSizeVertical * 2),
            Center(
              child: Column(
                children: [
                  Text(
                    "${user?.prenom ?? ''} ${user?.nom ?? ''}",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: SizeConfig.fontSize(
                        SizeConfig.blockSizeHorizontal * 4.2,
                      ),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: SizeConfig.blockSizeVertical * 0.5),
                  if (user?.telephone != null)
                    Text(
                      user!.telephone.toString(),
                      style: TextStyle(
                        color: Utilities().colorGreyDark,
                        fontSize: SizeConfig.fontSize(
                          SizeConfig.blockSizeHorizontal * 3.2,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: SizeConfig.blockSizeVertical * 3),
            Text(
              "Vos Informations",
              style: TextStyle(
                color: Utilities().colorGreyDark,
                fontSize: SizeConfig.fontSize(
                  SizeConfig.blockSizeHorizontal * 4,
                ),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: SizeConfig.blockSizeVertical * 2),
            _buildAccordionItem(
              title: user?.nom ?? '',
              icon: Icons.badge_outlined,
              isOpen: _openEntreprise,
              onToggle: () {
                setState(() => _openEntreprise = !_openEntreprise);
              },
              children: [
                if ((user?.role ?? '') == 'PARTICULIER')
                  CustomTextField(
                    controller: prenomController,
                    borderColor: Utilities().colorGreyDark,
                    fillColor: Colors.white,
                    label: "Prénom",
                    labelStyle: TextStyle(
                      color: Colors.black,
                      fontSize: SizeConfig.blockSizeHorizontal * 3.2,
                      fontWeight: FontWeight.bold,
                    ),
                    placeholder: "Votre prénom",
                    textfieldStyle: TextStyle(color: Utilities().colorGreyDark),
                    placeholderStyle: TextStyle(
                      color: Utilities().colorGreyDark,
                      fontSize: SizeConfig.blockSizeHorizontal * 3,
                      fontWeight: FontWeight.normal,
                    ),
                    obscur: false,
                    height: SizeConfig.blockSizeVertical * 5,
                    width: SizeConfig.blockSizeHorizontal * 80,
                    validator: (value) => null,
                    prefixIcon: null,
                    radius: SizeConfig.blockSizeHorizontal * 10,
                  ),
                CustomTextField(
                  controller: nameController,
                  borderColor: Utilities().colorGreyDark,
                  fillColor: Colors.transparent,
                  label: (user?.role ?? '') == 'PARTICULIER'
                      ? "Nom"
                      : "Nom / Raison sociale",
                  labelStyle: TextStyle(
                    color: Colors.black,
                    fontSize: SizeConfig.blockSizeHorizontal * 3.2,
                    fontWeight: FontWeight.bold,
                  ),
                  placeholder: (user?.role ?? '') == 'PARTICULIER'
                      ? "Votre nom"
                      : "Nom de l’entreprise",
                  textfieldStyle: TextStyle(color: Utilities().colorGreyDark),
                  placeholderStyle: TextStyle(
                    color: Utilities().colorGreyDark,
                    fontSize: SizeConfig.blockSizeHorizontal * 3,
                    fontWeight: FontWeight.normal,
                  ),
                  obscur: false,
                  height: SizeConfig.blockSizeVertical * 5,
                  width: SizeConfig.blockSizeHorizontal * 80,
                  validator: (value) => null,
                  prefixIcon: null,
                  radius: SizeConfig.blockSizeHorizontal * 10,
                ),
                if ((user?.role ?? '') == 'PRESTATAIRE')
                  SizedBox(height: SizeConfig.blockSizeVertical * 1),
                if ((user?.role ?? '') == 'PRESTATAIRE')
                  CustomTextField(
                    controller: _bioController,
                    borderColor: Utilities().colorGreyDark,
                    fillColor: Colors.transparent,
                    label: "Bio",
                    labelStyle: TextStyle(
                      color: Colors.black,
                      fontSize: SizeConfig.blockSizeHorizontal * 3.2,
                      fontWeight: FontWeight.bold,
                    ),
                    placeholder: "Décrivez vos prestations et votre expérience",
                    textfieldStyle: TextStyle(color: Utilities().colorGreyDark),
                    placeholderStyle: TextStyle(
                      color: Utilities().colorGreyDark,
                      fontSize: SizeConfig.blockSizeHorizontal * 3,
                      fontWeight: FontWeight.normal,
                    ),
                    obscur: false,
                    height: SizeConfig.blockSizeVertical * 8,
                    width: SizeConfig.blockSizeHorizontal * 80,
                    validator: (value) => null,
                    prefixIcon: null,
                    radius: SizeConfig.blockSizeHorizontal * 5,
                  ),
              ],
            ),
            _buildAccordionItem(
              title: 'Téléphone',
              icon: Icons.phone_outlined,
              isOpen: _openTelephone,
              onToggle: () {
                setState(() => _openTelephone = !_openTelephone);
              },
              children: [
                CustomTextField(
                  controller: _telephoneController,
                  borderColor: Utilities().colorGreyDark,
                  fillColor: Colors.transparent,
                  label: "Téléphone",
                  labelStyle: TextStyle(
                    color: Colors.black,
                    fontSize: SizeConfig.blockSizeHorizontal * 3.2,
                    fontWeight: FontWeight.bold,
                  ),
                  placeholder: "Numéro de téléphone",
                  textfieldStyle: TextStyle(color: Utilities().colorGreyDark),
                  placeholderStyle: TextStyle(
                    color: Utilities().colorGreyDark,
                    fontSize: SizeConfig.blockSizeHorizontal * 3,
                    fontWeight: FontWeight.normal,
                  ),
                  obscur: false,
                  height: SizeConfig.blockSizeVertical * 5,
                  width: SizeConfig.blockSizeHorizontal * 80,
                  validator: (value) => null,
                  prefixIcon: null,
                  radius: SizeConfig.blockSizeHorizontal * 10,
                ),
              ],
            ),
            _buildAccordionItem(
              title: 'Adresse',
              icon: Icons.location_on_outlined,
              isOpen: _openAdresse,
              onToggle: () {
                setState(() => _openAdresse = !_openAdresse);
              },
              children: [
                AddressAutocompleteField(
                  controller: _adresseController,
                  borderColor: Utilities().colorGreyDark,
                  fillColor: Colors.transparent,
                  label: "Adresse",
                  labelStyle: TextStyle(
                    color: Colors.black,
                    fontSize: SizeConfig.blockSizeHorizontal * 3.2,
                    fontWeight: FontWeight.bold,
                  ),
                  placeholder: "Adresse de l’entreprise",
                  textfieldStyle: TextStyle(color: Utilities().colorGreyDark),
                  placeholderStyle: TextStyle(
                    color: Utilities().colorGreyDark,
                    fontSize: SizeConfig.blockSizeHorizontal * 3,
                    fontWeight: FontWeight.normal,
                  ),
                  height: SizeConfig.blockSizeVertical * 5,
                  width: SizeConfig.blockSizeHorizontal * 80,
                  validator: (value) => null,
                ),
              ],
            ),
            if ((user?.role ?? '') == 'PRESTATAIRE')
              _buildAccordionItem(
                title: 'Vos services',
                icon: Icons.build_outlined,
                isOpen: _openServices,
                onToggle: () {
                  setState(() => _openServices = !_openServices);
                  if (_openServices) {
                    _fetchServicesAndPrecheckPrestataireServices();
                  }
                },
                children: [
                  if (prestatairesProvider.servicesLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (prestatairesProvider.servicesError != null)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: SizeConfig.blockSizeHorizontal * 4,
                      ),
                      child: Text(
                        prestatairesProvider.servicesError!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    )
                  else
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: SizeConfig.blockSizeHorizontal * 4,
                      ),
                      child: Column(
                        children: prestatairesProvider.services.map((srv) {
                          final id = srv.id;
                          final libelle = srv.libelle;
                          if (id.isEmpty || libelle.isEmpty) {
                            return const SizedBox();
                          }
                          final selected = _selectedServiceIds.contains(id);
                          return CheckboxListTile(
                            value: selected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedServiceIds.add(id);
                                } else {
                                  _selectedServiceIds.remove(id);
                                }
                              });
                            },
                            dense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: SizeConfig.blockSizeHorizontal * 2,
                            ),
                            activeColor: Utilities().colorBlueDark,
                            title: Text(
                              libelle,
                              style: TextStyle(
                                fontSize: SizeConfig.blockSizeHorizontal * 3.2,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            SizedBox(height: SizeConfig.blockSizeVertical * 1.5),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSavingInfos ? null : _saveInfos,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    alignment: Alignment.centerRight,
                  ),
                  child: _isSavingInfos
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            ),
                            SizedBox(width: SizeConfig.blockSizeHorizontal * 2),
                            Text(
                              'Enregistrement...',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: SizeConfig.fontSize(
                                  SizeConfig.blockSizeHorizontal * 3.2,
                                ),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          'Enregistrer mes infos',
                          style: TextStyle(
                            color: Colors.black,
                            decoration: TextDecoration.underline,
                            fontSize: SizeConfig.fontSize(
                              SizeConfig.blockSizeHorizontal * 3.2,
                            ),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
              ],
            ),
            SizedBox(height: SizeConfig.blockSizeVertical * 3),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      SizeConfig.blockSizeHorizontal * 8,
                    ),
                  ),
                  padding: EdgeInsets.symmetric(
                    vertical: SizeConfig.blockSizeVertical * 1.6,
                  ),
                ),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) {
                      return AlertDialog(
                        title: const Text('Supprimer mon compte'),
                        content: Text(
                          'Êtes-vous sûr de vouloir désactiver votre compte ? '
                          'Pour une éventuelle réactivation, vous devrez contacter notre équipe au ${Utilities().telephoneEquipe}.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Annuler'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text(
                              'Confirmer',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                  if (confirm != true) return;

                  final res = await userProvider.deleteAccount();
                  if (!mounted) return;
                  if (res.success == true) {
                    Utilities().showMesage(
                      context,
                      'success',
                      "Votre compte a été désactivé. Pour une réactivation, contactez notre équipe au ${Utilities().telephoneEquipe}.",
                    );
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const Welcome()),
                      (route) => false,
                    );
                  } else {
                    Utilities().showMesage(
                      context,
                      'error',
                      res.message ??
                          "Échec de la désactivation du compte. Veuillez réessayer.",
                    );
                  }
                },
                child: Text(
                  'Supprimer mon compte',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: SizeConfig.fontSize(
                      SizeConfig.blockSizeHorizontal * 3.4,
                    ),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveInfos() async {
    final userProvider = context.read<UserProvider>();
    final user = userProvider.user;
    if (user == null) return;

    late final ResponseData res;
    setState(() => _isSavingInfos = true);
    try {
      if ((user.role ?? '') == 'PRESTATAIRE') {
        res = await userProvider.updatePrestataireInfos(
          nomEntreprise: nameController.text.trim().isEmpty
              ? null
              : nameController.text.trim(),
          telephone: _telephoneController.text.trim().isEmpty
              ? null
              : _telephoneController.text.trim(),
          adresse: _adresseController.text.trim().isEmpty
              ? null
              : _adresseController.text.trim(),
          bio: _bioController.text.trim().isEmpty
              ? null
              : _bioController.text.trim(),
          serviceIds: _selectedServiceIds.isEmpty
              ? null
              : _selectedServiceIds.toList(),
        );
      } else {
        res = await userProvider.updateParticulierInfos(
          nom: nameController.text.trim().isEmpty
              ? null
              : nameController.text.trim(),
          prenom: prenomController.text.trim().isEmpty
              ? null
              : prenomController.text.trim(),
          telephone: _telephoneController.text.trim().isEmpty
              ? null
              : _telephoneController.text.trim(),
          adresse: _adresseController.text.trim().isEmpty
              ? null
              : _adresseController.text.trim(),
        );
      }
      if (!mounted) return;
      if (res.success == true) {
        Utilities().showMesage(
          context,
          'success',
          'Informations mises à jour.',
        );
      } else {
        Utilities().showMesage(
          context,
          'error',
          res.message ?? "Échec de la mise à jour des informations.",
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingInfos = false);
      }
    }
  }

  Widget _buildAccordionItem({
    required String title,
    required IconData icon,
    required bool isOpen,
    required VoidCallback onToggle,
    required List<Widget> children,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: SizeConfig.blockSizeVertical * 1.2),
      decoration: BoxDecoration(
        color: Utilities().colorGreyLightDark,
        borderRadius: BorderRadius.circular(SizeConfig.blockSizeHorizontal * 5),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(
              SizeConfig.blockSizeHorizontal * 5,
            ),
            onTap: onToggle,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: SizeConfig.blockSizeHorizontal * 4,
                vertical: SizeConfig.blockSizeVertical * 1.6,
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: Colors.black,
                    size: SizeConfig.blockSizeHorizontal * 5,
                  ),
                  SizedBox(width: SizeConfig.blockSizeHorizontal * 3),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: SizeConfig.fontSize(
                          SizeConfig.blockSizeHorizontal * 3.4,
                        ),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    isOpen
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.black,
                    size: SizeConfig.blockSizeHorizontal * 4,
                  ),
                ],
              ),
            ),
          ),
          if (isOpen) const Divider(height: 1),
          if (isOpen)
            Column(
              children: [
                ...children,
                SizedBox(height: SizeConfig.blockSizeVertical * 1.2),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _changeProfilePhoto() async {
    final userProvider = context.read<UserProvider>();
    final token = userProvider.token;
    if (token == null) return;
    try {
      final XFile? picked = await ImageHelper.pickImageWithChoice(
        context,
        _picker,
      );
      if (picked == null || !mounted) return;
      setState(() => _isUploadingAvatar = true);
      var res = await _authController.uploadPhoto(picked.path, token);
      if (res.status == 401) {
        await userProvider.refreshToken();
        if (userProvider.token != null && mounted) {
          res = await _authController.uploadPhoto(
            picked.path,
            userProvider.token,
          );
        }
      }
      if (!mounted) return;
      setState(() => _isUploadingAvatar = false);
      if (res.success == true && res.data != null) {
        String? url;
        if (res.data is String) {
          url = res.data as String?;
        } else if (res.data is Map && (res.data as Map).containsKey('url')) {
          url = (res.data as Map)['url'] as String?;
        }
        if (url != null && url.isNotEmpty) {
          final saved = await userProvider.updateAvatarUrl(url);
          if (!mounted) return;
          if (saved) {
            Utilities().showMesage(
              context,
              'success',
              'Photo de profil mise à jour.',
            );
          } else {
            Utilities().showMesage(
              context,
              'error',
              'Impossible d’enregistrer la photo sur le serveur.',
            );
          }
        } else {
          Utilities().showMesage(context, 'error', 'Réponse serveur invalide.');
        }
      } else {
        Utilities().showMesage(
          context,
          'error',
          res.message ?? 'Échec de l\'upload.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        Utilities().showMesage(
          context,
          'error',
          'Impossible de changer la photo.',
        );
      }
    }
  }
}
