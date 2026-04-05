import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/incident.dart';

class LocalEvidenceService {
  static const String _dbFileName = 'sentinel_local.db';
  static const String _evidenceDirName = 'evidence';
  static const String _incidentTable = 'incidents';

  static Directory? _baseDir;
  static Database? _db;

  static Future<void> initialize() async {
    _baseDir ??= await getApplicationDocumentsDirectory();
    await _ensureStructure();
  }

  static Future<void> _ensureStructure() async {
    final evidenceDir = Directory(_join(_baseDir!.path, _evidenceDirName));
    if (!await evidenceDir.exists()) {
      await evidenceDir.create(recursive: true);
    }
    _db ??= await openDatabase(
      p.join(_baseDir!.path, _dbFileName),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_incidentTable (
            incidentId TEXT PRIMARY KEY,
            cid TEXT,
            sha256Hash TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            latitude REAL,
            longitude REAL,
            description TEXT NOT NULL,
            status TEXT NOT NULL,
            evidenceType TEXT NOT NULL,
            mimeType TEXT NOT NULL,
            deviceInfo TEXT,
            previousHash TEXT,
            localFilePath TEXT,
            retryCount INTEGER NOT NULL,
            uploadError TEXT,
            blockId TEXT NOT NULL,
            blockHash TEXT NOT NULL,
            simulatedTxId TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_incidents_timestamp ON $_incidentTable(timestamp DESC)',
        );
        await db.execute(
          'CREATE INDEX idx_incidents_status ON $_incidentTable(status)',
        );
      },
    );
  }

  static Future<String> saveEncryptedEvidence(
    Uint8List encryptedBytes, {
    required String incidentId,
    required String extension,
  }) async {
    await initialize();
    final sanitizedExtension =
        extension.startsWith('.') ? extension.substring(1) : extension;
    final filePath = _join(
      _join(_baseDir!.path, _evidenceDirName),
      '$incidentId.$sanitizedExtension',
    );
    final file = File(filePath);
    await file.writeAsBytes(encryptedBytes, flush: true);
    return file.path;
  }

  static Future<List<Incident>> getAllIncidents() async {
    await initialize();
    final rows = await _db!.query(
      _incidentTable,
      orderBy: 'timestamp DESC',
    );
    return rows
        .map((item) => Incident.fromMap(Map<String, dynamic>.from(item)))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  static Future<Incident?> getLatestIncident() async {
    final incidents = await getAllIncidents();
    if (incidents.isEmpty) return null;
    return incidents.first;
  }

  static Future<void> saveIncident(Incident incident) async {
    await initialize();
    await _db!.insert(
      _incidentTable,
      incident.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> updateIncident(Incident incident) async {
    await saveIncident(incident);
  }

  static Future<List<Incident>> getPendingIncidents() async {
    await initialize();
    final rows = await _db!.query(
      _incidentTable,
      where:
          'cid IS NULL AND status IN (?, ?, ?)',
      whereArgs: ['pending_local', 'pending_upload', 'failed'],
      orderBy: 'timestamp ASC',
    );
    return rows
        .map((row) => Incident.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  static Future<Uint8List?> readEncryptedEvidence(String? path) async {
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  static Future<int> getStatusCount(String status) async {
    await initialize();
    final result = await _db!.rawQuery(
      'SELECT COUNT(*) AS count FROM $_incidentTable WHERE status = ?',
      [status],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  static String _join(String left, String right) {
    return '$left${Platform.pathSeparator}$right';
  }
}
