// ============================================================================
// Reaction animation — Avogadro Player parity tests
// ----------------------------------------------------------------------------
// These exercise the widget the way the Player tool is used, and they run
// headlessly: off the web the NGL engine resolves to its stub, so the geometry
// path is exercised (parse -> perceive -> build) while the WebGL surface is
// absent. That is deliberate — the numbers worth asserting on are computed in
// Dart, and a test that needed a GPU would not be run.
//
// The playback expectations mirror upstream `playertool.cpp`:
//   * discrete frames, no tweening
//   * wrapping within [Start, End], including from the last frame forwards and
//     the first frame backwards
//   * `Frame rate: 0` means 5 FPS
//
// Surface size note: the 3D canvas is an AspectRatio(1.2) below a header, so at
// 1280x800 the Avogadro controls sit off-screen and a synthesised tap would miss
// them. The tests therefore use a tall, narrow surface where the whole panel is
// visible, and assert against real taps rather than poking callbacks.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/reaction_animation_widget.dart';

const String _frame1 =
    '3\nReactant\nC 0.00 0.00 0.00\nO 1.43 0.00 0.00\nH 2.39 0.00 0.00\n';
const String _frame2 =
    '3\nTransition state\nC 0.00 0.00 0.00\nO 1.20 0.00 0.00\nH 2.10 0.60 0.00\n';
const String _frame3 =
    '3\nProduct\nC 0.00 0.00 0.00\nO 1.16 0.00 0.00\nH 1.80 0.70 0.00\n';

const List<String> _trajectory = <String>[_frame1, _frame2, _frame3];
const List<double> _energies = <double>[0.0, 5.2, -2.1];

/// Builds the widget on a surface tall enough that every control is tappable.
Future<void> pumpAnimation(
  WidgetTester tester, {
  List<String> frames = _trajectory,
  List<double>? energyProfile = _energies,
  List<double>? energyProfileEv,
  int? maxEnergyIndex,
  int? frameRateOverride,
  Size surface = const Size(900, 1700),
}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ReactionAnimationWidget(
            trajectoryFrames: frames,
            energyProfile: energyProfile,
            energyProfileEv: energyProfileEv,
            maxEnergyIndex: maxEnergyIndex,
            frameRateOverride: frameRateOverride,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// The 1-based frame index shown by the `Frame:` spin box.
int shownFrame(WidgetTester tester) {
  final field = tester.widget<TextField>(
    find.descendant(
      of: find.byKey(const Key('qf-frame-spinbox')),
      matching: find.byType(TextField),
    ),
  );
  return int.parse(field.controller!.text);
}

/// The value of a spin box, by key.
int spinValue(WidgetTester tester, String key) {
  final field = tester.widget<TextField>(
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField)),
  );
  return int.parse(field.controller!.text);
}

