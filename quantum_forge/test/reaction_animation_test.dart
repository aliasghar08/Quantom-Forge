// ============================================================================
// Reaction animation smoke test
// ----------------------------------------------------------------------------
// The reaction animation is an infinite CustomPainter loop, so it cannot be
// exercised with `pumpAndSettle`. This test pumps a fixed number of frames,
// turns on the electron-transfer / mechanism overlay, and asserts the painter
// draws without throwing — covering the curved-arrow, partial-charge and
// lone-pair code paths that were added on top of the original ball-and-stick
// interpolator.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quantum_forge/features/reaction_runner/presentation/widgets/reaction_animation_widget.dart';

const String _frameR = '3\nReactant\nC 0.00 0.00 0.00\nO 1.50 0.00 0.00\nH 2.40 0.90 0.00\n';
const String _frameTS = '3\nTransition state\nC 0.00 0.00 0.00\nO 1.20 0.00 0.00\nH 2.00 0.80 0.00\n';
const String _frameP = '3\nProduct\nC 0.00 0.00 0.00\nO 1.00 0.00 0.00\nH 1.80 0.70 0.00\n';

void main() {
  testWidgets('renders the trajectory and the mechanism overlay', (tester) async {
    tester.view.physicalSize = const Size(1280, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: const ReactionAnimationWidget(
              trajectoryFrames: [_frameR, _frameTS, _frameP],
              energyProfile: [0.0, 5.2, -2.1],
            ),
          ),
        ),
      ),
    );

    // Initial pump: parse the frames asynchronously.
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);

    // A few animation frames so the ball-and-stick painter runs.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);

    // The mechanism toggle is present and off by default.
    final bolt = find.byIcon(Icons.electric_bolt_outlined);
    expect(bolt, findsOneWidget);

    // Turn on the electron-transfer overlay and render again.
    await tester.tap(bolt);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.electric_bolt), findsOneWidget);

    // Pause, scrub to the transition-state region (where breaking/forming
    // bonds and electron flow are most visible), and render once more.
    final pause = find.byIcon(Icons.pause_rounded);
    await tester.tap(pause);
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);

    // Dispose the infinite animation controller cleanly.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
