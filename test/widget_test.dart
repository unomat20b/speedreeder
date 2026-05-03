import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:speedreeder/app.dart';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  await EasyLocalization.ensureInitialized();

  testWidgets('App builds', (WidgetTester tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('ru')],
        path: 'langs',
        fallbackLocale: const Locale('en'),
        child: const SpeedreederApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Speedreeder'), findsWidgets);
  });
}