/// Types [value] into the spin box identified by [key] and commits it.
Future<void> setSpin(WidgetTester tester, String key, int value) async {
  final field = find.descendant(
    of: find.byKey(Key(key)),
    matching: find.byType(TextField),
  );
  await tester.tap(field);
  await tester.pump();
  await tester.enterText(field, '$value');
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

/// Stops playback first, so the frame ticker stops scheduling and the tree can
/// settle — otherwise every assertion races the timer.
Future<void> pause(WidgetTester tester) async {
  final button = find.byKey(const Key('qf-play-button'));
  if (tester.widget<FilledButton>(button).onPressed != null &&
      find.text('Pause').evaluate().isNotEmpty) {
    await tester.tap(button);
    await tester.pump();
  }
}

void main() {
  testWidgets('renders a trajectory without throwing', (tester) async {
    await pumpAnimation(tester);
    expect(tester.takeException(), isNull);

    // The composition is on screen with real geometry behind it.
    expect(find.text('Approach'), findsWidgets);
    expect(find.text('1 / 3'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'exposes Avogadro\'s Player controls, labelled as upstream does',
    (tester) async {
      await pumpAnimation(tester);
      await pause(tester);

      // The exact label strings from playertool.cpp's toolWidget().
      expect(find.text('Frame:'), findsOneWidget);
      expect(find.text('Start:'), findsOneWidget);
      expect(find.text('End:'), findsOneWidget);
      expect(find.text('Dynamic bonding?'), findsOneWidget);
      expect(find.text('Frame rate:'), findsOneWidget);
      expect(find.text('FPS'), findsOneWidget);

      // The frame spin box and its `/<count>` suffix, as QSpinBox renders it.
      expect(find.byKey(const Key('qf-frame-spinbox')), findsOneWidget);
      expect(find.text('/3'), findsOneWidget);

      // Step buttons are `<` and `>`, not glyph arrows.
      expect(find.text('<'), findsOneWidget);
      expect(find.text('>'), findsOneWidget);
      expect(find.byTooltip('Step back one frame (←)'), findsOneWidget);
      expect(find.byTooltip('Step forward one frame (→)'), findsOneWidget);

      // Avogadro starts with Dynamic bonding unchecked.
      expect(
        tester
            .widget<Checkbox>(find.byKey(const Key('qf-dynamic-bonding')))
            .value,
        isFalse,
      );

      // Avogadro's frame-rate default is 5.
      expect(
        spinValue(tester, 'qf-framerate-spinbox'),
        ReactionAnimationWidget.defaultFrameRate,
      );
      expect(find.text('5 FPS'), findsOneWidget);

      // Start/End default to the full range, shown 1-based.
      expect(spinValue(tester, 'qf-start-spinbox'), 1);
      expect(spinValue(tester, 'qf-end-spinbox'), 3);

      // Ball and Stick is Avogadro's default display type and the only one
      // enabled out of the box.
      expect(find.text('Ball and Stick'), findsOneWidget);

      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('shows the research readout alongside the player', (
    tester,
  ) async {
    await pumpAnimation(tester);
    await pause(tester);

    expect(find.text('Frame: '), findsOneWidget);
    expect(find.text('Energy: '), findsOneWidget);
    expect(find.text('Progress: '), findsOneWidget);
    expect(find.text('Status: '), findsOneWidget);
    expect(find.text('Speed: '), findsOneWidget);
    expect(find.text('Cycle: '), findsOneWidget);
    expect(find.text('Loop: '), findsOneWidget);
    expect(find.text('Bonds: '), findsOneWidget);

    // Cycle duration is span / FPS — the number that actually reads as speed.
    expect(find.text('0.6 s'), findsOneWidget); // 3 frames at 5 FPS
    expect(find.text('Stopped'), findsOneWidget);
    expect(find.text('0.00 kcal·mol⁻¹'), findsOneWidget);
    expect(find.text('0.0%'), findsOneWidget);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('steps frame by frame and wraps like Avogadro', (tester) async {
    await pumpAnimation(tester);
    await pause(tester);

    expect(shownFrame(tester), 1);

    await tester.tap(find.byTooltip('Step forward one frame (→)'));
    await tester.pump();
    expect(shownFrame(tester), 2);
    expect(find.text('5.20 kcal·mol⁻¹'), findsOneWidget);

    await tester.tap(find.byTooltip('Step forward one frame (→)'));
    await tester.pump();
    expect(shownFrame(tester), 3);

    // Stepping past End wraps to Start — `first + ((frame - first) % span +
    // span) % span` — rather than clamping.
    await tester.tap(find.byTooltip('Step forward one frame (→)'));
    await tester.pump();
    expect(shownFrame(tester), 1);

    // And stepping back from the first frame wraps to the last.
    await tester.tap(find.byTooltip('Step back one frame (←)'));
    await tester.pump();
    expect(shownFrame(tester), 3);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('jumps straight to a frame typed into the spin box', (
    tester,
  ) async {
    await pumpAnimation(tester);
    await pause(tester);

    await setSpin(tester, 'qf-frame-spinbox', 2);
    expect(shownFrame(tester), 2);
    expect(find.text('5.20 kcal·mol⁻¹'), findsOneWidget);

    // Out-of-range input is clamped, not rejected.
    await setSpin(tester, 'qf-frame-spinbox', 99);
    expect(shownFrame(tester), 3);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Start and End bound playback, and the current frame follows', (
    tester,
  ) async {
    await pumpAnimation(tester);
    await pause(tester);

    // Narrow the range to frames 2..3.
    await setSpin(tester, 'qf-start-spinbox', 2);
    expect(spinValue(tester, 'qf-start-spinbox'), 2);
    expect(
      shownFrame(tester),
      2,
      reason: 'the current frame must be pulled into the new range',
    );

    await setSpin(tester, 'qf-end-spinbox', 2);
    expect(spinValue(tester, 'qf-end-spinbox'), 2);
    expect(shownFrame(tester), 2);

    // With a single-frame range, stepping cannot leave it.
    await tester.tap(find.byTooltip('Step forward one frame (→)'));
    await tester.pump();
    expect(shownFrame(tester), 2);

    // Cycle is span / FPS, so a one-frame range is one frame long.
    expect(find.text('0.2 s'), findsOneWidget);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('remaps Frame rate 0 to 5 FPS, as Avogadro does', (tester) async {
    await pumpAnimation(tester);
    await pause(tester);

    await setSpin(tester, 'qf-framerate-spinbox', 10);
    expect(find.text('10 FPS'), findsOneWidget);
    // 3 frames at 10 FPS.
    expect(find.text('0.3 s'), findsOneWidget);

    await setSpin(tester, 'qf-framerate-spinbox', 0);
    // Avogadro: `if (fps < 0.00001) fps = 5;` — 0 is not "unbounded".
    expect(find.text('5 FPS'), findsOneWidget);
    expect(find.text('0.6 s'), findsOneWidget);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Dynamic bonding re-perceives bonds from the current frame', (
    tester,
  ) async {
    await pumpAnimation(tester);
    await pause(tester);

    // Frame 1: C–O 1.43 A and O–H 0.96 A are both bonded -> two bonds, one
    // fragment. The first frame's bonds are what a static view draws.
    expect(find.text('2'), findsWidgets);

    await tester.tap(find.byKey(const Key('qf-dynamic-bonding')));
    await tester.pump();
    expect(
      tester
          .widget<Checkbox>(find.byKey(const Key('qf-dynamic-bonding')))
          .value,
      isTrue,
    );

    // Frame 3 is O 1.16 A from C, H 0.64 A from O: still bonded, still 2.
    await tester.tap(find.byTooltip('Step forward one frame (→)'));
    await tester.pump();
    await tester.tap(find.byTooltip('Step forward one frame (→)'));
    await tester.pump();
    expect(shownFrame(tester), 3);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('play/pause toggles the label and stops the frame ticker', (
    tester,
  ) async {
    await pumpAnimation(tester);

    // Autoplay is a deliberate deviation from Avogadro's stopped start, kept
    // from the previous release: a frozen molecule reads as a broken widget.
    expect(find.text('Pause'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is Text && w.data == 'Playing'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('qf-play-button')));
    await tester.pump();
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Stopped'), findsOneWidget);

    // Stopped means stopped: no frame advance over several frame intervals.
    final before = shownFrame(tester);
    await tester.pump(const Duration(milliseconds: 1200));
    expect(shownFrame(tester), before);

    await tester.tap(find.byKey(const Key('qf-play-button')));
    await tester.pump();
    expect(find.text('Pause'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('autoplay advances frames at the configured rate', (
    tester,
  ) async {
    await pumpAnimation(tester);
    expect(find.text('Pause'), findsOneWidget);
    expect(shownFrame(tester), 1);

    // 5 FPS -> 200 ms per frame. Two intervals should advance two frames; the
    // path is three frames long, so this also exercises the wrap.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    expect(shownFrame(tester), 3);

    await tester.pump(const Duration(milliseconds: 200));
    expect(shownFrame(tester), 1, reason: 'wraps to Start after End');

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('keyboard: Space, arrows and Shift for ten', (tester) async {
    await pumpAnimation(tester);
    await pause(tester);

    // Tapping a transport control claims keyboard focus for the panel, which is
    // how the shortcuts become active without stealing the page's arrow keys.
    await tester.tap(find.byTooltip('Step forward one frame (→)'));
    await tester.pump();
    expect(shownFrame(tester), 2);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(shownFrame(tester), 3);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(shownFrame(tester), 2);

    // Shift + arrow steps ten, wrapping within [Start, End].
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(shownFrame(tester), 1);

    // Up jumps to Start, Down to End.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(shownFrame(tester), 3);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(shownFrame(tester), 1);

    // Space toggles playback.
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(find.text('Pause'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(find.text('Play'), findsOneWidget);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('uses the backend transition-state index for the TS readout', (
    tester,
  ) async {
    // max_energy_index is 0-based on the wire; the readout is 1-based like the
    // rest of the Avogadro-style controls.
    await pumpAnimation(tester, maxEnergyIndex: 2);
    await pause(tester);
    expect(find.text('TS frame: '), findsOneWidget);
    expect(find.text('3 / 3'), findsWidgets);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('falls back to the energy-profile maximum when the backend is '
      'silent', (tester) async {
    await pumpAnimation(tester, maxEnergyIndex: null);
    await pause(tester);
    // _energies peaks at index 1 -> frame 2.
    expect(find.text('2 / 3'), findsWidgets);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('reports a missing trajectory instead of an empty canvas', (
    tester,
  ) async {
    await pumpAnimation(tester, frames: const <String>[]);
    expect(find.text('No trajectory frames to animate'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('honours a frame-rate override', (tester) async {
    await pumpAnimation(tester, frameRateOverride: 1);
    await pause(tester);
    expect(find.text('1 FPS'), findsOneWidget);
    // 3 frames at 1 FPS.
    expect(find.text('3.0 s'), findsOneWidget);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
