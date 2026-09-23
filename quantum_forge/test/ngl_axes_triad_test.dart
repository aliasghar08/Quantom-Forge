// ============================================================================
// NglAxesTriad — projection and paint-contract tests
// ----------------------------------------------------------------------------
// The triad is the only orientation feedback the 3D pane has, and NGL cannot
// provide one (see the header of `ngl_axes_triad.dart`), so the widget is the
// whole feature. These tests therefore pin three separate things:
//
//   * the robustness contract — a null, wrong-length or non-finite matrix draws
//     nothing; it must never take the viewer down mid-animation,
//   * the projection — which axis is which colour, which way each one points,
//     and which end reads as nearer. None of that is a pixel assertion: the
//     projection is a pure function, so it is asserted directly,
//   * the paint contract — six half-axes, one origin dot, three labels, and the
//     negative half thinner and dimmer in the same hue as its positive half.
//
// Canvas calls are inspected through `TestRecordingCanvas`, so "renders
// nothing" means "issued no canvas calls at all" rather than "looked blank".
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/ngl/ngl_axes_triad.dart';

// Column-major, so each line below is one COLUMN of the matrix: the image of
// that world basis vector in camera space.
//
// Identity camera: +x right, +y up, +z straight out of the screen at the viewer.
const List<double> _identity = <double>[
  1, 0, 0, 0, // world +x -> camera (1, 0, 0), depth 0
  0, 1, 0, 0, // world +y -> camera (0, 1, 0), depth 0
  0, 0, 1, 0, // world +z -> camera (0, 0, 1), depth +1 (at the viewer)
  0, 0, 0, 1,
];

/// 180 degrees about camera x: +x unchanged, +y flipped, +z away from viewer.
const List<double> _flipped = <double>[
  1,
  0,
  0,
  0,
  0,
  -1,
  0,
  0,
  0,
  0,
  -1,
  0,
  0,
  0,
  0,
  1,
];

/// The box every paint assertion below records into.
const Size _box = Size(72, 72);

/// Several valid camera poses, each with orthonormal columns, for the claims
/// that have to hold at *any* orientation rather than at one lucky one.
const List<List<double>> _cameraAngles = <List<double>>[
  _identity,
  _flipped,
  <double>[
    0, 1, 0, 0, // +x -> camera +y
    0, 0, 1, 0, // +y -> camera +z
    1, 0, 0, 0, // +z -> camera +x
    0, 0, 0, 1,
  ],
  <double>[
    -1, 0, 0, 0, // +x -> camera -x
    0, 0, -1, 0, // +y -> camera -z
    0, -1, 0, 0, // +z -> camera -y
    0, 0, 0, 1,
  ],
  // A non-axis-aligned pose, so every axis is foreshortened and off the axes.
  <double>[
    0.8, 0.6, 0, 0, //
    -0.36, 0.48, 0.8, 0, //
    0.48, -0.64, 0.6, 0, //
    0, 0, 0, 1,
  ],
];

/// A drawLine call, as the painter issued it.
typedef _Line = ({Offset from, Offset to, Paint paint});

