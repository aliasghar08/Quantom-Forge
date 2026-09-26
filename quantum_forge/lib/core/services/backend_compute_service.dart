// ============================================================================
// Backend compute service — bridge to the ColabReaction (DMF) API
// ----------------------------------------------------------------------------
// Talks to the FastAPI backend in `backend/` that runs the Direct MaxFlux +
// MLIP machine-learning-potential reaction-path search. When no backend URL is
// configured, the app keeps its local (illustrative) simulation; when it is
// configured, reactions are dispatched here for the real optimisation.
//
// The request/response shapes mirror `backend/app/models/reaction.py`.
//
// Deployed backend: https://aliasgharinnocent-tx1-backend.hf.space
// (see `kDefaultComputeBackendUrl` in core/settings/app_settings_provider.dart)
// ============================================================================

import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;

import 'package:quantum_forge/core/services/web_services.dart';
import 'package:quantum_forge/features/reaction_runner/data/models/reaction_models.dart';
import 'package:quantum_forge/state/settings_provider.dart';

/// Result of a backend liveness probe, suitable for display in Settings.
class BackendHealth {
  /// True only when `/health` answered with the backend's JSON status payload.
  final bool ok;

  /// Human-readable detail: the server's own message, or why the probe failed.
  final String detail;

  const BackendHealth(this.ok, this.detail);
}

class BackendComputeService {
  const BackendComputeService();

  /// Maps the app's convergence labels onto the notebook's DMF tolerances.
  static String _convergence(QuantumSettings s) {
    switch (s.convergence.toLowerCase()) {
      case 'tight':
      case 'very tight':
        return 'tight';
      case 'loose':
        return 'loose';
      default:
        return 'middle';
    }
  }

  /// Normalises a configured backend URL (drops trailing slashes) so route
  /// paths can be appended directly.
  static String _base(String backendUrl) {
    var base = backendUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return base;
  }

  Map<String, dynamic> _body(
    String reactantXyz,
    String productXyz,
    QuantumSettings settings,
  ) {
    return {
      'reactant_xyz': reactantXyz,
      'product_xyz': productXyz,
      'charge': settings.charge,
      'spin_multiplicity': settings.spinMultiplicity,
      'nmove': settings.nmove,
      'update_teval': settings.updateTeval,
      'convergence': _convergence(settings),
      'mlip_model': settings.mlipModel,
      'hf_token': settings.hfToken.isEmpty ? null : settings.hfToken,
    };
  }

  /// Submits the reaction and returns the reaction id (from the backend).
  Future<String> submit(
    String backendUrl,
    String reactantXyz,
    String productXyz,
    QuantumSettings settings,
  ) async {
    final base = _base(backendUrl);
    final json = await WebServices.postJson(
      '$base/reactions/submit',
      _body(reactantXyz, productXyz, settings),
    );
    final id = json['reaction_id'] as String?;
    if (id == null || id.isEmpty) {
      throw StateError('Backend returned no reaction_id: $json');
    }
    return id;
  }

  /// Polls the backend until the reaction settles, yielding intermediate statuses.
  Stream<ReactionStatusResponse> poll(
    String backendUrl,
    String reactionId, {
    int maxAttempts = 600,
    Duration interval = const Duration(seconds: 2),
  }) async* {
    final base = _base(backendUrl);
    for (var i = 0; i < maxAttempts; i++) {
      await Future<void>.delayed(interval);
      final raw = await WebServices.fetchString('$base/reactions/$reactionId');
      final Map<String, dynamic> json;
      try {
        json = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        continue; // transient non-JSON response; retry
      }
      final state = (json['state'] as String?) ?? 'pending';
      yield _toStatus(json);
      
      if (state == 'completed' || state == 'error') {
        return;
      }
    }
    throw StateError('Reaction $reactionId did not settle in time.');
  }

