// ============================================================================
// ReactionAnimationWidget — v2
// Anti-flicker rewrite:
//   • Rotation uses a ValueNotifier so drag repaints only the canvas (no
//     full widget rebuild).
//   • The animation controller and rotation notifier are merged into one
//     Listenable so a single RepaintBoundary CustomPaint is the only thing
//     that ever repaints.
//   • Phase bar and labels sit outside the painter and use a separate
//     AnimatedBuilder so they don't interfere with the 3-D canvas.
// ============================================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:quantum_forge/core/utils/xyz_parser.dart';

// ---------------------------------------------------------------------------
// Public widget
// ---------------------------------------------------------------------------
class ReactionAnimationWidget extends StatefulWidget {
  final List<String> trajectoryFrames;
  final List<double>? energyProfile;

  const ReactionAnimationWidget({
    super.key,
    required this.trajectoryFrames,
    this.energyProfile,
  });

  @override
  State<ReactionAnimationWidget> createState() =>
      _ReactionAnimationWidgetState();
}

class _ReactionAnimationWidgetState extends State<ReactionAnimationWidget>
    with SingleTickerProviderStateMixin {
  // ── Animation ──────────────────────────────────────────────────────────────
  late AnimationController _ctrl;

  // ── Rotation notifier (avoids setState on drag) ────────────────────────────
  final _rotNotifier = ValueNotifier<Offset>(const Offset(0.4, 0.5));

  // ── Merged listenable for the painter ─────────────────────────────────────
  late Listenable _repaint;

  // ── Key frames ────────────────────────────────────────────────────────────
  List<Atom> _rAtoms = [];
  List<Atom> _tsAtoms = [];
  List<Atom> _pAtoms = [];
  Set<String> _rBonds = {};
  Set<String> _pBonds = {};
  bool _loaded = false;
  bool _playing = true;

  static const _phaseLabels = [
    'Reactants',
    'Transition State',
    'Products',
    'Transition State',
  ];
  static const _phaseColors = [
    Color(0xFF4FC3F7),
    Color(0xFFFFAB40),
    Color(0xFF66BB6A),
    Color(0xFFFFAB40),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8), // slower = smoother appearance
    )..repeat();
    _repaint = Listenable.merge([_ctrl, _rotNotifier]);
    _load();
  }

  @override
  void didUpdateWidget(covariant ReactionAnimationWidget old) {
    super.didUpdateWidget(old);
    if (old.trajectoryFrames != widget.trajectoryFrames) _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _rotNotifier.dispose();
    super.dispose();
  }

  // ── Parse three key frames asynchronously ─────────────────────────────────
  Future<void> _load() async {
    final frames = widget.trajectoryFrames;
    if (frames.length < 3) return;

    int tsIdx = frames.length ~/ 2;
    final ep = widget.energyProfile;
    if (ep != null && ep.length == frames.length) {
      double maxE = double.negativeInfinity;
      for (int i = 0; i < ep.length; i++) {
        if (ep[i] > maxE) { maxE = ep[i]; tsIdx = i; }
      }
    }

    final rA  = await XyzParser.parseAsync(frames.first);
    final tsA = await XyzParser.parseAsync(frames[tsIdx]);
    final pA  = await XyzParser.parseAsync(frames.last);
    final rB  = _bonds(rA);
    final pB  = _bonds(pA);

    if (mounted) {
      setState(() {
        _rAtoms = rA; _tsAtoms = tsA; _pAtoms = pA;
        _rBonds = rB; _pBonds = pB;
        _loaded = true;
      });
    }
  }

  Set<String> _bonds(List<Atom> atoms, {double factor = 1.18}) {
    final s = <String>{};
    for (int i = 0; i < atoms.length; i++) {
      for (int j = i + 1; j < atoms.length; j++) {
        final a = atoms[i], b = atoms[j];
        final dx = a.x - b.x, dy = a.y - b.y, dz = a.z - b.z;
        final d = math.sqrt(dx * dx + dy * dy + dz * dz);
        if (d < (a.covalentRadius + b.covalentRadius) * factor) s.add('$i:$j');
      }
    }
    return s;
  }




  int get _phase => (_ctrl.value * 4).floor() % 4;
  double get _localT => (_ctrl.value * 4) - _phase.toDouble();

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF4FC3F7), strokeWidth: 2),
            SizedBox(height: 12),
            Text('Parsing trajectory frames…',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // ── Phase label row ────────────────────────────────────────────────
        AnimatedBuilder(
          animation: _ctrl,
          builder: (ctx, _) {
            final p = _phase;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _phaseColors[p].withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _phaseColors[p].withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_phaseIcon(p), color: _phaseColors[p], size: 14),
                        const SizedBox(width: 6),
                        Text(_phaseLabels[p],
                            style: TextStyle(
                                color: _phaseColors[p],
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _localT,
                        minHeight: 4,
                        backgroundColor: Colors.white.withValues(alpha: 0.07),
                        valueColor: AlwaysStoppedAnimation(_phaseColors[p]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Legend
                  _chip(Colors.grey.shade500, 'Stable'),
                  const SizedBox(width: 6),
                  _chip(Colors.deepOrangeAccent, 'Breaking'),
                  const SizedBox(width: 6),
                  _chip(const Color(0xFF66BB6A), 'Forming'),
                  const SizedBox(width: 8),
                  // Play/Pause
                  _btn(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded, () {
                    setState(() {
                      _playing = !_playing;
                      _playing ? _ctrl.repeat() : _ctrl.stop();
                    });
                  }),
                  const SizedBox(width: 4),
                  _btn(Icons.replay_rounded, () {
                    _ctrl.reset(); _ctrl.repeat();
                    setState(() => _playing = true);
                  }),
                ],
              ),
            );
          },
        ),

        // ── 3-D canvas (no setState on drag → no flicker) ─────────────────
        Expanded(
          child: GestureDetector(
            onPanUpdate: (d) {
              // Update ValueNotifier — does NOT call setState — only triggers
              // the CustomPainter via the merged Listenable.
              _rotNotifier.value = Offset(
                _rotNotifier.value.dx + d.delta.dy * 0.01,
                _rotNotifier.value.dy + d.delta.dx * 0.01,
              );
            },
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _RxnPainter(
                  repaint: _repaint,
                  rAtoms: _rAtoms,
                  tsAtoms: _tsAtoms,
                  pAtoms: _pAtoms,
                  rBonds: _rBonds,
                  pBonds: _pBonds,
                  ctrl: _ctrl,
                  rotNotifier: _rotNotifier,
                ),
                size: Size.infinite,
              ),
            ),
          ),
        ),

        // ── Phase progress bar (4 segments) ───────────────────────────────
        AnimatedBuilder(
          animation: _ctrl,
          builder: (ctx2, _) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: List.generate(4, (i) {
                final active = i == _phase;
                final done = i < _phase;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      children: [
                        Text(
                          _phaseLabels[i],
                          style: TextStyle(
                            color: active
                                ? _phaseColors[i]
                                : Colors.white.withValues(alpha: 0.28),
                            fontSize: 9,
                            fontWeight: active ? FontWeight.bold : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 3),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: active ? _localT : (done ? 1.0 : 0.0),
                            minHeight: 3,
                            backgroundColor: Colors.white.withValues(alpha: 0.07),
                            valueColor: AlwaysStoppedAnimation(
                                _phaseColors[i].withValues(alpha: active ? 1.0 : 0.28)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  IconData _phaseIcon(int p) => switch (p) {
    0 => Icons.arrow_forward,
    1 => Icons.swap_horiz,
    2 => Icons.check_circle_outline,
    _ => Icons.swap_horiz,
  };

  Widget _chip(Color c, String l) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: c.withValues(alpha: 0.45)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 7, height: 7, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(l, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 9)),
    ]),
  );

  Widget _btn(IconData icon, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Icon(icon, color: Colors.white60, size: 16),
    ),
  );
}

