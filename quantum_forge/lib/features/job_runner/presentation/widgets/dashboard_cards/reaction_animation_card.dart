// ============================================================================
// Reaction Animation Card — wraps ReactionAnimationWidget in a glass card
// ============================================================================

import 'package:flutter/material.dart';
import 'package:quantum_forge/features/job_runner/data/models/job_models.dart';
import 'package:quantum_forge/features/job_runner/presentation/widgets/reaction_animation_widget.dart';
import 'glass_card.dart';

class ReactionAnimationCard extends StatelessWidget {
  final JobStatusResponse status;
  const ReactionAnimationCard({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final energyProfile = status.energyProfile ?? [];
    final trajectoryFrames = status.trajectoryFrames ?? [];

    return GlassCard(
      child: SizedBox(
        height: 650,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  const Icon(Icons.animation,
                      color: Color(0xFF4FC3F7), size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Reaction Mechanism — Bond Breaking & Formation',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFF4FC3F7).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFF4FC3F7)
                              .withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      'Drag to rotate · Live interpolation',
                      style:
                          TextStyle(color: Color(0xFF4FC3F7), fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
            // Animation canvas
            Expanded(
              child: trajectoryFrames.length >= 3
                  ? ReactionAnimationWidget(
                      trajectoryFrames: trajectoryFrames,
                      energyProfile:
                          energyProfile.isEmpty ? null : energyProfile,
                    )
                  : const Center(
                      child: Text(
                        'Need ≥ 3 trajectory frames for animation',
                        style:
                            TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
