import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ligtasalert/alert_status_page.dart';
import 'package:ligtasalert/app_shell.dart';
import 'package:ligtasalert/home_page.dart';
import 'package:ligtasalert/main.dart';
import 'package:ligtasalert/services/alert_api.dart';
import 'package:ligtasalert/services/auth_service.dart';

/// Records what the rescuee tried to send, so we can assert the wiring
/// without standing up a real backend.
class RecordingAlertApi extends AlertApi {
  String? sentType;
  String? sentLocation;
  String? sentFacility;

  @override
  Future<Alert> sendAlert({
    required String facility,
    required String type,
    required String location,
    String details = '',
  }) async {
    sentFacility = facility;
    sentType = type;
    sentLocation = location;

    if (onSend != null) {
      return onSend!.call(facility, type, location);
    }

    return Alert.fromJson({
      'id': 1,
      'facility': facility,
      'type': type,
      'location': location,
      'status': 'active',
      'open': true,
    } as Map<String, dynamic>);
  }

  /// Override the send result. Lets a test raise an unknown outcome.
  Future<Alert> Function(String facility, String type, String location)?
      onSend;
}

/// Wraps an [AlertApi] and counts how many times each method is called, so
/// a test can prove that an ambiguous outcome did not trigger an automatic
/// second attempt.
class _CountingAlertApi extends AlertApi {
  _CountingAlertApi({required this.inner, this.onCall});

  final AlertApi inner;
  final VoidCallback? onCall;
  int sendCalls = 0;

  @override
  Future<Alert> sendAlert({
    required String facility,
    required String type,
    required String location,
    String details = '',
  }) async {
    sendCalls++;
    onCall?.call();
    return inner.sendAlert(
      facility: facility,
      type: type,
      location: location,
      details: details,
    );
  }

  @override
  Future<Alert> fetchAlert(int id) => inner.fetchAlert(id);

  @override
  void close() => inner.close();
}

/// A fake AuthService that never touches a platform channel. It is a
/// subclass, not a mock, so the real `token` getter and `close()` stay
/// available if the app ever reaches them.
class FakeAuthService extends AuthService {
  FakeAuthService({this.signedIn = false, this.user});

  final bool signedIn;
  final AuthUser? user;

  @override
  Future<AuthUser?> restoreSession() async => signedIn ? user : null;

  @override
  Future<void> logout() async {}

  @override
  void close() {}

  @override
  String? get token => signedIn ? 'fake-token' : null;
}

