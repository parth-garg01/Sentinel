import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Service for generating cryptographic hashes of evidence files.
///
/// Uses SHA-256 for tamper-proof integrity verification.
class HashService {
  /// Generate a SHA-256 hash from raw file bytes.
  ///
  /// Returns the hash as a lowercase hexadecimal string.
  static String generateSHA256(Uint8List fileBytes) {
    final digest = sha256.convert(fileBytes);
    return digest.toString(); // Returns hex string
  }

  /// Verify that a file's hash matches an expected hash.
  ///
  /// Useful for integrity checks when retrieving evidence.
  static bool verifyHash(Uint8List fileBytes, String expectedHash) {
    final computedHash = generateSHA256(fileBytes);
    return computedHash == expectedHash;
  }

  /// Generate a chained hash by combining the current file hash
  /// with the previous incident's hash.
  ///
  /// This creates a simple blockchain-like integrity chain.
  /// If [previousHash] is null (first incident), uses the file hash alone.
  static String generateChainedHash(Uint8List fileBytes, String? previousHash) {
    final fileHash = generateSHA256(fileBytes);

    if (previousHash == null || previousHash.isEmpty) {
      return fileHash;
    }

    // Chain: SHA-256(previousHash + currentFileHash)
    final chainInput = '$previousHash$fileHash';
    final chainedDigest = sha256.convert(chainInput.codeUnits);
    return chainedDigest.toString();
  }
}
