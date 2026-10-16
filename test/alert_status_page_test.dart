import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ligtasalert/alert_status_page.dart';
import 'package:ligtasalert/constants.dart';
import 'package:ligtasalert/services/alert_api.dart';

/// Stands in for the Laravel backend so the test drives status changes itself.
class FakeAlertApi extends AlertApi {
  FakeAlertApi(this.status);

  String status;

  @override
  Future<Alert> fetchAlert(int id) async => Alert.fromJson({
        'id': id,
        'user_id': 1,
        'facility': 'MCC MAIN',
        'type': 'Medical',
        'location': 'Room 204',
        'status': status,
        'open': status != kStatusResolved,
        'response_seconds': status == kStatusActive ? null : 12,
      } as Map<String, dynamic>);

  @override
  Future<Alert> sendAlert({
    required String facility,
    required String type,
    required String location,
    String details = '',
  }) =>
      throw UnimplementedError();
}

Alert buildAlert({String status = kStatusActive}) => Alert.fromJson({
      'id': 1,
      'user_id': 1,
      'facility': 'MCC MAIN',
      'type': 'Medical',
      'location': 'Room 204',
      'status': status,
      'open': status != kStatusResolved,
    } as Map<String, dynamic>);

void main() {
  /// The status card shows an infinite spinner while the alert is open, so
  /// pumpAndSettle never settles. Everything on this page must use bounded
  /// pumps instead.
  Future<void> pumpBriefly(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// The status page is a scroll view; scroll a target into view before
  /// asserting on it so off-screen-but-present widgets still count.
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await pumpBriefly(tester);
  }

  Future<void> pumpStatus(WidgetTester tester, AlertApi api) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: AlertStatusPage(alert: buildAlert(), api: api)),
    );
  }

  testWidgets('shows the sent state and the alert details', (tester) async {
    await pumpStatus(tester, FakeAlertApi(kStatusActive));

    // "Alert Sent" shows in both the app bar and the status card, so assert on
    // the card's own copy plus the alert details instead.
    expect(find.text('Help is on the way. Stay where you are.'), findsOneWidget);
    await scrollTo(tester, find.text('MCC MAIN'));
    expect(find.text('MCC MAIN'), findsOneWidget);
    expect(find.text('Room 204'), findsOneWidget);
    expect(find.text('#1'), findsOneWidget);
  });

  testWidgets('renders without overflow on a small phone', (tester) async {
    await pumpStatus(tester, FakeAlertApi(kStatusActive));
    expect(tester.takeException(), isNull);
  });

  // The whole point of the integration: a rescuer acknowledging on the web
  // has to show up on the rescuee's screen without them doing anything.
  testWidgets('reflects a rescuer acknowledgement on the next poll', (tester) async {
    final api = FakeAlertApi(kStatusActive);
    await pumpStatus(tester, api);

    expect(find.text('Help Is On The Way'), findsNothing);

    api.status = kStatusAcknowledged;
    await tester.pump(const Duration(seconds: 5));
    await pumpBriefly(tester);

    expect(find.text('Help Is On The Way'), findsOneWidget);
    expect(find.text('12s'), findsOneWidget);
  });

  testWidgets('shows resolved as the end of the line', (tester) async {
    final api = FakeAlertApi(kStatusResolved);
    await pumpStatus(tester, api);
    await tester.pump(const Duration(seconds: 5));
    await pumpBriefly(tester);

    expect(find.text('Resolved'), findsWidgets);
    expect(find.text('Updating automatically...'), findsNothing);
  });
}