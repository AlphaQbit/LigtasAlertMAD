import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ligtasalert/home_page.dart';
import 'package:ligtasalert/login_page.dart';
import 'package:ligtasalert/main.dart';
import 'package:ligtasalert/services/auth_service.dart';

/// Stands in for the Laravel backend so tests never hit the network.
class FakeAuthService extends AuthService {
  FakeAuthService({this.failWith, this.succeeds = true});

  /// When set, login/register throw this instead of succeeding.
  final String? failWith;
  final bool succeeds;

  int loginCalls = 0;
  int registerCalls = 0;
  int microsoftCalls = 0;

  @override
  Future<AuthResult> login(String email, String password) async {
    loginCalls++;
    if (failWith != null) throw AuthException(failWith!);

    return AuthResult(
      user: AuthUser(id: 1, name: 'Kyla Flores', email: email),
      token: '1|faketoken',
    );
  }

  @override
  Future<AuthResult> register(String name, String email, String password) async {
    registerCalls++;
    if (failWith != null) throw AuthException(failWith!);

    return AuthResult(
      user: AuthUser(id: 2, name: name, email: email),
      token: '1|faketoken',
    );
  }

  @override
  Future<({String url, String state})> microsoftStart() async {
    microsoftCalls++;
    if (failWith != null) throw AuthException(failWith!);

    return (url: 'https://login.microsoftonline.com/authorize', state: 'state123');
  }

  @override
  Future<AuthResult> microsoftFinish(String state) async {
    if (failWith != null) throw AuthException(failWith!);

    return AuthResult(
      user: const AuthUser(id: 3, name: 'Kyla Flores', email: 'kyla@example.com'),
      token: '1|msftoken',
    );
  }

  /// No previous session in tests, so startup goes straight to the login page.
  @override
  Future<AuthUser?> restoreSession() async => null;

  @override
  Future<void> logout() async {}

  @override
  void close() {}
}

