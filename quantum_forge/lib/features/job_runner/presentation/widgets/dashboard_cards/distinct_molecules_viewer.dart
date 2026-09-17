import 'package:flutter/material.dart';
import 'package:quantum_forge/core/utils/xyz_parser.dart';
import 'package:quantum_forge/features/job_runner/presentation/widgets/molecular_viewer_widget.dart';

class DistinctMoleculesViewer extends StatelessWidget {
  final String title;
  final List<Atom> atoms;

  const DistinctMoleculesViewer({
    super.key,
    required this.title,
    required this.atoms,
  });

  @override
  Widget build(BuildContext context) {
    final distinctMolecules = XyzParser.getDistinctMolecules(atoms);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Icon(Icons.science, color: const Color(0xFF4FC3F7), size: 18),
                const SizedBox(width: 8),
                Text(
                  '$title (${distinctMolecules.length} Distinct)',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4FC3F7).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF4FC3F7).withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'Drag to rotate',
                    style: TextStyle(color: Color(0xFF4FC3F7), fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 300,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: distinctMolecules.length,
              separatorBuilder: (context, index) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final molAtoms = distinctMolecules[index];
                final info = XyzParser.getMolecularInfo(molAtoms);
                
                return Container(
                  width: 300,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          info.formula.isEmpty ? 'Unknown' : info.formula,
                          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                          child: MolecularViewerWidget(atoms: molAtoms),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
