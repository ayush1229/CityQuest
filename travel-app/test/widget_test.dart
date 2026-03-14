import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cityquest/features/auth/login_screen.dart';

void main() {
  testWidgets('Login screen renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginScreen()),
    );

    expect(find.text('CityQuest'), findsOneWidget);
    expect(find.text('Turn your city into an adventure'), findsOneWidget);
    expect(find.text('Start Exploring'), findsOneWidget);
  });
}
