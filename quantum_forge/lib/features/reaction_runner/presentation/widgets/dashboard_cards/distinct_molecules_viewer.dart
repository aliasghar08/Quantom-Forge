import 'package:flutter/material.dart';
import 'package:quantum_forge/core/utils/unicode_math.dart';
import 'package:quantum_forge/core/utils/xyz_parser.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/reaction_animation_widget.dart';

// ============================================================================
// DistinctMoleculesViewer — tabbed viewer for distinct molecules
// Uses a single ReactionAnimationWidget to avoid WebGL context limits (16 active contexts).
// ============================================================================

class DistinctMoleculesViewer extends StatefulWidget {
  final String title;
  final List<Atom> atoms;

  const DistinctMoleculesViewer({
    super.key,
    required this.title,
    required this.atoms,
  });

  @override
  State<DistinctMoleculesViewer> createState() => _DistinctMoleculesViewerState();
}

class _DistinctMoleculesViewerState extends State<DistinctMoleculesViewer> {
  int _selectedIndex = 0;
  List<List<Atom>>? _distinctMolecules;
  int _rawMoleculesCount = 0;

  @override
  void initState() {
    super.initState();
    _loadMolecules();
  }

  @override
  void didUpdateWidget(DistinctMoleculesViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.atoms, widget.atoms)) {
      _distinctMolecules = null;
      _loadMolecules();
    }
  }

  Future<void> _loadMolecules() async {
    // Yield to the event loop so the framework can paint the loading spinner,
    // then run the heavy algorithm. (compute() fails on Web with DataCloneError for custom classes).
    await Future.delayed(const Duration(milliseconds: 50));
    final rawMolecules = XyzParser.getDistinctMolecules(widget.atoms);
    
    final uniqueMols = <List<Atom>>[];
    final seenFormulas = <String>{};
    for (final mol in rawMolecules) {
      final info = XyzParser.getMolecularInfo(mol);
      final formula = info.formula.isEmpty ? 'Unknown' : info.formula;
      if (!seenFormulas.contains(formula)) {
        seenFormulas.add(formula);
        uniqueMols.add(mol);
      }
    }
    
    if (mounted) {
      setState(() {
        _distinctMolecules = uniqueMols;
        _rawMoleculesCount = rawMolecules.length;
      });
    }
  }

  String _toXyz(List<Atom> atoms) {
    final sb = StringBuffer();
    sb.writeln(atoms.length);
    sb.writeln('Generated');
    for (final a in atoms) {
      sb.writeln('${a.symbol} ${a.x} ${a.y} ${a.z}');
    }
    return sb.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (_distinctMolecules == null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF4FC3F7)),
            SizedBox(height: 16),
            Text('Analyzing distinct fragments...', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      );
    }

    final distinctMolecules = _distinctMolecules!;
    
    // Safety check if atoms change and the selected index is now out of bounds
    if (_selectedIndex >= distinctMolecules.length) {
      _selectedIndex = 0;
    }

    final selectedMol = distinctMolecules.isNotEmpty 
        ? distinctMolecules[_selectedIndex] 
        : <Atom>[];

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
                      widget.title,
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
                    '${distinctMolecules.length} unique component${distinctMolecules.length == 1 ? '' : 's'} ($_rawMoleculesCount total)',
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
                    'Select a fragment',
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

          if (distinctMolecules.isNotEmpty) ...[
            // ── Selectable Tabs ────────────────────────────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: List.generate(distinctMolecules.length, (index) {
                  final molAtoms = distinctMolecules[index];
                  final info = XyzParser.getMolecularInfo(molAtoms);
                  final formula = info.formula.isEmpty
                      ? 'Unknown'
                      : subscriptFormula(info.formula);

                  final isSelected = _selectedIndex == index;
                  final cardColor = _indexColor(index);

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedIndex = index;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? cardColor.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? cardColor.withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.1),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: cardColor.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: cardColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formula,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Element pills
                          Wrap(
                            spacing: 4,
                            children: _elementPills(molAtoms),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),

            // ── Single 3D Viewer ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _indexColor(_selectedIndex).withValues(alpha: 0.3),
                    width: 1.2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 400),
                    child: ReactionAnimationWidget(
                      // Not using a ValueKey prevents destroying the WebGL context!
                      // Flutter will reuse the widget and just pass new trajectoryFrames.
                      trajectoryFrames: [_toXyz(selectedMol)],
                    ),
                  ),
                ),
              ),
            ),
          ]
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
          '$sym${counts[sym]! > 1 ? subscriptFormula(counts[sym].toString()) : ''}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }).toList();
  }
}
