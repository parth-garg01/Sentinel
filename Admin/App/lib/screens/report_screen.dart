import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'dart:typed_data';
import 'dart:io';

import '../models/incident.dart';
import '../services/blockchain_service.dart';
import '../services/evidence_sync_service.dart';
import '../services/ipfs_service.dart';
import '../services/hash_service.dart';
import '../services/location_service.dart';
import '../services/encryption_service.dart';
import '../services/local_evidence_service.dart';

/// Main evidence reporting screen.
///
/// Flow: Capture → Hash → Encrypt → Save locally → Upload when possible
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();

  // State
  Uint8List? _capturedBytes;
  String? _previewPath;
  String? _sha256Hash;
  String? _cid;
  String _evidenceType = 'image';
  String _mimeType = 'application/octet-stream';
  double? _latitude;
  double? _longitude;
  String _statusMessage = '';
  int _currentStep = 0; // 0: capture, 1: review, 2: uploading, 3: done

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  // ─── Step 1: Capture Evidence ─────────────────────────────────────────

  Future<void> _captureImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85, // Compress slightly for faster upload
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();
      _setCapturedEvidence(
        bytes: bytes,
        previewPath: image.path,
        evidenceType: 'image',
        mimeType: _inferMimeType(image.path, fallback: 'image/jpeg'),
      );
    } catch (e) {
      _showError('Failed to capture evidence: $e');
    }
  }

  Future<void> _captureVideo(ImageSource source) async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 2),
      );

      if (video == null) return;

      final bytes = await video.readAsBytes();
      _setCapturedEvidence(
        bytes: bytes,
        previewPath: video.path,
        evidenceType: 'video',
        mimeType: _inferMimeType(video.path, fallback: 'video/mp4'),
      );
    } catch (e) {
      _showError('Failed to capture evidence: $e');
    }
  }

  void _setCapturedEvidence({
    required Uint8List bytes,
    required String previewPath,
    required String evidenceType,
    required String mimeType,
  }) {
    setState(() {
      _capturedBytes = bytes;
      _previewPath = previewPath;
      _evidenceType = evidenceType;
      _mimeType = mimeType;
      _sha256Hash = HashService.generateSHA256(bytes);
      _currentStep = 1;
      _statusMessage = 'Evidence captured. Hash generated.';
    });
  }

  // ─── Step 2: Upload & Store ───────────────────────────────────────────

  Future<void> _submitEvidence() async {
    if (_capturedBytes == null || _sha256Hash == null) return;

    setState(() {
      _currentStep = 2;
      _statusMessage = 'Acquiring location...';
    });

    try {
      final capturedAt = DateTime.now().toUtc();

      // 1. Fetch location + previous local incident concurrently for speed
      final locationFuture = LocationService.getCurrentPosition();
      final latestIncidentFuture = LocalEvidenceService.getLatestIncident();

      final position = await locationFuture;
      final latestIncident = await latestIncidentFuture;
      final previousHash = latestIncident?.sha256Hash;

      // 2. Generate chained hash
      final chainedHash = HashService.generateChainedHash(
        _capturedBytes!,
        previousHash,
      );

      // 3. Encrypt bytes before upload (AES-256-CBC)
      setState(() => _statusMessage = 'Encrypting evidence...');
      final encryptedBytes = EncryptionService.encryptBytes(_capturedBytes!);

      // 4. Simulated blockchain trail
      final incidentId = const Uuid().v4();
      final block = BlockchainService.createBlock(
        incidentId: incidentId,
        sha256Hash: chainedHash,
        timestamp: capturedAt,
        previousHash: previousHash,
      );

      // 5. Save encrypted evidence locally first
      setState(() => _statusMessage = 'Saving encrypted evidence locally...');
      final localFilePath = await LocalEvidenceService.saveEncryptedEvidence(
        encryptedBytes,
        incidentId: incidentId,
        extension: 'enc',
      );

      // 6. Build local-first incident record
      final incident = Incident(
        incidentId: incidentId,
        cid: null,
        sha256Hash: chainedHash,
        timestamp: capturedAt,
        latitude: position?.latitude,
        longitude: position?.longitude,
        description: _descriptionController.text.trim(),
        status: 'pending_local',
        evidenceType: _evidenceType,
        mimeType: _mimeType,
        previousHash: previousHash,
        localFilePath: localFilePath,
        retryCount: 0,
        uploadError: null,
        blockId: block.blockId,
        blockHash: block.blockHash,
        simulatedTxId: block.simulatedTxId,
      );

      await LocalEvidenceService.saveIncident(incident);

      // 7. Try to upload now; if offline, queue remains local
      setState(() => _statusMessage = 'Syncing evidence when connection is available...');
      await EvidenceSyncService.instance.syncPendingIncidents();
      final storedIncident =
          await LocalEvidenceService.getLatestIncident() ?? incident;

      setState(() {
        _cid = storedIncident.incidentId == incidentId ? storedIncident.cid : null;
        _latitude = position?.latitude;
        _longitude = position?.longitude;
        _currentStep = 3;
        _statusMessage = storedIncident.cid != null
            ? 'Evidence secured successfully!'
            : 'Evidence stored locally and queued for upload.';
      });
    } catch (e) {
      setState(() {
        _currentStep = 1; // Go back to review
        _statusMessage = 'Evidence could not be queued safely.';
      });
      _showError('Submission error: $e');
    }
  }

  // ─── Reset for new report ─────────────────────────────────────────────

  void _resetForm() {
    setState(() {
      _capturedBytes = null;
      _previewPath = null;
      _sha256Hash = null;
      _cid = null;
      _evidenceType = 'image';
      _mimeType = 'application/octet-stream';
      _latitude = null;
      _longitude = null;
      _statusMessage = '';
      _currentStep = 0;
      _descriptionController.clear();
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─── UI ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: const Text(
          'Sentinal',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: const Color(0xFF161B22),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.calculate_outlined, size: 22),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back to Calculator',
        ),
        actions: [
          if (_currentStep > 0 && _currentStep < 3)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetForm,
              tooltip: 'Start Over',
            ),
        ],
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildCurrentStep(),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildCaptureStep();
      case 1:
        return _buildReviewStep();
      case 2:
        return _buildUploadingStep();
      case 3:
        return _buildSuccessStep();
      default:
        return _buildCaptureStep();
    }
  }

  // ─── Step 0: Capture ──────────────────────────────────────────────────

  Widget _buildCaptureStep() {
    return Center(
      key: const ValueKey('capture'),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shield_outlined,
              size: 80,
              color: Colors.tealAccent.shade400,
            ),
            const SizedBox(height: 24),
            Text(
              'Secure Evidence Capture',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade100,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your evidence will be encrypted, hashed, saved locally, and uploaded when a connection is available.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 48),
            _buildActionButton(
              icon: Icons.camera_alt,
              label: 'Capture from Camera',
              onPressed: () => _captureImage(ImageSource.camera),
              isPrimary: true,
            ),
            const SizedBox(height: 16),
            _buildActionButton(
              icon: Icons.photo_library,
              label: 'Select from Gallery',
              onPressed: () => _captureImage(ImageSource.gallery),
              isPrimary: false,
            ),
            const SizedBox(height: 16),
            _buildActionButton(
              icon: Icons.videocam,
              label: 'Record Video',
              onPressed: () => _captureVideo(ImageSource.camera),
              isPrimary: false,
            ),
            const SizedBox(height: 16),
            _buildActionButton(
              icon: Icons.video_library,
              label: 'Select Video',
              onPressed: () => _captureVideo(ImageSource.gallery),
              isPrimary: false,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Step 1: Review ───────────────────────────────────────────────────

  Widget _buildReviewStep() {
    return SingleChildScrollView(
      key: const ValueKey('review'),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preview
          if (_previewPath != null)
            _evidenceType == 'image'
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(_previewPath!),
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  )
                : Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade800),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.videocam,
                            size: 52, color: Colors.tealAccent),
                        const SizedBox(height: 12),
                        Text(
                          File(_previewPath!).uri.pathSegments.last,
                          style: TextStyle(color: Colors.grey.shade300),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
          const SizedBox(height: 20),

          // Hash display
          _buildInfoCard(
            icon: Icons.fingerprint,
            title: 'SHA-256 Hash',
            value: _sha256Hash ?? 'N/A',
            color: Colors.tealAccent,
          ),
          const SizedBox(height: 12),

          // File size
          _buildInfoCard(
            icon: Icons.data_usage,
            title: 'Evidence Size',
            value: _capturedBytes != null
                ? '${(_capturedBytes!.lengthInBytes / 1024).toStringAsFixed(1)} KB'
                : 'N/A',
            color: Colors.blueAccent,
          ),
          const SizedBox(height: 20),
          _buildInfoCard(
            icon: _evidenceType == 'image' ? Icons.image : Icons.videocam,
            title: 'Evidence Type',
            value: _evidenceType.toUpperCase(),
            color: Colors.orangeAccent,
          ),
          const SizedBox(height: 20),

          // Description field
          Text(
            'Description (optional)',
            style: TextStyle(
              color: Colors.grey.shade300,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Describe the incident...',
              hintStyle: TextStyle(color: Colors.grey.shade600),
              filled: true,
              fillColor: const Color(0xFF161B22),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade800),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade800),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.tealAccent),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _submitEvidence,
              icon: const Icon(Icons.cloud_upload),
              label: const Text(
                'Submit Evidence',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step 2: Uploading ────────────────────────────────────────────────

  Widget _buildUploadingStep() {
    return Center(
      key: const ValueKey('uploading'),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                color: Colors.tealAccent,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade300,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'The app will retry uploads automatically',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Step 3: Success ──────────────────────────────────────────────────

  Widget _buildSuccessStep() {
    return SingleChildScrollView(
      key: const ValueKey('success'),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Icon(
            Icons.check_circle_outline,
            size: 80,
            color: Colors.greenAccent.shade400,
          ),
          const SizedBox(height: 24),
          Text(
            'Evidence Secured',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade100,
            ),
          ),
          const SizedBox(height: 32),

          if (_cid != null)
            _buildInfoCard(
              icon: Icons.cloud_done,
              title: 'IPFS CID',
              value: _cid!,
              color: Colors.greenAccent,
            ),
          if (_cid == null)
            _buildInfoCard(
              icon: Icons.save_alt,
              title: 'Queue Status',
              value: 'Stored locally and waiting for upload',
              color: Colors.orangeAccent,
            ),
          const SizedBox(height: 12),

          _buildInfoCard(
            icon: Icons.fingerprint,
            title: 'SHA-256 Hash',
            value: _sha256Hash ?? 'N/A',
            color: Colors.tealAccent,
          ),
          const SizedBox(height: 12),

          _buildInfoCard(
            icon: Icons.access_time,
            title: 'Timestamp',
            value: DateTime.now().toUtc().toIso8601String(),
            color: Colors.blueAccent,
          ),
          const SizedBox(height: 12),

          _buildInfoCard(
            icon: Icons.location_on,
            title: 'GPS Coordinates',
            value: (_latitude != null && _longitude != null)
                ? '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}'
                : 'Location unavailable',
            color: Colors.orangeAccent,
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _resetForm,
              icon: const Icon(Icons.add_a_photo),
              label: const Text(
                'Report New Incident',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Shared Widgets ───────────────────────────────────────────────────

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool isPrimary,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: isPrimary
          ? ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(label, style: const TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(label, style: const TextStyle(fontSize: 16)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.tealAccent,
                side: const BorderSide(color: Colors.tealAccent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade200,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _inferMimeType(String path, {required String fallback}) {
    final lowerPath = path.toLowerCase();
    if (lowerPath.endsWith('.png')) return 'image/png';
    if (lowerPath.endsWith('.jpg') || lowerPath.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lowerPath.endsWith('.mp4')) return 'video/mp4';
    if (lowerPath.endsWith('.mov')) return 'video/quicktime';
    if (lowerPath.endsWith('.mkv')) return 'video/x-matroska';
    return fallback;
  }
}
