import 'package:flutter/material.dart';

import '../models/admin_case.dart';
import '../services/admin_api_service.dart';

class ReportReviewScreen extends StatefulWidget {
  const ReportReviewScreen({super.key, required this.adminCase});

  final AdminCase adminCase;

  @override
  State<ReportReviewScreen> createState() => _ReportReviewScreenState();
}

class _ReportReviewScreenState extends State<ReportReviewScreen> {
  static const _statuses = [
    'submitted',
    'underreview',
    'investigating',
    'resolved',
    'closed',
  ];

  late String _selectedStatus;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.adminCase.status;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await AdminApiService.updateStatus(
        widget.adminCase.incidentId,
        _selectedStatus,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lifecycle updated successfully.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminCase = widget.adminCase;
    return Scaffold(
      appBar: AppBar(title: const Text('Report Review')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              adminCase.reporterName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            _DetailRow(label: 'Incident ID', value: adminCase.incidentId),
            _DetailRow(label: 'Timestamp', value: adminCase.timestamp.toLocal().toString()),
            _DetailRow(
              label: 'Location',
              value: adminCase.latitude != null && adminCase.longitude != null
                  ? '${adminCase.latitude}, ${adminCase.longitude}'
                  : 'Unavailable',
            ),
            _DetailRow(
              label: 'Description',
              value: adminCase.description.isEmpty
                  ? 'No description provided'
                  : adminCase.description,
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              value: _selectedStatus,
              items: _statuses
                  .map((status) => DropdownMenuItem(
                        value: status,
                        child: Text(status.toUpperCase()),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedStatus = value);
                }
              },
              decoration: const InputDecoration(
                labelText: 'Complaint Lifecycle',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_saving ? 'Saving...' : 'Update Lifecycle'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
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
