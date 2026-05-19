import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:milleservices/providers/userProvider.dart';
import 'package:milleservices/navigation/app_navigation.dart';
import 'package:go_router/go_router.dart';
import 'package:milleservices/services/sizeConfig.dart';
import 'package:milleservices/services/utilities.dart';
import 'package:milleservices/widgets/auth_keyboard_aware_layout.dart';
import 'package:milleservices/widgets/customButton.dart';
import 'package:milleservices/widgets/customTextField.dart';
import 'package:provider/provider.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> with TickerProviderStateMixin {
  TabController? tabController;
  final formParticulierKey = GlobalKey<FormState>();
  final formPrestataireKey = GlobalKey<FormState>();

  TextEditingController emailParticulierController = TextEditingController();
  TextEditingController passwordParticulierController = TextEditingController();
  TextEditingController emailPrestataireController = TextEditingController();
  TextEditingController passwordPrestataireController = TextEditingController();
  bool obscurPasswordParticulier = true;
  bool obscurPasswordPrestataire = true;
  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    // tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthKeyboardAwareLayout(
      tabController: tabController!,
      taglineForYou: 'login_tagline_for_you'.tr(),
      taglineFromHome: 'login_tagline_from_home'.tr(),
      welcomeTitle: 'login_welcome_title'.tr(),
      tabParticulierLabel: 'login_tab_particulier'.tr(),
      tabProfessionnelLabel: 'login_tab_professionnel'.tr(),
      tabViews: [
        _buildForm('particulier', context),
        _buildForm('prestataire', context),
      ],
    );
  }

  Widget _buildForm(String type, BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    bool isLoading = userProvider.isLoading;

    Future<void> handleLogin() async {
      print("handleLogin");
      /* if (type == "particulier"
          ? formParticulierKey.currentState!.validate()
          : formPrestataireKey.currentState!.validate()) {
        print("validate false");
        return;
      } */
      final email = type == "particulier"
          ? emailParticulierController.text.trim()
          : emailPrestataireController.text.trim();
      final password = type == "particulier"
          ? passwordParticulierController.text
          : passwordPrestataireController.text;

      final role = type == "particulier" ? 'PARTICULIER' : 'PRESTATAIRE';
      final res = await userProvider.login(email, password, role: role);
      if (res.success == true) {
        if (mounted) {
          Utilities().showMesage(context, 'success', "login_success".tr());
          AppNavigation.goHome(context);
        }
      } else {
        if (mounted) {
          final defaultMsg = "login_failed".tr();
          final msg = (res.message?.toString().trim().isNotEmpty ?? false)
              ? (res.message ?? defaultMsg)
              : defaultMsg;
          //   Navigator.of(context).pop(false);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              Utilities().showMesage(context, 'error', msg);
            }
          });
        }
      }
    }

    return SingleChildScrollView(
      padding: AuthKeyboardAwareLayout.formScrollPadding(context),
      key: type == "particulier" ? formParticulierKey : formPrestataireKey,
      child: Form(
        child: Column(
          children: [
            CustomTextField(
              radius: SizeConfig.blockSizeHorizontal * 10,
              controller: type == "particulier"
                  ? emailParticulierController
                  : emailPrestataireController,
              borderColor: Utilities().colorGreyDark,
              fillColor: Colors.white,
              label: "Telephone",
              labelStyle: TextStyle(
                color: Colors.black,
                fontSize: SizeConfig.blockSizeHorizontal * 3.5,
                fontWeight: FontWeight.bold,
              ),
              placeholder: "Ex: 770000000",
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
                if (value == null || value.isEmpty) {
                  return "Le telephone est requis";
                }
                return null;
              },
              prefixIcon: null,
            ),
            CustomTextField(
              radius: SizeConfig.blockSizeHorizontal * 10,
              controller: type == "particulier"
                  ? passwordParticulierController
                  : passwordPrestataireController,
              borderColor: Utilities().colorGreyDark,
              fillColor: Colors.white,
              label: "login_password_label".tr(),
              labelStyle: TextStyle(
                color: Colors.black,
                fontSize: SizeConfig.blockSizeHorizontal * 3.5,
                fontWeight: FontWeight.bold,
              ),
              placeholder: "login_password_placeholder".tr(),
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
                if (value == null || value.isEmpty) {
                  return "login_password_required".tr();
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
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () {
                  context.push('/forgot-password');
                },
                child: Padding(
                  padding: EdgeInsets.only(
                    left: SizeConfig.blockSizeHorizontal * 10,
                    top: SizeConfig.blockSizeVertical * 1,
                  ),
                  child: Text(
                    "login_forgot_password".tr(),
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: SizeConfig.blockSizeHorizontal * 3,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: SizeConfig.blockSizeVertical * 1,
                horizontal: SizeConfig.blockSizeHorizontal * 10,
              ),
              child: CustomButton(
                onTap: handleLogin,
                title: Center(
                  child: isLoading
                      ? SizedBox(
                          width: SizeConfig.blockSizeHorizontal * 5,
                          height: SizeConfig.blockSizeHorizontal * 5,
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          "login_button".tr(),
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
                  "login_no_account".tr(),
                  style: TextStyle(
                    color: Utilities().colorGreyDark,
                    fontSize: SizeConfig.blockSizeHorizontal * 3,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    AppNavigation.goSignUp(context);
                  },
                  child: Text(
                    "login_register_now".tr(),
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: SizeConfig.blockSizeHorizontal * 3,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.only(
                top: SizeConfig.blockSizeVertical * 1,
                left: SizeConfig.blockSizeHorizontal * 10,
                right: SizeConfig.blockSizeHorizontal * 10,
              ),
              child: Divider(
                color: Utilities().colorGreyDark.withOpacity(0.3),
                thickness: 1,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: SizeConfig.blockSizeVertical * 1,
              ),
              child: Text(
                "login_connect_with".tr(),
                style: TextStyle(
                  color: Utilities().colorGreyDark,
                  fontSize: SizeConfig.blockSizeHorizontal * 3,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: SizeConfig.blockSizeHorizontal * 1,
              children: [
                CustomButton(
                  onTap: () {
                    // TODO: Implement Google login
                  },
                  title: Center(
                    child: Text(
                      "G",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: SizeConfig.blockSizeHorizontal * 4,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  color: Utilities().colorYellow,
                  borderColor: Colors.white,
                  width: SizeConfig.blockSizeHorizontal * 12,
                  height: SizeConfig.blockSizeVertical * 5,
                  borderRadius: SizeConfig.blockSizeHorizontal * 10,
                ),

                CustomButton(
                  onTap: () {
                    // TODO: Implement Facebook login
                  },
                  title: Center(
                    child: Text(
                      "f",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: SizeConfig.blockSizeHorizontal * 4,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  color: Utilities().colorBlueDark,
                  borderColor: Colors.white,
                  width: SizeConfig.blockSizeHorizontal * 12,
                  height: SizeConfig.blockSizeVertical * 5,
                  borderRadius: SizeConfig.blockSizeHorizontal * 10,
                ),

                CustomButton(
                  onTap: () {
                    // TODO: Implement Apple login
                  },
                  title: Center(
                    child: Text(
                      "A",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: SizeConfig.blockSizeHorizontal * 4,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  color: Colors.black,
                  borderColor: Colors.white,
                  width: SizeConfig.blockSizeHorizontal * 12,
                  height: SizeConfig.blockSizeVertical * 5,
                  borderRadius: SizeConfig.blockSizeHorizontal * 10,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
