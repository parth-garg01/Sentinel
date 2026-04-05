class AdminCase {
  final String incidentId;
  final String reporterName;
  final String assignedAdminId;
  final String status;
  final String evidenceType;
  final String mimeType;
  final String? cid;
  final String? sha256Hash;
  final DateTime timestamp;
  final double? latitude;
  final double? longitude;
  final String description;

  const AdminCase({
    required this.incidentId,
    required this.reporterName,
    required this.assignedAdminId,
    required this.status,
    required this.evidenceType,
    required this.mimeType,
    required this.cid,
    required this.sha256Hash,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.description,
  });

  factory AdminCase.fromMap(Map<String, dynamic> map) {
    return AdminCase(
      incidentId: map['incidentId'] as String,
      reporterName: map['reporterName'] as String? ?? 'Unknown Reporter',
      assignedAdminId: map['assignedAdminId'] as String? ?? 'unassigned',
      status: map['status'] as String? ?? 'submitted',
      evidenceType: map['evidenceType'] as String? ?? 'image',
      mimeType: map['mimeType'] as String? ?? 'application/octet-stream',
      cid: map['cid'] as String?,
      sha256Hash:
          map['rawSha256Hash'] as String? ??
          map['fileSha256Hash'] as String? ??
          map['sha256Hash'] as String?,
      timestamp: DateTime.parse(map['timestamp'] as String),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      description: map['description'] as String? ?? '',
    );
  }
}