// ---------------------------------------------------------------------------
// Painter — receives the merged Listenable and computes everything inside
// paint() so there are zero external setState calls during animation.
// ---------------------------------------------------------------------------
class _RxnPainter extends CustomPainter {
  final List<Atom> rAtoms, tsAtoms, pAtoms;
  final Set<String> rBonds, pBonds;
  final AnimationController ctrl;
  final ValueNotifier<Offset> rotNotifier;

  // Scale: bigger → longer bonds & bigger atoms
  static const double _scale = 55.0;

  _RxnPainter({
    required Listenable repaint,
    required this.rAtoms,
    required this.tsAtoms,
    required this.pAtoms,
    required this.rBonds,
    required this.pBonds,
    required this.ctrl,
    required this.rotNotifier,
  }) : super(repaint: repaint);

  // ── Interpolation (same logic as state, duplicated to avoid extra closure) ─
  double _smooth(double t) => t * t * (3 - 2 * t);
  double _lerp(double a, double b, double t) => a + (b - a) * t;

  List<Atom> _lerpAtoms(List<Atom> from, List<Atom> to, double t) {
    if (from.length != to.length) return from;
    return List.generate(from.length, (i) {
      final a = from[i], b = to[i];
      return Atom(a.symbol, _lerp(a.x, b.x, t), _lerp(a.y, b.y, t),
          _lerp(a.z, b.z, t), a.color, a.radius, a.covalentRadius);
    });
  }

