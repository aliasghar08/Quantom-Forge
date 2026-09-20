// ============================================================================
// Reaction Animation Card — wraps ReactionAnimationWidget in a glass card
//
// v2 changes:
//   * Removed SizedBox(height: 1300) — the card no longer caps its own height.
//   * Removed Expanded around the child — no bounded box to fight against.
//   * Column uses mainAxisSize.min so the card sizes to its content.
//   * Wrapped the whole thing in a SingleChildScrollView as a safety net.
//     If any ancestor hands us a bounded, small box, we scroll internally
//     instead of overflowing. If the ancestor is unbounded (the normal case
//     because the dashboard already has a page-level scroll view), the inner
//     scroll view silently sizes to content and no scrollbar appears.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:quantum_forge/features/reaction_runner/data/models/reaction_models.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/reaction_animation_widget.dart';
import 'glass_card.dart';

class ReactionAnimationCard extends StatelessWidget {
  final ReactionStatusResponse status;
  const ReactionAnimationCard({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final energyProfile    = status.energyProfile    ?? [];
    final trajectoryFrames = status.trajectoryFrames ?? [];

    return GlassCard(
      // SingleChildScrollView defends against any upstream height cap.
      // Under normal conditions the parent is unbounded, so this is a
      // pass-through and the page itself scrolls.
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.animation,
                        color: Color(0xFF4FC3F7), size: 18),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'Reaction Mechanism',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ]),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4FC3F7).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color:
                              const Color(0xFF4FC3F7).withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      '3D Trajectory',
                      style: TextStyle(
                          color: Color(0xFF4FC3F7),
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

            // ── Animation ──────────────────────────────────────────
            // No SizedBox, no Expanded — the widget owns its own height.
            if (trajectoryFrames.length >= 3)
              ReactionAnimationWidget(
                trajectoryFrames: trajectoryFrames,
                energyProfile:
                    energyProfile.isEmpty ? null : energyProfile,
                // Both come straight from the UMA response and were being dropped.
                energyProfileEv: status.energyProfileEv,
                maxEnergyIndex: status.maxEnergyIndex,
              )
            else
              const AspectRatio(
                aspectRatio: 1.5,
                child: Center(
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