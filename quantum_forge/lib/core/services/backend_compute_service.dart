// ============================================================================
// Backend compute service — bridge to the ColabReaction (DMF/UMA) API
// ----------------------------------------------------------------------------
// Talks to the FastAPI backend in `backend/` that runs the Direct MaxFlux +
// UMA machine-learning-potential reaction-path search. When no backend URL is
// configured, the app keeps its local (illustrative) simulation; when it is
// configured, reactions are dispatched here for the real optimisation.
//
// The request/response shapes mirror `backend/app/models/reaction.py`.
// ============================================================================

import 'dart:convert';

import 'package:quantum_forge/core/services/web_services.dart';
import 'package:quantum_forge/features/reaction_runner/data/models/reaction_models.dart';
import 'package:quantum_forge/state/settings_provider.dart';

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
    final base = backendUrl.endsWith('/')
        ? backendUrl.substring(0, backendUrl.length - 1)
        : backendUrl;
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

  /// Polls the backend until the reaction settles, returning the final status.
  Future<ReactionStatusResponse> poll(
    String backendUrl,
    String reactionId, {
    int maxAttempts = 600,
    Duration interval = const Duration(seconds: 2),
  }) async {
    final base = backendUrl.endsWith('/')
        ? backendUrl.substring(0, backendUrl.length - 1)
        : backendUrl;
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
      if (state == 'completed' || state == 'error') {
        return _toStatus(json);
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
      message: json['message'] as String? ?? json['error'] as String?,
      energyProfile: (json['energy_profile'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      trajectoryFrames: (json['trajectory_frames'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      vibrationalModes: (json['vibrational_modes'] as List<dynamic>?)
          ?.map((e) => VibrationalMode.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