  List<Atom> get _currentAtoms {
    final t = ctrl.value;
    final phase = (t * 4).floor() % 4;
    final localT = _smooth((t * 4) - phase.toDouble());
    return switch (phase) {
      0 => _lerpAtoms(rAtoms, tsAtoms, localT),
      1 => _lerpAtoms(tsAtoms, pAtoms, localT),
      2 => _lerpAtoms(pAtoms, tsAtoms, localT),
      _ => _lerpAtoms(tsAtoms, rAtoms, localT),
    };
  }



  @override
  void paint(Canvas canvas, Size size) {
    final atoms = _currentAtoms;
    if (atoms.isEmpty) return;

    final rot = rotNotifier.value;
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Centre of mass
    double ax = 0, ay = 0, az = 0;
    for (final a in atoms) { ax += a.x; ay += a.y; az += a.z; }
    ax /= atoms.length; ay /= atoms.length; az /= atoms.length;

    final cosX = math.cos(rot.dx), sinX = math.sin(rot.dx);
    final cosY = math.cos(rot.dy), sinY = math.sin(rot.dy);

    // Project atoms
    final proj = <_PA>[];
    for (final atom in atoms) {
      final dx = atom.x - ax, dy = atom.y - ay, dz = atom.z - az;
      final rx  = dx * cosY - dz * sinY;
      final rz1 = dx * sinY + dz * cosY;
      final ry  = dy * cosX - rz1 * sinX;
      final rz2 = dy * sinX + rz1 * cosX;
      proj.add(_PA(atom: atom,
          sx: cx + rx * _scale, sy: cy + ry * _scale, z: rz2));
    }

    // Build bond list
    final bonds = <_BD>[];
    for (int i = 0; i < atoms.length; i++) {
      for (int j = i + 1; j < atoms.length; j++) {
        final a1 = atoms[i], a2 = atoms[j];
        final dx = a1.x - a2.x, dy = a1.y - a2.y, dz = a1.z - a2.z;
        final dist = math.sqrt(dx * dx + dy * dy + dz * dz);
        final ideal = a1.covalentRadius + a2.covalentRadius;
        if (dist > ideal * 1.8) continue;

        final key = '$i:$j';
        final inR = rBonds.contains(key);
        final inP = pBonds.contains(key);
        final kind = inR && inP  ? _BK.stable
                   : inR        ? _BK.breaking
                   : inP        ? _BK.forming
                                : _BK.ts;

        bonds.add(_BD(
          p1: proj[i], p2: proj[j],
          z: (proj[i].z + proj[j].z) / 2,
          dist: dist, ideal: ideal, kind: kind,
        ));
      }
    }

    // Depth-sort everything together (painter's algorithm)
    final items = <_Item>[...proj, ...bonds];
    items.sort((a, b) => a.z.compareTo(b.z));

    // Draw
    for (final item in items) {
      if (item is _BD) {
        _drawBond(canvas, item);
      } else if (item is _PA) {
        _drawAtom(canvas, item);
      }
    }

    // Draw a subtle axis cross for orientation
    _drawAxes(canvas, cx, cy, cosX, sinX, cosY, sinY);
  }

