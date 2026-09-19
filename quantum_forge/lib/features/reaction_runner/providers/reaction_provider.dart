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
import 'package:quantum_forge/core/utils/molecule_parser.dart';
import 'package:quantum_forge/core/utils/uuid_util.dart';
import 'dart:convert';
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
      final reactantXyz = reactantFile.bytes != null
          ? utf8.decode(reactantFile.bytes!, allowMalformed: true)
          : '';
      final productXyz = productFile.bytes != null
          ? utf8.decode(productFile.bytes!, allowMalformed: true)
          : '';

      // Guests run in a local, in-memory session — no Firestore, no history.
      // Signing in turns history on (cross-device sync).
      if (!await _auth.isAuthenticated()) {
        await _simulateGuestReaction(reactantXyz, productXyz);
        return;
      }

      final userId = await _auth.getUserId();
      
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
        ...settings.toFirestoreMap(),
      });

      _listenToReactionUpdates(reactionId);
      
      // Simulate backend processing
      _simulateReactionProcessing(reactionId, reactantXyz, productXyz);
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
      // Guests run locally; the template cache and Firestore persistence only
      // apply to signed-in users.
      if (!await _auth.isAuthenticated()) {
        await _simulateGuestReaction(template.reactantXyz, template.productXyz);
        return;
      }

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
      double y = 25.0 * math.exp(-x * x / 2); // Gaussian curve up to ~25 kcal·mol⁻¹
      energyProfile.add(y);
    }

    // Generate mock trajectory frames (smart interpolation)
    List<String> trajectoryFrames = [];
    try {
      final rAtoms = MoleculeParser.parse(reactantXyz, 'xyz');
      final pAtoms = MoleculeParser.parse(productXyz, 'xyz');
      
      if (rAtoms.isEmpty || pAtoms.isEmpty) {
        throw Exception("Empty xyz");
      }

      // Group by symbol to pair them up
      Map<String, List<Atom>> rGroups = {};
      Map<String, List<Atom>> pGroups = {};
      
      for (var a in rAtoms) {
        rGroups.putIfAbsent(a.symbol, () => []).add(a);
      }
      for (var a in pAtoms) {
        pGroups.putIfAbsent(a.symbol, () => []).add(a);
      }

      for (int frame = 0; frame < 21; frame++) {
        double t = frame / 20.0;
        List<Atom> frameAtoms = [];
        
        // Match symbols
        Set<String> allSymbols = {...rGroups.keys, ...pGroups.keys};
        for (var sym in allSymbols) {
          var rList = rGroups[sym] ?? [];
          var pList = pGroups[sym] ?? [];
          int maxLen = math.max(rList.length, pList.length);
          
          for (int i = 0; i < maxLen; i++) {
            if (i < rList.length && i < pList.length) {
              // Interpolate
              var a1 = rList[i];
              var a2 = pList[i];
              frameAtoms.add(Atom(
                sym,
                a1.x + (a2.x - a1.x) * t,
                a1.y + (a2.y - a1.y) * t,
                a1.z + (a2.z - a1.z) * t,
                a1.color,
                a1.radius,
                a1.covalentRadius,
              ));
            } else if (i < rList.length) {
              // Only in reactant - stays at its original position
              var a1 = rList[i];
              frameAtoms.add(Atom(
                sym,
                a1.x,
                a1.y,
                a1.z,
                a1.color,
                a1.radius,
                a1.covalentRadius,
              ));
            } else if (i < pList.length) {
              // Only in product - stays at its original position
              var a2 = pList[i];
              frameAtoms.add(Atom(
                sym,
                a2.x,
                a2.y,
                a2.z,
                a2.color,
                a2.radius,
                a2.covalentRadius,
              ));
            }
          }
        }
        
        StringBuffer sb = StringBuffer();
        sb.writeln('${frameAtoms.length}');
        sb.writeln('Frame $frame (t=$t)');
        for (var a in frameAtoms) {
          sb.writeln('${a.symbol.padRight(2)} ${a.x.toStringAsFixed(4).padLeft(8)} ${a.y.toStringAsFixed(4).padLeft(8)} ${a.z.toStringAsFixed(4).padLeft(8)}');
        }
        trajectoryFrames.add(sb.toString());
      }
    } catch (e) {
      // Fallback if parsing fails entirely
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

  // --- Local (guest) simulation — no Firestore, no history ------------------
  /// Runs the whole workflow in memory for unauthenticated users, updating the
  /// notifier directly. Nothing is persisted, so "history" remains a signed-in
  /// feature while the app itself stays fully usable without an account.
  Future<void> _simulateGuestReaction(String reactantXyz, String productXyz) async {
    final reactionId = 'guest-${UuidUtil.v4()}';

    void emit(ReactionState state, double progress, String message) {
      value = ReactionStatusResponse(
        reactionId: reactionId,
        state: state,
        progress: progress,
        message: message,
      );
      notifyListeners();
    }

    emit(ReactionState.pending, 0.0, 'Queued (local session)…');
    await Future.delayed(const Duration(seconds: 1));
    emit(ReactionState.optimizing, 0.1, 'Initializing TS Search (NEB)…');
    for (int i = 2; i <= 9; i++) {
      await Future.delayed(const Duration(milliseconds: 1200));
      emit(ReactionState.optimizing, i / 10.0, 'Optimizing geometry… (Cycle $i)');
    }
    await Future.delayed(const Duration(seconds: 1));

    // Mock energy profile (Gaussian barrier).
    final energyProfile = List<double>.generate(21, (i) {
      final x = (i - 10) / 5.0;
      return 25.0 * math.exp(-x * x / 2);
    });

    // Mock trajectory frames via symbol-matched interpolation.
    List<String> trajectoryFrames;
    try {
      final rAtoms = MoleculeParser.parse(reactantXyz, 'xyz');
      final pAtoms = MoleculeParser.parse(productXyz, 'xyz');
      if (rAtoms.isEmpty || pAtoms.isEmpty) throw Exception('Empty xyz');

      final rGroups = <String, List<Atom>>{};
      final pGroups = <String, List<Atom>>{};
      for (final a in rAtoms) {
        rGroups.putIfAbsent(a.symbol, () => []).add(a);
      }
      for (final a in pAtoms) {
        pGroups.putIfAbsent(a.symbol, () => []).add(a);
      }

      trajectoryFrames = <String>[];
      for (int frame = 0; frame < 21; frame++) {
        final t = frame / 20.0;
        final frameAtoms = <Atom>[];
        for (final sym in {...rGroups.keys, ...pGroups.keys}) {
          final rList = rGroups[sym] ?? const <Atom>[];
          final pList = pGroups[sym] ?? const <Atom>[];
          final maxLen = math.max(rList.length, pList.length);
          for (int i = 0; i < maxLen; i++) {
            if (i < rList.length && i < pList.length) {
              final a1 = rList[i], a2 = pList[i];
              frameAtoms.add(Atom(
                sym,
                a1.x + (a2.x - a1.x) * t,
                a1.y + (a2.y - a1.y) * t,
                a1.z + (a2.z - a1.z) * t,
                a1.color, a1.radius, a1.covalentRadius,
              ));
            } else if (i < rList.length) {
              frameAtoms.add(rList[i]);
            } else {
              frameAtoms.add(pList[i]);
            }
          }
        }
        final sb = StringBuffer()
          ..writeln('${frameAtoms.length}')
          ..writeln('Frame $frame (t=$t)');
        for (final a in frameAtoms) {
          sb.writeln('${a.symbol.padRight(2)} '
              '${a.x.toStringAsFixed(4).padLeft(8)} '
              '${a.y.toStringAsFixed(4).padLeft(8)} '
              '${a.z.toStringAsFixed(4).padLeft(8)}');
        }
        trajectoryFrames.add(sb.toString());
      }
    } catch (_) {
      trajectoryFrames =
          List.generate(21, (i) => i < 10 ? reactantXyz : productXyz);
    }

    value = ReactionStatusResponse(
      reactionId: reactionId,
      state: ReactionState.completed,
      progress: 1.0,
      message: 'TS Search Converged Successfully (local session).',
      energyProfile: energyProfile,
      trajectoryFrames: trajectoryFrames,
    );
    _isLoading = false;
    notifyListeners();
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
