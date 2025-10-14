// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synq_manager/src/core/isolate_helper.dart';

import 'package:synq_manager_example/main.dart';

void main() {
  setUpAll(() {
    // Disable the long-lived isolate for widget tests to prevent timeouts.
    IsolateHelper.disableForTests = true;
  });

  testWidgets('Adds and displays a task', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // The app starts with a loading indicator.
    // We use pump() instead of pumpAndSettle() to avoid timeouts caused by
    // the periodic auto-sync timer in the background.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // pumpAndSettle is better here to ensure the UI is stable. We give it a
    // generous timeout to account for async initialization.
    await tester.pumpAndSettle(
        const Duration(seconds: 2),);

    // Verify that no tasks are displayed initially.
    expect(find.text('No tasks yet'), findsOneWidget);
    expect(find.text('My first task'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle(); // Wait for the dialog to appear.

    // Verify the dialog is open.
    expect(find.text('Add Task'), findsOneWidget);

    // Enter 'My first task' into the TextField.
    await tester.enterText(find.byType(TextField), 'My first task');

    // Tap the 'Add' button.
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle(); // Wait for the UI to update.

    // Verify that the new task is displayed.
    expect(find.text('My first task'), findsOneWidget);
  });
}