  // ── Bond ──────────────────────────────────────────────────────────────────
  void _drawBond(Canvas canvas, _BD b) {
    final p1 = Offset(b.p1.sx, b.p1.sy);
    final p2 = Offset(b.p2.sx, b.p2.sy);
    final stretch = (b.dist / b.ideal).clamp(0.8, 2.0);

    switch (b.kind) {
      case _BK.stable:
        // Thick grey cylinder-look bond
        _solidBond(canvas, p1, p2, Colors.blueGrey.shade400, 7.0);

      case _BK.breaking:
        final t = ((stretch - 1.0) / 0.65).clamp(0.0, 1.0);
        final color = Color.lerp(Colors.blueGrey.shade400, Colors.deepOrange, t)!;
        if (stretch > 1.15) {
          _dashedBond(canvas, p1, p2, color, 5.0);
          _bondEnergyLabel(canvas, p1, p2, b.dist, b.ideal, color);
        } else {
          _solidBond(canvas, p1, p2, color, 7.0);
        }

      case _BK.forming:
        final t = (1.0 - ((stretch - 1.0) / 0.65).clamp(0.0, 1.0));
        final color = Color(0xFF66BB6A).withValues(alpha: t.clamp(0.2, 1.0));
        if (stretch > 1.12) {
          _dashedBond(canvas, p1, p2, color, 4.5);
        } else {
          _solidBond(canvas, p1, p2, color, 7.0);
        }
        if (t > 0.25) _bondEnergyLabel(canvas, p1, p2, b.dist, b.ideal, const Color(0xFF66BB6A));

      case _BK.ts:
        _dashedBond(canvas, p1, p2, Colors.amber.withValues(alpha: 0.6), 3.5);
    }
  }

  void _solidBond(Canvas canvas, Offset p1, Offset p2, Color color, double w) {
    // Shadow
    canvas.drawLine(p1, p2, Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..strokeWidth = w + 2
      ..strokeCap = StrokeCap.round);
    // Main
    canvas.drawLine(p1, p2, Paint()
      ..color = color
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round);
    // Highlight stripe
    final mid = (p1 + p2) / 2;
    final dir = (p2 - p1);
    final len = dir.distance;
    if (len > 0) {
      final perp = Offset(-dir.dy, dir.dx) / len * 1.5;
      canvas.drawLine(p1 + perp, mid + perp, Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round);
    }
  }

