

enum ReactionState { idle, pending, optimizing, completed, error }

class VibrationalMode {
  final double frequency;
  final List<List<double>> vectors;

  VibrationalMode({required this.frequency, required this.vectors});

  factory VibrationalMode.fromJson(Map<String, dynamic> json) {
    return VibrationalMode(
      frequency: (json['frequency'] as num).toDouble(),
      vectors: (json['vectors'] as List<dynamic>)
          .map((row) => (row as List<dynamic>)
              .map((val) => (val as num).toDouble())
              .toList())
          .toList(),
    );
  }
}

class ReactionStatusResponse {
  final String reactionId;
  final ReactionState state;
  final double progress;
  final String? message;

  /// The backend's own failure reason, kept separate from [message].
  ///
  /// The API returns both: `message` is the generic "DMF/UMA optimisation failed."
  /// and `error` carries the real cause ("ase.io.extxyz: Frame has 1 atoms…").
  /// Merging them — as this did — made the generic string win and discarded the
  /// only useful line.
  final String? error;

  final List<double>? energyProfile;

  /// Absolute potential energies from the UMA model, in eV.
  ///
  /// The backend has always returned these; the app discarded them. They are the
  /// model's own numbers (relative profile is derived from them), so they are kept
  /// and shown rather than recomputed.
  final List<double>? energyProfileEv;

  final List<String>? trajectoryFrames;
  final List<VibrationalMode>? vibrationalModes;

  /// Index of the highest-energy image, computed by DMF on the optimised path.
  ///
  /// Authoritative: the app previously re-derived the transition state by scanning
  /// the profile for its maximum, which can disagree with the solver.
  final int? maxEnergyIndex;

  final DateTime? createdAt;

  /// True when this result came from the ColabReaction (DMF/UMA) compute
  /// backend rather than the local illustrative simulation.
  ///
  /// Real results must never be pushed through the surrogate response model in
  /// `computeResultsSummary`, which multiplies energies by T/300 and shifts them
  /// by charge/spin — that would silently distort genuine UMA output.
  final bool fromBackend;

  ReactionStatusResponse({
    required this.reactionId,
    required this.state,
    required this.progress,
    this.message,
    this.error,
    this.energyProfile,
    this.energyProfileEv,
    this.trajectoryFrames,
    this.vibrationalModes,
    this.maxEnergyIndex,
    this.createdAt,
    this.fromBackend = false,
  });

  factory ReactionStatusResponse.empty() {
    return ReactionStatusResponse(
      reactionId: '',
      state: ReactionState.idle,
      progress: 0.0,
      message: 'Ready to begin optimization.',
    );
  }

  factory ReactionStatusResponse.fromJson(Map<String, dynamic> json) {
    ReactionState parseState(String stateStr) {
      switch (stateStr) {
        case 'pending': return ReactionState.pending;
        case 'optimizing': return ReactionState.optimizing;
        case 'completed': return ReactionState.completed;
        case 'error': return ReactionState.error;
        default: return ReactionState.idle;
      }
    }

    return ReactionStatusResponse(
      reactionId: json['reaction_id'] as String,
      state: parseState(json['state'] as String),
      progress: (json['progress'] as num).toDouble(),
      message: json['message'] as String?,
      error: json['error'] as String?,
      energyProfile: (json['energy_profile'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
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
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }
}
