import 'package:flutter/material.dart';
import 'package:quantum_forge/features/reaction_library/data/reaction_templates.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/reaction_animation_widget.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/dashboard_cards/distinct_molecules_viewer.dart';
import 'package:quantum_forge/core/utils/xyz_parser.dart';

class TemplateDetailScreen extends StatelessWidget {
  final ReactionTemplate template;
  final VoidCallback onLoad;

  const TemplateDetailScreen({
    super.key,
    required this.template,
    required this.onLoad,
  });

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(template.category);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(template.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Animation Viewer Header ─────────────────────────────────────
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF15151C),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.1),
                    blurRadius: 30,
                    spreadRadius: 5,
                  )
                ]
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: ReactionAnimationWidget(
                  // A smooth preview path. This previously passed
                  // [reactant, reactant, product] — the reactant duplicated as a
                  // "dummy TS" — so the animation snapped from reactant to product
                  // in a single step and read as far too fast. Interpolating gives
                  // the motion something to show.
                  //
                  // Still only a preview: the real path comes from DMF/UMA, and the
                  // home-screen animation is where that is displayed.
                  trajectoryFrames: _previewTrajectory(template),
                  energyProfile: _generateSyntheticProfile(template.referenceEa),
                  // Slower than the derived default. This is a short preview and the
                  // point is to read the geometry change, not to loop it quickly.
                  speedMsOverride: _previewSpeedMs,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // The preview above is entirely synthetic. Say so, rather than letting
            // it read as a computed result.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFFFCA28).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFFFFCA28).withValues(alpha: 0.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFFFCA28), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Fallback preview — this path is a straight-line interpolation '
                      'between the template\'s reactant and product, and the barrier '
                      'curve is illustrative. Nothing here is UMA output; run the '
                      'template to compute the real path, energies and frequencies.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Metadata Header ───────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    _categoryLabel(template.category),
                    style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt, size: 16, color: Colors.amber.shade400),
                      const SizedBox(width: 4),
                      Text(
                        'Ea: ${template.referenceEa} kcal·mol⁻¹',
                        style: TextStyle(color: Colors.amber.shade300, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onLoad();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                  icon: const Icon(Icons.science),
                  label: const Text('Simulate Reaction', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ── Info Section ──────────────────────────────────────────────
            const Text('Reaction Name', style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 4),
            Text(template.name, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            const Text('IUPAC Description', style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 4),
            Text(template.iupacName, style: const TextStyle(color: Colors.white70, fontSize: 16, fontStyle: FontStyle.italic)),
            const SizedBox(height: 24),

            const Text('Mechanism & Details', style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 4),
            Text(template.description, style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.6)),
            const SizedBox(height: 32),

            // ── Static Molecule Viewers ──────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DistinctMoleculesViewer(
                    title: 'Reactants',
                    atoms: XyzParser.parse(template.reactantXyz),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: DistinctMoleculesViewer(
                    title: 'Products',
                    atoms: XyzParser.parse(template.productXyz),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ── Tags & Reference ──────────────────────────────────────────
            const Text('Tags', style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: template.tags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('#$tag', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.book, color: Colors.white54),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Literature Reference', style: TextStyle(color: Colors.white54, fontSize: 10)),
                        Text(template.journalRef, style: const TextStyle(color: Colors.white, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('DOI: ${template.doi}', style: const TextStyle(color: Colors.blueAccent, fontSize: 12)),
                      ],
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Color _categoryColor(ReactionCategory c) {
    return switch (c) {
      ReactionCategory.pericyclic    => const Color(0xFF4FC3F7),
      ReactionCategory.radical       => const Color(0xFFFF7043),
      ReactionCategory.organometallic=> const Color(0xFFAB47BC),
      ReactionCategory.ionic         => const Color(0xFF26A69A),
      ReactionCategory.thermal       => const Color(0xFFFFCA28),
      ReactionCategory.nucleophilic  => const Color(0xFF66BB6A),
    };
  }

  String _categoryLabel(ReactionCategory c) {
    return switch (c) {
      ReactionCategory.pericyclic    => 'Pericyclic',
      ReactionCategory.radical       => 'Radical',
      ReactionCategory.organometallic=> 'Organometallic',
      ReactionCategory.ionic         => 'Ionic',
      ReactionCategory.thermal       => 'Thermal',
      ReactionCategory.nucleophilic  => 'Nucleophilic',
    };
  }

  /// Frames in the preview path.
  ///
  /// Kept in step with [_generateSyntheticProfile], which emits the same number of
  /// points: the animation widget maps frame index straight onto profile index, so
  /// a mismatch (it was 3 frames against 31 points) shows the energy of the wrong
  /// point on the path.
  static const int _previewFrames = 31;

  /// Per-frame interval for the preview (~28 s per pass). Slower than the derived
  /// default because this short path is meant to be read, not skimmed.
  static const int _previewSpeedMs = 900;

  /// A smooth preview path — linear interpolation between the reactant and product
  /// coordinates, which is all the template data supports.
  ///
  /// Not a computed reaction path: DMF/UMA produces the real one. This exists so
  /// the preview reads as motion instead of a single jump.
  List<String> _previewTrajectory(ReactionTemplate template) {
    final reactant = XyzParser.parse(template.reactantXyz);
    final product = XyzParser.parse(template.productXyz);

    // The two structures must be comparable or there is nothing to interpolate.
    if (reactant.isEmpty || reactant.length != product.length) {
      return [template.reactantXyz, template.productXyz];
    }

    return List<String>.generate(_previewFrames, (frame) {
      final t = frame / (_previewFrames - 1);
      final buffer = StringBuffer()
        ..writeln(reactant.length)
        ..writeln('${template.name} — preview frame ${frame + 1}/$_previewFrames');
      for (var a = 0; a < reactant.length; a++) {
        final r = reactant[a];
        final p = product[a];
        buffer.writeln(
          '${r.symbol.padRight(2)} '
          '${(r.x + (p.x - r.x) * t).toStringAsFixed(4).padLeft(10)} '
          '${(r.y + (p.y - r.y) * t).toStringAsFixed(4).padLeft(10)} '
          '${(r.z + (p.z - r.z) * t).toStringAsFixed(4).padLeft(10)}',
        );
      }
      return buffer.toString();
    });
  }

  List<double> _generateSyntheticProfile(double ea) {
    final profile = <double>[];
    final ep = -ea * 0.5; // Exothermic assumption
    for (int i = 0; i < _previewFrames; i++) {
      double t = i / (_previewFrames - 1);
      if (t <= 0.35) {
        double p = t / 0.35;
        double s = p * p * (3 - 2 * p);
        profile.add(ea * s);
      } else {
        double p = (t - 0.35) / 0.65;
        double s = p * p * (3 - 2 * p);
        profile.add(ea + (ep - ea) * s);
      }
    }
    return profile;
  }
}