void main() {
  final emailField = find.widgetWithText(TextFormField, 'Email');
  final passwordField = find.widgetWithText(TextFormField, 'Password');

  Future<void> pumpAt(
    WidgetTester tester,
    Size size, {
    AuthService? auth,
    VoidCallback? onLoggedIn,
    ValueChanged<String>? onOpenUrl,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(
          auth: auth,
          onLoggedIn: onLoggedIn,
          // Never launch a real browser from a test. Recording the URL proves
          // the app opens the consent page before polling for a token.
          openUrl: (url) async {
            onOpenUrl?.call(url);
            return true;
          },
        ),
      ),
    );
  }

  /// Pumps until [finder] matches, or fails after a bounded number of frames.
  /// Use this instead of pumpAndSettle whenever an infinite spinner may be on
  /// screen, since the frame scheduler then never goes idle.
  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (finder.evaluate().isNotEmpty) return;
    }

    fail('$finder never appeared');
  }

  /// The login card grew a name field and a Microsoft button, so on a 640px
  /// test viewport the lower controls sit off-screen. Scroll them into view
  /// before tapping, exactly as a real user would.
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> fillCredentials(WidgetTester tester) async {
    await tester.enterText(find.widgetWithText(TextFormField, 'Full name'), 'Kyla Flores');
    await tester.enterText(emailField, 'kyle@campus.edu');
    await tester.enterText(passwordField, 'secret123');
    await tester.pump();
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

    await tester.enterText(emailField, 'kyle@campus.edu');
    await tester.pump();

    button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Log In'),
    );
    expect(button.onPressed, isNull);

    await tester.enterText(passwordField, 'secret123');
    await tester.pump();

    button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Log In'),
    );
    expect(button.onPressed, isNotNull);
  });

  // Regression: login used to be a stub that never called the backend.
  testWidgets('valid credentials call the backend and then onLoggedIn', (tester) async {
    final auth = FakeAuthService();
    var loggedIn = false;

    await pumpAt(
      tester,
      const Size(360, 640),
      auth: auth,
      onLoggedIn: () => loggedIn = true,
    );

    await fillCredentials(tester);
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Log In'));

    expect(auth.loginCalls, 1);
    expect(loggedIn, isTrue);
  });

  // The whole point: a wrong password must say so, not silently pass.
  testWidgets('a rejected password shows the backend message', (tester) async {
    final auth = FakeAuthService(
      failWith: 'These credentials do not match our records.',
    );
    var loggedIn = false;

    await pumpAt(
      tester,
      const Size(360, 640),
      auth: auth,
      onLoggedIn: () => loggedIn = true,
    );

    await fillCredentials(tester);
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Log In'));

    expect(auth.loginCalls, 1);
    expect(loggedIn, isFalse);
    expect(
      find.text('These credentials do not match our records.'),
      findsOneWidget,
    );
  });

  testWidgets('creating an account posts to register', (tester) async {
    final auth = FakeAuthService();
    var loggedIn = false;

    await pumpAt(
      tester,
      const Size(360, 640),
      auth: auth,
      onLoggedIn: () => loggedIn = true,
    );

    await fillCredentials(tester);
    await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Create an account'));

    expect(auth.registerCalls, 1);
    expect(loggedIn, isTrue);
  });

  testWidgets('microsoft sign in completes and logs in', (tester) async {
    final auth = FakeAuthService();
    var loggedIn = false;
    String? openedUrl;

    await pumpAt(
      tester,
      const Size(360, 640),
      auth: auth,
      onLoggedIn: () => loggedIn = true,
      onOpenUrl: (url) => openedUrl = url,
    );

    await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Continue with Microsoft'));

    expect(auth.microsoftCalls, 1);
    // The app used to fetch the consent URL and throw it away, then poll for
    // a token that could never arrive. Assert it really opens the page.
    expect(openedUrl, 'https://login.microsoftonline.com/authorize');
    expect(loggedIn, isTrue);
  });


  testWidgets('failed microsoft sign in shows a message', (tester) async {
    final auth = FakeAuthService(failWith: 'Microsoft sign-in failed.');
    var loggedIn = false;

    await pumpAt(
      tester,
      const Size(360, 640),
      auth: auth,
      onLoggedIn: () => loggedIn = true,
    );

    await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Continue with Microsoft'));

    expect(loggedIn, isFalse);
    expect(find.text('Microsoft sign-in failed.'), findsOneWidget);
  });

  testWidgets('forgot password explains how to get help', (tester) async {
    await pumpAt(tester, const Size(360, 640));

    await tapVisible(tester, find.text('Forgot password?'));

    expect(find.text('Reset your password'), findsOneWidget);
    expect(find.textContaining('security office'), findsOneWidget);
  });

  testWidgets('invalid email shows a validation error without calling the API', (tester) async {
    final auth = FakeAuthService();
    await pumpAt(tester, const Size(360, 640), auth: auth);

    await tester.enterText(emailField, 'not-an-email');
    await tester.enterText(passwordField, 'secret123');
    await tester.pump();

    await tapVisible(tester, find.widgetWithText(FilledButton, 'Log In'));

    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(auth.loginCalls, 0);
  });

  // Drives the real wiring in main.dart, so the app can still leave login.
  testWidgets('logging in navigates to HomePage', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // LigtasApp checks for a stored session on startup. Inject a fake so this
    // does not touch shared_preferences, a platform channel that does not exist
    // under flutter_test.
    final auth = FakeAuthService();
    await tester.pumpWidget(LigtasApp(auth: auth));

    // The restore check gates the login screen behind a future, so wait for
    // the form to appear. Bounded pumps, not pumpAndSettle: the startup
    // spinner is an infinite CircularProgressIndicator and never settles.

    await waitFor(tester, emailField);

    await tester.enterText(emailField, 'kyle@campus.edu');
    await tester.enterText(passwordField, 'secret123');
    await tester.pump();

    await tapVisible(tester, find.widgetWithText(FilledButton, 'Log In'));

    // The fake resolves, so the app must actually switch to the home page.
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Email'), findsNothing);
  });
}
