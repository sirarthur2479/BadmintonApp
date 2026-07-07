import 'dart:convert';

import 'package:http/http.dart' as http;

/// Non-2xx API responses become this; `message` carries the backend's
/// `detail` field when present.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Thin JSON HTTP wrapper for the self-hosted backend.
///
/// The base URL is baked in at build time
/// (`--dart-define=API_BASE_URL=...`); tests inject a MockClient.
class ApiClient {
  static const _defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api/v1',
  );

  final String baseUrl;
  final http.Client _inner;
  final String? Function()? tokenProvider;

  ApiClient({http.Client? inner, String? baseUrl, this.tokenProvider})
      : _inner = inner ?? http.Client(),
        baseUrl = baseUrl ?? _defaultBaseUrl;

  Map<String, String> _headers({bool json = false}) {
    final token = tokenProvider?.call();
    return {
      if (json) 'content-type': 'application/json',
      if (token != null) 'authorization': 'Bearer $token',
    };
  }

  dynamic _decode(http.Response resp) {
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      String message = resp.body;
      try {
        final body = jsonDecode(resp.body);
        if (body is Map && body['detail'] != null) {
          message = body['detail'].toString();
        }
      } catch (_) {
        // keep raw body as the message
      }
      throw ApiException(resp.statusCode, message);
    }
    if (resp.body.isEmpty) return null;
    return jsonDecode(resp.body);
  }

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<dynamic> getJson(String path) async =>
      _decode(await _inner.get(_uri(path), headers: _headers()));

  Future<dynamic> postJson(String path, Object body) async => _decode(
        await _inner.post(
          _uri(path),
          headers: _headers(json: true),
          body: jsonEncode(body),
        ),
      );

  Future<dynamic> putJson(String path, Object body) async => _decode(
        await _inner.put(
          _uri(path),
          headers: _headers(json: true),
          body: jsonEncode(body),
        ),
      );

  Future<void> delete(String path) async =>
      _decode(await _inner.delete(_uri(path), headers: _headers()));
}
