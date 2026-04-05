import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../models/admin_case.dart';
import '../services/admin_api_service.dart';

class EvidenceReviewScreen extends StatefulWidget {
  const EvidenceReviewScreen({super.key, required this.adminCase});

  final AdminCase adminCase;

  @override
  State<EvidenceReviewScreen> createState() => _EvidenceReviewScreenState();
}

class _EvidenceReviewScreenState extends State<EvidenceReviewScreen> {
  Uint8List? _bytes;
  VideoPlayerController? _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEvidence();
  }

  Future<void> _loadEvidence() async {
    try {
      final bytes =
          await AdminApiService.fetchDecryptedEvidence(widget.adminCase.incidentId);
      if (!mounted) return;

      if (widget.adminCase.evidenceType == 'video') {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File(
          '${tempDir.path}${Platform.pathSeparator}${widget.adminCase.incidentId}.mp4',
        );
        await tempFile.writeAsBytes(bytes, flush: true);
        final controller = VideoPlayerController.file(tempFile);
        await controller.initialize();
        setState(() {
          _bytes = bytes;
          _controller = controller;
        });
        await controller.play();
      } else {
        setState(() {
          _bytes = bytes;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminCase = widget.adminCase;
    return Scaffold(
      appBar: AppBar(title: const Text('Evidence Review')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _error != null
            ? Center(child: Text(_error!))
            : _bytes == null
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Case ${adminCase.incidentId}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text('Hash: ${adminCase.sha256Hash ?? 'Unavailable'}'),
                      const SizedBox(height: 16),
                      _EvidenceMetaRow(
                        label: 'Timestamp',
                        value: adminCase.timestamp.toLocal().toString(),
                      ),
                      _EvidenceMetaRow(
                        label: 'Location',
                        value: adminCase.latitude != null &&
                                adminCase.longitude != null
                            ? '${adminCase.latitude}, ${adminCase.longitude}'
                            : 'Unavailable',
                      ),
                      _EvidenceMetaRow(
                        label: 'Description',
                        value: adminCase.description.isEmpty
                            ? 'No description provided'
                            : adminCase.description,
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: adminCase.evidenceType == 'video'
                            ? (_controller?.value.isInitialized ?? false)
                                ? AspectRatio(
                                    aspectRatio: _controller!.value.aspectRatio,
                                    child: VideoPlayer(_controller!),
                                  )
                                : const Center(
                                    child: CircularProgressIndicator(),
                                  )
                            : InteractiveViewer(
                                child: Image.memory(
                                  _bytes!,
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                ),
                              ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _EvidenceMetaRow extends StatelessWidget {
  const _EvidenceMetaRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(value),
        ],
      ),
    );
  }
}
