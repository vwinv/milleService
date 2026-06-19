import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:milleservices/navigation/app_navigation.dart';
import 'package:milleservices/providers/auth_resume_provider.dart';
import 'package:milleservices/providers/userProvider.dart';
import 'package:milleservices/services/sizeConfig.dart';
import 'package:milleservices/services/utilities.dart';
import 'package:provider/provider.dart';

/// Dialogue de confirmation puis désactivation via [UserProvider.deleteAccount].
Future<void> confirmAndDeactivateAccount(BuildContext context) async {
  final userProvider = context.read<UserProvider>();
  final phone = Utilities().telephoneEquipe;

  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text('profil_delete_account_confirm_title'.tr()),
        content: Text(
          'profil_delete_account_confirm_body'.tr(namedArgs: {'phone': phone}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('deroulement_pay_cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'profil_delete_account_confirm_btn'.tr(),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      );
    },
  );
  if (confirm != true || !context.mounted) return;

  final role = userProvider.user?.role?.toString() ?? 'PARTICULIER';
  final isParticulier = role.toUpperCase() == 'PARTICULIER';

  // Quitter profil / edit-infos AVANT logout : sinon le redirect invité reste sur « Compte ».
  if (isParticulier) {
    AppNavigation.goParticulierHome(context);
  }

  final res = await userProvider.deleteAccount();
  if (!context.mounted) return;

  final deactivated = res.success == true ||
      (res.status != null && res.status! >= 200 && res.status! < 300);

  if (deactivated) {
    context.read<AuthResumeProvider>().clear();
    if (!isParticulier) {
      AppNavigation.goPrestataireLogin(context);
    }
    if (!context.mounted) return;
    Utilities().showMesage(
      context,
      'success',
      'profil_delete_account_success'.tr(namedArgs: {'phone': phone}),
    );
  } else {
    Utilities().showMesage(
      context,
      'error',
      res.message?.toString().isNotEmpty == true
          ? res.message.toString()
          : 'profil_delete_account_failed'.tr(),
    );
  }
}

/// Bouton rouge « Supprimer mon compte » (désactivation, pas suppression).
class DeleteAccountButton extends StatelessWidget {
  const DeleteAccountButton({super.key});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => confirmAndDeactivateAccount(context),
      child: Text(
        'profil_delete_account'.tr(),
        style: TextStyle(
          color: Colors.red,
          fontSize: SizeConfig.fontSize(
            SizeConfig.blockSizeHorizontal * 3.4,
          ),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
