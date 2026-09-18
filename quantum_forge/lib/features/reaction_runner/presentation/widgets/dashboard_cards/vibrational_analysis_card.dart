import 'package:flutter/material.dart';
import 'package:quantum_forge/features/reaction_runner/data/models/reaction_models.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/vibrational_viewer_widget.dart';
import 'package:quantum_forge/core/utils/xyz_parser.dart';
import 'glass_card.dart';

class VibrationalAnalysisCard extends StatelessWidget {
  final ReactionStatusResponse status;
  const VibrationalAnalysisCard({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    if (status.trajectoryFrames == null || status.trajectoryFrames!.length < 3) return const SizedBox();
    if (status.vibrationalModes == null || status.vibrationalModes!.isEmpty) return const SizedBox();

    // The transition state is the middle frame of the trajectory
    final tsIdx = status.trajectoryFrames!.length ~/ 2;
    final tsAtoms = XyzParser.parse(status.trajectoryFrames![tsIdx]);

    return GlassCard(
      child: SizedBox(
        height: 500,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  const Icon(Icons.waves, color: Color(0xFFFFAB40), size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Transition State Vibrational Modes',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            // Viewer
            Expanded(
              child: VibrationalViewerWidget(
                atoms: tsAtoms,
                modes: status.vibrationalModes!,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
