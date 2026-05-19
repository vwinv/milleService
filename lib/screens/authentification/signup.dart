import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:milleservices/controllers/authController.dart';
import 'package:milleservices/controllers/geocodingController.dart';
import 'package:milleservices/providers/prestatairesProvider.dart';
import 'package:milleservices/models/user.dart';
import 'package:milleservices/providers/settings_provider.dart';
import 'package:milleservices/providers/userProvider.dart';
import 'package:milleservices/services/document_picker_helper.dart';
import 'package:milleservices/services/pick_file_name.dart';
import 'package:milleservices/navigation/app_navigation.dart';
import 'package:milleservices/services/sizeConfig.dart';
import 'package:milleservices/services/utilities.dart';
import 'package:milleservices/widgets/address_autocomplete_field.dart';
import 'package:milleservices/widgets/customButton.dart';
import 'package:milleservices/widgets/customTextField.dart';
import 'package:milleservices/widgets/auth_keyboard_aware_layout.dart';
import 'package:milleservices/widgets/dashed_upload_zone.dart';
import 'package:provider/provider.dart';

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> with TickerProviderStateMixin {
  TabController? tabController;
  final formParticulierKey = GlobalKey<FormState>();
  final formPrestataireKey = GlobalKey<FormState>();

  TextEditingController emailParticulierController = TextEditingController();
  TextEditingController passwordParticulierController = TextEditingController();
  TextEditingController passwordConfirmParticulierController =
      TextEditingController();
  TextEditingController firstnameParticulierController =
      TextEditingController();
  TextEditingController lastnameParticulierController = TextEditingController();
  TextEditingController telephoneParticulierController =
      TextEditingController();
  TextEditingController addressParticulierController = TextEditingController();
  bool obscurPasswordParticulier = true;
  bool obscurPasswordConfirmParticulier = true;

  TextEditingController emailPrestataireController = TextEditingController();
  TextEditingController passwordPrestataireController = TextEditingController();
  TextEditingController passwordConfirmPrestataireController =
      TextEditingController();
  TextEditingController fistnamePrestataireController = TextEditingController();
  TextEditingController lastnamePrestataireController = TextEditingController();
  TextEditingController telephonePrestataireController =
      TextEditingController();
  TextEditingController addressPrestataireController = TextEditingController();
  TextEditingController bioPrestataireController = TextEditingController();

  bool obscurPasswordConfirmPrestataire = true;
  bool obscurPasswordPrestataire = true;

  // Services sélectionnés pour les prestataires
  final Set<String> _selectedServiceIdsPrestataire = {};

  // Documents prestataire (nom affiché + fichier pour upload)
  String? cniRectoFileName;
  String? cniVersoFileName;
  String? certificatResidenceFileName;
  String? diplomeFileName;
  PlatformFile? cniRectoFile;
  PlatformFile? cniVersoFile;
  PlatformFile? certificatResidenceFile;
  PlatformFile? diplomeFile;

  bool _signUpInProgress = false;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 2, vsync: this);
    // Charger la liste des services prestataire une seule fois après le premier build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prestatairesProvider = Provider.of<PrestatairesProvider>(
        context,
        listen: false,
      );
      prestatairesProvider.loadServicesIfNeeded();
    });
  }

  @override
  void dispose() {
    // tabController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument(
    void Function(String name, PlatformFile file) onPicked,
  ) async {
    final file = await DocumentPickerHelper.pickDocument(context);
    if (file != null && mounted) {
      onPicked(file.name, file);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthKeyboardAwareLayout(
      tabController: tabController!,
      taglineForYou: 'signup_tagline_for_you'.tr(),
      taglineFromHome: 'signup_tagline_from_home'.tr(),
      welcomeTitle: 'signup_welcome_title'.tr(),
      tabParticulierLabel: 'signup_tab_particulier'.tr(),
      tabProfessionnelLabel: 'signup_tab_professionnel'.tr(),
      tabViews: [
        _buildForm('particulier'),
        _buildForm('prestataire'),
      ],
    );
  }

  Widget _buildForm(String type) {
    final userProvider = Provider.of<UserProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final prestatairesProvider = Provider.of<PrestatairesProvider>(context);

    Future<void> handleSignUp() async {
      if (_signUpInProgress) return;
      _signUpInProgress = true;
      userProvider.setLoading(true);
      try {
        print("handle sign  ");
        // final formKey = type == "particulier"
        //     ? formParticulierKey
        //     : formPrestataireKey;
        // TODO: réactiver la validation des formulaires si nécessaire.

        final address = type == "particulier"
            ? addressParticulierController.text.trim()
            : addressPrestataireController.text.trim();
        double? lat;
        double? lng;
        if (address.length >= 3) {
          final coords = await GeocodingController().geocode(address);
          if (coords != null) {
            lat = coords.lat;
            lng = coords.lng;
          }
        }

        final particulieData = {
          "nom": lastnameParticulierController.text.trim(),
          "prenom": firstnameParticulierController.text.trim(),
          "telephone": telephoneParticulierController.text.trim(),
          "adresse": addressParticulierController.text.trim(),
          if (lat != null) "latitude": lat,
          if (lng != null) "longitude": lng,
        };
        final prestataireData = {
          "nom": lastnamePrestataireController.text.trim(),
          "prenom": fistnamePrestataireController.text.trim(),
          "telephone": telephonePrestataireController.text.trim(),
          "adresse": addressPrestataireController.text.trim(),
          "bio": bioPrestataireController.text.trim(),
          "zoneIntervention": [],
          "statutVerification": "",
          if (lat != null) "latitude": lat,
          if (lng != null) "longitude": lng,
        };

        final user = User.fromJson({
          "email": type == "particulier"
              ? emailParticulierController.text.trim()
              : emailPrestataireController.text.trim(),
          "password": type == "particulier"
              ? passwordParticulierController.text
              : passwordPrestataireController.text,
          "particulier": particulieData,
          "prestataire": prestataireData,

          "role": type == "particulier" ? "PARTICULIER" : "PRESTATAIRE",
        });
        print(" user : ${user.toString()}");
        List<Map<String, String>>? documentsList;
        if (type == "prestataire") {
          if (_selectedServiceIdsPrestataire.isEmpty) {
            if (mounted) {
              Utilities().showMesage(
                context,
                'error',
                'Veuillez choisir au moins un service.',
              );
            }
            return;
          }
          final toUpload = <String, PlatformFile?>{
            'cni_recto': cniRectoFile,
            'cni_verso': cniVersoFile,
            'certificat_residence': certificatResidenceFile,
            'diplome': diplomeFile,
          };
          documentsList = [];
          for (final entry in toUpload.entries) {
            final file = entry.value;
            if (file == null) continue;
            final up = await Authcontroller.instance.uploadDocument(
              path: file.path,
              bytes: file.bytes?.isNotEmpty == true ? file.bytes : null,
              name: safePickFileName(file),
            );
            if (up.url == null || up.url!.isEmpty) {
              if (mounted) {
                Utilities().showMesage(
                  context,
                  'error',
                  up.error ?? 'Échec de l\'upload du document: ${file.name}',
                );
              }
              return;
            }
            documentsList.add({
              'typeCode': entry.key,
              'fichierUrl': up.url!,
              'nomFichier': file.name,
            });
          }
        }

        final res = await userProvider.signUp(
          user,
          type == "particulier"
              ? passwordParticulierController.text
              : passwordPrestataireController.text,
          documents: documentsList?.isEmpty == true ? null : documentsList,
          serviceIds: type == "prestataire"
              ? _selectedServiceIdsPrestataire.toList()
              : null,
          manageLoading: false,
        );
        print("res: ${res.toString()}");
        if (res.success == true) {
          if (mounted) {
            Utilities().showMesage(context, 'success', "signup_success".tr());
            // Navigation après inscription selon le type d'utilisateur

          AppNavigation.goHome(context);
          }
        } else {
          if (mounted) {
            final defaultMsg = "signup_failed".tr();
            final msg = (res.message?.toString().trim().isNotEmpty ?? false)
                ? (res.message ?? defaultMsg)
                : defaultMsg;
            print(msg);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                Utilities().showMesage(context, 'error', msg);
              }
            });
          }
        }
      } finally {
        _signUpInProgress = false;
        userProvider.setLoading(false);
      }
    }

    return SingleChildScrollView(
      padding: AuthKeyboardAwareLayout.formScrollPadding(context),
      child: Form(
        key: type == "particulier" ? formParticulierKey : formPrestataireKey,
        child: Column(
          children: [
            if (type == "particulier")
              CustomTextField(
                radius: SizeConfig.blockSizeHorizontal * 10,
                controller: firstnameParticulierController,
                borderColor: Utilities().colorGreyDark,
                fillColor: Colors.white,
                label: "signup_firstname_label".tr(),
                labelStyle: TextStyle(
                  color: Colors.black,
                  fontSize: SizeConfig.blockSizeHorizontal * 3.5,
                  fontWeight: FontWeight.bold,
                ),
                placeholder: "signup_firstname_placeholder".tr(),
                textfieldStyle: TextStyle(color: Utilities().colorGreyDark),
                placeholderStyle: TextStyle(
                  color: Utilities().colorGreyDark,
                  fontSize: SizeConfig.blockSizeHorizontal * 3,
                  fontWeight: FontWeight.normal,
                ),
                obscur: false,
                height: SizeConfig.blockSizeVertical * 5,
                width: SizeConfig.blockSizeHorizontal * 80,
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return "signup_firstname_required".tr();
                  }
                  return null;
                },
                prefixIcon: null,
              ),

            CustomTextField(
              controller: type == "particulier"
                  ? lastnameParticulierController
                  : lastnamePrestataireController,
              borderColor: Utilities().colorGreyDark,
              fillColor: Colors.white,
              label: "signup_lastname_label".tr(),
              labelStyle: TextStyle(
                color: Colors.black,
                fontSize: SizeConfig.blockSizeHorizontal * 3.5,
                fontWeight: FontWeight.bold,
              ),
              placeholder: "signup_lastname_placeholder".tr(),
              textfieldStyle: TextStyle(color: Utilities().colorGreyDark),
              placeholderStyle: TextStyle(
                color: Utilities().colorGreyDark,
                fontSize: SizeConfig.blockSizeHorizontal * 3,
                fontWeight: FontWeight.normal,
              ),
              obscur: false,
              height: SizeConfig.blockSizeVertical * 5,
              width: SizeConfig.blockSizeHorizontal * 80,
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return "signup_lastname_required".tr();
                }
                return null;
              },
              prefixIcon: null,
              radius: SizeConfig.blockSizeHorizontal * 10,
            ),
            CustomTextField(
              controller: type == "particulier"
                  ? emailParticulierController
                  : emailPrestataireController,
              borderColor: Utilities().colorGreyDark,
              fillColor: Colors.white,
              label: "signup_email_label".tr(),
              labelStyle: TextStyle(
                color: Colors.black,
                fontSize: SizeConfig.blockSizeHorizontal * 3.5,
                fontWeight: FontWeight.bold,
              ),
              placeholder: "signup_email_placeholder".tr(),
              textfieldStyle: TextStyle(color: Utilities().colorGreyDark),
              placeholderStyle: TextStyle(
                color: Utilities().colorGreyDark,
                fontSize: SizeConfig.blockSizeHorizontal * 3,
                fontWeight: FontWeight.normal,
              ),
              obscur: false,
              height: SizeConfig.blockSizeVertical * 5,
              width: SizeConfig.blockSizeHorizontal * 80,
              validator: (value) {
                final v = (value ?? '').trim();
                if (type == "particulier" && v.isEmpty) {
                  return "signup_email_required".tr();
                }
                if (v.isNotEmpty &&
                    !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v)) {
                  return "Email invalide";
                }
                return null;
              },
              prefixIcon: null,
              radius: SizeConfig.blockSizeHorizontal * 10,
            ),
            CustomTextField(
              controller: type == "particulier"
                  ? telephoneParticulierController
                  : telephonePrestataireController,
              borderColor: Utilities().colorGreyDark,
              fillColor: Colors.white,
              label: "signup_phone_label".tr(),
              labelStyle: TextStyle(
                color: Colors.black,
                fontSize: SizeConfig.blockSizeHorizontal * 3.5,
                fontWeight: FontWeight.bold,
              ),
              placeholder: "signup_phone_placeholder".tr(),
              textfieldStyle: TextStyle(color: Utilities().colorGreyDark),
              placeholderStyle: TextStyle(
                color: Utilities().colorGreyDark,
                fontSize: SizeConfig.blockSizeHorizontal * 3,
                fontWeight: FontWeight.normal,
              ),
              obscur: false,
              height: SizeConfig.blockSizeVertical * 5,
              width: SizeConfig.blockSizeHorizontal * 80,
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return "signup_phone_required".tr();
                }
                if (!RegExp(r'^[0-9]{10}$').hasMatch(value ?? '')) {
                  return "signup_phone_invalid".tr();
                }
                return null;
              },
              prefixIcon: null,
              radius: SizeConfig.blockSizeHorizontal * 10,
            ),

            CustomTextField(
              controller: type == "particulier"
                  ? passwordParticulierController
                  : passwordPrestataireController,
              borderColor: Utilities().colorGreyDark,
              fillColor: Colors.white,
              label: "signup_password_label".tr(),
              labelStyle: TextStyle(
                color: Colors.black,
                fontSize: SizeConfig.blockSizeHorizontal * 3.5,
                fontWeight: FontWeight.bold,
              ),
              placeholder: "signup_password_placeholder".tr(),
              textfieldStyle: TextStyle(color: Utilities().colorGreyDark),
              placeholderStyle: TextStyle(
                color: Utilities().colorGreyDark,
                fontSize: SizeConfig.blockSizeHorizontal * 3,
                fontWeight: FontWeight.normal,
              ),
              obscur: type == "particulier"
                  ? obscurPasswordParticulier
                  : obscurPasswordPrestataire,
              height: SizeConfig.blockSizeVertical * 5,
              width: SizeConfig.blockSizeHorizontal * 80,
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return "signup_password_required".tr();
                }
                return null;
              },
              prefixIcon: Padding(
                padding: EdgeInsetsGeometry.symmetric(
                  horizontal: SizeConfig.blockSizeHorizontal * 2,
                ),
                child: GestureDetector(
                  child: Icon(
                    (type == "particulier"
                            ? obscurPasswordParticulier
                            : obscurPasswordPrestataire)
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: Utilities().colorGreyDark,
                  ),
                  onTap: () {
                    setState(() {
                      if (type == "particulier") {
                        obscurPasswordParticulier = !obscurPasswordParticulier;
                      } else {
                        obscurPasswordPrestataire = !obscurPasswordPrestataire;
                      }
                    });
                  },
                ),
              ),
              radius: SizeConfig.blockSizeHorizontal * 10,
            ),
            CustomTextField(
              controller: type == "particulier"
                  ? passwordConfirmParticulierController
                  : passwordConfirmPrestataireController,
              borderColor: Utilities().colorGreyDark,
              fillColor: Colors.white,
              label: "signup_password_confirm_label".tr(),
              labelStyle: TextStyle(
                color: Colors.black,
                fontSize: SizeConfig.blockSizeHorizontal * 3.5,
                fontWeight: FontWeight.bold,
              ),
              placeholder: "signup_password_confirm_placeholder".tr(),
              textfieldStyle: TextStyle(color: Utilities().colorGreyDark),
              placeholderStyle: TextStyle(
                color: Utilities().colorGreyDark,
                fontSize: SizeConfig.blockSizeHorizontal * 3,
                fontWeight: FontWeight.normal,
              ),
              obscur: type == "particulier"
                  ? obscurPasswordConfirmParticulier
                  : obscurPasswordConfirmPrestataire,
              height: SizeConfig.blockSizeVertical * 5,
              width: SizeConfig.blockSizeHorizontal * 80,
              validator: (value) {
                final v = value?.trim() ?? '';
                if (v.isEmpty) {
                  return "signup_password_confirm_required".tr();
                }
                final pwd =
                    (type == "particulier"
                            ? passwordParticulierController
                            : passwordPrestataireController)
                        .text
                        .trim();
                if (v != pwd) {
                  return "signup_passwords_not_matching".tr();
                }
                return null;
              },
              prefixIcon: Padding(
                padding: EdgeInsetsGeometry.symmetric(
                  horizontal: SizeConfig.blockSizeHorizontal * 2,
                ),
                child: GestureDetector(
                  child: Icon(
                    (type == "particulier"
                            ? obscurPasswordConfirmParticulier
                            : obscurPasswordConfirmPrestataire)
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: Utilities().colorGreyDark,
                  ),
                  onTap: () {
                    setState(() {
                      if (type == "particulier") {
                        obscurPasswordConfirmParticulier =
                            !obscurPasswordConfirmParticulier;
                      } else {
                        obscurPasswordConfirmPrestataire =
                            !obscurPasswordConfirmPrestataire;
                      }
                    });
                  },
                ),
              ),
              radius: SizeConfig.blockSizeHorizontal * 10,
            ),
            AddressAutocompleteField(
              controller: type == "particulier"
                  ? addressParticulierController
                  : addressPrestataireController,
              borderColor: Utilities().colorGreyDark,
              fillColor: Colors.white,
              label: "signup_address_label".tr(),
              labelStyle: TextStyle(
                color: Colors.black,
                fontSize: SizeConfig.blockSizeHorizontal * 3.5,
                fontWeight: FontWeight.bold,
              ),
              placeholder: "signup_address_placeholder".tr(),
              textfieldStyle: TextStyle(color: Utilities().colorGreyDark),
              placeholderStyle: TextStyle(
                color: Utilities().colorGreyDark,
                fontSize: SizeConfig.blockSizeHorizontal * 3,
                fontWeight: FontWeight.normal,
              ),
              height: SizeConfig.blockSizeVertical * 5,
              width: SizeConfig.blockSizeHorizontal * 80,
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return "signup_address_required".tr();
                }
                return null;
              },
            ),
            if (type == "prestataire")
              CustomTextField(
                controller: bioPrestataireController,
                borderColor: Utilities().colorGreyDark,
                fillColor: Colors.white,
                label: "Bio (optionnelle)",
                labelStyle: TextStyle(
                  color: Colors.black,
                  fontSize: SizeConfig.blockSizeHorizontal * 3.5,
                  fontWeight: FontWeight.bold,
                ),
                placeholder: "Parlez brievement de vos services",
                textfieldStyle: TextStyle(color: Utilities().colorGreyDark),
                placeholderStyle: TextStyle(
                  color: Utilities().colorGreyDark,
                  fontSize: SizeConfig.blockSizeHorizontal * 3,
                  fontWeight: FontWeight.normal,
                ),
                obscur: false,
                height: SizeConfig.blockSizeVertical * 10,
                width: SizeConfig.blockSizeHorizontal * 80,
                validator: (_) => null,
                prefixIcon: null,
                radius: SizeConfig.blockSizeHorizontal * 5,
                maxLines: 10,
              ),
            if (type == "prestataire") ...[
              SizedBox(height: SizeConfig.blockSizeVertical * 1.5),
              Padding(
                padding: EdgeInsets.only(
                  left: SizeConfig.blockSizeHorizontal * 10,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "signup_services_title".tr(),
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: SizeConfig.blockSizeHorizontal * 3.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(height: SizeConfig.blockSizeVertical * 1),
              if (prestatairesProvider.servicesLoading)
                const Center(child: CircularProgressIndicator())
              else
                Padding(
                  padding: EdgeInsets.only(
                    left: SizeConfig.blockSizeHorizontal * 10,
                  ),
                  child: Column(
                    children: prestatairesProvider.services.map((srv) {
                      print("srv: ${srv.toString()}");
                      final id = srv.id;
                      final libelle = srv.libelle;
                      if (id.isEmpty || libelle.isEmpty) {
                        return const SizedBox();
                      }
                      final selected = _selectedServiceIdsPrestataire.contains(
                        id,
                      );
                      return CheckboxListTile(
                        value: selected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedServiceIdsPrestataire.add(id);
                            } else {
                              _selectedServiceIdsPrestataire.remove(id);
                            }
                          });
                        },
                        dense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: SizeConfig.blockSizeHorizontal * 5,
                        ),
                        activeColor: Utilities().colorBlueDark,
                        title: Text(
                          libelle,
                          style: TextStyle(
                            fontSize: SizeConfig.blockSizeHorizontal * 3.2,
                            color: Colors.black,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
            if (type == "prestataire") ...[
              Padding(
                padding: EdgeInsets.only(
                  top: SizeConfig.blockSizeVertical * 1.5,
                  left: SizeConfig.blockSizeHorizontal * 5,
                  right: SizeConfig.blockSizeHorizontal * 5,
                ),
                child: Text(
                  "signup_docs_title".tr(),
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: SizeConfig.blockSizeHorizontal * 3.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: SizeConfig.blockSizeVertical * 1),
              Text(
                "signup_doc_cni_title".tr(),
                style: TextStyle(
                  color: Utilities().colorGreyDark,
                  fontSize: SizeConfig.blockSizeHorizontal * 3,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: SizeConfig.blockSizeVertical * 0.8),
              Column(
                children: [
                  DashedUploadZone(
                    title: "signup_doc_cni_recto_title".tr(),
                    subtitle: "signup_doc_cni_recto_subtitle".tr(),
                    fileName: cniRectoFileName,
                    onTap: () => _pickDocument(
                      (name, file) => setState(() {
                        cniRectoFileName = name;
                        cniRectoFile = file;
                      }),
                    ),
                  ),
                  SizedBox(height: SizeConfig.blockSizeVertical * 1),
                  DashedUploadZone(
                    title: "signup_doc_cni_verso_title".tr(),
                    subtitle: "signup_doc_cni_verso_subtitle".tr(),
                    fileName: cniVersoFileName,
                    onTap: () => _pickDocument(
                      (name, file) => setState(() {
                        cniVersoFileName = name;
                        cniVersoFile = file;
                      }),
                    ),
                  ),
                ],
              ),
              SizedBox(height: SizeConfig.blockSizeVertical * 1.2),
              Text(
                "signup_doc_residence_title".tr(),
                style: TextStyle(
                  color: Utilities().colorGreyDark,
                  fontSize: SizeConfig.blockSizeHorizontal * 3,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: SizeConfig.blockSizeVertical * 0.8),
              DashedUploadZone(
                title: "signup_doc_residence_tile_title".tr(),
                fileName: certificatResidenceFileName,
                onTap: () => _pickDocument(
                  (name, file) => setState(() {
                    certificatResidenceFileName = name;
                    certificatResidenceFile = file;
                  }),
                ),
              ),
              SizedBox(height: SizeConfig.blockSizeVertical * 1.2),
              Text(
                "signup_doc_diplome_title".tr(),
                style: TextStyle(
                  color: Utilities().colorGreyDark,
                  fontSize: SizeConfig.blockSizeHorizontal * 3,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: SizeConfig.blockSizeVertical * 0.8),
              DashedUploadZone(
                title: "signup_doc_diplome_tile_title".tr(),
                fileName: diplomeFileName,
                onTap: () => _pickDocument(
                  (name, file) => setState(() {
                    diplomeFileName = name;
                    diplomeFile = file;
                  }),
                ),
              ),
              SizedBox(height: SizeConfig.blockSizeVertical * 1.5),
            ],
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: SizeConfig.blockSizeVertical * 1,
                horizontal: SizeConfig.blockSizeHorizontal * 10,
              ),
              child: CustomButton(
                onTap: userProvider.isLoading ? null : handleSignUp,
                title: Center(
                  child: userProvider.isLoading
                      ? SizedBox(
                          width: SizeConfig.blockSizeHorizontal * 5,
                          height: SizeConfig.blockSizeHorizontal * 5,
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          "signup_button".tr(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: SizeConfig.blockSizeHorizontal * 3,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                color: Utilities().colorBlueDark,
                borderColor: Colors.white,
                width: SizeConfig.blockSizeHorizontal * 90,
                height: SizeConfig.blockSizeVertical * 6,
                borderRadius: SizeConfig.blockSizeHorizontal * 10,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: SizeConfig.blockSizeHorizontal * 1,
              children: [
                Text(
                  "signup_already_account".tr(),
                  style: TextStyle(
                    color: Utilities().colorGreyDark,
                    fontSize: SizeConfig.blockSizeHorizontal * 3,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    AppNavigation.goLogin(context);
                  },
                  child: Text(
                    "signup_go_to_login".tr(),
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: SizeConfig.blockSizeHorizontal * 3,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: SizeConfig.blockSizeVertical * 5),
          ],
        ),
      ),
    );
  }
}
