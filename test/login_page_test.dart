import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ligtasalert/home_page.dart';
import 'package:ligtasalert/login_page.dart';
import 'package:ligtasalert/main.dart';

void main() {
  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
  }

  testWidgets('renders without overflow at 360x640', (tester) async {
    await pumpAt(tester, const Size(360, 640));
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders without overflow at 375x667', (tester) async {
    await pumpAt(tester, const Size(375, 667));
    expect(tester.takeException(), isNull);
  });

  testWidgets('log in starts disabled until both fields are filled', (tester) async {
    await pumpAt(tester, const Size(360, 640));

    var button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Log In'),
    );
    expect(button.onPressed, isNull);

    await tester.enterText(find.byType(TextFormField).first, 'kyle@campus.edu');
    await tester.pump();

    button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Log In'),
    );
    expect(button.onPressed, isNull);

    await tester.enterText(find.byType(TextFormField).last, 'secret123');
    await tester.pump();

    button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Log In'),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('valid credentials call onLoggedIn', (tester) async {
    var called = false;
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(
          onLoggedIn: () => called = true,
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField).first, 'kyle@campus.edu');
    await tester.enterText(find.byType(TextFormField).last, 'secret123');
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Log In'));
    await tester.pump();

    expect(called, isTrue);
  });

  // Regression: onLoggedIn used to be wired against LigtasApp's own context,
  // which sits above the Navigator MaterialApp installs, so Navigator.of()
  // threw and the real app could never leave the login screen. Stubbing
  // onLoggedIn out (as the test above does) hid it - this drives the real
  // wiring in main.dart and asserts we actually land on HomePage.
  testWidgets('logging in navigates to HomePage', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const LigtasApp());

    await tester.enterText(find.byType(TextFormField).first, 'kyle@campus.edu');
    await tester.enterText(find.byType(TextFormField).last, 'secret123');
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Log In'));
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('forgot password explains how to get help', (tester) async {
    await pumpAt(tester, const Size(360, 640));

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    expect(find.text('Reset your password'), findsOneWidget);
    expect(find.textContaining('security office'), findsOneWidget);
  });

  testWidgets('invalid email shows a validation error', (tester) async {
    await pumpAt(tester, const Size(360, 640));

    await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
    await tester.enterText(find.byType(TextFormField).last, 'secret123');
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Log In'));
    await tester.pump();

    expect(find.text('Enter a valid email'), findsOneWidget);
  });
}
