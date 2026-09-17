// ============================================================================
// JobRepository — Abstract interface for job CRUD + real-time streaming
//
// Both LocalJobRepository (JSON files) and FirebaseJobRepository (Firestore)
// implement this interface. The app only depends on JobRepository.
// ============================================================================

import 'package:quantum_forge/features/job_runner/data/models/job_models.dart';

abstract class JobRepository {
  /// Create a new job document and return its ID.
  Future<String> createJob(Map<String, dynamic> jobData);



  /// Stream real-time updates for a specific job.
  Stream<JobStatusResponse> watchJob(String jobId);

  /// Fetch a snapshot of a job by ID.
  Future<JobStatusResponse?> getJob(String jobId);

  /// Update fields on an existing job document.
  Future<void> updateJob(String jobId, Map<String, dynamic> fields);

  /// List all jobs for a user, ordered newest-first.
  Future<List<JobStatusResponse>> listJobs(String userId);

  /// Permanently delete a job record.
  Future<void> deleteJob(String jobId);
}
