import 'package:flutter/material.dart';
import 'package:quantum_forge/core/utils/unicode_math.dart';
import 'package:quantum_forge/core/utils/xyz_parser.dart';

class MolecularDataCards extends StatelessWidget {
  final List<String> trajectoryFrames;

  const MolecularDataCards({
    super.key,
    required this.trajectoryFrames,
  });

  @override
  Widget build(BuildContext context) {
    if (trajectoryFrames.isEmpty) return const SizedBox();

    final rAtoms = XyzParser.parse(trajectoryFrames.first);
    final pAtoms = XyzParser.parse(trajectoryFrames.last);

    final rInfo = XyzParser.getMolecularInfo(rAtoms);
    final pInfo = XyzParser.getMolecularInfo(pAtoms);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return Column(
            children: [
              _buildMolecularDataCard('Reactant', rInfo),
              const SizedBox(height: 16),
              _buildMolecularDataCard('Product', pInfo),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: _buildMolecularDataCard('Reactant', rInfo)),
            const SizedBox(width: 16),
            Expanded(child: _buildMolecularDataCard('Product', pInfo)),
          ],
        );
      },
    );
  }

  Widget _buildMolecularDataCard(String title, MolecularInfo info) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(title == 'Reactant' ? Icons.login : Icons.logout, color: const Color(0xFF4FC3F7), size: 16),
                const SizedBox(width: 8),
                Text(
                  '$title Data',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Formula', style: TextStyle(color: Colors.white54, fontSize: 12)),
                Text(info.formula.isEmpty ? 'Unknown' : subscriptFormula(info.formula), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Molecular Weight', style: TextStyle(color: Colors.white54, fontSize: 12)),
                Text('${info.weight.toStringAsFixed(2)} g/mol', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Atoms', style: TextStyle(color: Colors.white54, fontSize: 12)),
                Text('${info.numAtoms}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
            if (info.elementCounts.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Elements:', style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: info.elementCounts.entries.map((e) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: Text('${e.key}: ${e.value}', style: const TextStyle(color: Colors.white, fontSize: 11)),
                  );
                }).toList(),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
