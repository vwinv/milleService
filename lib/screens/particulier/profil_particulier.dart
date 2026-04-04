import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:milleservices/widgets/customButton.dart';
import 'package:milleservices/screens/edit_infos.dart';
import 'package:provider/provider.dart';
import 'package:milleservices/models/user.dart';
import 'package:milleservices/providers/userProvider.dart';
import 'package:milleservices/providers/prestationsProvider.dart';
import 'package:milleservices/models/prestation.dart';
import 'package:milleservices/screens/historique.dart';
import 'package:milleservices/providers/settings_provider.dart';
import 'package:milleservices/services/app_locale.dart';
import 'package:milleservices/services/sizeConfig.dart';
import 'package:milleservices/services/utilities.dart';
import 'package:milleservices/screens/welcome.dart';

class ProfilParticulier extends StatefulWidget {
  const ProfilParticulier({super.key});

  @override
  State<ProfilParticulier> createState() => _ProfilParticulierState();
}

class _ProfilParticulierState extends State<ProfilParticulier> {
  bool _languageOpen = false;

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    final userProvider = context.watch<UserProvider>();
    final User? user = userProvider.user;
    final avatarUrl = userProvider.avatarUrlForDisplay;
    final settings = context.watch<SettingsProvider>();

    if (user == null) {
      final waiting =
          !userProvider.initialLoadDone || userProvider.isLoading;
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'profil_title'.tr(),
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
        body: Center(
          child: waiting
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'profil_unavailable'.tr(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black87),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('common_back'.tr()),
                      ),
                    ],
                  ),
                ),
        ),
      );
    }
    final currentCode =
        settings.selectedLocale?.languageCode ?? context.locale.languageCode;
    final currentLabel = currentCode == 'en' ? 'profil_lang_en'.tr() : 'profil_lang_fr'.tr();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'profil_title'.tr(),
          style: TextStyle(
            color: Colors.black,
            fontSize: SizeConfig.fontSize(SizeConfig.blockSizeHorizontal * 5),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
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
                                      size:
                                          SizeConfig.blockSizeHorizontal * 14,
                                      color: Utilities().colorGreyDark,
                                    ),
                                  ),
                                )
                              : ColoredBox(
                                  color: Utilities().colorGreyLight,
                                  child: Icon(
                                    Icons.person,
                                    size:
                                        SizeConfig.blockSizeHorizontal * 14,
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
                    child: CircleAvatar(
                      radius: SizeConfig.blockSizeHorizontal * 3.5,
                      backgroundColor: Utilities().colorBlueDark,
                      child: const Icon(
                        Icons.edit,
                        size: 16,
                        color: Colors.white,
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
                    '${user.prenom ?? ''} ${user.nom ?? ''}'.trim(),
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: SizeConfig.fontSize(
                        SizeConfig.blockSizeHorizontal * 4.2,
                      ),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: SizeConfig.blockSizeVertical * 0.5),
                  if (user.telephone != null)
                    Text(
                      user.telephone.toString(),
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
            SizedBox(height: SizeConfig.blockSizeVertical * 4),
            _buildSimpleTile(
              icon: Icons.miscellaneous_services_outlined,
              label: 'profil_service_ongoing'.tr(),
              onTap: () {},
            ),
            SizedBox(height: SizeConfig.blockSizeVertical * 1.5),
            _buildSimpleTile(
              icon: Icons.history,
              label: 'profil_history'.tr(),
              onTap: () async {
                final prestationsProvider = context.read<PrestationsProvider>();
                final userProvider = context.read<UserProvider>();

                await prestationsProvider.loadMyPrestations(userProvider);

                if (!mounted) return;

                if (prestationsProvider.error != null &&
                    prestationsProvider.myPrestations.isEmpty) {
                  print(prestationsProvider.error);
                  Utilities().showMesage(
                    context,
                    'error',
                    prestationsProvider.error!.isNotEmpty
                        ? prestationsProvider.error!
                        : 'profil_load_error'.tr(),
                  );
                  return;
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Historique(
                      prestations: List<Prestation>.from(
                        prestationsProvider.myPrestations,
                      ),
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: SizeConfig.blockSizeVertical * 1.5),
            _buildSimpleTile(
              icon: Icons.credit_card,
              label: 'profil_payment'.tr(),
              onTap: () {},
            ),
            SizedBox(height: SizeConfig.blockSizeVertical * 2),
            _buildLanguageAccordion(
              currentLabel: currentLabel,
              currentCode: currentCode,
              settings: settings,
            ),
            SizedBox(height: SizeConfig.blockSizeVertical * 2.5),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Utilities().colorBlueDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      SizeConfig.blockSizeHorizontal * 8,
                    ),
                  ),
                  padding: EdgeInsets.symmetric(
                    vertical: SizeConfig.blockSizeVertical * 1.8,
                  ),
                ),
                onPressed: () async {
                  final res = await context
                      .read<UserProvider>()
                      .becomePrestataire();
                  if (!mounted) return;
                  if (res.success == true) {
                    Utilities().showMesage(
                      context,
                      'success',
                      'profil_become_provider_success'.tr(),
                    );
                    await context.read<UserProvider>().logout();
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const Welcome()),
                      (route) => false,
                    );
                  } else {
                    Utilities().showMesage(
                      context,
                      'error',
                      res.message ??
                          'profil_become_provider_failed'.tr(),
                    );
                  }
                },
                child: Text(
                  'profil_become_provider_btn'.tr(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: SizeConfig.fontSize(
                      SizeConfig.blockSizeHorizontal * 3.5,
                    ),
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            SizedBox(height: SizeConfig.blockSizeVertical * 2.5),
            _buildSimpleTile(
              icon: Icons.person_outline,
              label: 'profil_personal_info'.tr(),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EditInfos()),
                );
              },
              trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.black,
              ),
            ),

            SizedBox(height: SizeConfig.blockSizeVertical * 2),
            TextButton(
        onPressed: () {
          userProvider.logout();
                Navigator.pushAndRemoveUntil(
            context,
                  MaterialPageRoute(builder: (context) => const Welcome()),
                  (route) => false,
                );
              },
              child: Text(
                'profil_logout'.tr(),
                style: TextStyle(
                  color: Colors.red,
                  fontSize: SizeConfig.fontSize(
                    SizeConfig.blockSizeHorizontal * 3.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleTile({
    required IconData icon,
    required String label,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return CustomButton(
      onTap: onTap,
      color: Utilities().colorGreyLight,
      borderColor: Utilities().colorGreyLightDark,
      borderRadius: SizeConfig.blockSizeHorizontal * 5,
      width: SizeConfig.blockSizeHorizontal * 88,
      height: SizeConfig.blockSizeVertical * 6,
      title: Row(
        children: [
          SizedBox(width: SizeConfig.blockSizeHorizontal * 4),
          Icon(icon, color: Colors.black),
          SizedBox(width: SizeConfig.blockSizeHorizontal * 3),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.black,
                fontSize: SizeConfig.fontSize(
                  SizeConfig.blockSizeHorizontal * 3.5,
                ),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          trailing ??
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.black,
              ),
          SizedBox(width: SizeConfig.blockSizeHorizontal * 4),
        ],
      ),
    );
  }

  Widget _buildLanguageAccordion({
    required String currentLabel,
    required String currentCode,
    required SettingsProvider settings,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Utilities().colorGreyLight,
        borderRadius: BorderRadius.circular(SizeConfig.blockSizeHorizontal * 5),
        border: Border.all(color: Utilities().colorGreyLightDark, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(
              SizeConfig.blockSizeHorizontal * 5,
            ),
            onTap: () {
              setState(() {
                _languageOpen = !_languageOpen;
              });
            },
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: SizeConfig.blockSizeHorizontal * 4,
                vertical: SizeConfig.blockSizeVertical * 1.8,
              ),
              child: Row(
                children: [
                  const Icon(Icons.language, color: Colors.black),
                  SizedBox(width: SizeConfig.blockSizeHorizontal * 3),
                  Expanded(
                    child: Text(
                      'profil_language'.tr(namedArgs: {'label': currentLabel}),
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: SizeConfig.fontSize(
                          SizeConfig.blockSizeHorizontal * 3.5,
                        ),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    _languageOpen
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.black,
                  ),
                ],
              ),
            ),
          ),
          if (_languageOpen) const Divider(height: 1),
          if (_languageOpen)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: SizeConfig.blockSizeHorizontal * 4,
                vertical: SizeConfig.blockSizeVertical * 1.5,
              ),
              child: Column(
                children: [
                  _buildLanguageRow(
                    flag: '🇫🇷',
                    label: 'profil_lang_fr'.tr(),
                    selected: currentCode == 'fr',
                    onTap: () async {
                      await applyAppLanguage(context, settings, 'fr');
                    },
                  ),
                  SizedBox(height: SizeConfig.blockSizeVertical * 1.2),
                  _buildLanguageRow(
                    flag: '🇬🇧',
                    label: 'profil_lang_en'.tr(),
                    selected: currentCode == 'en',
                    onTap: () async {
                      await applyAppLanguage(context, settings, 'en');
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLanguageRow({
    required String flag,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Text(
            flag,
            style: TextStyle(
              fontSize: SizeConfig.fontSize(
                SizeConfig.blockSizeHorizontal * 4.5,
              ),
            ),
          ),
          SizedBox(width: SizeConfig.blockSizeHorizontal * 3),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.black,
                fontSize: SizeConfig.fontSize(
                  SizeConfig.blockSizeHorizontal * 3.4,
                ),
              ),
            ),
          ),
          Container(
            width: SizeConfig.blockSizeHorizontal * 4,
            height: SizeConfig.blockSizeHorizontal * 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? Colors.green : Utilities().colorGreyDark,
                width: 2,
              ),
              color: selected ? Colors.green : Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}
