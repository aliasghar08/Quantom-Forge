// ============================================================================
// NglAxesTriad — the orientation triad NGL 2.5.0 never shipped
// ----------------------------------------------------------------------------
// A 3D pane is ambiguous without an orientation cue: "the camera moved" and
// "the molecule changed" look the same on screen, and a researcher reading a
// trajectory needs to know which way they are looking. Every desktop viewer
// answers that with a small x/y/z triad in a corner of the canvas.
//
// NGL cannot supply one. The vendored bundle (web/ngl/ngl.js, see
// `ngl_engine_web.dart`) accepts `stage.setParameters({ axes: true })` and then
// ignores it, and the class that used to back the feature — `NGL.Axes` — is not
// exported by that build at all, so there is neither an API to call nor an
// object to fall back to. Patching a third-party bundle to draw a 20-pixel
// widget would be the tail wagging the dog, so the triad is drawn here instead,
// from the one thing NGL does report reliably: `viewerControls
// .getOrientation()`, a column-major 4x4 world->camera matrix.
//
// The widget therefore takes 16 plain doubles and nothing else — no NGL, no
// JavaScript, no WebGL, no conditional import. That keeps it renderable on
// every platform the app builds for, and it makes the whole projection a pure
// function ([projectAxes]) that the unit tests can call without a canvas.
//
// Why the negative halves are dimmed instead of recoloured: an axis and its
// negation are the *same* axis. The common trick of drawing -x in a darker red
// turns it into a fourth, unrelated direction, and it breaks the x=red /
// y=green / z=blue convention this app already uses for axes and spheres. Weight
// is the honest signal: the positive half stays a solid stroke, the negative
// half becomes thinner and more transparent. The pair still reads as one axis
// with two ends, and only the labelled end is ambiguous — which is exactly the
// information the triad exists to convey.
//
// Layout note: the origin hangs off the bottom-right corner, inset by one axis
// length so that the positive — labelled — half of every axis stays inside the
// widget whatever the camera does. Only a negative half can reach out of the
// box, and only when it aims at that corner; they are the second reason the
// negative halves are de-emphasised, and painting is clipped to the box so the
// overlay can never leak strokes onto the rest of the viewer.
// ============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One world axis of the triad, projected into the widget's local space.
///
/// Public so the projection can be asserted directly: a rendered triad is a
/// pure function of the orientation matrix, and every claim the widget makes —
/// which axis is red, which end is nearer, which is drawn last — is a property
/// of these values rather than of the pixels.
class AxisProjection {
  const AxisProjection({
    required this.index,
    required this.label,
    required this.color,
    required this.offset,
    required this.depth,
    required this.nearFactor,
    required this.opacity,
    required this.strokeWidth,
  });

  /// 0 for x, 1 for y, 2 for z — also the index of the matrix column this axis
  /// was read from, and the tie-breaker that keeps painting order deterministic.
  final int index;

  /// `'x'`, `'y'` or `'z'`; drawn at the tip of the positive half.
  final String label;

  /// The axis colour: red for x, green for y, blue for z.
  final Color color;

  /// Tip of the **positive** half, relative to the triad origin, in logical
  /// pixels. Canvas y grows downwards, so the matrix's y component is already
  /// negated here.
  final Offset offset;

  /// Camera-space z of the positive half, clamped to -1..1. Positive means the
  /// axis leans towards the viewer, negative means it leans away.
  final double depth;

  /// [depth] remapped onto 0 (pointing away) .. 1 (pointing at the viewer).
  ///
  /// A linear remap is enough because the projection is orthographic: the
  /// foreshortening of a unit axis is already `depth` itself, so brightness and
  /// depth move together without a separate perspective term.
  final double nearFactor;

  /// Opacity of the positive half — the depth cue.
  final double opacity;

  /// Stroke width of the positive half in logical pixels.
  final double strokeWidth;

  /// How much thinner the negative half is than the positive half.
  static const double negativeStrokeScale = 0.55;

  /// How much dimmer the negative half is than the positive half.
  static const double negativeOpacityScale = 0.38;

  /// Stroke width of the negative half.
  double get negativeStrokeWidth => strokeWidth * negativeStrokeScale;

  /// Opacity of the negative half, in the *same* hue as the positive half.
  double get negativeOpacity => opacity * negativeOpacityScale;

