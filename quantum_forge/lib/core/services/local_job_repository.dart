// ============================================================================
// LocalJobRepository — JSON file-based job store. Fully offline, no Firebase.
//
// Storage layout (in app documents directory):
//   colabrxn/
//   └── jobs/
//       ├── index.json          ← list of all job IDs + metadata
//       └── <jobId>.json        ← full job document
//
// Real-time streaming is simulated with a StreamController that is updated
// whenever updateJob() is called. The compute_worker.py, when running locally,
// can also write to these files via the same JSON protocol.
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:quantum_forge/core/utils/uuid_util.dart';
import 'package:quantum_forge/features/job_runner/data/models/job_models.dart';
import 'job_repository.dart';

class LocalJobRepository implements JobRepository {

  static const _folder = 'colabrxn/jobs';

  // Active stream controllers keyed by jobId
  final Map<String, StreamController<JobStatusResponse>> _controllers = {};

  // -------------------------------------------------------------------------
  // Directory helpers
  // -------------------------------------------------------------------------
  Future<String> get _jobsDir async {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData == null) throw UnsupportedError('Windows only');
    final dir = Directory(p.join(localAppData, _folder));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  Future<File> _jobFile(String jobId) async =>
      File(p.join(await _jobsDir, '$jobId.json'));

  Future<File> get _indexFile async =>
      File(p.join(await _jobsDir, 'index.json'));

  // -------------------------------------------------------------------------
  // CRUD
  // -------------------------------------------------------------------------
  @override
  Future<String> createJob(Map<String, dynamic> jobData) async {
    final jobId = jobData['job_id'] as String? ?? UuidUtil.v4();
    final doc = {
      ...jobData,
      'job_id': jobId,
      'created_at': DateTime.now().toIso8601String(),
    };

    // Write job file
    final file = await _jobFile(jobId);
    await file.writeAsString(jsonEncode(doc));

    // Update index
    await _updateIndex(jobId, doc);

    // Notify any active watcher
    _notifyController(jobId, doc);

    return jobId;
  }

  @override
  Future<JobStatusResponse?> getJob(String jobId) async {
    try {
      final file = await _jobFile(jobId);
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;
      final raw = jsonDecode(content) as Map<String, dynamic>;
      return _fromMap(raw);
    } catch (e) {
      print('Error reading job $jobId: $e');
      return null;
    }
  }

  @override
  Future<void> updateJob(String jobId, Map<String, dynamic> fields) async {
    final file = await _jobFile(jobId);
    Map<String, dynamic> existing = {};
    if (await file.exists()) {
      existing = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    }
    final merged = {...existing, ...fields, 'updated_at': DateTime.now().toIso8601String()};
    await file.writeAsString(jsonEncode(merged));
    await _updateIndex(jobId, merged);
    _notifyController(jobId, merged);
  }



  @override
  Stream<JobStatusResponse> watchJob(String jobId) {
    final ctrl = _controllers.putIfAbsent(
      jobId,
      () => StreamController<JobStatusResponse>.broadcast(),
    );

    // Emit the current state immediately if available
    _jobFile(jobId).then((f) async {
      if (await f.exists()) {
        final raw = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        if (!ctrl.isClosed) ctrl.add(_fromMap(raw));
      }
    });

    return ctrl.stream;
  }

  @override
  Future<List<JobStatusResponse>> listJobs(String userId) async {
    final index = await _readIndex();
    final jobs = <JobStatusResponse>[];
    for (final entry in index.reversed) {
      if (entry['user_id'] == userId || entry['user_id'] == null) {
        final job = await getJob(entry['job_id'] as String);
        if (job != null) jobs.add(job);
      }
    }
    return jobs;
  }

  @override
  Future<void> deleteJob(String jobId) async {
    final file = await _jobFile(jobId);
    if (await file.exists()) await file.delete();
    await _removeFromIndex(jobId);
    final ctrl = _controllers.remove(jobId);
    await ctrl?.close();
  }

  // -------------------------------------------------------------------------
  // Index management
  // -------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> _readIndex() async {
    try {
      final file = await _indexFile;
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];
      final raw = jsonDecode(content);
      return (raw as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error reading index: $e');
      return [];
    }
  }

  Future<void> _updateIndex(String jobId, Map<String, dynamic> doc) async {
    final index = await _readIndex();
    index.removeWhere((e) => e['job_id'] == jobId);
    index.add({
      'job_id': jobId,
      'user_id': doc['user_id'],
      'state': doc['state'],
      'template_name': doc['template_name'],
      'created_at': doc['created_at'],
    });
    final file = await _indexFile;
    await file.writeAsString(jsonEncode(index));
  }

  Future<void> _removeFromIndex(String jobId) async {
    final index = await _readIndex();
    index.removeWhere((e) => e['job_id'] == jobId);
    final file = await _indexFile;
    await file.writeAsString(jsonEncode(index));
  }

  // -------------------------------------------------------------------------
  // Stream helpers
  // -------------------------------------------------------------------------
  void _notifyController(String jobId, Map<String, dynamic> doc) {
    final ctrl = _controllers[jobId];
    if (ctrl != null && !ctrl.isClosed) {
      ctrl.add(_fromMap(doc));
    }
  }

  // -------------------------------------------------------------------------
  // Mapping
  // -------------------------------------------------------------------------
  static JobStatusResponse _fromMap(Map<String, dynamic> data) {
    final jobStateStr = data['state'] as String? ?? JobState.pending.name;
    final stateEnum = JobState.values.firstWhere(
      (e) => e.name == jobStateStr,
      orElse: () => JobState.error,
    );
    final energyRaw = data['energy_profile'] as List<dynamic>?;
    final framesRaw = data['trajectory_frames'] as List<dynamic>?;

    return JobStatusResponse(
      jobId: data['job_id'] as String,
      state: stateEnum,
      progress: (data['progress'] as num?)?.toDouble() ?? 0.0,
      message: data['message'] as String?,
      energyProfile: energyRaw?.map((e) => (e as num).toDouble()).toList(),
      trajectoryFrames: framesRaw?.map((e) => e.toString()).toList(),
      createdAt: data['created_at'] != null ? DateTime.tryParse(data['created_at']) : null,
    );
  }

  /// Call this to release all open stream controllers (e.g., on app shutdown).
  Future<void> dispose() async {
    for (final ctrl in _controllers.values) {
      await ctrl.close();
    }
    _controllers.clear();
  }
}
