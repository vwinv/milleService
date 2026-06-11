import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:milleservices/app/app_root.dart';
import 'package:milleservices/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      buildMilleServicesApp(
        child: const AppRoot(),
        startLocale: const Locale('fr'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
  }

  testWidgets('Commencer flow welcome to settings', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('welcome_start'.tr()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('choose_profile_continue'.tr()));
    await tester.pumpAndSettle();

    expect(find.text('settings_choose_language'.tr()), findsOneWidget);

    await tester.tap(find.text('abonnement_start'.tr()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
  });
}
