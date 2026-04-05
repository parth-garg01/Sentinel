import 'package:flutter/material.dart';

import '../models/admin_case.dart';
import '../services/admin_api_service.dart';
import 'evidence_review_screen.dart';
import 'report_review_screen.dart';

class CaseListScreen extends StatefulWidget {
  const CaseListScreen({super.key});

  @override
  State<CaseListScreen> createState() => _CaseListScreenState();
}

class _CaseListScreenState extends State<CaseListScreen> {
  late Future<List<AdminCase>> _casesFuture;

  @override
  void initState() {
    super.initState();
    _casesFuture = AdminApiService.fetchAssignedCases();
  }

  void _refresh() {
    setState(() {
      _casesFuture = AdminApiService.fetchAssignedCases();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assigned Cases'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<AdminCase>>(
        future: _casesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snapshot.error.toString(),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final cases = snapshot.data ?? [];
          if (cases.isEmpty) {
            return const Center(
              child: Text('No assigned cases found.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: cases.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, index) => _CaseCard(
              adminCase: cases[index],
              onEvidenceReview: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EvidenceReviewScreen(adminCase: cases[index]),
                  ),
                );
              },
              onReportReview: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ReportReviewScreen(adminCase: cases[index]),
                  ),
                );
                _refresh();
              },
            ),
          );
        },
      ),
    );
  }
}

class _CaseCard extends StatelessWidget {
  const _CaseCard({
    required this.adminCase,
    required this.onEvidenceReview,
    required this.onReportReview,
  });

  final AdminCase adminCase;
  final VoidCallback onEvidenceReview;
  final VoidCallback onReportReview;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  adminCase.reporterName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _StatusChip(status: adminCase.status),
            ],
          ),
          const SizedBox(height: 10),
          Text('Case ID: ${adminCase.incidentId}'),
          Text('Assigned to: ${adminCase.assignedAdminId}'),
          Text('Evidence: ${adminCase.evidenceType.toUpperCase()}'),
          Text('Filed: ${adminCase.timestamp.toLocal()}'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEvidenceReview,
                  icon: const Icon(Icons.perm_media),
                  label: const Text('Evidence Review'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onReportReview,
                  icon: const Icon(Icons.fact_check),
                  label: const Text('Report Review'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final color = switch (normalized) {
      'submitted' => Colors.blueAccent,
      'underreview' => Colors.orangeAccent,
      'investigating' => Colors.deepOrange,
      'resolved' => Colors.green,
      'closed' => Colors.grey,
      _ => Colors.black54,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
