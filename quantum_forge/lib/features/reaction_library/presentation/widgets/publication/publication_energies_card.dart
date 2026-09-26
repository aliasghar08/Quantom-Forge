import 'package:flutter/material.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/dashboard_cards/glass_card.dart';

class PublicationEnergiesCard extends StatelessWidget {
  final bool isLoading;
  final double? reactantEnergy;
  final double? productEnergy;

  const PublicationEnergiesCard({
    super.key,
    required this.isLoading,
    this.reactantEnergy,
    this.productEnergy,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Transition1x GNN Predictions', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (isLoading)
              const Center(child: CircularProgressIndicator(color: Color(0xFF4FC3F7)))
            else if (reactantEnergy == null && productEnergy == null)
              const Text('Energy predictions unavailable. Ensure tx1-fastapi-backend is running.', style: TextStyle(color: Colors.white54, fontSize: 13))
            else
              Row(
                children: [
                  Expanded(
                    child: _buildEnergyBox('Reactant Energy', reactantEnergy),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildEnergyBox('Product Energy', productEnergy),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnergyBox(String label, double? energy) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          Text(
            energy != null ? '${energy.toStringAsFixed(3)} eV' : 'N/A',
            style: const TextStyle(color: Color(0xFF4FC3F7), fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
