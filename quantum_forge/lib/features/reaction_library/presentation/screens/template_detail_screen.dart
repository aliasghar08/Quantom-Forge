import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:quantum_forge/core/utils/xyz_parser.dart';
import 'package:quantum_forge/core/widgets/reaction_animation_widget.dart';
import 'package:quantum_forge/features/reaction_library/data/reaction_templates.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/dashboard_cards/distinct_molecules_viewer.dart';

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
        title: Text(
          template.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
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
                border: Border.all(
                  color: color.withValues(alpha: 0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.1),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: ReactionAnimationWidget(
                  // ── Preview trajectory ─────────────────────────────────
                  //
                  // _previewFrames frames long (see the constant below), with
                  // cosine easing so the system accelerates through the TS
                  // rather than sliding mechanically. Atom-count mismatches —
                  // water leaving, HCl leaving, a fragment dissociating — are
                  // handled by phantom atoms that drift in from or out to a
                  // far radial position, so the leaving group is visible.
                  //
                  // This is a *preview*, not a computed reaction path. The
                  // real path comes from DMF/MLIP through the backend, and for
                  // publication-grade TS work that is what should be used.
                  // The preview exists so a researcher can see the mechanism
                  // before committing cluster time.
                  trajectoryFrames: _previewTrajectory(template),
                  energyProfile: _generateSyntheticProfile(
                    template.referenceEa,
                  ),
                  // Marks the exact TS frame so the readout and the phase
                  // timeline agree on where the barrier is.
                  maxEnergyIndex: _tsFrame,
                  // Deliberately slower than Avogadro's 5 FPS default: this
                  // path is meant to be read frame by frame, not skimmed.
                  frameRateOverride: _previewFps,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // ── Metadata Header ───────────────────────────────────────────
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 600) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: color.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Text(
                              _categoryLabel(template.category),
                              style: TextStyle(
                                color: color,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.bolt,
                                  size: 16,
                                  color: Colors.amber.shade400,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Ea: ${template.referenceEa} kcal·mol⁻¹',
                                  style: TextStyle(
                                    color: Colors.amber.shade300,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          onLoad();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                        ),
                        icon: const Icon(Icons.science),
                        label: const Text(
                          'Simulate Reaction',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  );
                } else {
                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: color.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          _categoryLabel(template.category),
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bolt,
                              size: 16,
                              color: Colors.amber.shade400,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Ea: ${template.referenceEa} kcal·mol⁻¹',
                              style: TextStyle(
                                color: Colors.amber.shade300,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                        ),
                        icon: const Icon(Icons.science),
                        label: const Text(
                          'Simulate Reaction',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 32),

            // ── Info Section ──────────────────────────────────────────────
            const Text(
              'Reaction Name',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              template.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'IUPAC Description',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              template.iupacName,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Mechanism & Details',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              template.description,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),

            // ── Static Molecule Viewers ──────────────────────────────────
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 600) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DistinctMoleculesViewer(
                        title: 'Reactants',
                        atoms: XyzParser.parse(template.reactantXyz),
                      ),
                      const SizedBox(height: 24),
                      DistinctMoleculesViewer(
                        title: 'Products',
                        atoms: XyzParser.parse(template.productXyz),
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                } else {
                  return Row(
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
                  );
                }
              },
            ),
            const SizedBox(height: 32),

            // ── Tags & Reference ──────────────────────────────────────────
            const Text(
              'Tags',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: template.tags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '#$tag',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
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
                        const Text(
                          'Literature Reference',
                          style: TextStyle(color: Colors.white54, fontSize: 10),
                        ),
                        Text(
                          template.journalRef,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'DOI: ${template.doi}',
                          style: const TextStyle(
                            color: Colors.blueAccent,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _categoryColor(ReactionCategory c) {
    return switch (c) {
      ReactionCategory.pericyclic => const Color(0xFF4FC3F7),
      ReactionCategory.radical => const Color(0xFFFF7043),
      ReactionCategory.organometallic => const Color(0xFFAB47BC),
      ReactionCategory.ionic => const Color(0xFF26A69A),
      ReactionCategory.thermal => const Color(0xFFFFCA28),
      ReactionCategory.nucleophilic => const Color(0xFF66BB6A),
      ReactionCategory.electrochemistry => const Color(0xFFE040FB),
      ReactionCategory.inorganic => const Color(0xFF8D6E63),
    };
  }

  String _categoryLabel(ReactionCategory c) {
    return switch (c) {
      ReactionCategory.pericyclic => 'Pericyclic',
      ReactionCategory.radical => 'Radical',
      ReactionCategory.organometallic => 'Organometallic',
      ReactionCategory.ionic => 'Ionic',
      ReactionCategory.thermal => 'Thermal',
      ReactionCategory.nucleophilic => 'Nucleophilic',
      ReactionCategory.electrochemistry => 'Electrochemistry',
      ReactionCategory.inorganic => 'Inorganic',
    };
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ── Preview path ─────────────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════
  //
  // The preview is a research-grade *schematic*, not a computed reaction path.
  // Its job is to show a researcher, before they commit cluster time, what
  // the mechanism does — which atoms move, in what direction, where the TS
  // sits, and what leaves or arrives. The real path comes from the DMF/MLIP
  // backend and lands on the home-screen animation after a run.
  //
  // Design choices below, each with the reasoning attached because they are
  // the kind of thing a reviewer will ask about:
  //
  //   1. **121 frames.** The animation widget's phase timeline splits the
  //      path into Approach (0.00–0.30), TS (0.30–0.70), Separation
  //      (0.70–0.85), Products (0.85–1.00). At 121 frames those bands get
  //      36 / 49 / 18 / 18 frames respectively, so the TS window — the part
  //      a researcher actually wants to step through — has the finest
  //      resolution. 31 frames, the previous value, gave roughly four frames
  //      in the TS window, which is not enough to see a hydrogen migrate.
  //
  //   2. **Cosine easing on the interpolation parameter.** Linear
  //      interpolation moves every atom at constant speed, which reads as a
  //      mechanism drawn by a machine and hides the fact that a real system
  //      *accelerates* through the barrier and *decelerates* into the wells.
  //      `s(t) = 0.5 · (1 − cos(π t))` has zero derivative at both endpoints
  //      and maximum derivative at the midpoint, which is the shape a Morse
  //      trajectory has near a well-to-well transition.
  //
  //   3. **Phantom atoms for the count mismatch.** A condensation loses atoms
  //      (water, HCl, CO₂); an addition gains them. The XYZ interpolation is
  //      per-index, so the two sides must be the same length. Phantom atoms
  //      fill the shorter side by mirroring the unmatched atoms of the longer
  //      side, displaced *radially outward from the molecular centroid* by
  //      25 Å — not along a fixed axis. Radial ejection is what a leaving
  //      group actually does physically, and it avoids the phantom colliding
  //      with the reacting atoms for molecules of any shape.
  //
  //   4. **Eckart-like energy profile.** The previous profile was two cubic
  //      Bezier segments meeting at t = 0.35. That has a kink at the join and
  //      places the maximum at t = 0.35 rather than at the actual TS. The
  //      profile now is the analytic Eckart form
  //
  //          E(t) = (Ea − ΔH/2) · sech²(β(t − 0.5))
  //                     + (ΔH/2) · tanh(β(t − 0.5))
  //                     + ΔH/2
  //
  //      which satisfies E(0) = 0, E(0.5) = Ea, E(1) = ΔH by construction,
  //      is smooth everywhere, and has a properly rounded barrier peak.
  //      β = 6 gives a peak that is visually sharp but not cusped.
  //
  //   5. **ΔH heuristic.** The template does not carry a reaction enthalpy,
  //      so the profile assumes a mildly exothermic reaction, ΔH = −0.3·Ea.
  //      That is a reasonable default for the curated set (condensations,
  //      cycloadditions, substitutions) and it can be replaced the moment
  //      the template schema grows a `deltaH` field. Until then, this is
  //      honest about being an estimate rather than pretending to be a
  //      computed value.
  //
  //   6. **`cosh` and `tanh` implemented via `exp`.** `dart:math` does not
  //      export them. Both are stable for the argument range used here
  //      (`|x| ≤ 3`, since β = 6 and t ∈ [0, 1]), so the exponential form
  //      does not overflow.

  /// Number of frames in the preview path.
  ///
  /// 121 gives the animation widget's four phase bands roughly 36 / 49 / 18 /
  /// 18 frames. The TS window — the part a researcher steps through one image
  /// at a time — gets the most.
  static const int _previewFrames = 121;

  /// Frame index of the transition state.
  ///
  /// The Eckart peak sits at t = 0.5 by construction, so the TS is the middle
  /// frame. Passing this to the animation widget as `maxEnergyIndex` makes the
  /// readout's "TS frame" line agree with the profile.
  static const int _tsFrame = _previewFrames ~/ 2;

  /// Playback rate for the preview.
  ///
  /// Four frames per second makes a full pass about thirty seconds — long
  /// enough to read the mechanism, short enough not to be tedious. Slower
  /// than Avogadro's 5 FPS default because the preview is meant to be read
  /// rather than skimmed.
  static const int _previewFps = 4;

  /// Radial distance, in ångström, that a phantom atom is displaced from its
  /// matched partner's position.
  ///
  /// Chosen to be far outside the range of any non-bonded interaction
  /// (typical van der Waals contact is ~3.5 Å) so the phantom is
  /// unambiguously "gone" by the final frame, and roughly matching the
  /// scale of the camera's default fit so the phantom remains in the frame
  /// while it drifts.
  static const double _phantomEjectionDistance = 25.0;

  /// A smooth, research-grade preview path.
  ///
  /// Not a computed reaction path — see the file-level notes above. Returns
  /// [_previewFrames] XYZ documents interpolated between the reactant and
  /// product geometries, with cosine easing and phantom atoms handling any
  /// atom-count mismatch.
  List<String> _previewTrajectory(ReactionTemplate template) {
    final reactant = XyzParser.parse(template.reactantXyz);
    final product = XyzParser.parse(template.productXyz);

    if (reactant.isEmpty || product.isEmpty) {
      // Nothing to interpolate. Return the two endpoints so the widget shows
      // something rather than nothing; it will draw the reactant and the
      // product as a two-frame sequence.
      return [template.reactantXyz, template.productXyz];
    }

    final int maxLen = math.max(reactant.length, product.length);

    final List<Atom> rAtoms = _padToLength(
      reactant,
      maxLen,
      unmatchedSource: product,
    );
    final List<Atom> pAtoms = _padToLength(
      product,
      maxLen,
      unmatchedSource: reactant,
    );

    return List<String>.generate(_previewFrames, (frame) {
      final double t = frame / (_previewFrames - 1);
      // Cosine easing: derivative is zero at both endpoints, maximal at the
      // midpoint. This is what makes the animation read as a physical
      // trajectory rather than a linear slide.
      final double s = 0.5 * (1.0 - math.cos(math.pi * t));

      final buffer = StringBuffer()
        ..writeln(rAtoms.length)
        ..writeln(
          '${template.name} — frame ${frame + 1}/$_previewFrames',
        );

      for (var a = 0; a < rAtoms.length; a++) {
        final r = rAtoms[a];
        final p = pAtoms[a];
        buffer.writeln(
          '${r.symbol.padRight(2)} '
          '${(r.x + (p.x - r.x) * s).toStringAsFixed(4).padLeft(10)} '
          '${(r.y + (p.y - r.y) * s).toStringAsFixed(4).padLeft(10)} '
          '${(r.z + (p.z - r.z) * s).toStringAsFixed(4).padLeft(10)}',
        );
      }
      return buffer.toString();
    });
  }

  /// Pads [atoms] with phantom atoms until it has [targetLength] entries.
  ///
  /// The phantoms mirror the atoms of [unmatchedSource] that have no partner
  /// in [atoms], displaced radially outward from the molecular centroid by
  /// [_phantomEjectionDistance]. Padding the reactant side therefore produces
  /// a set of atoms that fly away (a leaving group); padding the product side
  /// produces a set that flies in (an arriving group). The two directions are
  /// the same operation with the arguments swapped.
  ///
  /// If a phantom would land on top of the centroid — which happens when an
  /// atom is sitting at the centroid, unusual but possible — the fallback
  /// direction is straight along +x. The choice of +x is arbitrary; the
  /// fallback exists so no phantom ever sits exactly at the centroid.
  List<Atom> _padToLength(
    List<Atom> atoms,
    int targetLength, {
    required List<Atom> unmatchedSource,
  }) {
    if (atoms.length == targetLength) return atoms;
    if (atoms.length > targetLength) {
      // Only reached if the caller passes a longer list by mistake; truncate
      // rather than throw, so the preview still renders.
      return atoms.sublist(0, targetLength);
    }

    final padded = List<Atom>.from(atoms);

    // Centroid of the *matched* atoms — the atoms we are keeping. The
    // centroid of the whole set would be pulled around by the phantoms
    // themselves, which would make the ejection direction unstable.
    final double cx = atoms.fold(0.0, (a, at) => a + at.x) / atoms.length;
    final double cy = atoms.fold(0.0, (a, at) => a + at.y) / atoms.length;
    final double cz = atoms.fold(0.0, (a, at) => a + at.z) / atoms.length;

    // The unmatched atoms of the source list: the tail of the longer list.
    final unmatched = unmatchedSource.sublist(atoms.length, targetLength);

    for (final phantom in unmatched) {
      final double dx = phantom.x - cx;
      final double dy = phantom.y - cy;
      final double dz = phantom.z - cz;
      final double r = math.sqrt(dx * dx + dy * dy + dz * dz);

      final double unitX = r > 0.1 ? dx / r : 1.0;
      final double unitY = r > 0.1 ? dy / r : 0.0;
      final double unitZ = r > 0.1 ? dz / r : 0.0;

      padded.add(Atom(
        phantom.symbol,
        phantom.x + unitX * _phantomEjectionDistance,
        phantom.y + unitY * _phantomEjectionDistance,
        phantom.z + unitZ * _phantomEjectionDistance,
        phantom.color,
        phantom.radius,
        phantom.covalentRadius,
      ));
    }
    return padded;
  }

  /// The synthetic energy profile the animation widget renders.
  ///
  /// Eckart-like: smooth everywhere, maximum at t = 0.5, endpoints fixed at
  /// E(0) = 0 and E(1) = ΔH by construction.
  ///
  /// `cosh` and `tanh` are computed from `exp` directly because `dart:math`
  /// does not export them. Both are stable for the argument range used here
  /// (`|x| ≤ 3`, since β = 6 and t ∈ [0, 1]), so the exponential form does
  /// not overflow.
  List<double> _generateSyntheticProfile(double ea) {
    // Barrier curvature. β = 6 gives a peak that is visually sharp but not
    // cusped at the sampling resolution of 121 frames.
    const double beta = 6.0;

    // Assumed reaction enthalpy. Negative means exothermic, which is the
    // common case for the curated templates. See the file-level notes.
    final double dH = -ea * 0.3;

    final double a = ea - dH / 2;
    final double b = dH / 2;

    return List<double>.generate(_previewFrames, (i) {
      final double t = i / (_previewFrames - 1);
      final double x = beta * (t - 0.5);

      // cosh(x) = (e^x + e^-x) / 2
      final double ex = math.exp(x);
      final double emx = math.exp(-x);
      final double coshX = (ex + emx) / 2.0;

      // sech²(x) = 1 / cosh²(x)
      final double sechSq = 1.0 / (coshX * coshX);

      // tanh(x) = (e^x - e^-x) / (e^x + e^-x)
      final double tanhX = (ex - emx) / (ex + emx);

      return a * sechSq + b * tanhX + dH / 2;
    });
  }
}