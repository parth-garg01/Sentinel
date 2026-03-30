import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

/// AES-256-CBC encryption service for evidence files.
///
/// Security model:
///   • Key: 32-byte app-level secret (hackathon mode)
///   • In production: derive key from user PIN via PBKDF2
///   • IV: cryptographically random 16 bytes per encryption
///   • Storage format: [16-byte IV] + [ciphertext]
///     → IV is public by design; ciphertext is meaningless without the key
///
/// WHY encrypt before IPFS upload?
///   IPFS is public. Anyone with the CID can download the file.
///   Encrypting before upload means raw evidence is never exposed —
///   only authorized holders of the key can decrypt it.
class EncryptionService {
  // ── Key Configuration ────────────────────────────────────────────────
  //
  // HACKATHON MODE: fixed 32-byte app secret.
  // PRODUCTION:     derive this from user's biometric/PIN using PBKDF2.
  //
  // Must be EXACTLY 32 bytes for AES-256.
  static final enc.Key _key =
      enc.Key.fromUtf8(r'Sentinel@@SecureKey32Bytes!!###$');

  // ── Encrypt ──────────────────────────────────────────────────────────

  /// Encrypt raw bytes using AES-256-CBC.
  ///
  /// Returns: [16-byte random IV] + [AES ciphertext]
  static Uint8List encryptBytes(Uint8List plaintext) {
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(_key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encryptBytes(plaintext, iv: iv);

    // Prepend IV so we can decrypt later without storing it separately
    return Uint8List.fromList([...iv.bytes, ...encrypted.bytes]);
  }

  // ── Decrypt ──────────────────────────────────────────────────────────

  /// Decrypt bytes produced by [encryptBytes].
  ///
  /// Expects: [16-byte IV] + [AES ciphertext]
  /// Returns: original plaintext bytes, or null on failure.
  static Uint8List? decryptBytes(Uint8List ciphertext) {
    try {
      if (ciphertext.length < 17) return null;

      final iv = enc.IV(Uint8List.fromList(ciphertext.sublist(0, 16)));
      final data =
          enc.Encrypted(Uint8List.fromList(ciphertext.sublist(16)));

      final encrypter = enc.Encrypter(enc.AES(_key, mode: enc.AESMode.cbc));
      return Uint8List.fromList(encrypter.decryptBytes(data, iv: iv));
    } catch (_) {
      return null; // Wrong key or corrupted data
    }
  }

  // ── Integrity Verify ─────────────────────────────────────────────────

  /// Verify decrypted bytes match the stored SHA-256 hash.
  ///
  /// Call after downloading + decrypting from IPFS to confirm
  /// evidence has not been tampered with.
  static bool verifyIntegrity(
      Uint8List decryptedBytes, String expectedSHA256) {
    final hash = sha256.convert(decryptedBytes).toString();
    return hash == expectedSHA256;
  }
}
