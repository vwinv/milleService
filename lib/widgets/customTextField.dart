import 'package:flutter/material.dart';
import 'package:milleservices/services/sizeConfig.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextStyle labelStyle;
  final TextStyle textfieldStyle;
  final TextStyle placeholderStyle;
  final String placeholder;
  final bool obscur;
  final double height;
  final double width;
  final double radius;
  final Widget? prefixIcon;
  final String? Function(String?)? validator;
  final Color borderColor;
  final Color fillColor;
  final int? maxLines;

  CustomTextField({
    super.key,
    required this.controller,
    required this.borderColor,
    required this.fillColor,
    required this.label,
    required this.labelStyle,
    required this.placeholder,
    required this.textfieldStyle,
    required this.placeholderStyle,
    required this.obscur,
    required this.height,
    required this.width,
    required this.radius,
    required this.validator,
    required this.prefixIcon,
    this.maxLines,
  });

  InputBorder _outlineBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(radius)),
      borderSide: BorderSide(color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveHeight = height < 48 ? 48.0 : height;
    final horizontalPadding = SizeConfig.blockSizeHorizontal * 5;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: SizeConfig.blockSizeHorizontal * 5,
        vertical: SizeConfig.blockSizeVertical * 1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: SizeConfig.blockSizeVertical * 1,
        children: [
          Text(label, style: labelStyle),
          SizedBox(
            width: width,
            child: TextFormField(
              controller: controller,
              style: textfieldStyle,
              validator: validator,
              obscureText: obscur,
              maxLines: obscur ? 1 : maxLines,
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: placeholderStyle,
                filled: true,
                fillColor: fillColor,
                isDense: false,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: maxLines != null && maxLines! > 1 ? 14 : 12,
                ),
                constraints: BoxConstraints(
                  minHeight: effectiveHeight,
                ),
                border: _outlineBorder(borderColor),
                enabledBorder: _outlineBorder(borderColor),
                focusedBorder: _outlineBorder(borderColor),
                errorBorder: _outlineBorder(Colors.red.shade700),
                focusedErrorBorder: _outlineBorder(Colors.red.shade700),
                errorMaxLines: 3,
                errorStyle: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: SizeConfig.blockSizeHorizontal * 2.8,
                  height: 1.25,
                ),
                suffixIcon: prefixIcon,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
