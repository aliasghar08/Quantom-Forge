import 'dart:async';
import 'package:quantum_forge/features/job_runner/data/models/job_models.dart';
import 'job_repository.dart';

class LocalJobRepository implements JobRepository {
  @override
  Future<String> createJob(Map<String, dynamic> jobData) => throw UnsupportedError('Stub');

  @override
  Future<JobStatusResponse?> getJob(String jobId) => throw UnsupportedError('Stub');

  @override
  Future<void> updateJob(String jobId, Map<String, dynamic> fields) => throw UnsupportedError('Stub');

  @override
  Stream<JobStatusResponse> watchJob(String jobId) => throw UnsupportedError('Stub');

  @override
  Future<List<JobStatusResponse>> listJobs(String userId) => throw UnsupportedError('Stub');

  @override
  Future<void> deleteJob(String jobId) => throw UnsupportedError('Stub');
  
  Future<void> dispose() => throw UnsupportedError('Stub');
}
