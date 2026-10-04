import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants.dart';
import 'token_store.dart';

/// The signed-in rescuee, as the backend returns them.
class AuthUser {
  const AuthUser({required this.id, required this.name, required this.email});

  final int id;
  final String name;
  final String email;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
      );
}

class AuthResult {
  const AuthResult({required this.user, required this.token});

  final AuthUser user;
  final String token;
}

class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thrown while waiting for the Microsoft browser round-trip. Not an error the
/// rescuee should ever see - the caller just keeps polling.
class AuthPendingException implements AuthException {
  @override
  String get message => 'pending';

  @override
  String toString() => message;
}

/// Talks to the Laravel auth endpoints and keeps the bearer token on disk.
///
/// ponytail: the token always persists, no "remember me" checkbox. A rescuee
/// being logged out mid-emergency because the app restarted is worse than the
/// small risk of a stale token on a shared device, and restoreSession() checks
/// the token against the backend before trusting it anyway.
class AuthService {
  AuthService({
    String? baseUrl,
    http.Client? client,
    TokenStore? store,
    Duration pollInterval = const Duration(seconds: 2),
    int maxPolls = 150,
  })  : baseUrl = baseUrl ?? kApiBase,
        _client = client ?? http.Client(),
        _store = store ?? SharedPrefsTokenStore(),
        _pollInterval = pollInterval,
        _maxPolls = maxPolls;

  final String baseUrl;
  final http.Client _client;
  final TokenStore _store;
  final Duration _pollInterval;
  final int _maxPolls;

  String? _token;

  String? get token => _token;
  bool get isSignedIn => _token != null;

  /// Take a token from the backend and remember it across restarts.
  void _adopt(String token) {
    _token = token;
    _store.write(token);
  }

  /// Rehydrate a previous session on startup.
  ///
  /// Verifies the stored token against /api/auth/me rather than trusting it, so
  /// a revoked or expired token drops the rescuee back to the login screen
  /// instead of failing on their first alert. Returns the signed-in user, or
  /// null when there is nothing usable to restore.
  Future<AuthUser?> restoreSession() async {
    final saved = await _store.read();
    if (saved == null) return null;

    try {
      final body = await _get('/api/auth/me', token: saved);
      _token = saved;

      return AuthUser.fromJson(body['user'] as Map<String, dynamic>);
    } on AuthException {
      // Stale, revoked, or the backend is down. Either way we cannot use it.
      await _store.clear();
      _token = null;

      return null;
    } catch (_) {
      // Storage itself can fail (no plugin registered, corrupt prefs). Falling
      // back to the login screen is always safe, so never crash startup on it.
      _token = null;

      return null;
    }
  }

  static const _timeout = Duration(seconds: 10);

  static const _headers = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  Future<AuthResult> login(String email, String password) async {
    final body = await _post('/api/auth/login', {
      'email': email,
      'password': password,
    });

    _adopt(body['token'] as String);
    return AuthResult(
      user: AuthUser.fromJson(body['user'] as Map<String, dynamic>),
      token: _token!,
    );
  }

  Future<AuthResult> register(String name, String email, String password) async {
    final body = await _post('/api/auth/register', {
      'name': name,
      'email': email,
      'password': password,
      'password_confirmation': password,
    });

    _adopt(body['token'] as String);
    return AuthResult(
      user: AuthUser.fromJson(body['user'] as Map<String, dynamic>),
      token: _token!,
    );
  }

  /// Step one of Microsoft sign-in: the URL to open in a browser.
  Future<({String url, String state})> microsoftStart() async {
    final body = await _get('/api/auth/microsoft/start');

    return (
      url: body['url'] as String,
      state: body['state'] as String,
    );
  }

  /// Step two: poll until the browser callback has delivered a token.
  /// Throws a readable message if the user cancels or it times out.
  Future<AuthResult> microsoftFinish(String state) async {
    // 150 polls x 2s = 5 minutes. The backend caches the state for 10, so
    // polling has to outlast "user picked an account and came back" without
    // giving up while they were still legitimately signing in.
    for (var attempt = 0; attempt < _maxPolls; attempt++) {
      try {
        final body = await _get('/api/auth/microsoft/finish?state=$state');

        _adopt(body['token'] as String);
        return AuthResult(
          user: AuthUser.fromJson(body['user'] as Map<String, dynamic>),
          token: _token!,
        );
      } on AuthPendingException {
        await Future<void>.delayed(_pollInterval);
      }
    }

    throw AuthException('Microsoft sign-in timed out. Please try again.');
  }

  Future<void> logout() async {
    final token = _token;
    _token = null;
    await _store.clear();

    if (token == null) return;

    try {
      await _client
          .post(
            Uri.parse('$baseUrl/api/auth/logout'),
            headers: {..._headers, 'Authorization': 'Bearer $token'},
          )
          .timeout(_timeout);
    } on http.ClientException {
      // Signing out locally is what matters; the token expires anyway.
    }
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    try {
      final response = await _client
          .post(Uri.parse('$baseUrl$path'), headers: _headers, body: jsonEncode(body))
          .timeout(_timeout);

      return _unwrap(response);
    } on http.ClientException {
      throw AuthException('Cannot reach the rescue service. Check your connection.');
    }
  }

  Future<Map<String, dynamic>> _get(String path, {String? token}) async {
    try {
      final response = await _client
          .get(
            Uri.parse('$baseUrl$path'),
            headers: token == null
                ? _headers
                : {..._headers, 'Authorization': 'Bearer $token'},
          )
          .timeout(_timeout);

      return _unwrap(response);
    } on http.ClientException {
      throw AuthException('Cannot reach the rescue service. Check your connection.');
    }
  }

  Map<String, dynamic> _unwrap(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw AuthException(_messageFor(response.statusCode, response.body));
  }

  String _messageFor(int statusCode, String body) {
    // The app polls /finish until the callback lands; 404 is the "wait" signal.
    if (statusCode == 404 && body.contains('pending')) {
      throw AuthPendingException();
    }

    if (statusCode == 422) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic> && decoded['errors'] is Map) {
          final first = (decoded['errors'] as Map).values.first;
          if (first is List && first.isNotEmpty) return first.first.toString();
        }
      } on FormatException {
        // Fall through.
      }
    }

    if (statusCode == 401) return 'These credentials do not match our records.';

    return 'Sign-in failed (error $statusCode).';
  }

  void close() => _client.close();
}