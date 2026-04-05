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
  final String mimeType;
  final String? deviceInfo;
  final String? previousHash; // For future hash-chaining
  final String? localFilePath;
  final int retryCount;
  final String? uploadError;
  final String blockId;
  final String blockHash;
  final String simulatedTxId;

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
    this.mimeType = 'application/octet-stream',
    this.deviceInfo,
    this.previousHash,
    this.localFilePath,
    this.retryCount = 0,
    this.uploadError,
    required this.blockId,
    required this.blockHash,
    required this.simulatedTxId,
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
      'mimeType': mimeType,
      'deviceInfo': deviceInfo,
      'previousHash': previousHash,
      'localFilePath': localFilePath,
      'retryCount': retryCount,
      'uploadError': uploadError,
      'blockId': blockId,
      'blockHash': blockHash,
      'simulatedTxId': simulatedTxId,
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
      mimeType: map['mimeType'] as String? ?? 'application/octet-stream',
      deviceInfo: map['deviceInfo'] as String?,
      previousHash: map['previousHash'] as String?,
      localFilePath: map['localFilePath'] as String?,
      retryCount: (map['retryCount'] as num?)?.toInt() ?? 0,
      uploadError: map['uploadError'] as String?,
      blockId: map['blockId'] as String? ?? '',
      blockHash: map['blockHash'] as String? ?? '',
      simulatedTxId: map['simulatedTxId'] as String? ?? '',
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
    String? mimeType,
    String? deviceInfo,
    String? previousHash,
    String? localFilePath,
    int? retryCount,
    String? uploadError,
    String? blockId,
    String? blockHash,
    String? simulatedTxId,
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
      mimeType: mimeType ?? this.mimeType,
      deviceInfo: deviceInfo ?? this.deviceInfo,
      previousHash: previousHash ?? this.previousHash,
      localFilePath: localFilePath ?? this.localFilePath,
      retryCount: retryCount ?? this.retryCount,
      uploadError: uploadError ?? this.uploadError,
      blockId: blockId ?? this.blockId,
      blockHash: blockHash ?? this.blockHash,
      simulatedTxId: simulatedTxId ?? this.simulatedTxId,
    );
  }

  @override
  String toString() {
    return 'Incident(id: $incidentId, cid: $cid, hash: ${sha256Hash.substring(0, 8)}..., status: $status)';
  }
}
