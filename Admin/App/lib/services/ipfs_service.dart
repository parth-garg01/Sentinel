import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Uploads encrypted evidence through a Sentinel backend that owns the
/// Storacha agent key + delegation proof.
///
/// Why this design?
/// Storacha uses agent keys + UCAN delegations. Those credentials should stay
/// on a backend service, not in a Flutter client where they can be extracted.
///
/// Expected backend contract:
///   POST {backendUrl}/api/v1/evidence/upload
///   multipart field: file
///   optional fields: filename, mimeType
///
/// Response:
///   { "cid": "...", "gatewayUrl": "..." }
class IPFSService {
  static const String _backendUrl = String.fromEnvironment(
    'SENTINEL_BACKEND_URL',
    defaultValue: '',
  );
  static const String _apiToken = String.fromEnvironment(
    'SENTINEL_API_TOKEN',
    defaultValue: '',
  );
  static const String _uploadPath = '/api/v1/evidence/upload';

  static Future<String?> uploadToIPFS(
    Uint8List fileBytes, {
    String filename = 'evidence.jpg',
    String mimeType = 'application/octet-stream',
  }) async {
    if (_backendUrl.isEmpty) {
      throw StateError(
        'Missing SENTINEL_BACKEND_URL. Configure your backend upload endpoint.',
      );
    }

    try {
      final uri = Uri.parse(_backendUrl).resolve(_uploadPath);

      final request = http.MultipartRequest("POST", uri);

      request.headers['X-Upload-Content-Type'] = mimeType;
      if (_apiToken.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $_apiToken';
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          "file",
          fileBytes,
          filename: filename,
        ),
      );
      request.fields['filename'] = filename;
      request.fields['mimeType'] = mimeType;

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final jsonData = jsonDecode(responseBody) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final cid = jsonData["cid"];
        return cid is String ? cid : null;
      } else {
        final message = jsonData['error'];
        throw Exception(
          message is String
              ? message
              : 'Backend upload failed with status ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Failed to upload encrypted evidence: $e');
    }
  }

  static String gatewayUrl(String cid) {
    return 'https://$cid.ipfs.w3s.link';
  }
}
