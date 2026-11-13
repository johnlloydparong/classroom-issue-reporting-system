import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:classroom_issue_reporting/main.dart';

void main() {
  testWidgets(
    'Classroom Issue Reporting login screen displays correctly',
    (WidgetTester tester) async {
      await tester.pumpWidget(const ClassroomApp());

      // Check that the Week 14 login page appears.
      expect(
        find.text('Secure Login'),
        findsOneWidget,
      );

      // Verify the username field.
      expect(
        find.widgetWithText(TextField, 'Username'),
        findsOneWidget,
      );

      // Verify the password field.
      expect(
        find.widgetWithText(TextField, 'Password'),
        findsOneWidget,
      );

      // Verify the login button.
      expect(
        find.text('Login'),
        findsOneWidget,
      );
    },
  );
}
