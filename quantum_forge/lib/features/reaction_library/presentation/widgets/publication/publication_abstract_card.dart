import 'package:flutter/material.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/dashboard_cards/glass_card.dart';

class PublicationAbstractCard extends StatelessWidget {
  final String abstractText;
  final bool isLoading;
  
  const PublicationAbstractCard({super.key, required this.abstractText, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          iconColor: const Color(0xFF4FC3F7),
          collapsedIconColor: Colors.white54,
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          title: const Text('Abstract', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: isLoading 
                  ? const Center(child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(color: Color(0xFF4FC3F7), strokeWidth: 2),
                    ))
                  : Text(abstractText, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.6)),
            ),
          ],
        ),
      ),
    );
  }
}
