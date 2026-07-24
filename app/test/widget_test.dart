import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiluxos/core/theme/colors.dart';

void main() {
  testWidgets('AppColors sanity check', (WidgetTester tester) async {
    expect(AppColors.background, const Color(0xFF0d1117));
    expect(AppColors.primary, const Color(0xFF58a6ff));
  });

  testWidgets('MaterialApp builds a card', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('hiluxOS'))),
    );
    expect(find.text('hiluxOS'), findsOneWidget);
  });
}