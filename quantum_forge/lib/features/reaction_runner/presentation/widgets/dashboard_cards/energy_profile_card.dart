import 'package:flutter/material.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/kinetic_chart_widget.dart';

class EnergyProfileCard extends StatelessWidget {
  final List<double> energyProfile;
  final double? referenceEa;
  final ValueChanged<int> onPointSelected;

  const EnergyProfileCard({
    super.key,
    required this.energyProfile,
    this.referenceEa,
    required this.onPointSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(
              children: [
                const Text('Reaction Energy Profile',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (referenceEa != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'Ref Ea: ${referenceEa!.toStringAsFixed(1)} kcal/mol',
                      style: TextStyle(color: Colors.amber.shade300, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: KineticChartWidget(
              energyProfile: energyProfile,
              referenceEa: referenceEa,
              onPointSelected: onPointSelected,
            ),
          ),
        ],
      ),
    );
  }
}
