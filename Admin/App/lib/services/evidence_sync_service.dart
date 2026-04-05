import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../models/incident.dart';
import 'firestore_service.dart';
import 'ipfs_service.dart';
import 'local_evidence_service.dart';

class EvidenceSyncService {
  EvidenceSyncService._();

  static final EvidenceSyncService instance = EvidenceSyncService._();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isSyncing = false;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    await LocalEvidenceService.initialize();
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((results) {
      if (_hasConnection(results)) {
        unawaited(syncPendingIncidents());
      }
    });
    _initialized = true;
  }

  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
  }

  Future<void> syncPendingIncidents() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final pendingIncidents = await LocalEvidenceService.getPendingIncidents();
      for (final incident in pendingIncidents) {
        await _syncIncident(incident);
      }
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncIncident(Incident incident) async {
    final encryptedBytes =
        await LocalEvidenceService.readEncryptedEvidence(incident.localFilePath);
    if (encryptedBytes == null) {
      await LocalEvidenceService.updateIncident(
        incident.copyWith(
          status: 'failed',
          retryCount: incident.retryCount + 1,
          uploadError: 'Encrypted evidence file missing from local storage.',
        ),
      );
      return;
    }

    try {
      final uploadedCid = await IPFSService.uploadToIPFS(
        encryptedBytes,
        filename:
            '${incident.evidenceType}_${incident.timestamp.millisecondsSinceEpoch}.enc',
        mimeType: incident.mimeType,
      );

      if (uploadedCid == null) {
        await LocalEvidenceService.updateIncident(
          incident.copyWith(
            status: 'pending_upload',
            retryCount: incident.retryCount + 1,
            uploadError: 'Upload did not return a CID.',
          ),
        );
        return;
      }

      final uploadedIncident = incident.copyWith(
        cid: uploadedCid,
        status: 'uploaded',
        retryCount: incident.retryCount,
        uploadError: null,
      );

      await LocalEvidenceService.updateIncident(uploadedIncident);

      try {
        await FirestoreService.saveIncident(uploadedIncident);
      } catch (_) {
        await LocalEvidenceService.updateIncident(
          uploadedIncident.copyWith(
            status: 'uploaded',
            uploadError: 'Remote metadata sync pending.',
          ),
        );
      }
    } catch (e) {
      await LocalEvidenceService.updateIncident(
        incident.copyWith(
          status: 'pending_upload',
          retryCount: incident.retryCount + 1,
          uploadError: e.toString(),
        ),
      );
    }
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }
}
