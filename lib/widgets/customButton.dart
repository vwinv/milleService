import 'package:flutter/material.dart';
import 'package:milleservices/services/sizeConfig.dart';

class CustomButton extends StatelessWidget {
  final Widget title;
  Color color;
  Color borderColor;
  double borderRadius;
  double width;
  double height;
  Function()? onTap;

  CustomButton({
    super.key,
    required this.title,
    required this.color,
    required this.borderColor,
    required this.borderRadius,
    required this.width,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
        ),
        child: title,
      ),
    );
  }
}
