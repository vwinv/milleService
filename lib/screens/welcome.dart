import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:milleservices/navigation/app_navigation.dart';
import 'package:milleservices/services/sizeConfig.dart';
import 'package:milleservices/services/utilities.dart';
import 'package:milleservices/widgets/customButton.dart';

class Welcome extends StatefulWidget {
  const Welcome({super.key});

  @override
  State<Welcome> createState() => _WelcomeState();
}

class _WelcomeState extends State<Welcome> {
  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    return Scaffold(
      backgroundColor: Utilities().colorBlueDark,
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: SizeConfig.screenHeight),
            child: SizedBox(
              width: SizeConfig.screenWidth,
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.only(
                      top: SizeConfig.blockSizeVertical * 10,
                      bottom: SizeConfig.blockSizeVertical * 5,
                    ),
                    child: Image.asset("${Utilities().imagePath}logo.png"),
                  ),
                  Image.asset("${Utilities().imagePath}maps.png"),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: SizeConfig.blockSizeVertical * 3,
                      horizontal: SizeConfig.blockSizeHorizontal * 7,
                    ),
                    child: Text(
                      "description".tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: SizeConfig.blockSizeHorizontal * 4,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: SizeConfig.blockSizeVertical * 1,
                      horizontal: SizeConfig.blockSizeHorizontal * 10,
                    ),
                    child: CustomButton(
                      onTap: () => AppNavigation.goChooseProfile(context),
                      title: Center(
                        child: Text(
                          'welcome_start'.tr(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: SizeConfig.blockSizeHorizontal * 4,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      color: Utilities().colorYellow,
                      borderColor: Colors.white,
                      width: SizeConfig.blockSizeHorizontal * 90,
                      height: SizeConfig.blockSizeVertical * 6,
                      borderRadius: SizeConfig.blockSizeHorizontal * 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