  void _dashedBond(Canvas canvas, Offset p1, Offset p2, Color color, double w) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;
    const dash = 6.0, gap = 5.0;
    final dir = p2 - p1;
    double rem = dir.distance;
    final norm = rem > 0 ? dir / rem : Offset.zero;
    double cur = 0;
    while (cur < rem) {
      final end = math.min(cur + dash, rem);
      canvas.drawLine(
        p1 + norm * cur,
        p1 + norm * end,
        paint,
      );
      cur += dash + gap;
    }
  }

  void _bondEnergyLabel(
      Canvas canvas, Offset p1, Offset p2, double dist, double ideal, Color color) {
    final energy = 120.0 * math.exp(-2.0 * (dist - ideal));
    if (energy < 1) return;
    final mid = (p1 + p2) / 2;

    final tp = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: '${energy.toStringAsFixed(0)} ',
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          TextSpan(
            text: 'kcal/mol',
            style: TextStyle(
                color: color.withValues(alpha: 0.75), fontSize: 8),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final bg = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: mid - const Offset(0, 14),
          width: tp.width + 10,
          height: tp.height + 6),
      const Radius.circular(5),
    );
    canvas.drawRRect(bg, Paint()..color = Colors.black.withValues(alpha: 0.7));
    tp.paint(canvas,
        Offset(mid.dx - tp.width / 2, mid.dy - 14 - tp.height / 2));
  }

  // ── Atom ──────────────────────────────────────────────────────────────────
  void _drawAtom(Canvas canvas, _PA p) {
    final r = p.atom.radius * _scale * 0.43;
    final c = Offset(p.sx, p.sy);

    // Outer glow for non-hydrogen
    if (p.atom.symbol != 'H') {
      canvas.drawCircle(c, r * 1.4, Paint()
        ..color = p.atom.color.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    }

    // Shadow
    canvas.drawCircle(c + const Offset(2, 2), r, Paint()
      ..color = Colors.black.withValues(alpha: 0.35));

    // Sphere with radial gradient
    final rect = Rect.fromCircle(center: c, radius: r);
    final grad = RadialGradient(
      colors: [
        Colors.white.withValues(alpha: 0.82),
        p.atom.color,
        p.atom.color.withValues(alpha: 0.65),
      ],
      stops: const [0.0, 0.42, 1.0],
      center: const Alignment(-0.3, -0.35),
    );
    canvas.drawCircle(c, r, Paint()..shader = grad.createShader(rect));

    // Depth darkening
    final dark = (1.0 - ((p.z + 12) / 22.0).clamp(0.1, 1.0)) * 0.45;
    if (dark > 0) {
      canvas.drawCircle(c, r,
          Paint()..color = Colors.black.withValues(alpha: dark));
    }

    // Outline
    canvas.drawCircle(c, r, Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9);

    // Atom symbol (skip H for clarity unless large)
    if (p.atom.symbol != 'H' || r > 9) {
      final label = p.atom.symbol;
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.92),
            fontSize: (r * 0.72).clamp(8.0, 18.0),
            fontWeight: FontWeight.bold,
            shadows: const [Shadow(color: Colors.black87, blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));
    }
  }

  // ── Orientation axes (small, bottom-right corner) ─────────────────────────
  void _drawAxes(Canvas canvas, double cx, double cy,
      double cosX, double sinX, double cosY, double sinY) {
    const o = 28.0; // axis length
    final ox = cx - 45.0, oy = cy - 45.0; // origin, will be bottom-left

    void axis(double dx, double dy, double dz, Color color, String label) {
      final rx  = dx * cosY - dz * sinY;
      final rz1 = dx * sinY + dz * cosY;
      final ry  = dy * cosX - rz1 * sinX;
      final ex = ox + rx * o, ey = oy + ry * o;
      canvas.drawLine(
        Offset(ox, oy), Offset(ex, ey),
        Paint()..color = color.withValues(alpha: 0.55)..strokeWidth = 1.5..strokeCap = StrokeCap.round,
      );
      final tp = TextPainter(
        text: TextSpan(text: label,
            style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 9)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(ex - tp.width / 2, ey - tp.height / 2));
    }

    axis(1, 0, 0, Colors.red, 'x');
    axis(0, 1, 0, Colors.green, 'y');
    axis(0, 0, 1, Colors.blue, 'z');
  }

  @override
  bool shouldRepaint(covariant _RxnPainter old) =>
      rAtoms != old.rAtoms || pAtoms != old.pAtoms;
}

// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------
enum _BK { stable, breaking, forming, ts }

abstract class _Item { double get z; }

class _PA implements _Item {
  final Atom atom;
  final double sx, sy;
  @override final double z;
  _PA({required this.atom, required this.sx, required this.sy, required this.z});
}

class _BD implements _Item {
  final _PA p1, p2;
  @override final double z;
  final double dist, ideal;
  final _BK kind;
  _BD({required this.p1, required this.p2, required this.z,
       required this.dist, required this.ideal, required this.kind});
}