  static ReactionStatusResponse _toStatus(Map<String, dynamic> json) {
    final state = switch (json['state'] as String?) {
      'pending' => ReactionState.pending,
      'optimizing' => ReactionState.optimizing,
      'completed' => ReactionState.completed,
      'error' => ReactionState.error,
      _ => ReactionState.idle,
    };
    return ReactionStatusResponse(
      reactionId: json['reaction_id'] as String? ?? '',
      state: state,
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      message: json['message'] as String?,
      // Kept separate: collapsing this into `message` let the generic
      // "DMF optimisation failed." shadow the actual cause.
      error: json['error'] as String?,
      fromBackend: true,
      energyProfile: (json['energy_profile'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      // Both of these have always been in the API response and were being dropped.
      energyProfileEv: (json['energy_profile_ev'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      maxEnergyIndex: (json['max_energy_index'] as num?)?.toInt(),
      trajectoryFrames: (json['trajectory_frames'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      vibrationalModes: (json['vibrational_modes'] as List<dynamic>?)
          ?.map((e) => VibrationalMode.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Probes `<backendUrl>/health` — powers the Settings "Test connection" button.
  ///
  /// A bare HTTP 200 is deliberately *not* treated as success. A misrouted or
  /// misconfigured Space answers 200 with an HTML page (that is exactly how a
  /// broken deployment previously looked "healthy"), so the body must decode to
  /// JSON carrying `"status": "ok"`.
  Future<BackendHealth> healthCheck(String backendUrl) async {
    final base = _base(backendUrl);
    if (base.isEmpty) {
      return const BackendHealth(false, 'No backend URL configured.');
    }
    try {
      final raw = await WebServices.fetchString('$base/health');
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['status'] == 'ok') {
        final message = decoded['message'];
        return BackendHealth(
          true,
          message is String && message.isNotEmpty
              ? message
              : 'Backend is healthy.',
        );
      }
      return BackendHealth(false, 'Unexpected /health payload: $raw');
    } catch (e) {
      return BackendHealth(false, 'Cannot reach $base/health —$e');
    }
  }

  // ── Transition1x GNN Energy Prediction ────────────────────────────────────

  /// Predicts the energy of a single molecule using the deployed FastAPI GNN.
  Future<double?> predictEnergy(
    String gnnBackendUrl,
    List<int> atomicNumbers,
    List<List<double>> positions,
  ) async {
    final base = _base(gnnBackendUrl);
    try {
      final json = await WebServices.postJson(
        '$base/predict',
        {
          'atomic_numbers': atomicNumbers,
          'positions': positions,
        },
      );

      if (json['status'] == 'success' && json['energy_ev'] != null) {
        return (json['energy_ev'] as num).toDouble();
      }
      return null;
    } catch (e) {
      // Catch network exceptions or JSON parsing errors. `debugPrint`, not
      // `print`: this is stripped from release builds and does not trip
      // `avoid_print`, while still reaching the console during development.
      debugPrint('GNN Backend Error: $e');
      return null;
    }
  }

  // ── Hybrid MLIP → DFT handoff ──────────────────────────────────────────────

  /// Fetches the transition-state geometry as an XYZ document.
  ///
  /// The backend writes the provenance into the comment line (reaction id, MLIP
  /// barrier, max energy index), so the text is downloaded verbatim rather than
  /// re-serialised here — re-serialising would drop that comment.
  Future<String> exportTransitionState(String backendUrl, String reactionId) {
    final base = _base(backendUrl);
    return WebServices.fetchString('$base/reactions/$reactionId/export-ts');
  }

  /// Attaches a DFT refinement. Returns what the backend stored, including the
  /// barrier it derived from the two Hartree energies.
  Future<DftAttachment> attachDft(
    String backendUrl,
    String reactionId,
    Map<String, dynamic> body,
  ) async {
    final base = _base(backendUrl);
    final json = await WebServices.postJson(
      '$base/reactions/$reactionId/attach-dft',
      body,
    );
    return DftAttachment.fromJson(json);
  }

  // ==========================================
  // Hybrid ML/MM MD Pipeline
  // ==========================================
  
  /// Submits the PDB for hybrid MD simulation and returns the job_id.
  Future<String> submitHybridMd(String backendUrl, String pdbPath) async {
    final base = _base(backendUrl);
    final json = await WebServices.postJson(
      '$base/simulate/hybrid-md',
      {'pdb_path': pdbPath, 'steps': 5000},
      headers: {'Bypass-Tunnel-Reminder': 'true'},
    );
    final id = json['job_id'] as String?;
    if (id == null || id.isEmpty) {
      throw StateError('Backend returned no job_id: $json');
    }
    return id;
  }

  /// Polls the status using a Stream to yield updates every 10 seconds.
  /// Yields a HybridMdStatus containing state and optionally trajectory data.
  Stream<HybridMdStatus> pollHybridMdStream(String backendUrl, String jobId) async* {
    final base = _base(backendUrl);
    
    // We yield the pending state initially
    yield HybridMdStatus(jobId: jobId, state: 'PENDING');
    
    while (true) {
      await Future<void>.delayed(const Duration(seconds: 10));
      
      try {
        final raw = await WebServices.fetchString(
          '$base/simulate/status/$jobId',
          headers: {'Bypass-Tunnel-Reminder': 'true'},
        );
        final json = jsonDecode(raw) as Map<String, dynamic>;
        
        final state = json['status'] as String? ?? 'PENDING';
        final trajectoryDir = json['trajectory_dir'] as String?;
        final frameCount = json['frame_count'] as int?;
        
        yield HybridMdStatus(jobId: jobId, state: state, trajectoryDir: trajectoryDir, frameCount: frameCount);
        
        if (state == 'SUCCESS' || state == 'FAILURE' || state == 'REVOKED') {
          break;
        }
      } catch (e) {
        debugPrint('Error polling Hybrid MD status: $e');
        // Continue polling in case of transient network issues
      }
    }
  }
}

class HybridMdStatus {
  final String jobId;
  final String state;
  final String? trajectoryDir;
  final int? frameCount;

  const HybridMdStatus({
    required this.jobId,
    required this.state,
    this.trajectoryDir,
    this.frameCount,
  });
}