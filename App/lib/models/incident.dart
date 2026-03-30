/// Data model representing a reported incident with evidence metadata.
///
/// Stored in Firestore collection: `incidents`
class Incident {
  final String incidentId;
  final String? cid; // IPFS Content Identifier
  final String sha256Hash;
  final DateTime timestamp;
  final double? latitude;
  final double? longitude;
  final String description;
  final String status; // submitted | verified | flagged
  final String evidenceType; // image | video | audio
  final String? deviceInfo;
  final String? previousHash; // For future hash-chaining

  Incident({
    required this.incidentId,
    this.cid,
    required this.sha256Hash,
    required this.timestamp,
    this.latitude,
    this.longitude,
    this.description = '',
    this.status = 'submitted',
    this.evidenceType = 'image',
    this.deviceInfo,
    this.previousHash,
  });

  /// Convert to Firestore-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'incidentId': incidentId,
      'cid': cid,
      'sha256Hash': sha256Hash,
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
      'status': status,
      'evidenceType': evidenceType,
      'deviceInfo': deviceInfo,
      'previousHash': previousHash,
    };
  }

  /// Create Incident from Firestore document map.
  factory Incident.fromMap(Map<String, dynamic> map) {
    return Incident(
      incidentId: map['incidentId'] as String,
      cid: map['cid'] as String?,
      sha256Hash: map['sha256Hash'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      description: map['description'] as String? ?? '',
      status: map['status'] as String? ?? 'submitted',
      evidenceType: map['evidenceType'] as String? ?? 'image',
      deviceInfo: map['deviceInfo'] as String?,
      previousHash: map['previousHash'] as String?,
    );
  }

  /// Create a copy with updated fields.
  Incident copyWith({
    String? incidentId,
    String? cid,
    String? sha256Hash,
    DateTime? timestamp,
    double? latitude,
    double? longitude,
    String? description,
    String? status,
    String? evidenceType,
    String? deviceInfo,
    String? previousHash,
  }) {
    return Incident(
      incidentId: incidentId ?? this.incidentId,
      cid: cid ?? this.cid,
      sha256Hash: sha256Hash ?? this.sha256Hash,
      timestamp: timestamp ?? this.timestamp,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      description: description ?? this.description,
      status: status ?? this.status,
      evidenceType: evidenceType ?? this.evidenceType,
      deviceInfo: deviceInfo ?? this.deviceInfo,
      previousHash: previousHash ?? this.previousHash,
    );
  }

  @override
  String toString() {
    return 'Incident(id: $incidentId, cid: $cid, hash: ${sha256Hash.substring(0, 8)}..., status: $status)';
  }
}
