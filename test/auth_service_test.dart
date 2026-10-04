import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ligtasalert/services/auth_service.dart';
import 'package:ligtasalert/services/token_store.dart';

/// Builds an AuthService wired to a fake backend and an in-memory token store.
({AuthService auth, MemoryTokenStore store, List<String> calls}) build({
  required http.Response Function(http.Request request) handler,
  MemoryTokenStore? store,
}) {
  final calls = <String>[];
  final client = MockClient((request) async {
    calls.add('${request.method} ${request.url.path}');
    return handler(request);
  });

  // One store instance shared by the service and the assertions. Building two
  // would make every stored-token read come back null.
  final resolvedStore = store ?? MemoryTokenStore();

  return (
    auth: AuthService(
      baseUrl: 'http://localhost:8000',
      client: client,
      store: resolvedStore,
      // Never really wait in tests.
      pollInterval: Duration.zero,
      maxPolls: 3,
    ),
    store: resolvedStore,
    calls: calls,
  );
}

http.Response json(Map<String, dynamic> body, [int status = 200]) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

void main() {
  group('token persistence', () {
    test('login stores the token for the next launch', () async {
      final built = build(
        handler: (_) => json({
          'token': '1|abc',
          'user': {'id': 1, 'name': 'Kyla', 'email': 'kyla@example.com'},
        }),
      );

      await built.auth.login('kyla@example.com', 'secret123');

      expect(await built.store.read(), '1|abc');
    });

    test('register and Microsoft sign-in store the token too', () async {
      final register = build(
        handler: (_) => json({
          'token': '1|reg',
          'user': {'id': 2, 'name': 'Kyla', 'email': 'k@example.com'},
        }),
      );
      await register.auth.register('Kyla', 'k@example.com', 'secret123');
      expect(await register.store.read(), '1|reg');

      final microsoft = build(
        handler: (request) {
          if (request.url.path.endsWith('/start')) {
            return json({'url': 'https://login.example', 'state': 's1'});
          }
          return json({
            'token': '1|ms',
            'user': {'id': 3, 'name': 'Kyla', 'email': 'm@example.com'},
          });
        },
      );
      final start = await microsoft.auth.microsoftStart();
      await microsoft.auth.microsoftFinish(start.state);
      expect(await microsoft.store.read(), '1|ms');
    });

    test('a stored token is verified against the backend on startup', () async {
      final store = MemoryTokenStore('1|saved');
      final built = build(
        store: store,
        handler: (_) => json({
          'user': {'id': 1, 'name': 'Kyla', 'email': 'kyla@example.com'},
        }),
      );

      final user = await built.auth.restoreSession();

      expect(user?.email, 'kyla@example.com');
      expect(built.auth.isSignedIn, isTrue);
      expect(built.calls, contains('GET /api/auth/me'));
    });

    test('a revoked token drops back to signed out and is cleared', () async {
      final store = MemoryTokenStore('1|stale');
      final built = build(
        store: store,
        handler: (_) => json({'message': 'Unauthenticated.'}, 401),
      );

      final user = await built.auth.restoreSession();

      expect(user, isNull);
      expect(built.auth.isSignedIn, isFalse);
      expect(await store.read(), isNull);
    });

    test('no stored token means nothing to restore', () async {
      final built = build(
        handler: (_) => json({'message': 'should not be called'}),
      );

      expect(await built.auth.restoreSession(), isNull);
      expect(built.auth.isSignedIn, isFalse);
      expect(built.calls, isEmpty);
    });

    test('logout clears the stored token', () async {
      final store = MemoryTokenStore('1|abc');
      final built = build(
        store: store,
        handler: (_) => json({'message': 'Signed out.'}),
      );

      await built.auth.logout();

      expect(await store.read(), isNull);
      expect(built.auth.isSignedIn, isFalse);
    });
  });

  group('microsoft polling ceiling', () {
    test('keeps polling past the old 2-minute limit', () async {
      var finishCalls = 0;

      // Pending for longer than the old 120-poll ceiling, then success.
      final service = AuthService(
        baseUrl: 'http://localhost:8000',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/start')) {
            return json({'url': 'https://login.example', 'state': 's1'});
          }
          finishCalls++;
          if (finishCalls <= 120) {
            return json({'pending': true}, 404);
          }
          return json({
            'token': '1|late',
            'user': {'id': 4, 'name': 'Kyla', 'email': 'late@example.com'},
          });
        }),
        store: MemoryTokenStore(),
        pollInterval: Duration.zero,
        maxPolls: 200,
      );

      final start = await service.microsoftStart();
      final result = await service.microsoftFinish(start.state);

      expect(finishCalls, greaterThan(120));
      expect(result.token, '1|late');
    });

    test('gives up with a readable message once the ceiling is hit', () async {
      final built = build(
        handler: (request) {
          if (request.url.path.endsWith('/start')) {
            return json({'url': 'https://login.example', 'state': 's1'});
          }
          return json({'pending': true}, 404);
        },
      );

      final start = await built.auth.microsoftStart();

      await expectLater(
        built.auth.microsoftFinish(start.state),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('timed out'),
          ),
        ),
      );
    });
  });
}