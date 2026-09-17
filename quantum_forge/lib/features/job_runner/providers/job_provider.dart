// ============================================================================
// Job Provider — Riverpod AsyncNotifier decoupled from Firebase
// 
// Delegates all operations (Auth, Storage, DB) to the injected service layer.
// Supports both custom file dispatch and template dispatch.
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:quantum_forge/core/services/auth_service.dart';
import 'package:quantum_forge/core/services/storage_service.dart';
import 'package:quantum_forge/core/services/job_repository.dart';
import 'package:quantum_forge/core/services/file_picker_service.dart';
import 'package:quantum_forge/features/job_runner/data/models/job_models.dart';
import 'package:quantum_forge/features/job_runner/providers/settings_provider.dart';
import 'package:quantum_forge/features/reaction_library/data/reaction_templates.dart';

class JobNotifier extends ValueNotifier<JobStatusResponse?> {
  final AuthService _auth;
  final StorageService _storage;
  final JobRepository _repo;
  bool _isLoading = false;
  String? _error;

  JobNotifier(this._auth, this._storage, this._repo) : super(null);

  bool get isLoading => _isLoading;
  String? get error => _error;

  void _setLoading(bool loading) {
    _isLoading = loading;
    if (loading) _error = null;
    notifyListeners();
  }

  void _setError(String error) {
    _isLoading = false;
    _error = error;
    notifyListeners();
  }

  // --- Dispatch from custom files ---
  Future<void> dispatchJob(
    PickedFile reactantFile,
    PickedFile productFile,
    QuantumSettings settings,
  ) async {
    _setLoading(true);
    try {
      final userId = await _auth.getUserId();
      
      // We don't have the Job ID yet, let's create a stub document first 
      // or generate a local ID. Since JobRepository.createJob can generate one
      // if not provided, or we can just pass an empty map and let it return the ID.
      // Better: let's generate a temporary unique ID or let repo generate it.
      // For Storage, we need the jobId. Let's create the job first in pending/uploading state.
      
      final jobId = await _repo.createJob({
        'user_id': userId,
        'state': JobState.pending.name,
        'progress': 0.0,
        'message': 'Uploading structures...',
      });

      // Upload Reactant
      final reactantStored = reactantFile.bytes != null 
          ? await _storage.uploadBytes(
              userId: userId, 
              jobId: jobId, 
              fileName: 'reactant.xyz', 
              bytes: reactantFile.bytes!)
          : await _storage.uploadFile(
              userId: userId, 
              jobId: jobId, 
              fileName: 'reactant.xyz', 
              filePath: reactantFile.path!);

      // Upload Product
      final productStored = productFile.bytes != null 
          ? await _storage.uploadBytes(
              userId: userId, 
              jobId: jobId, 
              fileName: 'product.xyz', 
              bytes: productFile.bytes!)
          : await _storage.uploadFile(
              userId: userId, 
              jobId: jobId, 
              fileName: 'product.xyz', 
              filePath: productFile.path!);

      // Update job with locators and settings
      await _repo.updateJob(jobId, {
        'message': 'Job submitted to compute node...',
        'reactant_xyz': reactantStored.locator,
        'product_xyz': productStored.locator,
        ...settings.toFirestoreMap(), // Reusing method name for map export
      });

      _listenToJobUpdates(jobId);
    } catch (e) {
      _setError('Failed to dispatch job: $e');
    }
  }

  // --- Dispatch from embedded template (no file upload) ---
  Future<void> dispatchFromTemplate(
    ReactionTemplate template,
    QuantumSettings settings,
  ) async {
    _setLoading(true);
    try {
      final userId = await _auth.getUserId();

      final jobId = await _repo.createJob({
        'user_id': userId,
        'template_id': template.id,
        'template_name': template.name,
        'reference_ea': template.referenceEa,
        'state': JobState.pending.name,
        'progress': 0.0,
        'message': 'Template job submitted — ${template.name}...',
        'reactant_xyz_inline': template.reactantXyz,
        'product_xyz_inline': template.productXyz,
        ...settings.toFirestoreMap(),
      });

      _listenToJobUpdates(jobId);
    } catch (e) {
      _setError('Failed to dispatch template job: $e');
    }
  }

  // --- Snapshot listener ---
  void _listenToJobUpdates(String jobId) {
    _repo.watchJob(jobId).listen(
      (jobStatus) {
        value = jobStatus;
        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        _setError('Error listening to job: $e');
      },
    );
  }
}
