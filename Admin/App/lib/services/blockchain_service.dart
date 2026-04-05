import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

class SimulatedBlock {
  final String blockId;
  final String blockHash;
  final String simulatedTxId;

  const SimulatedBlock({
    required this.blockId,
    required this.blockHash,
    required this.simulatedTxId,
  });
}

class BlockchainService {
  static SimulatedBlock createBlock({
    required String incidentId,
    required String sha256Hash,
    required DateTime timestamp,
    String? previousHash,
  }) {
    final blockId = const Uuid().v4();
    final payload =
        '$blockId|$incidentId|$sha256Hash|${timestamp.toUtc().toIso8601String()}|${previousHash ?? 'GENESIS'}';
    final blockHash = sha256.convert(utf8.encode(payload)).toString();
    final txPayload = '$blockHash|$incidentId|sentinel-simulated-chain';
    final simulatedTxId =
        sha256.convert(utf8.encode(txPayload)).toString().substring(0, 24);

    return SimulatedBlock(
      blockId: blockId,
      blockHash: blockHash,
      simulatedTxId: simulatedTxId,
    );
  }
}
