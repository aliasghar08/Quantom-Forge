// ============================================================================
// NGL browser harness — a build target, not part of the app
// ----------------------------------------------------------------------------
// The unit tests cover everything that can be checked headlessly: bond
// perception, radii, colours, frame stepping. What they cannot cover is whether
// the WebGL path works at all — whether the vendored `ngl.js` loads, whether the
// platform-view factory hands NGL a sized element, whether a `Shape` actually
// turns into pixels, and whether stepping frames changes the picture.
//
// So this is a second entry point, built only when a harness is wanted:
//
//     flutter build web --release -t tool/ngl_harness.dart
//     python -m http.server 8099 --directory build/web
//     node tool/ngl_probe.cjs
//
// `tool/ngl_probe.cjs` drives headless Chrome over the DevTools protocol,
// asserts that a canvas exists inside the NGL container, and checks that the
// rendered frame is not uniformly black — which is what a silently broken
// geometry hand-off looks like.
//
// The production bundle is untouched: `flutter build web` with the default
// target only compiles what `lib/main.dart` reaches, and nothing in the app
// imports this file.
//
// The trajectory is a C–H homolysis, chosen because it makes dynamic bonding
// visible rather than merely exercised: the C–H2 bond is inside the 1.52 A
// cutoff for the first three frames and outside it for the last two, so the
// fragment count climbs 1 -> 2 across the path.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/reaction_animation_widget.dart';

/// `C–H1` fixed at 1.09 A, `H2` stretching away from the carbon until the bond
/// breaks.
String _frame(int index) {
  const h2Distances = <double>[1.09, 1.30, 1.50, 1.65, 1.85];
  final h2 = h2Distances[index];
  return '3\nC-H homolysis, image ${index + 1}\n'
      'C 0.00000 0.00000 0.00000\n'
      'H 1.09000 0.00000 0.00000\n'
      'H ${(-h2).toStringAsFixed(5)} 0.00000 0.00000\n';
}

void main() {
  final frames = <String>[for (var i = 0; i < 5; i++) _frame(i)];
  // Rising, then falling: a barrier, so the phase bands and the TS marker have
  // something real to point at.
  const energies = <double>[0.0, 28.4, 61.7, 55.2, 40.1];

  // Query parameters let `tool/ngl_probe.cjs` drive the two configurations it
  // needs from one build: dynamic bonding off (bond set fixed at the first
  // frame) and on (re-perceived every frame, so the cylinder count drops from
  // 4 to 2 once H2 leaves the 1.52 A C-H cutoff).
  final query = Uri.base.queryParameters;
  final dynamicBonding = query['dynamicBonding'] == '1';
  final frameRate = int.tryParse(query['fps'] ?? '') ?? 2;

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0D0D12),
        body: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'NGL harness — C–H homolysis, 5 images '
                      '(dynamic bonding: ${dynamicBonding ? 'on' : 'off'}, '
                      '$frameRate FPS)',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFF15151C),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ReactionAnimationWidget(
                        trajectoryFrames: frames,
                        energyProfile: energies,
                        maxEnergyIndex: 2,
                        dynamicBonding: dynamicBonding,
                        frameRateOverride: frameRate,
                        // Always on in the harness: the probe asserts the badges
                        // reach NGL as their own component, and a toggle that
                        // defaults off would never be exercised in the build that
                        // gets automated.
                        showBondNumbers: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
