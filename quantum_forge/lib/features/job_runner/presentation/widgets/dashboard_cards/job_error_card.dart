// ============================================================================
// Job Error Card — shown when a job fails
// ============================================================================

import 'package:flutter/material.dart';
import 'glass_card.dart';

class JobErrorCard extends StatelessWidget {
  final String error;
  const JobErrorCard({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              Text(error,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