void main() {
  // ── Robustness ────────────────────────────────────────────────────────────

  group('malformed orientation', () {
    /// Everything the NGL bridge can hand us when the camera is not ready, the
    /// page is mid-reload, or a quaternion degenerated.
    final malformed = <String, List<double>?>{
      'null': null,
      'empty': const <double>[],
      'too short': List<double>.filled(15, 0),
      'too long': List<double>.filled(17, 0),
      'NaN': <double>[double.nan, ..._identity.skip(1)],
      'infinity': <double>[double.infinity, ..._identity.skip(1)],
      'negative infinity deep in the matrix': <double>[
        ..._identity.take(9),
        double.negativeInfinity,
        ..._identity.skip(10),
      ],
    };

    malformed.forEach((name, orientation) {
      test('projects to nothing for $name', () {
        expect(projectAxes(orientation: orientation, axisLength: 22), isEmpty);
      });

      testWidgets('draws nothing and does not throw for $name', (tester) async {
        final painter = await _painterFor(tester, orientation);

        final canvas = TestRecordingCanvas();
        painter.paint(canvas, _box);

        expect(
          canvas.invocations,
          isEmpty,
          reason: 'a matrix we cannot read must not produce a triad',
        );
        // The box itself survives: "nothing drawn" is not "nothing laid out".
        expect(tester.getSize(find.byType(NglAxesTriad)), const Size(72, 72));
      });
    });

    test('rejects a non-finite axisLength', () {
      expect(
        projectAxes(orientation: _identity, axisLength: double.nan),
        isEmpty,
      );
    });
  });

  // ── Projection ────────────────────────────────────────────────────────────

  group('projectAxes', () {
    test('reads the columns, not the rows', () {
      // A matrix whose x column is (0, 1, 0) and y column is (1, 0, 0). If the
      // transpose were used instead, both axes would come out wrong.
      final axes = projectAxes(
        orientation: const <double>[
          0, 1, 0, 0, //
          1, 0, 0, 0, //
          0, 0, 1, 0, //
          0, 0, 0, 1,
        ],
        axisLength: 22,
      );

      expect(axes[0].offset.dx, closeTo(0, 1e-9));
      expect(axes[0].offset.dy, closeTo(-22, 1e-9));
      expect(axes[1].offset.dx, closeTo(22, 1e-9));
      expect(axes[1].offset.dy, closeTo(0, 1e-9));
    });

    test('identity points +x right, +y up and +z at the viewer', () {
      final axes = projectAxes(orientation: _identity, axisLength: 22);

      expect(axes, hasLength(3));
      expect(axes.map((a) => a.label), orderedEquals(<String>['x', 'y', 'z']));

      // Canvas y grows downwards, so camera +y is a negative dy.
      expect(axes[0].offset, _near(const Offset(22, 0)));
      expect(axes[0].depth, closeTo(0, 1e-9));

      expect(axes[1].offset, _near(const Offset(0, -22)));
      expect(axes[1].depth, closeTo(0, 1e-9));

      // +z is edge-on: it has no screen extent at all, only depth.
      expect(axes[2].offset, _near(Offset.zero));
      expect(axes[2].depth, closeTo(1, 1e-9));
      expect(axes[2].isEdgeOn, isTrue);
      expect(axes[0].isEdgeOn, isFalse);
    });

    test('uses axisLength for the reach of every axis', () {
      final short = projectAxes(orientation: _identity, axisLength: 10);
      final long = projectAxes(orientation: _identity, axisLength: 40);

      expect(short[0].offset.dx, closeTo(10, 1e-9));
      expect(long[0].offset.dx, closeTo(40, 1e-9));
      expect(
        short.map((a) => a.offset.distance).reduce(_max),
        closeTo(10, 1e-9),
      );
      expect(
        long.map((a) => a.offset.distance).reduce(_max),
        closeTo(40, 1e-9),
      );
    });

    test('carries the molecular-viewer colours', () {
      final axes = projectAxes(orientation: _identity, axisLength: 22);

      // +x red, +y green, +z blue: assert the dominant channel rather than the
      // exact shade, so the palette can be retuned without breaking the rule.
      expect(axes[0].color.r, greaterThan(axes[0].color.g));
      expect(axes[0].color.r, greaterThan(axes[0].color.b));
      expect(axes[1].color.g, greaterThan(axes[1].color.r));
      expect(axes[1].color.g, greaterThan(axes[1].color.b));
      expect(axes[2].color.b, greaterThan(axes[2].color.r));
      expect(axes[2].color.b, greaterThan(axes[2].color.g));
    });

    test('an axis leaning at the viewer is brighter and heavier than one '
        'leaning away', () {
      final nearAxis = projectAxes(orientation: _identity, axisLength: 22)[2];
      final farAxis = projectAxes(orientation: _flipped, axisLength: 22)[2];
      final flatAxis = projectAxes(orientation: _identity, axisLength: 22)[0];

      expect(nearAxis.depth, closeTo(1, 1e-9));
      expect(farAxis.depth, closeTo(-1, 1e-9));

      expect(nearAxis.nearFactor, closeTo(1, 1e-9));
      expect(farAxis.nearFactor, closeTo(0, 1e-9));
      expect(flatAxis.nearFactor, closeTo(0.5, 1e-9));

      expect(nearAxis.opacity, greaterThan(farAxis.opacity));
      expect(nearAxis.strokeWidth, greaterThan(farAxis.strokeWidth));
      // The screen-plane axis sits between the two extremes.
      expect(
        flatAxis.opacity,
        inExclusiveRange(farAxis.opacity, nearAxis.opacity),
      );
      expect(
        flatAxis.strokeWidth,
        inExclusiveRange(farAxis.strokeWidth, nearAxis.strokeWidth),
      );
    });

    test('the negative half is thinner and dimmer in the same hue', () {
      for (final axis in projectAxes(orientation: _identity, axisLength: 22)) {
        expect(axis.negativeStrokeWidth, lessThan(axis.strokeWidth));
        expect(axis.negativeOpacity, lessThan(axis.opacity));
        expect(
          axis.negativeStrokeWidth / axis.strokeWidth,
          closeTo(AxisProjection.negativeStrokeScale, 1e-9),
        );
        expect(
          axis.negativeOpacity / axis.opacity,
          closeTo(AxisProjection.negativeOpacityScale, 1e-9),
        );
      }
    });

    test('ignores a scale folded into a column', () {
      // Not a rotation matrix: every column is three times too long. The triad
      // must stay the size the caller asked for.
      final axes = projectAxes(
        orientation: const <double>[
          3, 0, 0, 0, //
          0, 3, 0, 0, //
          0, 0, 3, 0, //
          0, 0, 0, 1,
        ],
        axisLength: 22,
      );

      expect(axes[0].offset, _near(const Offset(22, 0)));
      expect(axes[2].depth, closeTo(1, 1e-9));
    });

    test('clamps a depth that cannot come from a rotation', () {
      // A garbage column with z far outside [-1, 1] must not push opacity or
      // stroke width past their endpoints.
      final axes = projectAxes(
        orientation: const <double>[
          1, 0, 0, 0, //
          0, 1, 0, 0, //
          0, 0, 50, 0, //
          0, 0, 0, 1,
        ],
        axisLength: 22,
      );

      expect(axes[2].depth, closeTo(1, 1e-9));
      expect(axes[2].nearFactor, closeTo(1, 1e-9));
      expect(axes[2].opacity, lessThanOrEqualTo(1.0));
    });
  });

  // ── Painting order and determinism ────────────────────────────────────────

  group('painting order', () {
    test('is farthest first, so the near axis lands on top', () {
      final identityOrder = orderAxesForPainting(
        projectAxes(orientation: _identity, axisLength: 22),
      );
      expect(
        identityOrder.map((a) => a.label),
        orderedEquals(<String>['x', 'y', 'z']),
      );
      expect(identityOrder.last.label, 'z', reason: '+z points at the viewer');

      final flippedOrder = orderAxesForPainting(
        projectAxes(orientation: _flipped, axisLength: 22),
      );
      expect(
        flippedOrder.map((a) => a.label),
        orderedEquals(<String>['z', 'x', 'y']),
      );
      expect(flippedOrder.first.label, 'z', reason: '+z now points away');
    });

    test('is total, so equal depths never reshuffle the stack', () {
      final projections = projectAxes(orientation: _identity, axisLength: 22);
      final variants = <List<AxisProjection>>[
        projections,
        projections.reversed.toList(),
        <AxisProjection>[projections[2], projections[0], projections[1]],
      ];

      for (final variant in variants) {
        expect(
          orderAxesForPainting(variant).map((a) => a.label),
          orderedEquals(<String>['x', 'y', 'z']),
        );
      }
    });
  });

  group('corner anchoring', () {
    test('keeps every labelled (positive) half inside the box', () {
      // This is what the one-axis-length inset buys. A "small padding" instead
      // looks tidier in the identity view and then cuts the x axis in half the
      // moment the camera turns, because the positive tip is up to axisLength
      // from the origin in any screen direction.
      final origin = triadOrigin(_box, 22);

      for (final orientation in _cameraAngles) {
        for (final axis in projectAxes(
          orientation: orientation,
          axisLength: 22,
        )) {
          final tip = origin + axis.offset;
          expect(
            tip.dx,
            inInclusiveRange(0, _box.width),
            reason: '${axis.label} left the box at $tip',
          );
          expect(
            tip.dy,
            inInclusiveRange(0, _box.height),
            reason: '${axis.label} left the box at $tip',
          );
        }
      }
    });

    test('never drags the origin out of the bottom-right half', () {
      // Even for axes longer than the box can hold, the origin stays in the
      // bottom-right half rather than being pulled towards the top-left.
      for (final box in <Size>[
        _box,
        const Size(120, 120),
        const Size(20, 20),
      ]) {
        for (final axisLength in <double>[0, 5, 22, 40, 500]) {
          final origin = triadOrigin(box, axisLength);
          expect(origin.dx, greaterThanOrEqualTo(box.width / 2));
          expect(origin.dy, greaterThanOrEqualTo(box.height / 2));
          expect(origin.dx, lessThanOrEqualTo(box.width));
          expect(origin.dy, lessThanOrEqualTo(box.height));
        }
      }
    });
  });

  group('determinism', () {
    test('the same matrix projects identically twice', () {
      final first = projectAxes(orientation: _identity, axisLength: 22);
      final second = projectAxes(orientation: _identity, axisLength: 22);

      expect(second, equals(first));
      expect(
        orderAxesForPainting(second).map((a) => a.label),
        orderedEquals(orderAxesForPainting(first).map((a) => a.label)),
      );
      // And a separate list with the same values is not treated as a change.
      expect(
        projectAxes(orientation: List<double>.of(_identity), axisLength: 22),
        first,
      );
    });

    test('the projection is independent of the caller\'s list identity', () {
      final copy = List<double>.of(_flipped);
      expect(
        projectAxes(orientation: copy, axisLength: 22),
        equals(projectAxes(orientation: _flipped, axisLength: 22)),
      );
    });
  });

  // ── Paint contract ────────────────────────────────────────────────────────

  group('painted output', () {
    testWidgets('draws six half-axes, an origin dot and three labels', (
      tester,
    ) async {
      final painter = await _painterFor(tester, _identity);
      final canvas = _record(painter, _box);

      expect(_lines(canvas), hasLength(6), reason: '3 axes, two halves each');
      // The origin dot plus its dark halo, so it reads on light and dark pages.
      expect(_callsTo(canvas, #drawCircle), hasLength(2));
      expect(_callsTo(canvas, #drawParagraph), hasLength(3));
    });

    testWidgets('anchors the origin in the bottom-right of the box', (
      tester,
    ) async {
      final painter = await _painterFor(tester, _identity);
      final canvas = _record(painter, _box);
      final origin = triadOrigin(_box, 22);

      expect(origin.dx, greaterThan(_box.width / 2));
      expect(origin.dy, greaterThan(_box.height / 2));
      expect(origin.dx, lessThan(_box.width));
      expect(origin.dy, lessThan(_box.height));

      for (final line in _lines(canvas)) {
        expect(line.from, origin);
      }
    });

    testWidgets('reaches exactly axisLength along each half', (tester) async {
      final painter = await _painterFor(tester, _identity);
      final canvas = _record(painter, _box);
      final origin = triadOrigin(_box, 22);

      // With the identity camera, +x is the positive half that runs to the
      // right of the origin; it is drawn right after its own negative half.
      final rightwards = _lines(canvas).firstWhere(
        (line) => (line.to - origin).dx > 0 && (line.to - origin).dy == 0,
      );
      expect(rightwards.to, _near(origin + const Offset(22, 0)));

      // Every half-axis is either the full reach or the collapsed edge-on case.
      for (final line in _lines(canvas)) {
        final reach = (line.to - line.from).distance;
        expect(
          reach == 0 || (reach - 22).abs() < 1e-9,
          isTrue,
          reason: 'reach was $reach, not 0 (edge-on) or axisLength (22)',
        );
      }
    });

    testWidgets('paints the negative half thinner and dimmer, same hue', (
      tester,
    ) async {
      final painter = await _painterFor(tester, _identity);
      final canvas = _record(painter, _box);
      final lines = _lines(canvas);

      // The painter emits each axis as (negative half, positive half) in
      // far-to-near order, so the pairs are adjacent.
      for (var i = 0; i < lines.length; i += 2) {
        final negative = lines[i];
        final positive = lines[i + 1];

        expect(
          positive.paint.strokeWidth,
          greaterThan(negative.paint.strokeWidth),
        );
        expect(positive.paint.color.a, greaterThan(negative.paint.color.a));
        // Dimming must happen in alpha only: the hue has to be identical.
        expect(positive.paint.color.r, closeTo(negative.paint.color.r, 1e-9));
        expect(positive.paint.color.g, closeTo(negative.paint.color.g, 1e-9));
        expect(positive.paint.color.b, closeTo(negative.paint.color.b, 1e-9));
      }
    });

    testWidgets('paints the viewer-facing axis brighter than the same axis '
        'pointing away', (tester) async {
      final nearCanvas = _record(await _painterFor(tester, _identity), _box);
      final farCanvas = _record(await _painterFor(tester, _flipped), _box);

      double maxAlpha(TestRecordingCanvas canvas) =>
          _lines(canvas).map((line) => line.paint.color.a).reduce(_max);
      double maxStroke(TestRecordingCanvas canvas) =>
          _lines(canvas).map((line) => line.paint.strokeWidth).reduce(_max);

      expect(maxAlpha(nearCanvas), greaterThan(maxAlpha(farCanvas)));
      expect(maxStroke(nearCanvas), greaterThan(maxStroke(farCanvas)));
    });

    testWidgets('keeps every stroke inside the box', (tester) async {
      // Edge-on axes collapse to a point and the clipped rect is the only thing
      // keeping the outward halves off the neighbouring UI, so pin the clip.
      final painter = await _painterFor(tester, _identity);
      final canvas = _record(painter, _box);

      expect(_callsTo(canvas, #clipRect), isNotEmpty);
      expect(_callsTo(canvas, #save), isNotEmpty);
      expect(_callsTo(canvas, #restore), isNotEmpty);
    });
  });

  // ── Widget contract ──────────────────────────────────────────────────────

  group('NglAxesTriad', () {
    testWidgets('occupies size x size', (tester) async {
      await tester.pumpWidget(
        const Center(child: NglAxesTriad(orientation: _identity)),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(NglAxesTriad)), const Size(72, 72));

      await tester.pumpWidget(
        const Center(
          child: NglAxesTriad(
            orientation: _identity,
            size: 120,
            axisLength: 40,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(NglAxesTriad)), const Size(120, 120));
    });

    testWidgets('renders for a valid identity matrix', (tester) async {
      await tester.pumpWidget(
        const Center(child: NglAxesTriad(orientation: _identity)),
      );
      expect(tester.takeException(), isNull);

      final customPaint = tester.widget<CustomPaint>(find.byType(CustomPaint));
      expect(customPaint.painter, isNotNull);
      expect(
        _record(customPaint.painter!, _box).invocations,
        isNotEmpty,
        reason: 'the identity camera must produce a visible triad',
      );
    });
  });

  group('shouldRepaint', () {
    testWidgets('is false when the orientation values are unchanged', (
      tester,
    ) async {
      final before = await _painterFor(tester, List<double>.of(_identity));
      final after = await _painterFor(tester, List<double>.of(_identity));

      expect(after.shouldRepaint(before), isFalse);
    });

    testWidgets('is false for two null orientations', (tester) async {
      final before = await _painterFor(tester, null);
      final after = await _painterFor(tester, null);

      expect(after.shouldRepaint(before), isFalse);
    });

    testWidgets('is true when the orientation changes', (tester) async {
      final before = await _painterFor(tester, _identity);
      final after = await _painterFor(tester, _flipped);

      expect(after.shouldRepaint(before), isTrue);
    });

    testWidgets('is true when a single value changes', (tester) async {
      final before = await _painterFor(tester, List<double>.of(_identity));
      final nudged = List<double>.of(_identity)..[9] = 0.0001;
      final after = await _painterFor(tester, nudged);

      expect(after.shouldRepaint(before), isTrue);
    });

    testWidgets('is true when a matrix appears where there was none', (
      tester,
    ) async {
      final before = await _painterFor(tester, null);
      final after = await _painterFor(tester, _identity);

      expect(after.shouldRepaint(before), isTrue);
    });

    testWidgets('is true when the orientation disappears', (tester) async {
      final before = await _painterFor(tester, _identity);
      final after = await _painterFor(tester, null);

      expect(after.shouldRepaint(before), isTrue);
    });

    testWidgets('is true when axisLength changes', (tester) async {
      final before = await _painterFor(tester, _identity, axisLength: 22);
      final after = await _painterFor(tester, _identity, axisLength: 30);

      expect(after.shouldRepaint(before), isTrue);
    });
  });
}

// ── Helpers ────────────────────────────────────────────────────────────────

/// Pumps a corner-placed triad and returns the painter the framework built.
///
/// The `Center` is not decoration: the test surface hands the root widget tight
/// constraints, which would stretch the triad's `SizedBox` to the whole 800x600
/// surface. Real call sites put the triad in a `Stack` or an `Align`, where the
/// constraints are loose and [NglAxesTriad.size] is what the box actually gets.
Future<CustomPainter> _painterFor(
  WidgetTester tester,
  List<double>? orientation, {
  double axisLength = 22,
}) async {
  await tester.pumpWidget(
    Center(
      child: NglAxesTriad(orientation: orientation, axisLength: axisLength),
    ),
  );
  expect(tester.takeException(), isNull);
  return tester.widget<CustomPaint>(find.byType(CustomPaint)).painter!;
}

/// Runs [painter] against a recording canvas instead of a real one.
TestRecordingCanvas _record(CustomPainter painter, Size size) {
  final canvas = TestRecordingCanvas();
  painter.paint(canvas, size);
  return canvas;
}

/// Every drawLine the painter issued, in paint order.
List<_Line> _lines(TestRecordingCanvas canvas) => <_Line>[
  for (final invocation in canvas.invocations)
    if (invocation.invocation.memberName == #drawLine)
      (
        from: invocation.invocation.positionalArguments[0] as Offset,
        to: invocation.invocation.positionalArguments[1] as Offset,
        paint: invocation.invocation.positionalArguments[2] as Paint,
      ),
];

/// The recorded invocations of one canvas method.
List<Invocation> _callsTo(TestRecordingCanvas canvas, Symbol name) =>
    <Invocation>[
      for (final invocation in canvas.invocations)
        if (invocation.invocation.memberName == name) invocation.invocation,
    ];

/// [value] matched with a sub-pixel tolerance.
Matcher _near(Offset value) => predicate<Offset>(
  (actual) =>
      (actual.dx - value.dx).abs() < 1e-9 &&
      (actual.dy - value.dy).abs() < 1e-9,
  'within 1e-9 of $value',
);

double _max(double a, double b) => a > b ? a : b;
