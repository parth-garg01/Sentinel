import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/incident.dart';

/// Service for all Firestore operations related to incidents.
///
/// Handles CRUD operations on the `incidents` collection.
class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collection = 'incidents';

  /// Save a new incident to Firestore.
  ///
  /// Uses the incident's [incidentId] as the document ID for easy lookups.
  static Future<void> saveIncident(Incident incident) async {
    try {
      await _db
          .collection(_collection)
          .doc(incident.incidentId)
          .set(incident.toMap());
    } catch (e) {
      throw Exception('Failed to save incident: $e');
    }
  }

  /// Retrieve a single incident by its ID.
  static Future<Incident?> getIncident(String incidentId) async {
    try {
      final doc =
          await _db.collection(_collection).doc(incidentId).get();

      if (!doc.exists || doc.data() == null) return null;

      return Incident.fromMap(doc.data()!);
    } catch (e) {
      throw Exception('Failed to fetch incident: $e');
    }
  }

  /// Get all incidents, ordered by timestamp (newest first).
  static Future<List<Incident>> getAllIncidents() async {
    try {
      final snapshot = await _db
          .collection(_collection)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Incident.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch incidents: $e');
    }
  }

  /// Update the status of an incident.
  static Future<void> updateStatus(
      String incidentId, String newStatus) async {
    try {
      await _db.collection(_collection).doc(incidentId).update({
        'status': newStatus,
      });
    } catch (e) {
      throw Exception('Failed to update incident status: $e');
    }
  }

  /// Get the most recent incident (for hash chaining).
  ///
  /// Returns null if no incidents exist yet.
  static Future<Incident?> getLatestIncident() async {
    try {
      final snapshot = await _db
          .collection(_collection)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      return Incident.fromMap(snapshot.docs.first.data());
    } catch (e) {
      throw Exception('Failed to fetch latest incident: $e');
    }
  }

  /// Get incidents filtered by status.
  static Future<List<Incident>> getIncidentsByStatus(
      String status) async {
    try {
      final snapshot = await _db
          .collection(_collection)
          .where('status', isEqualTo: status)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Incident.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch incidents by status: $e');
    }
  }
}
