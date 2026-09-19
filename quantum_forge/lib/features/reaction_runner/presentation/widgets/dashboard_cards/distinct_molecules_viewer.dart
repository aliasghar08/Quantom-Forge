import 'package:flutter/material.dart';
import 'package:quantum_forge/core/utils/xyz_parser.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/molecular_viewer_widget.dart';

// ============================================================================
// DistinctMoleculesViewer — full-height vertical column of molecule viewers
// Each distinct molecule gets a full-size viewer card so bonds are clearly
// visible. Cards are laid out in a vertical Column (all visible, no scrolling
// needed) since the parent is already inside a SingleChildScrollView.
// ============================================================================

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
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4FC3F7).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFF4FC3F7).withValues(alpha: 0.35)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.science,
                        color: Color(0xFF4FC3F7), size: 14),
                    const SizedBox(width: 6),
                    Text(
                      title,
                      style: const TextStyle(
                          color: Color(0xFF4FC3F7),
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                    ),
                  ]),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${distinctMolecules.length} distinct molecule${distinctMolecules.length == 1 ? '' : 's'}',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 11),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4FC3F7).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFF4FC3F7).withValues(alpha: 0.2)),
                  ),
                  child: const Text(
                    'Drag to rotate',
                    style: TextStyle(color: Color(0xFF4FC3F7), fontSize: 10),
                  ),
                ),
              ],
            ),
          ),

          // ── Divider ─────────────────────────────────────────────────────────
          Divider(
              height: 1,
              color: Colors.white.withValues(alpha: 0.06),
              indent: 16,
              endIndent: 16),

          // ── Molecule cards (full-width vertical column) ──────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: List.generate(distinctMolecules.length, (index) {
                final molAtoms = distinctMolecules[index];
                final info = XyzParser.getMolecularInfo(molAtoms);
                final formula =
                    info.formula.isEmpty ? 'Unknown' : info.formula;

                // Colour the molecule index badge
                final cardColor = _indexColor(index);

                return Padding(
                  padding: EdgeInsets.only(
                      bottom: index < distinctMolecules.length - 1 ? 16 : 0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: cardColor.withValues(alpha: 0.25), width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Card header
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(14, 12, 14, 6),
                          child: Row(
                            children: [
                              // Index badge
                              Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: cardColor.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: cardColor.withValues(alpha: 0.5)),
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                        color: cardColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Formula
                              Text(
                                formula,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5),
                              ),
                              const SizedBox(width: 10),
                              // Atom count
                              Text(
                                '${molAtoms.length} atoms',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    fontSize: 11),
                              ),
                              const Spacer(),
                              // Element pills
                              Wrap(
                                spacing: 4,
                                children: _elementPills(molAtoms),
                              ),
                            ],
                          ),
                        ),
                        // Full-size 3D viewer — tall enough to see all bonds
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(14)),
                          child: SizedBox(
                            height: 420,
                            child: MolecularViewerWidget(atoms: molAtoms),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  static Color _indexColor(int i) {
    const colors = [
      Color(0xFF4FC3F7),
      Color(0xFF66BB6A),
      Color(0xFFFFAB40),
      Color(0xFFAB47BC),
      Color(0xFFFF7043),
      Color(0xFF26A69A),
    ];
    return colors[i % colors.length];
  }

  static List<Widget> _elementPills(List<Atom> atoms) {
    final counts = <String, int>{};
    for (final a in atoms) {
      counts[a.symbol] = (counts[a.symbol] ?? 0) + 1;
    }
    // Sort: C first, then H, then alphabetical
    final sorted = counts.keys.toList()
      ..sort((a, b) {
        if (a == 'C') return -1;
        if (b == 'C') return 1;
        if (a == 'H') return -1;
        if (b == 'H') return 1;
        return a.compareTo(b);
      });
    return sorted.take(5).map((sym) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '$sym${counts[sym]! > 1 ? counts[sym] : ''}',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65), fontSize: 9),
        ),
      );
    }).toList();
  }
}
