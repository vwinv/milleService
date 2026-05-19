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

  testWidgets('App shows welcome when user is not logged in', (tester) async {
    await tester.pumpWidget(
      buildMilleServicesApp(
        child: const AppRoot(),
        startLocale: const Locale('fr'),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('login'.tr()), findsOneWidget);
  });
}
