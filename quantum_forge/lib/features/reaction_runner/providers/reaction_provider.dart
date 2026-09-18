// ============================================================================
// Reaction Provider — Riverpod AsyncNotifier decoupled from Firebase
// 
// Delegates all operations (Auth, Storage, DB) to the injected service layer.
// Supports both custom file dispatch and template dispatch.
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:quantum_forge/core/services/auth_service.dart';
import 'package:quantum_forge/core/services/storage_service.dart';
import 'package:quantum_forge/core/services/reaction_repository.dart';
import 'package:quantum_forge/core/services/file_picker_service.dart';
import 'package:quantum_forge/features/reaction_runner/data/models/reaction_models.dart';
import 'package:quantum_forge/features/reaction_runner/providers/settings_provider.dart';
import 'package:quantum_forge/features/reaction_library/data/reaction_templates.dart';
import 'dart:math' as math;

class ReactionNotifier extends ValueNotifier<ReactionStatusResponse?> {
  final AuthService _auth;
  final StorageService _storage;
  final ReactionRepository _repo;
  bool _isLoading = false;
  String? _error;

  ReactionNotifier(this._auth, this._storage, this._repo) : super(null);

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
  Future<void> dispatchReaction(
    PickedFile reactantFile,
    PickedFile productFile,
    QuantumSettings settings,
  ) async {
    _setLoading(true);
    try {
      final userId = await _auth.getUserId();
      
      // We don't have the Reaction ID yet, let's create a stub document first 
      // or generate a local ID. Since ReactionRepository.createReaction can generate one
      // if not provided, or we can just pass an empty map and let it return the ID.
      // Better: let's generate a temporary unique ID or let repo generate it.
      // For Storage, we need the reactionId. Let's create the reaction first in pending/uploading state.
      
      final reactionId = await _repo.createReaction({
        'user_id': userId,
        'state': ReactionState.pending.name,
        'progress': 0.0,
        'message': 'Uploading structures...',
      });

      // Upload Reactant
      final reactantStored = reactantFile.bytes != null 
          ? await _storage.uploadBytes(
              userId: userId, 
              reactionId: reactionId, 
              fileName: 'reactant.xyz', 
              bytes: reactantFile.bytes!)
          : await _storage.uploadFile(
              userId: userId, 
              reactionId: reactionId, 
              fileName: 'reactant.xyz', 
              filePath: reactantFile.path!);

      // Upload Product
      final productStored = productFile.bytes != null 
          ? await _storage.uploadBytes(
              userId: userId, 
              reactionId: reactionId, 
              fileName: 'product.xyz', 
              bytes: productFile.bytes!)
          : await _storage.uploadFile(
              userId: userId, 
              reactionId: reactionId, 
              fileName: 'product.xyz', 
              filePath: productFile.path!);

      // Update reaction with locators and settings
      await _repo.updateReaction(reactionId, {
        'message': 'Reaction submitted to compute node...',
        'reactant_xyz': reactantStored.locator,
        'product_xyz': productStored.locator,
        ...settings.toFirestoreMap(), // Reusing method name for map export
      });

      _listenToReactionUpdates(reactionId);
      
      // Simulate backend processing
      _simulateReactionProcessing(reactionId, reactantFile.bytes != null ? String.fromCharCodes(reactantFile.bytes!) : 'Mock reactant', productFile.bytes != null ? String.fromCharCodes(productFile.bytes!) : 'Mock product');
    } catch (e) {
      _setError('Failed to dispatch reaction: $e');
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

      // --- Caching check ---
      final cachedReaction = await _repo.findCachedTemplateReaction(template.id, settings.toFirestoreMap());
      if (cachedReaction != null) {
        // Found an existing completed reaction matching this template and settings!
        _setLoading(false);
        value = ReactionStatusResponse(
          reactionId: cachedReaction.reactionId,
          state: ReactionState.optimizing,
          progress: 0.0,
          message: 'Cache hit! Restoring quantum state...',
        );
        notifyListeners();

        // Simulate fast restoration progress
        for (int i = 1; i <= 10; i++) {
          await Future.delayed(const Duration(milliseconds: 100));
          value = ReactionStatusResponse(
            reactionId: cachedReaction.reactionId,
            state: ReactionState.optimizing,
            progress: i / 10.0,
            message: 'Restoring trajectory frames...',
          );
          notifyListeners();
        }

        value = cachedReaction;
        _listenToReactionUpdates(cachedReaction.reactionId);
        notifyListeners();
        return;
      }
      // ---------------------

      final reactionId = await _repo.createReaction({
        'user_id': userId,
        'template_id': template.id,
        'template_name': template.name,
        'reference_ea': template.referenceEa,
        'state': ReactionState.pending.name,
        'progress': 0.0,
        'message': 'Template reaction submitted — ${template.name}...',
        'reactant_xyz_inline': template.reactantXyz,
        'product_xyz_inline': template.productXyz,
        ...settings.toFirestoreMap(),
      });

      _listenToReactionUpdates(reactionId);
      
      // Simulate backend processing
      _simulateReactionProcessing(reactionId, template.reactantXyz, template.productXyz);
    } catch (e) {
      _setError('Failed to dispatch template reaction: $e');
    }
  }

