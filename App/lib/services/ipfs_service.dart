import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class IPFSService {
  static const String apiToken = "z4MXj1wBzi9jUstyPnyoRYmERo45FHEhc9R6HS8WKBzpCCSAwS3G5DFibHxPr7BoMHDQNA6eMvX7YcED8u9bSzeDwgJ914th7e3pLR2AspTCTyDwqsbqFdntDfbATrX3VZUanEP9BFkeWx35jz8d1KuMorLCMyPi8QBteZFsrmjLvZzaj1GkvsNELoEbG1yt17kp2bNU6nPytWjoc1NzAJSgwtYzRow5jVVa8JcdWwxPLio9KMxvXnrEJfHTQaAGXgdehZX71G6F4245e6G7STukoUSpf7E1tu8mGDPVDEmF2kvFV9VFRuWKHg1q8457jP3opwKvYWV7EQn6mUbnNiBoz3ty6VYxA63yv74X3broVbAfpgmyS";

  static Future<String?> uploadToIPFS(
    Uint8List fileBytes, {
    String filename = 'evidence.jpg',
    String mimeType = 'application/octet-stream',
  }) async {
    try {
      final uri = Uri.parse("https://api.web3.storage/upload");

      final request = http.MultipartRequest("POST", uri);

      request.headers.addAll({
        "Authorization": "Bearer $apiToken",
        "X-Upload-Content-Type": mimeType,
      });

      request.files.add(
        http.MultipartFile.fromBytes(
          "file",
          fileBytes,
          filename: filename,
        ),
      );

      final response = await request.send();

      final responseBody = await response.stream.bytesToString();
      final jsonData = jsonDecode(responseBody);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final cid = jsonData["cid"];
        return cid is String ? cid : null;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  static String gatewayUrl(String cid) {
    return 'https://$cid.ipfs.w3s.link';
  }
}
