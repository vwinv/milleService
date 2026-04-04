import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:milleservices/services/sizeConfig.dart';
import 'package:milleservices/services/utilities.dart';

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
  Widget? prefixIcon;
  String? Function(String?)? validator;
  Color borderColor;
  Color fillColor;
  int? maxLines;

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

  @override
  Widget build(BuildContext context) {
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
          Container(
            height: height,
            width: width,
            padding: EdgeInsets.only(left: SizeConfig.blockSizeHorizontal * 5),
            decoration: BoxDecoration(
              border: Border.all(color: borderColor),
              color: fillColor,
              borderRadius: BorderRadius.all(Radius.circular(radius)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controller,
                    style: textfieldStyle,
                    decoration: InputDecoration(
                      labelText: placeholder,
                      border: InputBorder.none,
                      labelStyle: placeholderStyle,
                    ),
                    validator: validator,
                    obscureText: obscur,
                  ),
                ),
                prefixIcon == null ? SizedBox.shrink() : prefixIcon!,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
