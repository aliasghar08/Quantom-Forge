import 'package:flutter/material.dart';
import 'package:quantum_forge/features/job_runner/presentation/widgets/kinetic_chart_widget.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  // Mock data for analytics
  final List<double> _mockFrames = List.generate(20, (i) {
    // Parabola shape: max at i=10
    double x = i / 10.0 - 1.0;
    double energy = 30.0 - 30.0 * (x * x); 
    if (energy < 0) energy = 0;
    return energy;
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'Advanced Analytics',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.download),
                label: const Text('Export CSV'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white12,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Main Chart
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Multi-Path Energy Profile (Overlay)', style: TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: KineticChartWidget(
                      energyProfile: _mockFrames,
                      referenceEa: 27.5,
                      onPointSelected: (idx) {},
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Thermodynamics Row
          Expanded(
            flex: 1,
            child: Row(
              children: [
                _buildThermoCard('Enthalpy (ΔH‡)', '25.4 kcal/mol', Icons.thermostat),
                const SizedBox(width: 16),
                _buildThermoCard('Entropy (ΔS‡)', '-12.3 cal/mol·K', Icons.shuffle),
                const SizedBox(width: 16),
                _buildThermoCard('Gibbs Free Energy (ΔG‡)', '29.1 kcal/mol', Icons.bolt),
                const SizedBox(width: 16),
                _buildThermoCard('Imaginary Freq.', '-452.1 cm⁻¹', Icons.waves),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThermoCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF4FC3F7), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
