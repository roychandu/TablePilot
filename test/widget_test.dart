// This is a basic Flutter widget test for Cafe Management app.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';

import 'package:table_pilot/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Set up method channels for testing
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/firebase_core'),
          (MethodCall methodCall) async {
            return null;
          },
        );
  });

  tearDownAll(() {
    // Clean up method channels
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/firebase_core'),
          null,
        );
  });

  testWidgets('Cafe Management app builds successfully', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify that the app builds without errors
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('Cafe Management app has correct title', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify that the app title is set correctly
    final MaterialApp app = tester.widget(find.byType(MaterialApp));
    expect(app.title, 'Cafe Management');
  });
}
