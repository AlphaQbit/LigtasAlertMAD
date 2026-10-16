import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants.dart';

/// One alert as the Laravel backend returns it.
class Alert {
  const Alert({
    required this.id,
    required this.userId,
    required this.facility,
    required this.type,
    required this.location,
    required this.status,
    required this.open,
    this.details = '',
    this.responseSeconds,
  });

  final int id;
  final int? userId;
  final String facility;
  final String type;
  final String location;
  final String details;
  final String status;
  final bool open;
  final int? responseSeconds;

  factory Alert.fromJson(Map<String, dynamic> json) {
    // The id is the one field nothing works without: it starts the status
    // poll. A missing or non-numeric id means the backend sent something
    // that is not an alert, so say that instead of crashing on a cast or
    // inventing an id.
    final id = json['id'];
    if (id is! int) {
      throw AlertApiException(
        'The rescue service sent an alert we could not read. '
        'Please try sending again.',
      );
    }

    return Alert(
        id: id,
        // null, not 0: no id means "not reported", not "reported as user 0".
        userId: json['user_id'] is int ? json['user_id'] as int : null,
        facility: json['facility'] as String? ?? '',
        type: json['type'] as String? ?? '',
        location: json['location'] as String? ?? '',
        details: json['details'] as String? ?? '',
        status: json['status'] as String? ?? kStatusActive,
        open: json['open'] as bool? ?? false,
        responseSeconds: json['response_seconds'] as int?,
      );
  }
}

/// Thrown for anything the rescuee needs to be told about: no connection,
/// a rejected alert, or a server error.
class AlertApiException implements Exception {
  AlertApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thrown when the server accepted the request but stopped answering. The
/// alert may or may not have been created, so callers must treat this as an
/// unknown outcome, never as a confirmed failure and never as success.
///
/// A client-side guard cannot prevent a duplicate: without a server-side
/// idempotency key (not documented in the backend, unverified), a retry
/// after an unknown outcome may create a second alert.
class AlertSubmissionUncertainException implements Exception {
  AlertSubmissionUncertainException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Talks to the Laravel backend. All calls require authentication (Sanctum bearer token)
/// so every alert is tied to the rescuee's account and they can only read their own.
///
/// Uses package:http so the same code runs on web, mobile, and desktop.
class AlertApi {
  AlertApi({String? baseUrl, http.Client? client, this.token})
      : baseUrl = baseUrl ?? kApiBase,
        _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  /// Bearer token for reading alert status. The POST to /api/alerts is also
  /// authenticated (auth:sanctum), so the rescuee's AuthService token rides
  /// along with the send too whenever one is available. Reading one definitely
  /// requires a login, so the token has to travel with every status poll.
  final String? token;

  Future<Alert> sendAlert({
    required String facility,
    required String type,
    required String location,
    String details = '',
  }) async {
    final payload = await _request(
      'POST',
      '/api/alerts',
      body: {
        'facility': facility,
        'type': type,
        'location': location,
        'details': details,
      },
    );

    return Alert.fromJson(payload);
  }

  Future<Alert> fetchAlert(int id) async {
    final payload = await _request('GET', '/api/alerts/$id');
    return Alert.fromJson(payload);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = token == null
        ? _headers
        : {..._headers, 'Authorization': 'Bearer $token'};

    late http.Response response;
    try {
      response = method == 'POST'
          ? await _client
              .post(uri, headers: headers, body: jsonEncode(body))
              .timeout(_timeout)
          : await _client.get(uri, headers: headers).timeout(_timeout);
    } on TimeoutException {
      if (method == 'POST') {
        // The request was already on the wire when the clock ran out. The
        // server may have accepted it. A POST that times out is an unknown
        // outcome, not a failure we can safely retry.
        throw AlertSubmissionUncertainException(
          'We did not get a reply from the rescue service in time. '
          'Your alert may or may not have been sent.',
        );
      }
      // A read that times out is safe to retry: it cannot create a duplicate.
      throw AlertApiException(
        'The rescue service took too long to respond.',
      );
    } on http.ClientException {
      if (method == 'POST') {
        // A dropped POST connection can be a dead link (request never
        // reached the server) or a cut-off response (it may have). The
        // client cannot tell them apart, so report it the same honest way
        // as a timeout: not confirmed, not failed.
        throw AlertSubmissionUncertainException(
          'The connection dropped before we could confirm your alert. '
          'It may or may not have been sent.',
        );
      }
      throw AlertApiException(
        'Cannot reach the rescue service. Check your connection and try again.',
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _unwrapAlertPayload(response.body);
    }

    throw AlertApiException(
      messageForStatus(response.statusCode, response.body),
    );
  }

  /// Parse a 2xx response body into the alert map.
  ///
  /// The backend contract was not verified during the audit, so both shapes
  /// that the mobile project's own tests prove are handled explicitly: a
  /// `data`-wrapped alert (the AlertApi unit tests) and a root-level alert.
  /// A successful body that is neither is an error, never a crash.
  Map<String, dynamic> _unwrapAlertPayload(String responseBody) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(responseBody);
    } on FormatException {
      throw AlertApiException(
        'The rescue service sent an unexpected response.',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw AlertApiException(
        'The rescue service sent an unexpected response.',
      );
    }

    final alert = decoded['data'];
    if (alert is Map<String, dynamic>) {
      return alert;
    }

    // Root-level alert object. Require a real identifier before trusting it;
    // `Alert.fromJson` throws the "could not read" error otherwise.
    if (decoded.containsKey('id')) {
      return decoded;
    }

    throw AlertApiException(
      'The rescue service sent an unexpected response.',
    );
  }

  static const _timeout = Duration(seconds: 10);

  static const _headers = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  /// Turn a failure into something worth showing a stressed user.
  String messageForStatus(int statusCode, String body) {
    if (statusCode == 422) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic> && decoded['errors'] is Map) {
          final first = (decoded['errors'] as Map).values.first;
          if (first is List && first.isNotEmpty) {
            return first.first.toString();
          }
        }
      } on FormatException {
        // Fall through to the generic message below.
      }
    }

    return switch (statusCode) {
      401 => 'Please sign in again to see your alert status.',
      404 => 'That alert no longer exists.',
      >= 500 => 'The rescue service is having trouble. Try again shortly.',
      _ => 'Could not send your alert (error $statusCode).',
    };
  }

  void close() => _client.close();
}