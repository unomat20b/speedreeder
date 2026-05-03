import 'package:flutter_test/flutter_test.dart';

import 'package:speedreeder/app.dart';

void main() {
  testWidgets('App builds', (WidgetTester tester) async {
    await tester.pumpWidget(const SpeedreederApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Speedreeder'), findsWidgets);
  });
}
