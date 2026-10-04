import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants.dart';

/// One alert as the Laravel backend returns it.
class Alert {
  const Alert({
    required this.id,
    required this.facility,
    required this.type,
    required this.location,
    required this.status,
    required this.open,
    this.details = '',
    this.responseSeconds,
  });

  final int id;
  final String facility;
  final String type;
  final String location;
  final String details;
  final String status;
  final bool open;
  final int? responseSeconds;

  factory Alert.fromJson(Map<String, dynamic> json) => Alert(
        id: json['id'] as int,
        facility: json['facility'] as String? ?? '',
        type: json['type'] as String? ?? '',
        location: json['location'] as String? ?? '',
        details: json['details'] as String? ?? '',
        status: json['status'] as String? ?? kStatusActive,
        open: json['open'] as bool? ?? false,
        responseSeconds: json['response_seconds'] as int?,
      );
}

/// Thrown for anything the rescuee needs to be told about: no connection,
/// a rejected alert, or a server error.
class AlertApiException implements Exception {
  AlertApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Talks to the Laravel backend. Both calls are unauthenticated by design -
/// a rescuee must be able to send an alert without an account.
///
/// Uses package:http so the same code runs on web, mobile, and desktop.
class AlertApi {
  AlertApi({String? baseUrl, http.Client? client, this.token})
      : baseUrl = baseUrl ?? kApiBase,
        _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  /// Bearer token for reading alert status. Sending an alert is unauthenticated
  /// on the backend, but reading one requires a login, so the rescuee's
  /// AuthService token has to travel with every status poll.
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

    try {
      final response = method == 'POST'
          ? await _client
              .post(uri, headers: headers, body: jsonEncode(body))
              .timeout(_timeout)
          : await _client.get(uri, headers: headers).timeout(_timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        return decoded['data'] as Map<String, dynamic>;
      }

      throw AlertApiException(
        messageForStatus(response.statusCode, response.body),
      );
    } on TimeoutException {
      throw AlertApiException('The rescue service took too long to respond.');
    } on AlertApiException {
      rethrow;
    } on http.ClientException {
      throw AlertApiException(
        'Cannot reach the rescue service. Check your connection and try again.',
      );
    } on FormatException {
      throw AlertApiException(
        'The rescue service sent an unexpected response.',
      );    }
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