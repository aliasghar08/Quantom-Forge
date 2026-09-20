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

  testWidgets('exposes the ColabReaction-style playback controls',
      (tester) async {
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
    await tester.pump(const Duration(milliseconds: 50));

    // Labelled "Frame duration", not "Speed": a larger value means a SLOWER
    // animation, so "Speed" read backwards. The default is derived from a target
    // cycle duration rather than the notebook's fixed 200 ms.
    expect(find.text('Frame duration'), findsOneWidget);
    final expectedMs = ReactionAnimationWidget.defaultSpeedMsFor(3);
    expect(expectedMs, greaterThanOrEqualTo(1000),
        reason: 'the default must not be as fast as the notebook 200 ms');
    expect(find.text('$expectedMs ms/frame'), findsOneWidget);

    // The readout also reports the resulting cycle time, which is what a user
    // actually perceives as speed.
    expect(find.text('Cycle: '), findsOneWidget);
    expect(find.text('${(3 * expectedMs / 1000).toStringAsFixed(1)} s'),
        findsOneWidget);

    // Position scrubber + speed slider.
    expect(find.byType(Slider), findsNWidgets(2));

    // The frame readout carries the same fields as the notebook's
    // "Current Frame Information" panel.
    expect(find.text('Frame: '), findsOneWidget);
    expect(find.text('Energy: '), findsOneWidget);
    expect(find.text('Progress: '), findsOneWidget);
    expect(find.text('Status: '), findsOneWidget);
    expect(find.text('Frame duration: '), findsOneWidget);
    expect(find.text('Loop: '), findsOneWidget);

    // The frame scrubber is now labelled, and shows the index beside it — it
    // previously sat under the duration slider with no label at all.
    expect(find.text('Frame'), findsOneWidget);
    // "0 / 2" appears twice now: in the readout and beside the scrubber.
    expect(find.text('0 / 2'), findsWidgets);

    // Navigation row.
    expect(find.byTooltip('First frame'), findsOneWidget);
    expect(find.byTooltip('Step back'), findsOneWidget);
    expect(find.byTooltip('Step forward'), findsOneWidget);
    expect(find.byTooltip('Last frame'), findsOneWidget);

    // Loop modes (each appears as a chip AND as the readout value).
    expect(find.text('forward'), findsWidgets);
    expect(find.text('backward'), findsWidgets);
    expect(find.text('pingpong'), findsWidgets);

    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('steps frame-by-frame and holds position when stopped',
      (tester) async {
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
    await tester.pump(const Duration(milliseconds: 50));

    // Stop first: while playing, the frame ticker keeps scheduling and the tree
    // never settles.
    await tester.tap(find.byTooltip('Stop'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Stopped'), findsOneWidget);

    // The transport row sits below a tall canvas inside a nested scroll view, so
    // a synthesised tap can miss it entirely. Invoke the button's callback
    // directly to exercise the frame-stepping logic itself.
    // The default interval is derived from the frame count, so the tween must be
    // given its full duration for the frame index to land.
    final stepMs = ReactionAnimationWidget.defaultSpeedMsFor(3);
    Future<void> tapControl(String tooltip) async {
      final inkWell = tester.widget<InkWell>(
        find.descendant(of: find.byTooltip(tooltip), matching: find.byType(InkWell)),
      );
      inkWell.onTap!();
      // A freshly scheduled ticker takes its first tick at elapsed 0, so the
      // tween only advances on the pump AFTER that.
      await tester.pump();
      await tester.pump(Duration(milliseconds: stepMs + 50));
    }

    // Read the frame index straight out of the "N / M" readout.
    int frameIndexNow() {
      final finder = find.byWidgetPredicate((w) =>
          w is Text &&
          w.data != null &&
          RegExp(r'^\d+ / \d+$').hasMatch(w.data!));
      final data = tester.widget<Text>(finder.first).data!;
      return int.parse(data.split('/').first.trim());
    }

    await tapControl('First frame');
    expect(frameIndexNow(), 0);

    await tapControl('Step forward');
    expect(frameIndexNow(), 1);

    // The middle frame carries the 5.2 kcal/mol reference energy.
    expect(find.text('5.20 kcal·mol⁻¹'), findsOneWidget);

    await tapControl('Last frame');
    expect(frameIndexNow(), 2);

    // Stepping past the end must clamp, not wrap.
    await tapControl('Step forward');
    expect(frameIndexNow(), 2);

    // Stepping back from the first frame must clamp too.
    await tapControl('First frame');
    await tapControl('Step back');
    expect(frameIndexNow(), 0);

    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
