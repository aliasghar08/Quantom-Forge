

enum JobState { idle, pending, optimizing, completed, error }

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

class JobStatusResponse {
  final String jobId;
  final JobState state;
  final double progress;
  final String? message;
  final List<double>? energyProfile;
  final List<String>? trajectoryFrames;
  final List<VibrationalMode>? vibrationalModes;
  final DateTime? createdAt;

  JobStatusResponse({
    required this.jobId,
    required this.state,
    required this.progress,
    this.message,
    this.energyProfile,
    this.trajectoryFrames,
    this.vibrationalModes,
    this.createdAt,
  });

  factory JobStatusResponse.empty() {
    return JobStatusResponse(
      jobId: '',
      state: JobState.idle,
      progress: 0.0,
      message: 'Ready to begin optimization.',
    );
  }

  factory JobStatusResponse.fromJson(Map<String, dynamic> json) {
    JobState parseState(String stateStr) {
      switch (stateStr) {
        case 'pending': return JobState.pending;
        case 'optimizing': return JobState.optimizing;
        case 'completed': return JobState.completed;
        case 'error': return JobState.error;
        default: return JobState.idle;
      }
    }

    return JobStatusResponse(
      jobId: json['job_id'] as String,
      state: parseState(json['state'] as String),
      progress: (json['progress'] as num).toDouble(),
      message: json['message'] as String?,
      energyProfile: (json['energy_profile'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
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