  /// True when the axis points straight at or away from the viewer, so its
  /// screen projection collapses onto the origin and only the label is left to
  /// show where it went.
  bool get isEdgeOn => offset.distance < 1e-9;

  @override
  bool operator ==(Object other) =>
      other is AxisProjection &&
      other.index == index &&
      other.label == label &&
      other.color == color &&
      other.offset == offset &&
      other.depth == depth &&
      other.nearFactor == nearFactor &&
      other.opacity == opacity &&
      other.strokeWidth == strokeWidth;

  @override
  int get hashCode => Object.hash(
    index,
    label,
    color,
    offset,
    depth,
    nearFactor,
    opacity,
    strokeWidth,
  );

  @override
  String toString() =>
      'AxisProjection($label, offset: $offset, depth: '
      '${depth.toStringAsFixed(3)}, opacity: ${opacity.toStringAsFixed(3)})';
}

/// Number of doubles in the matrix. NGL always returns 4x4, valid or not.
const int _orientationLength = 16;

/// Distance between the starts of two columns in the flat matrix.
const int _matrixStride = 4;

/// Axis labels in world-axis order.
const List<String> _axisLabels = <String>['x', 'y', 'z'];

/// +x red, +y green, +z blue — the convention molecular viewers have used
/// since the first wireframe renderers, and the same one the app's atom colours
/// assume. The shades are the accent variants so they stay readable on the
/// near-black NGL canvas.
const List<Color> _axisColors = <Color>[
  Color(0xFFFF5252),
  Color(0xFF69F0AE),
  Color(0xFF448AFF),
];

/// Stroke width of the positive half for an axis pointing away from the viewer.
const double _farStrokeWidth = 1.9;

/// Stroke width of the positive half for an axis pointing at the viewer.
const double _nearStrokeWidth = 3.2;

/// Opacity of the positive half for an axis pointing away from the viewer.
const double _farOpacity = 0.55;

/// Opacity of the positive half for an axis pointing straight at the viewer.
const double _nearOpacity = 1.0;

/// Projects the three world axes for [orientation] into the triad's local space.
///
/// [orientation] is the column-major 4x4 world->camera matrix NGL's
/// `viewerControls.getOrientation()` returns, so column `c` — the doubles at
/// indices `4c`, `4c+1`, `4c+2` — *is* world basis vector `c` expressed in
/// camera space. Its x/y components give the screen direction and its z
/// component gives the depth.
///
/// Returns a list in world-axis order (x, y, z) so callers can index it, or an
/// empty list when the matrix is missing, the wrong length, or carries a
/// non-finite value. Garbage in means no triad out: a triad drawn from a matrix
/// we cannot read would assert a camera direction that is not the real one,
/// which is harder to notice than an absent widget.
List<AxisProjection> projectAxes({
  required List<double>? orientation,
  required double axisLength,
}) {
  final matrix = orientation;
  if (matrix == null || matrix.length != _orientationLength) {
    return const <AxisProjection>[];
  }
  if (!axisLength.isFinite || axisLength < 0) {
    return const <AxisProjection>[];
  }
  for (var i = 0; i < _orientationLength; i++) {
    if (!matrix[i].isFinite) return const <AxisProjection>[];
  }

  final axes = <AxisProjection>[];
  for (var column = 0; column < 3; column++) {
    final base = column * _matrixStride;
    var cx = matrix[base];
    var cy = matrix[base + 1];
    var cz = matrix[base + 2];

    // A rotation matrix has unit columns, so this is a no-op for any matrix NGL
    // produces. It matters for the matrices that are not quite rotations —
    // quaternion drift, or a caller who folded a scale in — where an unnormalised
    // column would stretch one axis clean off the widget while its siblings
    // stayed put, which would misreport the camera twice over.
    final length = math.sqrt(cx * cx + cy * cy + cz * cz);
    if (length > 1e-9) {
      cx /= length;
      cy /= length;
      cz /= length;
    }

    final depth = math.max(-1.0, math.min(1.0, cz));
    final near = (depth + 1) / 2;

    axes.add(
      AxisProjection(
        index: column,
        label: _axisLabels[column],
        color: _axisColors[column],
        // Canvas y grows downwards; camera y grows upwards.
        offset: Offset(cx * axisLength, -cy * axisLength),
        depth: depth,
        nearFactor: near,
        opacity: _lerp(_farOpacity, _nearOpacity, near),
        strokeWidth: _lerp(_farStrokeWidth, _nearStrokeWidth, near),
      ),
    );
  }

  return axes;
}

