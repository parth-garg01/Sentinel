import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/incident.dart';
import '../services/firestore_service.dart';
import '../services/ipfs_service.dart';

/// Evidence vault — shows all submitted incidents from Firestore.
///
/// Each card shows: ID, timestamp, GPS, status badge, hash prefix, CID.
/// Tap a card → expanded detail sheet with integrity check.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<Incident>> _incidentsFuture;
  bool _chainValid = true;

  @override
  void initState() {
    super.initState();
    _incidentsFuture = _loadAndVerify();
  }

  Future<List<Incident>> _loadAndVerify() async {
    final incidents = await FirestoreService.getAllIncidents();
    _chainValid = _verifyChain(incidents);
    return incidents;
  }

  /// Verify the entire hash chain is intact.
  bool _verifyChain(List<Incident> incidents) {
    // incidents are newest-first; reverse to verify oldest→newest
    final ordered = incidents.reversed.toList();
    for (int i = 1; i < ordered.length; i++) {
      if (ordered[i].previousHash != ordered[i - 1].sha256Hash) {
        return false; // Chain broken — tampering detected
      }
    }
    return true;
  }

  void _refresh() {
    setState(() {
      _incidentsFuture = _loadAndVerify();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Icon(Icons.shield, color: Colors.tealAccent.shade400, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Evidence Vault',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: FutureBuilder<List<Incident>>(
        future: _incidentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.tealAccent),
            );
          }

          if (snapshot.hasError) {
            return _buildError(snapshot.error.toString());
          }

          final incidents = snapshot.data ?? [];

          if (incidents.isEmpty) {
            return _buildEmpty();
          }

          return Column(
            children: [
              // Chain integrity banner
              _buildChainBanner(incidents.length),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  color: Colors.tealAccent,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: incidents.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) =>
                        _buildIncidentCard(incidents[i], i),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Widgets ──────────────────────────────────────────────────────────

  Widget _buildChainBanner(int count) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _chainValid
            ? Colors.tealAccent.withValues(alpha: 0.08)
            : Colors.red.withValues(alpha: 0.08),
        border: Border.all(
          color: _chainValid ? Colors.tealAccent.shade700 : Colors.red.shade700,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            _chainValid ? Icons.verified_user : Icons.warning_amber_rounded,
            color: _chainValid ? Colors.tealAccent : Colors.redAccent,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _chainValid
                  ? '$count incident${count == 1 ? '' : 's'} — Hash chain integrity: VERIFIED'
                  : '⚠️ Hash chain BROKEN — possible tampering detected',
              style: TextStyle(
                fontSize: 12,
                color: _chainValid ? Colors.tealAccent : Colors.redAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentCard(Incident incident, int index) {
    return GestureDetector(
      onTap: () => _showDetail(incident),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF30363D)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.tealAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '#${incident.incidentId.substring(0, 6).toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.tealAccent,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusBadge(incident.status),
                  const Spacer(),
                  Icon(Icons.chevron_right,
                      color: Colors.grey.shade600, size: 18),
                ],
              ),
              const SizedBox(height: 12),

              // Timestamp
              _buildMeta(
                Icons.access_time,
                _formatTimestamp(incident.timestamp),
              ),
              const SizedBox(height: 6),

              // GPS
              _buildMeta(
                Icons.location_on,
                (incident.latitude != null && incident.longitude != null)
                    ? '${incident.latitude!.toStringAsFixed(4)}, ${incident.longitude!.toStringAsFixed(4)}'
                    : 'No location',
                color: (incident.latitude != null)
                    ? Colors.orangeAccent
                    : Colors.grey.shade600,
              ),
              const SizedBox(height: 6),

              // Hash (truncated)
              _buildMeta(
                Icons.fingerprint,
                '${incident.sha256Hash.substring(0, 20)}...',
                color: Colors.blueAccent.shade200,
                mono: true,
              ),

              // CID if available
              if (incident.cid != null) ...[
                const SizedBox(height: 6),
                _buildMeta(
                  Icons.cloud_done,
                  '${incident.cid!.substring(0, 16)}...',
                  color: Colors.greenAccent.shade700,
                  mono: true,
                ),
              ],

              // Description
              if (incident.description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  incident.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade400,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    IconData icon;
    switch (status) {
      case 'submitted':
        color = Colors.greenAccent;
        icon = Icons.check_circle_outline;
        break;
      case 'pending_upload':
        color = Colors.orangeAccent;
        icon = Icons.cloud_off;
        break;
      case 'verified':
        color = Colors.tealAccent;
        icon = Icons.verified;
        break;
      case 'flagged':
        color = Colors.redAccent;
        icon = Icons.flag;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help_outline;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          status.replaceAll('_', ' ').toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildMeta(IconData icon, String text,
      {Color? color, bool mono = false}) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color ?? Colors.grey.shade600),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color ?? Colors.grey.shade500,
              fontFamily: mono ? 'monospace' : null,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_outlined,
              size: 64, color: Colors.grey.shade700),
          const SizedBox(height: 16),
          Text(
            'No incidents recorded',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Submit evidence to see it here.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              'Failed to load incidents',
              style: TextStyle(color: Colors.grey.shade300, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(error,
                style:
                    TextStyle(color: Colors.grey.shade600, fontSize: 11),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _refresh,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent.shade700),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Detail Sheet ─────────────────────────────────────────────────────

  void _showDetail(Incident incident) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Row(
                children: [
                  const Icon(Icons.shield,
                      color: Colors.tealAccent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Incident ${incident.incidentId.substring(0, 8).toUpperCase()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _buildDetailRow('Status', incident.status),
              _buildDetailRow('Type', incident.evidenceType),
              _buildDetailRow(
                  'Timestamp', incident.timestamp.toIso8601String()),
              _buildDetailRow(
                'GPS',
                (incident.latitude != null)
                    ? '${incident.latitude}, ${incident.longitude}'
                    : 'Unavailable',
              ),
              _buildDetailRow('SHA-256 Hash', incident.sha256Hash),
              if (incident.previousHash != null)
                _buildDetailRow('Previous Hash', incident.previousHash!),
              if (incident.cid != null)
                _buildDetailRow('IPFS CID', incident.cid!),
              if (incident.description.isNotEmpty)
                _buildDetailRow('Description', incident.description),

              const SizedBox(height: 20),

              // Integrity check
              _buildIntegrityBadge(incident),

              const SizedBox(height: 20),

              // Copy hash button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                        ClipboardData(text: incident.sha256Hash));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Hash copied to clipboard'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy Hash'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.tealAccent,
                    side: const BorderSide(color: Colors.tealAccent),
                  ),
                ),
              ),

              if (incident.cid != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(
                          text: IPFSService.gatewayUrl(incident.cid!)));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('IPFS URL copied to clipboard'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.link, size: 16),
                    label: const Text('Copy IPFS Link'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.greenAccent,
                      side: const BorderSide(color: Colors.greenAccent),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white70,
              fontFamily: 'monospace',
            ),
          ),
          const Divider(color: Color(0xFF30363D), height: 20),
        ],
      ),
    );
  }

  Widget _buildIntegrityBadge(Incident incident) {
    // For a single record, we verify the hash format is valid (64 hex chars)
    final isValidHash = RegExp(r'^[a-f0-9]{64}$')
        .hasMatch(incident.sha256Hash);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isValidHash
            ? Colors.tealAccent.withValues(alpha: 0.05)
            : Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isValidHash
              ? Colors.tealAccent.withValues(alpha: 0.3)
              : Colors.redAccent.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isValidHash ? Icons.verified_user : Icons.gpp_bad,
            color: isValidHash ? Colors.tealAccent : Colors.redAccent,
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(
            isValidHash
                ? 'Hash format verified — SHA-256 valid'
                : 'Hash format invalid — record may be corrupted',
            style: TextStyle(
              fontSize: 12,
              color:
                  isValidHash ? Colors.tealAccent : Colors.redAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  String _formatTimestamp(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}  '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}
