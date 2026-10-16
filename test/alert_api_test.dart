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
          "user_id": 3,
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
      expect(alert.userId, 3);
      expect(alert.facility, 'MCC MAIN');
      expect(alert.type, 'Medical');
      expect(alert.status, 'acknowledged');
      expect(alert.open, isTrue);
      expect(alert.responseSeconds, 42);
    });

    // The rescuee must never see a null blow up mid-emergency.
    test('tolerates missing optional fields', () {
      final alert = Alert.fromJson({'id': 1, 'user_id': 0} as Map<String, dynamic>);

      expect(alert.facility, '');
      expect(alert.details, '');
      expect(alert.responseSeconds, isNull);
      expect(alert.status, 'active');
      expect(alert.open, isFalse);
      expect(alert.userId, 0);
    });

    // A missing id is not a recoverable default: it is the one field the
    // status page polls against, so inventing one would create an alert the
    // rescuee can never check.
    test('a missing id is a hard error, not a silent default', () {
      expect(
        () => Alert.fromJson({'facility': 'MCC MAIN'} as Map<String, dynamic>),
        throwsA(isA<AlertApiException>()),
      );
    });

    test('a non-numeric id is a hard error', () {
      expect(
        () => Alert.fromJson({'id': 'seven'} as Map<String, dynamic>),
        throwsA(isA<AlertApiException>()),
      );
    });

    test('a missing user_id is null, not user 0', () {
      final alert = Alert.fromJson({'id': 5} as Map<String, dynamic>);
      expect(alert.userId, isNull);
    });
  });

  group('bearer token', () {
    http.Response ok() => http.Response(
          jsonEncode({
            'data': {
              'id': 1,
              'user_id': 1,
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

  group('response envelopes', () {
    // The mobile project's own tests prove the data-wrapped shape. The
    // root-level shape is also handled explicitly because the real backend
    // envelope could not be verified; both are covered, and neither is
    // presented as proof of backend compatibility.
    final wrappedBody = jsonEncode({
      'data': {
        'id': 9,
        'facility': 'MCC MAIN',
        'type': 'Fire',
        'location': 'Room 214',
        'status': 'active',
        'open': true,
      },
    });

    final rootBody = jsonEncode({
      'id': 10,
      'facility': 'MCC MADAPDAP',
      'type': 'Medical',
      'location': 'Room 302',
      'status': 'active',
      'open': true,
    });

    http.Response body200(String body) => http.Response(body, 200);

    test('a data-wrapped alert parses', () async {
      final api = AlertApi(
        baseUrl: 'http://localhost:8000',
        client: MockClient((_) async => body200(wrappedBody)),
      );

      final alert = await api.fetchAlert(9);

      expect(alert.id, 9);
      expect(alert.facility, 'MCC MAIN');
    });

    test('a root-level alert parses', () async {
      final api = AlertApi(
        baseUrl: 'http://localhost:8000',
        client: MockClient((_) async => body200(rootBody)),
      );

      final alert = await api.fetchAlert(10);

      expect(alert.id, 10);
      expect(alert.facility, 'MCC MADAPDAP');
    });

    test('sendAlert accepts a data-wrapped success', () async {
      final api = AlertApi(
        baseUrl: 'http://localhost:8000',
        client: MockClient((_) async => body200(wrappedBody)),
      );

      final alert = await api.sendAlert(
        facility: 'MCC MAIN',
        type: 'Fire',
        location: 'Room 214',
      );

      expect(alert.id, 9);
    });

    test('malformed JSON on a 200 is a controlled error', () async {
      final api = AlertApi(
        baseUrl: 'http://localhost:8000',
        client: MockClient((_) async => body200('not json at all')),
      );

      await expectLater(
        api.fetchAlert(1),
        throwsA(
          isA<AlertApiException>().having(
            (e) => e.message,
            'message',
            contains('unexpected response'),
          ),
        ),
      );
    });

    test('a 200 with a JSON array is a controlled error', () async {
      final api = AlertApi(
        baseUrl: 'http://localhost:8000',
        client: MockClient((_) async => body200('[1, 2, 3]')),
      );

      await expectLater(
        api.fetchAlert(1),
        throwsA(
          isA<AlertApiException>().having(
            (e) => e.message,
            'message',
            contains('unexpected response'),
          ),
        ),
      );
    });

    test('a 200 with neither a data wrapper nor an id is a controlled error', () async {
      final api = AlertApi(
        baseUrl: 'http://localhost:8000',
        client: MockClient((_) async => body200('{"status":"active"}')),
      );

      await expectLater(
        api.fetchAlert(1),
        throwsA(
          isA<AlertApiException>().having(
            (e) => e.message,
            'message',
            contains('unexpected response'),
          ),
        ),
      );
    });

    test('a 200 whose alert map has no usable id fails to construct', () async {
      final api = AlertApi(
        baseUrl: 'http://localhost:8000',
        client: MockClient((_) async => body200('{"data":{"status":"active"}}')),
      );

      await expectLater(
        api.fetchAlert(1),
        throwsA(
          isA<AlertApiException>().having(
            (e) => e.message,
            'message',
            contains('could not read'),
          ),
        ),
      );
    });
  });

  group('ambiguous submission outcomes', () {
    // A POST that times out cannot be called a failure: the server may have
    // created the alert. The caller must be told the outcome is unknown.
    test('a POST timeout is an unknown outcome, not a confirmed failure', () async {
      final api = AlertApi(
        baseUrl: 'http://localhost:8000',
        client: MockClient((_) async {
          // Never answers, so the 10s timeout fires.
          return Future<http.Response>.delayed(
            const Duration(hours: 1),
            () => http.Response('{"data":{"id":1}}', 200),
          );
        }),
      );

      await expectLater(
        api.sendAlert(
          facility: 'MCC MAIN',
          type: 'Medical',
          location: 'Room 204',
        ),
        throwsA(
          isA<AlertSubmissionUncertainException>().having(
            (e) => e.message,
            'message',
            contains('may or may not have been sent'),
          ),
        ),
      );
    });

    // A GET timeout is safe to retry: a read cannot create a duplicate.
    test('a GET timeout stays a plain retryable error', () async {
      final api = AlertApi(
        baseUrl: 'http://localhost:8000',
        client: MockClient((_) async {
          return Future<http.Response>.delayed(
            const Duration(hours: 1),
            () => http.Response('{"data":{"id":1}}', 200),
          );
        }),
      );

      await expectLater(
        api.fetchAlert(1),
        throwsA(
          isA<AlertApiException>().having(
            (e) => e.message,
            'message',
            contains('took too long'),
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

  // A POST against a dead port cannot be confirmed as failed: the connection
  // dropped after the request went out, so the server may have it. The app
  // must report that honestly rather than inviting an immediate retry.
  test('sendAlert against a dead port reports an unknown outcome, not a failure', () async {
    final api = offlineApi();

    await expectLater(
      api.sendAlert(
        facility: 'MCC MAIN',
        type: 'Medical',
        location: 'Room 204',
      ),
      throwsA(isA<AlertSubmissionUncertainException>()),
    );

    api.close();
  });
}