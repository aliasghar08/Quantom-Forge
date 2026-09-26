import 'package:flutter/material.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/dashboard_cards/glass_card.dart';

class PublicationWarningBanner extends StatelessWidget {
  final String error;
  const PublicationWarningBanner({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Live metadata unavailable: $error',
                style: const TextStyle(color: Colors.orangeAccent, fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