  // --- Simulation logic for testing UI without backend ---
  Future<void> _simulateReactionProcessing(String reactionId, String reactantXyz, String productXyz) async {
    // 1. Pending -> Optimizing
    await Future.delayed(const Duration(seconds: 1));
    await _repo.updateReaction(reactionId, {
      'state': ReactionState.optimizing.name,
      'message': 'Initializing TS Search (NEB)...',
      'progress': 0.1,
    });

    // 2. Loop and update progress
    for (int i = 2; i <= 9; i++) {
      await Future.delayed(const Duration(milliseconds: 1200));
      await _repo.updateReaction(reactionId, {
        'message': 'Optimizing geometry... (Cycle $i)',
        'progress': i / 10.0,
      });
    }

    // 3. Complete and generate mock data
    await Future.delayed(const Duration(seconds: 1));
    
    // Generate mock energy profile based on a bell curve
    List<double> energyProfile = [];
    for (int i = 0; i < 21; i++) {
      double x = (i - 10) / 5.0; // -2 to 2
      double y = 25.0 * math.exp(-x * x / 2); // Gaussian curve up to ~25 kcal/mol
      energyProfile.add(y);
    }

    // Generate mock trajectory frames (linearly interpolate between reactant and product)
    List<String> trajectoryFrames = [];
    try {
      final rLines = reactantXyz.trim().split('\n');
      final pLines = productXyz.trim().split('\n');
      
      // Basic check to ensure they are the same length and format
      if (rLines.length == pLines.length && rLines.length > 2) {
        for (int frame = 0; frame < 21; frame++) {
          double t = frame / 20.0;
          StringBuffer sb = StringBuffer();
          sb.writeln(rLines[0]); // Atom count
          sb.writeln('Frame $frame (t=$t)'); // Comment line
          
          for (int i = 2; i < rLines.length; i++) {
            final rParts = rLines[i].trim().split(RegExp(r'\s+'));
            final pParts = pLines[i].trim().split(RegExp(r'\s+'));
            
            if (rParts.length >= 4 && pParts.length >= 4 && rParts[0] == pParts[0]) {
              final symbol = rParts[0];
              final rx = double.parse(rParts[1]);
              final ry = double.parse(rParts[2]);
              final rz = double.parse(rParts[3]);
              
              final px = double.parse(pParts[1]);
              final py = double.parse(pParts[2]);
              final pz = double.parse(pParts[3]);
              
              final x = rx + (px - rx) * t;
              final y = ry + (py - ry) * t;
              final z = rz + (pz - rz) * t;
              
              sb.writeln('$symbol ${x.toStringAsFixed(4)} ${y.toStringAsFixed(4)} ${z.toStringAsFixed(4)}');
            } else {
               sb.writeln(rLines[i]); // Fallback
            }
          }
          trajectoryFrames.add(sb.toString());
        }
      } else {
        throw Exception("Mismatched xyz lines");
      }
    } catch (e) {
      // Fallback if parsing fails
      trajectoryFrames = List.generate(21, (index) {
        return index < 10 ? reactantXyz : productXyz;
      });
    }

    await _repo.updateReaction(reactionId, {
      'state': ReactionState.completed.name,
      'message': 'TS Search Converged Successfully.',
      'progress': 1.0,
      'energy_profile': energyProfile,
      'trajectory_frames': trajectoryFrames,
    });
  }

  // --- Snapshot listener ---
  void _listenToReactionUpdates(String reactionId) {
    _repo.watchReaction(reactionId).listen(
      (reactionStatus) {
        value = reactionStatus;
        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        _setError('Error listening to reaction: $e');
      },
    );
  }
}
