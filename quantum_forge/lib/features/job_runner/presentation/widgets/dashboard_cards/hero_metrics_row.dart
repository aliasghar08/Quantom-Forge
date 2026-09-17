import 'package:flutter/material.dart';

class HeroMetricsRow extends StatelessWidget {
  final double gibbs;
  final double ea;
  final double rateConst;
  final double baseEnthalpy;
  final double baseEntropy;

  const HeroMetricsRow({
    super.key,
    required this.gibbs,
    required this.ea,
    required this.rateConst,
    required this.baseEnthalpy,
    required this.baseEntropy,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 130,
      child: Row(
        children: [
          _bigMetricCard('ΔG‡', gibbs.toStringAsFixed(1), 'kcal/mol', Icons.bolt, const Color(0xFF69F0AE)),
          const SizedBox(width: 16),
          _bigMetricCard('Ea', ea.toStringAsFixed(1), 'kcal/mol', Icons.local_fire_department, const Color(0xFFFF6E40)),
          const SizedBox(width: 16),
          _bigMetricCard('k', rateConst.toStringAsExponential(1), 's⁻¹', Icons.speed, const Color(0xFFFF80AB)),
          const SizedBox(width: 16),
          _bigMetricCard('ΔH‡', baseEnthalpy.toStringAsFixed(1), 'kcal/mol', Icons.thermostat, const Color(0xFF4FC3F7)),
          const SizedBox(width: 16),
          _bigMetricCard('ΔS‡', baseEntropy.toStringAsFixed(1), 'cal/mol·K', Icons.shuffle, const Color(0xFF80DEEA)),
        ],
      ),
    );
  }

  Widget _bigMetricCard(String title, String val, String unit, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
            const Spacer(),
            Text(val, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
            const SizedBox(height: 2),
            Text(unit, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
