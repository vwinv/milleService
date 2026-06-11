import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:milleservices/navigation/app_navigation.dart';
import 'package:milleservices/providers/settings_provider.dart';
import 'package:milleservices/services/sizeConfig.dart';
import 'package:milleservices/services/utilities.dart';
import 'package:milleservices/widgets/customButton.dart';
import 'package:provider/provider.dart';

enum UserProfileChoice { particulier, prestataire }

class ChooseProfile extends StatefulWidget {
  const ChooseProfile({super.key});

  @override
  State<ChooseProfile> createState() => _ChooseProfileState();
}

class _ChooseProfileState extends State<ChooseProfile> {
  UserProfileChoice _selected = UserProfileChoice.particulier;

  Future<void> _onContinue() async {
    if (_selected == UserProfileChoice.particulier) {
      final settings = context.read<SettingsProvider>();
      await settings.markGuestOnboardingDone();
      if (!mounted) return;
      if (settings.locale == null) {
        AppNavigation.goSettings(context);
      } else {
        AppNavigation.goParticulierHome(context);
      }
      return;
    }
    AppNavigation.goPrestataireLogin(context);
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => AppNavigation.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'choose_profile_title'.tr(),
          style: TextStyle(
            color: Colors.black,
            fontSize: SizeConfig.blockSizeHorizontal * 4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: SizeConfig.blockSizeHorizontal * 6,
                ),
                child: Column(
                  children: [
                    SizedBox(height: SizeConfig.blockSizeVertical * 2),
                    Image.asset('${Utilities().imagePath}logo.png'),
                    SizedBox(height: SizeConfig.blockSizeVertical * 3),
                    Text(
                      'choose_profile_question'.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: SizeConfig.blockSizeHorizontal * 5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: SizeConfig.blockSizeVertical * 1.5),
                    Text(
                      'choose_profile_subtitle'.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Utilities().colorGreyDark,
                        fontSize: SizeConfig.blockSizeHorizontal * 3.2,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    SizedBox(height: SizeConfig.blockSizeVertical * 3),
                    _ProfileCard(
                      selected: _selected == UserProfileChoice.particulier,
                      icon: Icons.person,
                      title: 'choose_profile_particulier_title'.tr(),
                      description: 'choose_profile_particulier_desc'.tr(),
                      onTap: () => setState(
                        () => _selected = UserProfileChoice.particulier,
                      ),
                    ),
                    SizedBox(height: SizeConfig.blockSizeVertical * 2),
                    _ProfileCard(
                      selected: _selected == UserProfileChoice.prestataire,
                      icon: Icons.work_outline,
                      title: 'choose_profile_prestataire_title'.tr(),
                      description: 'choose_profile_prestataire_desc'.tr(),
                      onTap: () => setState(
                        () => _selected = UserProfileChoice.prestataire,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                SizeConfig.blockSizeHorizontal * 6,
                SizeConfig.blockSizeVertical * 1,
                SizeConfig.blockSizeHorizontal * 6,
                SizeConfig.blockSizeVertical * 2,
              ),
              child: CustomButton(
                onTap: _onContinue,
                title: Center(
                  child: Text(
                    'choose_profile_continue'.tr(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: SizeConfig.blockSizeHorizontal * 4,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                color: Utilities().colorBlueDark,
                borderColor: Colors.white,
                width: double.infinity,
                height: SizeConfig.blockSizeVertical * 6,
                borderRadius: SizeConfig.blockSizeHorizontal * 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    final borderColor = selected
        ? Utilities().colorBlueDark
        : Utilities().colorGreyDark.withOpacity(0.25);
    final backgroundColor = selected
        ? Utilities().colorBlueLight.withOpacity(0.35)
        : Colors.white;
    final titleColor = selected ? Colors.black : Utilities().colorGreyDark;
    final descriptionColor = selected
        ? Colors.black87
        : Utilities().colorGreyDark.withOpacity(0.85);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(SizeConfig.blockSizeHorizontal * 4),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(
            SizeConfig.blockSizeHorizontal * 4,
          ),
          border: Border.all(color: borderColor, width: selected ? 2 : 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: SizeConfig.blockSizeHorizontal * 12,
              height: SizeConfig.blockSizeHorizontal * 12,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(
                  SizeConfig.blockSizeHorizontal * 2.5,
                ),
              ),
              child: Icon(
                icon,
                color: selected
                    ? Utilities().colorBlueDark
                    : Utilities().colorGreyDark,
                size: SizeConfig.blockSizeHorizontal * 6,
              ),
            ),
            SizedBox(width: SizeConfig.blockSizeHorizontal * 3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: SizeConfig.blockSizeHorizontal * 4,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: SizeConfig.blockSizeVertical * 0.5),
                  Text(
                    description,
                    style: TextStyle(
                      color: descriptionColor,
                      fontSize: SizeConfig.blockSizeHorizontal * 3.2,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: SizeConfig.blockSizeHorizontal * 2),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected
                  ? Utilities().colorBlueDark
                  : Utilities().colorGreyDark.withOpacity(0.4),
              size: SizeConfig.blockSizeHorizontal * 6,
            ),
          ],
        ),
      ),
    );
  }
}
