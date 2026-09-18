import 'dart:async';
import 'package:quantum_forge/core/utils/uuid_util.dart';
import 'package:quantum_forge/features/job_runner/data/models/job_models.dart';
import 'job_repository.dart';

class LocalJobRepository implements JobRepository {
  final Map<String, StreamController<JobStatusResponse>> _controllers = {};
  final Map<String, Map<String, dynamic>> _mockJobs = {};

  @override
  Future<String> createJob(Map<String, dynamic> jobData) async {
    final jobId = jobData['job_id'] as String? ?? UuidUtil.v4();
    final doc = {
      ...jobData,
      'job_id': jobId,
      'created_at': DateTime.now().toIso8601String(),
      'state': JobState.pending.name,
    };
    _mockJobs[jobId] = doc;
    _notifyController(jobId, doc);
    return jobId;
  }

  @override
  Future<JobStatusResponse?> getJob(String jobId) async {
    final doc = _mockJobs[jobId];
    if (doc == null) return null;
    return _fromMap(doc);
  }

  @override
  Future<void> updateJob(String jobId, Map<String, dynamic> fields) async {
    final existing = _mockJobs[jobId] ?? {};
    final merged = {...existing, ...fields, 'updated_at': DateTime.now().toIso8601String()};
    _mockJobs[jobId] = merged;
    _notifyController(jobId, merged);
  }

  @override
  Stream<JobStatusResponse> watchJob(String jobId) {
    final ctrl = _controllers.putIfAbsent(
      jobId,
      () => StreamController<JobStatusResponse>.broadcast(),
    );

    final doc = _mockJobs[jobId];
    if (doc != null && !ctrl.isClosed) {
      ctrl.add(_fromMap(doc));
    }

    return ctrl.stream;
  }

  @override
  Future<List<JobStatusResponse>> listJobs(String userId) async {
    final jobs = <JobStatusResponse>[];
    for (final doc in _mockJobs.values) {
      if (doc['user_id'] == userId || doc['user_id'] == null) {
        jobs.add(_fromMap(doc));
      }
    }
    // Reverse to simulate newest-first
    return jobs.reversed.toList();
  }

  @override
  Future<void> deleteJob(String jobId) async {
    _mockJobs.remove(jobId);
    final ctrl = _controllers.remove(jobId);
    await ctrl?.close();
  }

  void _notifyController(String jobId, Map<String, dynamic> doc) {
    final ctrl = _controllers[jobId];
    if (ctrl != null && !ctrl.isClosed) {
      ctrl.add(_fromMap(doc));
    }
  }

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

  Future<void> dispose() async {
    for (final ctrl in _controllers.values) {
      await ctrl.close();
    }
    _controllers.clear();
  }
}
