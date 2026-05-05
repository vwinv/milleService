import 'package:flutter/material.dart';
import 'package:milleservices/providers/userProvider.dart';
import 'package:milleservices/services/sizeConfig.dart';
import 'package:milleservices/services/utilities.dart';
import 'package:milleservices/widgets/customButton.dart';
import 'package:milleservices/widgets/customTextField.dart';
import 'package:provider/provider.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _telephoneController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final userProvider = context.read<UserProvider>();
    final res = await userProvider.forgotPassword(
      email: _emailController.text.trim(),
      telephone: _telephoneController.text.trim(),
      newPassword: _newPasswordController.text,
    );
    if (!mounted) return;

    final defaultSuccess = 'Mot de passe mis à jour avec succès';
    final defaultError = 'Impossible de mettre à jour le mot de passe';
    final message = (res.message?.toString().trim().isNotEmpty ?? false)
        ? res.message.toString()
        : (res.success == true ? defaultSuccess : defaultError);

    Utilities().showMesage(
      context,
      res.success == true ? 'success' : 'error',
      message,
    );

    if (res.success == true) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<UserProvider>().isLoading;
    SizeConfig().init(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Mot de passe oublié',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: SizeConfig.blockSizeHorizontal * 8,
          vertical: SizeConfig.blockSizeVertical * 2,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Renseignez votre email, votre numéro et un nouveau mot de passe.',
                style: TextStyle(
                  color: Utilities().colorGreyDark,
                  fontSize: SizeConfig.blockSizeHorizontal * 3.3,
                ),
              ),
              SizedBox(height: SizeConfig.blockSizeVertical * 3),
              CustomTextField(
                radius: SizeConfig.blockSizeHorizontal * 10,
                controller: _emailController,
                label: 'Email',
                labelStyle: TextStyle(
                  color: Utilities().colorGreyDark,
                  fontWeight: FontWeight.w600,
                ),
                placeholder: 'exemple@mail.com',
                borderColor: Utilities().colorGreyDark,
                fillColor: Colors.white,
                textfieldStyle: TextStyle(color: Utilities().colorGreyDark),
                placeholderStyle: TextStyle(
                  color: Utilities().colorGreyDark,
                  fontSize: SizeConfig.blockSizeHorizontal * 3,
                ),
                obscur: false,
                height: SizeConfig.blockSizeVertical * 5,
                width: SizeConfig.blockSizeHorizontal * 90,
                prefixIcon: null,
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) return 'Email requis';
                  final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
                  if (!ok) return 'Email invalide';
                  return null;
                },
              ),
              SizedBox(height: SizeConfig.blockSizeVertical * 1.8),
              CustomTextField(
                radius: SizeConfig.blockSizeHorizontal * 10,
                controller: _telephoneController,
                label: 'Téléphone',
                labelStyle: TextStyle(
                  color: Utilities().colorGreyDark,
                  fontWeight: FontWeight.w600,
                ),
                placeholder: '77 000 00 00',
                borderColor: Utilities().colorGreyDark,
                fillColor: Colors.white,
                textfieldStyle: TextStyle(color: Utilities().colorGreyDark),
                placeholderStyle: TextStyle(
                  color: Utilities().colorGreyDark,
                  fontSize: SizeConfig.blockSizeHorizontal * 3,
                ),
                obscur: false,
                height: SizeConfig.blockSizeVertical * 5,
                width: SizeConfig.blockSizeHorizontal * 90,
                prefixIcon: null,
                validator: (value) {
                  final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
                  if (digits.length < 8) return 'Téléphone invalide';
                  return null;
                },
              ),
              SizedBox(height: SizeConfig.blockSizeVertical * 1.8),
              CustomTextField(
                radius: SizeConfig.blockSizeHorizontal * 10,
                controller: _newPasswordController,
                label: 'Nouveau mot de passe',
                labelStyle: TextStyle(
                  color: Utilities().colorGreyDark,
                  fontWeight: FontWeight.w600,
                ),
                placeholder: '********',
                borderColor: Utilities().colorGreyDark,
                fillColor: Colors.white,
                textfieldStyle: TextStyle(color: Utilities().colorGreyDark),
                placeholderStyle: TextStyle(
                  color: Utilities().colorGreyDark,
                  fontSize: SizeConfig.blockSizeHorizontal * 3,
                ),
                obscur: _obscure,
                height: SizeConfig.blockSizeVertical * 5,
                width: SizeConfig.blockSizeHorizontal * 90,
                validator: (value) {
                  if ((value ?? '').length < 8) {
                    return 'Le mot de passe doit contenir au moins 8 caractères';
                  }
                  return null;
                },
                prefixIcon: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: SizeConfig.blockSizeHorizontal * 2,
                  ),
                  child: GestureDetector(
                    onTap: () => setState(() => _obscure = !_obscure),
                    child: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      color: Utilities().colorGreyDark,
                    ),
                  ),
                ),
              ),
              SizedBox(height: SizeConfig.blockSizeVertical * 3),
              CustomButton(
                onTap: isLoading ? null : _submit,
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
                          'Mettre à jour',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: SizeConfig.blockSizeHorizontal * 3.3,
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
            ],
          ),
        ),
      ),
    );
  }
}
