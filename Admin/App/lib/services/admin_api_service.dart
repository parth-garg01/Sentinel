import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/admin_case.dart';

class AdminApiService {
  static const String _configuredBackendUrl = String.fromEnvironment(
    'ADMIN_BACKEND_URL',
    defaultValue: '',
  );
  static const String _adminId = String.fromEnvironment(
    'ADMIN_ID',
    defaultValue: 'admin-001',
  );
  static const String _apiToken = String.fromEnvironment(
    'ADMIN_API_TOKEN',
    defaultValue: '',
  );

  static String get _backendBaseUrl {
    if (_configuredBackendUrl.isEmpty) {
      throw Exception(
        'Missing ADMIN_BACKEND_URL. Launch the admin app with your backend URL, '
        'for example: --dart-define=ADMIN_BACKEND_URL=https://your-backend.example.com',
      );
    }
    return _configuredBackendUrl;
  }

  static Uri _uri(String path, [Map<String, String>? queryParameters]) {
    return Uri.parse(_backendBaseUrl).resolve(path).replace(
          queryParameters: queryParameters,
        );
  }

  static Map<String, String> _headers() {
    return {
      'Content-Type': 'application/json',
      if (_apiToken.isNotEmpty) 'Authorization': 'Bearer $_apiToken',
    };
  }

  static Future<List<AdminCase>> fetchAssignedCases() async {
    final response = await _guardedGet(
      _uri('/api/admin/cases', {'assignedTo': _adminId}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to load assigned cases. '
        'Status: ${response.statusCode}. '
        'Response: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded
        .map((item) => AdminCase.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  static Future<Uint8List> fetchDecryptedEvidence(String incidentId) async {
    final response = await _guardedGet(
      _uri('/api/admin/cases/$incidentId/evidence'),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to fetch decrypted evidence. '
        'Status: ${response.statusCode}. '
        'Response: ${response.body}',
      );
    }

    return response.bodyBytes;
  }

  static Future<void> updateStatus(String incidentId, String status) async {
    final response = await _guardedPatch(
      _uri('/api/admin/cases/$incidentId/status'),
      body: jsonEncode({'status': status}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to update report lifecycle. '
        'Status: ${response.statusCode}. '
        'Response: ${response.body}',
      );
    }
  }

  static Future<http.Response> _guardedGet(Uri uri) async {
    try {
      return await http.get(uri, headers: _headers());
    } on http.ClientException catch (e) {
      throw Exception(_connectionHelp(e));
    }
  }

  static Future<http.Response> _guardedPatch(
    Uri uri, {
    required String body,
  }) async {
    try {
      return await http.patch(uri, headers: _headers(), body: body);
    } on http.ClientException catch (e) {
      throw Exception(_connectionHelp(e));
    }
  }

  static String _connectionHelp(Object error) {
    final base =
        'Could not reach the admin backend at $_backendBaseUrl.\n'
        'Make sure your backend is running and reachable from the app.\n';

    return '$base'
        'Or launch the app with:\n'
        '`--dart-define=ADMIN_BACKEND_URL=https://your-backend-host`\n\n'
        'Original error: $error';
  }
}
