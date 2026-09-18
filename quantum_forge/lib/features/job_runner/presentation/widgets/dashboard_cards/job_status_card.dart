// ============================================================================
// Job Status Card — shown while a job is running or pending
// ============================================================================

import 'package:flutter/material.dart';
import 'package:quantum_forge/features/job_runner/data/models/job_models.dart';
import 'glass_card.dart';

class JobStatusCard extends StatelessWidget {
  final String message;
  final double? progress;
  final JobState state;

  const JobStatusCard({
    super.key,
    required this.message,
    required this.progress,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final isRunning =
        state == JobState.optimizing || state == JobState.pending;

    return GlassCard(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isRunning) ...[
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    color: Color(0xFF4FC3F7),
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 24),
              ] else
                Icon(Icons.science_outlined,
                    size: 48, color: Colors.white.withValues(alpha: 0.2)),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7), fontSize: 16),
                textAlign: TextAlign.center,
              ),
              if (progress != null && progress! > 0) ...[
                const SizedBox(height: 24),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: Colors.white12,
                    valueColor:
                        const AlwaysStoppedAnimation(Color(0xFF4FC3F7)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(progress! * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                      color: Color(0xFF4FC3F7),
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
