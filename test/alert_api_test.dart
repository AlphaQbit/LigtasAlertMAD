import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ligtasalert/services/alert_api.dart';

void main() {
  // Point at a port nothing is listening on so no test can reach the network.
  AlertApi offlineApi() => AlertApi(baseUrl: 'http://127.0.0.1:1');

  group('Alert.fromJson', () {
    test('reads a payload from the Laravel resource', () {
      final alert = Alert.fromJson(jsonDecode('''
        {
          "id": 7,
          "facility": "MCC MAIN",
          "type": "Medical",
          "location": "Room 204",
          "details": "Person collapsed.",
          "status": "acknowledged",
          "open": true,
          "response_seconds": 42
        }
      ''') as Map<String, dynamic>);

      expect(alert.id, 7);
      expect(alert.facility, 'MCC MAIN');
      expect(alert.type, 'Medical');
      expect(alert.status, 'acknowledged');
      expect(alert.open, isTrue);
      expect(alert.responseSeconds, 42);
    });

    // The rescuee must never see a null blow up mid-emergency.
    test('tolerates missing optional fields', () {
      final alert = Alert.fromJson({'id': 1} as Map<String, dynamic>);

      expect(alert.facility, '');
      expect(alert.details, '');
      expect(alert.responseSeconds, isNull);
      expect(alert.status, 'active');
      expect(alert.open, isFalse);
    });
  });

  group('bearer token', () {
    http.Response ok() => http.Response(
          jsonEncode({
            'data': {
              'id': 1,
              'facility': 'MCC MAIN',
              'type': 'Medical',
              'location': 'Room 204',
              'status': 'active',
              'open': true,
            },
          }),
          200,
        );

    // Reading an alert needs a login on the backend, so the rescuee's token has
    // to ride along with the poll. It used to be dropped on the floor.
    test('fetchAlert sends the bearer token', () async {
      String? seen;
      final api = AlertApi(
        baseUrl: 'http://localhost:8000',
        token: '1|abc',
        client: MockClient((request) async {
          seen = request.headers['Authorization'];
          return ok();
        }),
      );

      await api.fetchAlert(1);

      expect(seen, 'Bearer 1|abc');
    });

    test('no token means no Authorization header', () async {
      String? seen = 'unset';
      final api = AlertApi(
        baseUrl: 'http://localhost:8000',
        client: MockClient((request) async {
          seen = request.headers['Authorization'];
          return ok();
        }),
      );

      await api.fetchAlert(1);

      expect(seen, isNull);
    });

    test('a 401 tells the rescuee to sign in again', () async {
      final api = AlertApi(
        baseUrl: 'http://localhost:8000',
        client: MockClient(
          (_) async => http.Response('{"message":"Unauthenticated."}', 401),
        ),
      );

      await expectLater(
        api.fetchAlert(1),
        throwsA(
          isA<AlertApiException>().having(
            (e) => e.message,
            'message',
            contains('sign in again'),
          ),
        ),
      );
    });
  });
  group('messageForStatus', () {
    final api = offlineApi();

    test('422 surfaces the first validation message', () {
      final message = api.messageForStatus(
        422,
        jsonEncode({
          'errors': {'facility': ['The facility field is required.']}
        }),
      );

      expect(message, 'The facility field is required.');
    });

    test('known statuses get a plain-language message', () {
      expect(api.messageForStatus(404, ''), 'That alert no longer exists.');
      expect(api.messageForStatus(500, ''), contains('having trouble'));
    });

    test('unknown status falls back to the code', () {
      expect(api.messageForStatus(418, ''), contains('418'));
    });
  });

  // A rescuee with no signal must get a human sentence, not a stack trace.
  test('unreachable backend becomes a readable AlertApiException', () async {
    final api = offlineApi();

    await expectLater(
      api.fetchAlert(1),
      throwsA(
        isA<AlertApiException>().having(
          (e) => e.message,
          'message',
          contains('Cannot reach the rescue service'),
        ),
      ),
    );

    api.close();
  });

  test('sendAlert against a dead port does not hang', () async {
    final api = offlineApi();

    await expectLater(
      api.sendAlert(
        facility: 'MCC MAIN',
        type: 'Medical',
        location: 'Room 204',
      ),
      throwsA(isA<AlertApiException>()),
    );

    api.close();
  });
}