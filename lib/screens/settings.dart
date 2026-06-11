import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:milleservices/providers/userProvider.dart';
import 'package:milleservices/services/app_locale.dart';
import 'package:milleservices/navigation/app_navigation.dart';
import 'package:milleservices/services/sizeConfig.dart';
import 'package:milleservices/services/utilities.dart';
import 'package:milleservices/widgets/customButton.dart';
import 'package:provider/provider.dart';
import 'package:milleservices/providers/settings_provider.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  UserProvider? _userProvider;
  String _selectedLanguage = 'fr';
  bool _languageInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _userProvider ??= context.read<UserProvider>();
    if (_languageInitialized) return;
    _languageInitialized = true;
    final saved = context.read<SettingsProvider>().selectedLocale?.languageCode;
    if (saved != null && saved.isNotEmpty) {
      _selectedLanguage = saved;
    } else {
      _selectedLanguage = deviceLanguagePreselection(context.locale);
    }
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: const SizedBox(),
        title: Text(
          'settings_choose_language'.tr(),
          style: TextStyle(
            color: Colors.black,
            fontSize: SizeConfig.fontSize(SizeConfig.blockSizeHorizontal * 5),
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.only(
          left: SizeConfig.blockSizeHorizontal * 15,
          right: SizeConfig.blockSizeHorizontal * 15,
          top: SizeConfig.blockSizeVertical * 5,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: SizeConfig.blockSizeVertical * 5),
            _buildLanguageOption(
              flag: '🇫🇷',
              language: 'Français',
              value: 'fr',
            ),
            const Divider(height: 1),
            _buildLanguageOption(
              flag: '🇬🇧',
              language: 'profil_lang_en'.tr(),
              value: 'en',
            ),

            Padding(
              padding: EdgeInsets.only(top: SizeConfig.blockSizeVertical * 10),
              child: CustomButton(
                onTap: _onCommencer,
                title: Center(
                  child: Text(
                    'abonnement_start'.tr(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: SizeConfig.blockSizeHorizontal * 4,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                color: Utilities().colorBlueDark,
                borderColor: Utilities().colorBlueDark,
                width: SizeConfig.blockSizeHorizontal * 90,
                height: SizeConfig.blockSizeVertical * 6,
                borderRadius: SizeConfig.blockSizeHorizontal * 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption({
    required String flag,
    required String language,
    required String value,
  }) {
    return InkWell(
      onTap: () => setState(() => _selectedLanguage = value),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: SizeConfig.blockSizeVertical * 2,
          horizontal: SizeConfig.blockSizeHorizontal * 4,
        ),
        child: Row(
          children: [
            Text(
              flag,
              style: TextStyle(
                fontSize: SizeConfig.fontSize(
                  SizeConfig.blockSizeHorizontal * 8,
                ),
              ),
            ),
            SizedBox(width: SizeConfig.blockSizeHorizontal * 3),
            Text(
              language,
              style: TextStyle(
                fontSize: SizeConfig.fontSize(
                  SizeConfig.blockSizeHorizontal * 4,
                ),
                color: Colors.black,
                fontWeight: _selectedLanguage == value
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            const Spacer(),
            Radio<String>(
              value: value,
              groupValue: _selectedLanguage,
              onChanged: (v) => setState(() => _selectedLanguage = value),
              activeColor: Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onCommencer() async {
    final settings = context.read<SettingsProvider>();
    final userProvider = _userProvider ?? context.read<UserProvider>();
    await applyAppLanguage(context, settings, _selectedLanguage);
    if (!mounted) return;
    final isGuest = !userProvider.isAuthenticated || userProvider.user == null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (isGuest) {
        AppNavigation.goParticulierHome(context);
      } else {
        AppNavigation.continueAfterAuth(context);
      }
    });
  }
}
