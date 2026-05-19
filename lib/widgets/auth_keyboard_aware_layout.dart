import 'package:flutter/material.dart';
import 'package:milleservices/services/sizeConfig.dart';
import 'package:milleservices/services/utilities.dart';
import 'package:milleservices/widgets/customButton.dart';

const _kAuthTransitionDuration = Duration(milliseconds: 300);
const _kAuthTransitionCurve = Curves.easeInOutCubic;

/// Layout login / signup : masque image + en-tête quand le clavier est ouvert.
class AuthKeyboardAwareLayout extends StatelessWidget {
  const AuthKeyboardAwareLayout({
    super.key,
    required this.tabController,
    required this.taglineForYou,
    required this.taglineFromHome,
    required this.welcomeTitle,
    required this.tabParticulierLabel,
    required this.tabProfessionnelLabel,
    required this.tabViews,
  });

  final TabController tabController;
  final String taglineForYou;
  final String taglineFromHome;
  final String welcomeTitle;
  final String tabParticulierLabel;
  final String tabProfessionnelLabel;
  final List<Widget> tabViews;

  /// Espace en bas du [SingleChildScrollView] pour scroller jusqu'au dernier champ.
  static EdgeInsets formScrollPadding(BuildContext context) {
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final base = SizeConfig.blockSizeVertical * 2;
    if (keyboardHeight <= 0) {
      return EdgeInsets.only(bottom: base);
    }
    return EdgeInsets.only(
      bottom: base + keyboardHeight + SizeConfig.blockSizeVertical * 6,
    );
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final keyboardVisible = bottomInset > 0;

    return Scaffold(
      resizeToAvoidBottomInset: !keyboardVisible,
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          IgnorePointer(
            ignoring: keyboardVisible,
            child: AnimatedOpacity(
              opacity: keyboardVisible ? 0 : 1,
              duration: _kAuthTransitionDuration,
              curve: _kAuthTransitionCurve,
              child: Image.asset("${Utilities().imagePath}ouvrier.jpeg"),
            ),
          ),
          SafeArea(
            child: AnimatedPadding(
              duration: _kAuthTransitionDuration,
              curve: _kAuthTransitionCurve,
              padding: EdgeInsets.only(
                bottom: keyboardVisible ? 0 : bottomInset,
              ),
              child: SizedBox(
                width: SizeConfig.screenWidth,
                height: SizeConfig.screenHeight,
                child: Column(
                  children: [
                    ClipRect(
                      child: AnimatedAlign(
                        duration: _kAuthTransitionDuration,
                        curve: _kAuthTransitionCurve,
                        heightFactor: keyboardVisible ? 0 : 1,
                        alignment: Alignment.topCenter,
                        child: AnimatedOpacity(
                          duration: _kAuthTransitionDuration,
                          curve: _kAuthTransitionCurve,
                          opacity: keyboardVisible ? 0 : 1,
                          child: _AuthHeader(
                            taglineForYou: taglineForYou,
                            taglineFromHome: taglineFromHome,
                            welcomeTitle: welcomeTitle,
                          ),
                        ),
                      ),
                    ),
                    _AuthTabBar(
                      controller: tabController,
                      particulierLabel: tabParticulierLabel,
                      professionnelLabel: tabProfessionnelLabel,
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: tabController,
                        children: tabViews,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthHeader extends StatelessWidget {
  const _AuthHeader({
    required this.taglineForYou,
    required this.taglineFromHome,
    required this.welcomeTitle,
  });

  final String taglineForYou;
  final String taglineFromHome;
  final String welcomeTitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.only(
            top: SizeConfig.blockSizeVertical * 15,
            left: SizeConfig.blockSizeHorizontal * 9.5,
          ),
          child: Row(
            spacing: SizeConfig.blockSizeHorizontal * 1,
            children: [
              CustomButton(
                onTap: () {},
                title: Center(
                  child: Text(
                    "Mille Services",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: SizeConfig.blockSizeHorizontal * 3,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ),
                color: Utilities().colorGreyDark.withOpacity(0.43),
                borderColor: Colors.white,
                width: SizeConfig.blockSizeHorizontal * 40,
                height: SizeConfig.blockSizeVertical * 3,
                borderRadius: SizeConfig.blockSizeHorizontal * 10,
              ),
              CustomButton(
                onTap: () {},
                title: Center(
                  child: Text(
                    taglineForYou,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: SizeConfig.blockSizeHorizontal * 3,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ),
                color: Utilities().colorGreyDark.withOpacity(0.43),
                borderColor: Colors.white,
                width: SizeConfig.blockSizeHorizontal * 40,
                height: SizeConfig.blockSizeVertical * 3,
                borderRadius: SizeConfig.blockSizeHorizontal * 10,
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.only(
            top: SizeConfig.blockSizeVertical * 1,
          ),
          child: CustomButton(
            onTap: () {},
            title: Center(
              child: Text(
                taglineFromHome,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: SizeConfig.blockSizeHorizontal * 3,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
            color: Utilities().colorGreyDark.withOpacity(0.43),
            borderColor: Colors.white,
            width: SizeConfig.blockSizeHorizontal * 40,
            height: SizeConfig.blockSizeVertical * 3,
            borderRadius: SizeConfig.blockSizeHorizontal * 10,
          ),
        ),
        Padding(
          padding: EdgeInsets.only(
            top: SizeConfig.blockSizeVertical * 2,
          ),
          child: Image.asset("${Utilities().imagePath}logo.png"),
        ),
        Padding(
          padding: EdgeInsets.only(
            top: SizeConfig.blockSizeVertical * 2,
          ),
          child: Text(
            welcomeTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black,
              fontSize: SizeConfig.blockSizeHorizontal * 4,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class _AuthTabBar extends StatelessWidget {
  const _AuthTabBar({
    required this.controller,
    required this.particulierLabel,
    required this.professionnelLabel,
  });

  final TabController controller;
  final String particulierLabel;
  final String professionnelLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: SizeConfig.blockSizeHorizontal * 90,
      height: SizeConfig.blockSizeVertical * 7,
      margin: EdgeInsets.symmetric(
        vertical: SizeConfig.blockSizeVertical * 2,
      ),
      padding: EdgeInsets.all(SizeConfig.blockSizeHorizontal * 2),
      decoration: BoxDecoration(
        color: Utilities().colorBlueLight.withOpacity(0.5),
        borderRadius: BorderRadius.circular(
          SizeConfig.blockSizeHorizontal * 10,
        ),
      ),
      child: TabBar(
        controller: controller,
        dividerColor: Colors.transparent,
        labelStyle: TextStyle(
          color: Colors.white,
          fontSize: SizeConfig.blockSizeHorizontal * 4,
          fontWeight: FontWeight.normal,
        ),
        unselectedLabelStyle: TextStyle(
          color: Colors.black,
          fontSize: SizeConfig.blockSizeHorizontal * 4,
          fontWeight: FontWeight.normal,
        ),
        indicator: BoxDecoration(
          color: Utilities().colorBlueDark,
          borderRadius: BorderRadius.circular(
            SizeConfig.blockSizeHorizontal * 10,
          ),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        tabs: [
          Tab(text: particulierLabel),
          Tab(text: professionnelLabel),
        ],
      ),
    );
  }
}