/// Orders [axes] for painting, farthest first.
///
/// Painter's algorithm: the axis leaning towards the viewer is painted last so
/// it lands on top of the ones behind it. Ties break on [AxisProjection.index]
/// — not on the sort's own stability — so a given matrix always produces the
/// same stacking order and therefore the same picture.
List<AxisProjection> orderAxesForPainting(List<AxisProjection> axes) {
  final ordered = List<AxisProjection>.of(axes);
  ordered.sort((a, b) {
    final byDepth = a.depth.compareTo(b.depth);
    return byDepth != 0 ? byDepth : a.index.compareTo(b.index);
  });
  return ordered;
}

/// Half the stroke width of the heaviest axis: added to the corner inset so a
/// line lying along the widget edge is not sliced by the clip rectangle.
const double _strokeRadius = _nearStrokeWidth / 2;

/// Most of the box the origin may be inset by, so a caller who asks for axes
/// longer than the box can hold still gets an origin near the corner rather
/// than one dragged to the top-left.
const double _maxInsetFraction = 0.5;

/// The origin the three axes share, in a [size] box's local coordinates.
///
/// Bottom-right, inset by one [axisLength] plus the stroke radius rather than by
/// a fixed handful of pixels. That inset is the smallest one for which the
/// positive — labelled — half of every axis stays inside the widget at any
/// camera angle: the positive tip is at most `origin + axisLength` from the
/// corner, so it needs exactly that much room. A smaller inset looks tidier in
/// an identity view and then cuts the x axis in half as soon as the camera
/// turns, which is the one thing a corner triad must not do.
///
/// The inset is capped at half the box so the origin stays in the bottom-right
/// half even when `2 * axisLength` does not fit; past that point no inset can
/// keep the whole triad inside, and the caller's layout is the constraint.
Offset triadOrigin(Size size, double axisLength) {
  final reach = math.max(0.0, axisLength) + _strokeRadius;
  final shortest = size.shortestSide;
  final inset = math.min(reach, shortest * _maxInsetFraction);
  return Offset(size.width - inset, size.height - inset);
}

/// Draws an x/y/z orientation triad from a camera orientation matrix.
///
/// [orientation] is a column-major 4x4 matrix in the same layout NGL's
/// `viewerControls.getOrientation()` returns: 16 doubles. It may be null
/// (nothing drawn yet) or malformed, in which case the widget must render
/// nothing rather than throw.
class NglAxesTriad extends StatelessWidget {
  const NglAxesTriad({
    super.key,
    required this.orientation,
    this.size = 72,
    this.axisLength = 22,
  });

  /// The camera orientation, world -> camera, column-major. Null or malformed
  /// input draws an empty box instead of throwing.
  final List<double>? orientation;

  /// Side length of the square box the triad is drawn in, in logical pixels.
  final double size;

  /// How far each axis reaches from the origin, in logical pixels. The positive
  /// and negative halves are both this long before clipping.
  final double axisLength;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size.square(size),
        painter: _NglAxesTriadPainter(
          orientation: orientation,
          axisLength: axisLength,
        ),
      ),
    );
  }
}

class _NglAxesTriadPainter extends CustomPainter {
  const _NglAxesTriadPainter({
    required this.orientation,
    required this.axisLength,
  });

  final List<double>? orientation;
  final double axisLength;

  /// Glyph height as a fraction of the box, floored and capped so the labels
  /// stay legible on a small triad and modest on a large one.
  static const double _labelFontFraction = 0.18;
  static const double _minLabelFontSize = 9;
  static const double _maxLabelFontSize = 14;

  /// Text is never dimmed below this, whatever the axis depth: a label the
  /// researcher has to squint at is worse than a label that is slightly too
  /// bright for its axis.
  static const double _minLabelOpacity = 0.72;

  /// Radius of the origin dot as a fraction of the box, with an absolute floor.
  static const double _originDotFraction = 0.035;
  static const double _minOriginDotRadius = 2.0;

  /// Keeps a clamped label just off the very edge of the widget.
  static const double _labelEdgeInset = 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (!size.isFinite || size.width <= 0 || size.height <= 0) return;

    final axes = projectAxes(orientation: orientation, axisLength: axisLength);
    if (axes.isEmpty) return;

