import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../core/exceptions.dart';

/// Thin wrapper around `package:http` that centralises timeouts, the required
/// User-Agent header for OSM services, and consistent error translation into
/// [ApiException]. Every service composes this instead of touching http directly.
class ApiClient {
  ApiClient({http.Client? client, Duration? timeout})
      : _client = client ?? http.Client(),
        _timeout = timeout ?? const Duration(seconds: 20);

  final http.Client _client;
  final Duration _timeout;

  Future<dynamic> getJson(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    return _send(() => _client.get(uri, headers: _headers(headers)));
  }

  Future<dynamic> postJson(
    Uri uri, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    return _send(
      () => _client.post(
        uri,
        headers: _headers(headers),
        body: body is String ? body : jsonEncode(body),
      ),
    );
  }

  /// POST for form-encoded bodies (Overpass expects `data=<query>`).
  Future<dynamic> postForm(Uri uri, Map<String, String> fields) async {
    return _send(
      () => _client.post(
        uri,
        headers: {
          'User-Agent': AppConstants.httpUserAgent,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: fields,
      ),
    );
  }

  Map<String, String> _headers(Map<String, String>? extra) => {
        'Accept': 'application/json',
        'User-Agent': AppConstants.httpUserAgent,
        ...?extra,
      };

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    late http.Response response;
    try {
      response = await request().timeout(_timeout);
    } on Exception catch (e) {
      throw ApiException('Request failed: $e');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'HTTP ${response.statusCode}: ${_shorten(response.body)}',
        statusCode: response.statusCode,
      );
    }

    if (response.body.isEmpty) return <String, dynamic>{};
    try {
      return jsonDecode(response.body);
    } on FormatException catch (e) {
      throw ParseException('Invalid JSON response: ${e.message}');
    }
  }

  String _shorten(String body) =>
      body.length > 180 ? '${body.substring(0, 180)}…' : body;

  void dispose() => _client.close();
}