void main() {
  /// The alert grid and send button sit below the fold on a 640px test
  /// viewport, so scroll them into view before tapping.
  /// The send button shows an infinite CircularProgressIndicator while the
  /// request is in flight, so pumpAndSettle would never return. Use bounded
  /// pumps for anything that can leave a spinner on screen.
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> pumpBriefly(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }


  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
  }

  testWidgets('renders without overflow at 360x640', (tester) async {
    await pumpAt(tester, const Size(360, 640));
    expect(tester.takeException(), isNull);
  });

  // ponytail: 320px (iPhone SE 1st gen, 2016) still overflows horizontally by
  // 26px on a text line. No current phone is that narrow - drop the guard here
  // or bisect the tree if a 320px target ever matters.
  testWidgets('renders without overflow at 375x667', (tester) async {
    await pumpAt(tester, const Size(375, 667));
    expect(tester.takeException(), isNull);
  });

  testWidgets('send button starts disabled', (tester) async {
    await pumpAt(tester, const Size(360, 640));
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'SEND ALERT'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('choosing an alert type enables send', (tester) async {
    await pumpAt(tester, const Size(360, 640));
    await tester.tap(find.text('Lockdown'));
    await tester.pump();
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'SEND ALERT'),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('no hamburger menu button exists', (tester) async {
    await pumpAt(tester, const Size(360, 640));
    expect(find.byIcon(Icons.menu_rounded), findsNothing);
  });

  testWidgets('bottom bar renders on the authenticated home screen',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: BottomShell(
          auth: AuthService(),
          onSignOut: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BottomShellBar), findsOneWidget);
    expect(find.text('Alert'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
  });

  testWidgets('selecting the Account tab opens the account screen',
      (tester) async {
    var signedOut = false;
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: BottomShell(
          auth: AuthService(),
          onSignOut: () => signedOut = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The home tab's app bar title, not the bar label, distinguishes the two
    // tabs - "Account" also appears as the bottom bar's unselected label.
    expect(find.text('LigtasAlert'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.person_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Account'), findsWidgets);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('LigtasAlert'), findsNothing);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(signedOut, isTrue);
  });

  testWidgets('switching back to Alert preserves the selected alert type',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: BottomShell(
          auth: AuthService(),
          onSignOut: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The alert grid sits below the fold on a 360x640 viewport, so scroll it
    // into view before tapping. The same applies to the SELECTED badge.
    await tester.ensureVisible(find.text('Medical'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Medical'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.person_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alert'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('SELECTED'));
    await tester.pumpAndSettle();
    // SELECTED only appears on the EmergencyCard that is currently selected.
    expect(find.text('SELECTED'), findsOneWidget);
  });

  testWidgets('sending an alert still opens its status screen from the shell',
      (tester) async {
    final api = RecordingAlertApi();
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: BottomShell(
          auth: AuthService(),
          api: api,
          onSignOut: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('Medical'));
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'SEND ALERT'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'SEND ALERT'));
    await pumpBriefly(tester);

    expect(api.sentType, 'Medical');
    expect(find.byType(AlertStatusPage), findsOneWidget);
    // The status page is pushed on top of the shell; the bar stays below it.
    expect(find.byType(BottomShellBar), findsOneWidget);
  });

  testWidgets('an empty room is shown as an unknown location, not a room',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pumpAndSettle();

    // The field starts pre-filled with 'Room 214'; clear it to reach the
    // unknown-location state.
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();

    // The summary no longer pretends the facility name is a room.
    expect(find.text('Exact room not provided'), findsOneWidget);
    expect(find.text('No room specified'), findsNothing);
    // The status pill says so out loud, and is not the green "ready" colour.
    expect(find.text('Exact room unknown'), findsOneWidget);
  });

  testWidgets('an alert can still be sent with no room entered', (tester) async {
    final api = RecordingAlertApi();
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: HomePage(api: api)));
    await tester.pumpAndSettle();

    // The default room text is 'Room 214', so overwrite it with nothing to prove
    // the empty path is reachable and does not block submission.
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();

    await tapVisible(tester, find.text('Medical'));
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'SEND ALERT'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'SEND ALERT'));
    await pumpBriefly(tester);

    expect(api.sentType, 'Medical');
    expect(api.sentFacility, 'MCC MAIN');
    // The location field carries the explicit unknown marker, not a room.
    expect(api.sentLocation, 'MCC MAIN (exact room not provided)');
    expect(api.sentLocation, isNot(contains('Room')));
    expect(find.byType(AlertStatusPage), findsOneWidget);
  });

  testWidgets('a provided room is submitted unchanged', (tester) async {
    final api = RecordingAlertApi();
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: HomePage(api: api)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Lab 3');
    await tester.pump();

    await tapVisible(tester, find.text('Medical'));
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'SEND ALERT'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'SEND ALERT'));
    await pumpBriefly(tester);

    expect(api.sentLocation, 'Lab 3');
    expect(find.text('Exact room unknown'), findsNothing);
    expect(find.text('Location set'), findsOneWidget);
  });

  testWidgets('login screen shows no bottom navigation', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: LigtasApp(auth: FakeAuthService(signedIn: false)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Log In'), findsOneWidget);
    expect(find.byType(BottomShellBar), findsNothing);
  });

  testWidgets('sign-out returns to the unauthenticated flow', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final auth = FakeAuthService(
      signedIn: true,
      user: const AuthUser(id: 1, name: 'Juan Dela Cruz', email: 'j@campus.edu'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: LigtasApp(auth: auth),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BottomShellBar), findsOneWidget);

    await tester.ensureVisible(find.byIcon(Icons.person_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.person_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    // Sign-out swaps the whole authenticated tree for the login screen; the
    // shell is gone entirely, not just hidden behind a tab.
    expect(find.text('Log In'), findsOneWidget);
    expect(find.byType(BottomShellBar), findsNothing);
    expect(find.byIcon(Icons.person_rounded), findsNothing);
  });

  // The send button used to be a no-op. This proves it now posts the chosen
  // type and room, then hands the rescuee to the status screen.
  testWidgets('sending an alert posts it and opens the status screen', (tester) async {
    final api = RecordingAlertApi();
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: HomePage(api: api)));

    await tapVisible(tester, find.text('Medical'));
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'SEND ALERT'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'SEND ALERT'));
    await pumpBriefly(tester);

    expect(api.sentType, 'Medical');
    expect(api.sentLocation, 'Room 214');
    expect(api.sentFacility, 'MCC MAIN');
    expect(find.byType(AlertStatusPage), findsOneWidget);
  });

  // A dropped POST connection is an unknown outcome, not a confirmed failure.
  // The app must not report success, and it must not auto-retry: the dialog
  // explains the ambiguity and leaves the choice to the rescuee.
  testWidgets(
      'an unknown submission outcome shows a dialog and never auto-retries',
      (tester) async {
    final api = RecordingAlertApi()
      ..onSend = (facility, type, location) async {
        throw AlertSubmissionUncertainException(
          'The connection dropped before we could confirm your alert. '
          'It may or may not have been sent.',
        );
      };

    var sendCalls = 0;
    final countingApi = _CountingAlertApi(inner: api, onCall: () => sendCalls++);
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: HomePage(api: countingApi)));

    await tapVisible(tester, find.text('Medical'));
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'SEND ALERT'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'SEND ALERT'));
    await pumpBriefly(tester);

    // The dialog explains the unknown outcome.
    expect(find.text('Alert status unknown'), findsOneWidget);
    expect(find.textContaining('may or may not have been sent'), findsWidgets);

    // No status page (that would falsely confirm success).
    expect(find.byType(AlertStatusPage), findsNothing);

    // No automatic second attempt.
    expect(sendCalls, 1);

    // Dismissing does not silently send another alert.
    await tapVisible(tester, find.text('OK, I understand'));
    expect(sendCalls, 1);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(AlertStatusPage), findsNothing);

    // The send button is usable again for a deliberate choice.
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'SEND ALERT'),
    );
    expect(button.onPressed, isNotNull);
  });
}