    final origin = triadOrigin(size, axisLength);
    final paint = _linePaint..strokeCap = StrokeCap.round;

    canvas.save();
    // The triad overlays a viewer; a stroke that escapes the box would be drawn
    // over whatever the layout put beside it.
    canvas.clipRect(Offset.zero & size);

    for (final axis in orderAxesForPainting(axes)) {
      // Negative half first, in the same hue at reduced weight — see the file
      // header for why the sign is carried by weight rather than by colour.
      paint
        ..color = axis.color.withValues(alpha: axis.negativeOpacity)
        ..strokeWidth = axis.negativeStrokeWidth;
      canvas.drawLine(origin, origin - axis.offset, paint);

      paint
        ..color = axis.color.withValues(alpha: axis.opacity)
        ..strokeWidth = axis.strokeWidth;
      canvas.drawLine(origin, origin + axis.offset, paint);
    }

    _paintOriginDot(canvas, origin, size);
    // Labels last, so no axis can be drawn through its own glyph.
    _paintLabels(canvas, axes, origin, size);

    canvas.restore();
  }

  static final Paint _linePaint = Paint();
  static final Paint _originHaloPaint = Paint()..color = const Color(0x66000000);
  static final Paint _originDotPaint = Paint()..color = const Color(0xFFE6E9EF);

  /// The hub all three axes start from.
  ///
  /// It gets a dot because three lines meeting at a point otherwise read as a
  /// single bent line, and it gets a dark halo so it stays visible on a light
  /// page as well as on the black NGL canvas without the caller having to tell
  /// the painter what the background is.
  void _paintOriginDot(Canvas canvas, Offset origin, Size size) {
    final radius = math.max(
      _minOriginDotRadius,
      size.shortestSide * _originDotFraction,
    );
    canvas.drawCircle(origin, radius + 1, _originHaloPaint);
    canvas.drawCircle(origin, radius, _originDotPaint);
  }

  /// Draws one label per positive axis, pushed past the tip along the axis.
  ///
  /// Positions are clamped into the box: the triad is corner-anchored, so a
  /// tip that points out of the widget is normal, and a half-drawn glyph at the
  /// edge would be misread as a different letter.
  void _paintLabels(
    Canvas canvas,
    List<AxisProjection> axes,
    Offset origin,
    Size size,
  ) {
    final fontSize = math.max(
      _minLabelFontSize,
      math.min(_maxLabelFontSize, size.shortestSide * _labelFontFraction),
    );

    for (final axis in orderAxesForPainting(axes)) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: axis.label,
          style: TextStyle(
            color: axis.color.withValues(
              alpha: math.max(axis.opacity, _minLabelOpacity),
            ),
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final tip = origin + axis.offset;
      // An edge-on axis has no direction left to push along, so its label goes
      // up and to the right of the origin dot rather than on top of it.
      final anchor = axis.isEdgeOn
          ? tip + Offset(fontSize * 0.5, -fontSize * 0.9)
          : tip + (axis.offset / axis.offset.distance) * (fontSize * 0.45);

      final maxX = math.max(
        0.0,
        size.width - textPainter.width - _labelEdgeInset,
      );
      final maxY = math.max(
        0.0,
        size.height - textPainter.height - _labelEdgeInset,
      );
      final topLeft = Offset(
        math.min(math.max(anchor.dx - textPainter.width / 2, 0.0), maxX),
        math.min(math.max(anchor.dy - textPainter.height / 2, 0.0), maxY),
      );
      textPainter.paint(canvas, topLeft);
      textPainter.dispose();
    }
  }

  @override
  bool shouldRepaint(covariant _NglAxesTriadPainter oldDelegate) {
    if (oldDelegate.axisLength != axisLength) return true;
    return !_sameMatrix(oldDelegate.orientation, orientation);
  }
}

/// Value comparison of two orientation matrices.
///
/// Deliberately not `identical`: the NGL bridge builds a fresh list on every
/// camera read, so identity would repaint the widget on every frame even when
/// the camera has not moved. Comparing the doubles is what makes "repaint when
/// the orientation values actually change" true.
bool _sameMatrix(List<double>? a, List<double>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    // NaN never equals itself, so a malformed matrix reports a change every
    // time. That costs a repaint of a widget that paints nothing, which is
    // cheaper than special-casing a value that should never reach here.
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Linear interpolation between [a] and [b] by [t].
double _lerp(double a, double b, double t) => a + (b - a) * t;
