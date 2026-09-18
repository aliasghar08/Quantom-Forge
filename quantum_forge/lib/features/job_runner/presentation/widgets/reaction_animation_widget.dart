// ============================================================================
// ReactionAnimationWidget — v3 "Research Level"
//
// 4-phase narrative animation (16 second loop):
//   Phase 0  [0.00–0.22]  Approach    — distinct reactant molecules drift toward
//                                        each other; VdW clouds glow as they close.
//   Phase 1  [0.22–0.48]  TS/Reaction — shockwave rings, atomic jitter, bond
//                                        breaking (dashed orange) / forming (green).
//   Phase 2  [0.48–0.70]  Separation  — product molecules drift apart.
//   Phase 3  [0.70–1.00]  Products    — stable products shown clearly.
//
// Live mini-IRC energy plot races along the reaction coordinate (bottom-right).
// Orientation axes drawn in the bottom-left corner.
// Single RepaintBoundary CustomPainter — zero setState during animation.
//
// Layout contract (adaptive):
//   * Parent generous → 3D canvas fills leftover height via Expanded.
//   * Parent unbounded (bare SingleChildScrollView) → intrinsic height.
//   * Parent bounded but too tight → internal scroll, never overflows.
// ============================================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:quantum_forge/core/utils/xyz_parser.dart';

// Fixed chrome heights
const double _kHeaderH    = 48;
const double _kTimelineH  = 52;
const double _kSliderH    = 40;
const double _kBondPanelH = 280;
const double _kCanvasPreferredH = 720;
const double _kChromeTotal  = _kHeaderH + _kTimelineH + _kSliderH + _kBondPanelH; // 420
const double _kPreferredTotal = _kChromeTotal + _kCanvasPreferredH;              // 1140

// ─────────────────────────────────────────────────────────────────────────────
// Public widget
// ─────────────────────────────────────────────────────────────────────────────
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
  late AnimationController _ctrl;
  final _rotNotifier = ValueNotifier<Offset>(const Offset(0.35, 0.45));
  late Listenable _repaint;

  List<Atom> _rAtoms = [];
  List<Atom> _tsAtoms = [];
  List<Atom> _pAtoms = [];
  List<List<Atom>> _rMolecules = [];
  List<List<Atom>> _pMolecules = [];
  Set<String> _rBonds = {};
  Set<String> _pBonds = {};
  bool _loaded = false;
  bool _playing = true;
  bool _isRendering = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 16))
      ..repeat();
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

    if (mounted) {
      setState(() {
        _rAtoms = rA; _tsAtoms = tsA; _pAtoms = pA;
        _rMolecules = XyzParser.getDistinctMolecules(rA);
        _pMolecules = XyzParser.getDistinctMolecules(pA);
        _rBonds = _buildBonds(rA);
        _pBonds = _buildBonds(pA);
        _loaded = true;
      });
    }
  }

  Set<String> _buildBonds(List<Atom> atoms) {
    final s = <String>{};
    for (int i = 0; i < atoms.length; i++) {
      for (int j = i + 1; j < atoms.length; j++) {
        final a = atoms[i], b = atoms[j];
        final dx = a.x - b.x, dy = a.y - b.y, dz = a.z - b.z;
        final d = math.sqrt(dx * dx + dy * dy + dz * dz);
        if (d < (a.covalentRadius + b.covalentRadius) * 1.18) s.add('$i:$j');
      }
    }
    return s;
  }

  // Phase helpers
  static const double _t1 = 0.22;
  static const double _t2 = 0.48;
  static const double _t3 = 0.70;

  double get _t => _ctrl.value;

  String get _phaseName {
    final t = _t;
    if (t < _t1) return 'Approach';
    if (t < _t2) return 'Transition State';
    if (t < _t3) return 'Separation';
    return 'Products';
  }

  Color get _phaseColor {
    final t = _t;
    if (t < _t1) return const Color(0xFF4FC3F7);
    if (t < _t2) return const Color(0xFFFFAB40);
    if (t < _t3) return const Color(0xFF80DEEA);
    return const Color(0xFF66BB6A);
  }

  double get _phaseProgress {
    final t = _t;
    if (t < _t1) return t / _t1;
    if (t < _t2) return (t - _t1) / (_t2 - _t1);
    if (t < _t3) return (t - _t2) / (_t3 - _t2);
    return (t - _t3) / (1.0 - _t3);
  }

  IconData get _phaseIcon {
    final t = _t;
    if (t < _t1) return Icons.arrow_right_alt;
    if (t < _t2) return Icons.bolt;
    if (t < _t3) return Icons.call_split;
    return Icons.check_circle_outline;
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 150,
              child: LinearProgressIndicator(
                color: Color(0xFF4FC3F7),
                backgroundColor: Colors.white10,
                minHeight: 2,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Parsing trajectory & detecting molecules...',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      final maxH = constraints.maxHeight;
      final bounded = maxH.isFinite;
      final tooTight = bounded && maxH < _kPreferredTotal;

      // Build the column once. Depending on the case, the canvas section
      // uses Expanded (generous) or a fixed height (tight / unbounded).
      final children = <Widget>[
        SizedBox(height: _kHeaderH, child: _buildHeader()),
        if (!tooTight && bounded)
          Expanded(child: _buildCanvas())
        else
          SizedBox(height: _kCanvasPreferredH, child: _buildCanvas()),
        SizedBox(height: _kTimelineH, child: _buildTimeline()),
        SizedBox(height: _kSliderH, child: _buildSlider()),
        SizedBox(height: _kBondPanelH, child: _buildBondPanel()),
      ];

      // Case 1 — parent is unbounded (bare SingleChildScrollView, for example).
      // Use intrinsic height so the parent scrolls naturally.
      if (!bounded) {
        return Column(mainAxisSize: MainAxisSize.min, children: children);
      }

      // Case 2 — parent gave us enough room. Expanded absorbs the slack.
      if (!tooTight) {
        return Column(children: children);
      }

      // Case 3 — parent bounded but too tight (like the 346 px we just saw).
      // Give the inner column its preferred height and let it scroll.
      return SingleChildScrollView(
        child: SizedBox(
          height: _kPreferredTotal,
          child: Column(children: [
            SizedBox(height: _kHeaderH, child: _buildHeader()),
            SizedBox(height: _kCanvasPreferredH, child: _buildCanvas()),
            SizedBox(height: _kTimelineH, child: _buildTimeline()),
            SizedBox(height: _kSliderH, child: _buildSlider()),
            SizedBox(height: _kBondPanelH, child: _buildBondPanel()),
          ]),
        ),
      );
    });
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _phaseColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _phaseColor.withValues(alpha: 0.45)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_phaseIcon, color: _phaseColor, size: 14),
                const SizedBox(width: 6),
                Text(_phaseName,
                    style: TextStyle(
                        color: _phaseColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _phaseProgress,
                  minHeight: 4,
                  backgroundColor: Colors.white.withValues(alpha: 0.07),
                  valueColor: AlwaysStoppedAnimation(_phaseColor),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _chip(Colors.blueGrey.shade400, 'Stable'),
            const SizedBox(width: 5),
            _chip(Colors.deepOrangeAccent, 'Breaking'),
            const SizedBox(width: 5),
            _chip(const Color(0xFF66BB6A), 'Forming'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Text('${_rMolecules.length}R → ${_pMolecules.length}P',
                  style: const TextStyle(color: Colors.white54, fontSize: 10)),
            ),
            const SizedBox(width: 6),
            _btn(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded, () {
              setState(() {
                _playing = !_playing;
                _playing ? _ctrl.repeat() : _ctrl.stop();
              });
            }),
            const SizedBox(width: 4),
            _btn(Icons.replay_rounded, () {
              _ctrl.reset();
              _ctrl.repeat();
              setState(() => _playing = true);
            }),
          ],
        ),
      ),
    );
  }

  // ── 3D canvas ─────────────────────────────────────────────────────────────
  Widget _buildCanvas() {
    return GestureDetector(
      onPanUpdate: (d) {
        _rotNotifier.value = Offset(
          _rotNotifier.value.dx + d.delta.dy * 0.009,
          _rotNotifier.value.dy + d.delta.dx * 0.009,
        );
      },
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _RxnPainterV3(
            repaint: _repaint,
            rAtoms: _rAtoms,
            tsAtoms: _tsAtoms,
            pAtoms: _pAtoms,
            rMolecules: _rMolecules,
            pMolecules: _pMolecules,
            rBonds: _rBonds,
            pBonds: _pBonds,
            ctrl: _ctrl,
            rotNotifier: _rotNotifier,
            energyProfile: widget.energyProfile ?? [],
          ),
          size: Size.infinite,
        ),
      ),
    );
  }

  // ── Phase timeline strip ──────────────────────────────────────────────────
  Widget _buildTimeline() {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, _) {
        final segments = [
          ('Approach', 0.0, _t1, const Color(0xFF4FC3F7)),
          ('Transition State', _t1, _t2, const Color(0xFFFFAB40)),
          ('Separation', _t2, _t3, const Color(0xFF80DEEA)),
          ('Products', _t3, 1.0, const Color(0xFF66BB6A)),
        ];
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Row(
            children: segments.map((seg) {
              final (label, start, end, color) = seg;
              final isActive = _t >= start && _t < end;
              final isDone = _t >= end;
              final segT = isActive
                  ? (_t - start) / (end - start)
                  : (isDone ? 1.0 : 0.0);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(label,
                          style: TextStyle(
                              color: isActive
                                  ? color
                                  : Colors.white.withValues(alpha: 0.25),
                              fontSize: 9,
                              fontWeight: isActive
                                  ? FontWeight.bold
                                  : FontWeight.normal),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: segT,
                          minHeight: 4,
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.06),
                          valueColor: AlwaysStoppedAnimation(
                              color.withValues(alpha: isActive ? 1.0 : 0.25)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // ── Timeline slider ───────────────────────────────────────────────────────
  Widget _buildSlider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          return SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF4FC3F7),
              inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
              thumbColor: Colors.white,
              trackHeight: 2,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: _ctrl.value,
              onChanged: (val) {
                if (_playing) {
                  setState(() {
                    _playing = false;
                    _ctrl.stop();
                  });
                }
                if (_isRendering) return;
                _isRendering = true;

                _ctrl.value = val;

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _isRendering = false;
                });
              },
            ),
          );
        },
      ),
    );
  }

  // ── Bond energies panel ───────────────────────────────────────────────────
  Widget _buildBondPanel() {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, _) => _buildLiveEnergiesPanel(),
    );
  }

  Widget _buildLiveEnergiesPanel() {
    final t = _ctrl.value;
    final atoms = _buildAtoms(t);
    final bonds = <_CalculatedBond>[];
    int idx = 1;
    for (int i = 0; i < atoms.length; i++) {
      for (int j = i + 1; j < atoms.length; j++) {
        final a1 = atoms[i], a2 = atoms[j];
        final dx = a1.x - a2.x, dy = a1.y - a2.y, dz = a1.z - a2.z;
        final dist = math.sqrt(dx * dx + dy * dy + dz * dz);
        final idealDist = a1.covalentRadius + a2.covalentRadius;
        if (dist > idealDist * 2.1) continue;
        bonds.add(_CalculatedBond(a1, a2, dist, idealDist, idx++));
      }
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4FC3F7),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Live Bond Energies',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${bonds.length} bonds',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: bonds.isEmpty
                ? Center(
                    child: Text(
                      'No bonds in current frame',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.25),
                        fontSize: 12,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: bonds.map(_bondChip).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _bondChip(_CalculatedBond b) {
    final energy = 110.0 * math.exp(-2.2 * (b.dist - b.idealDist));
    final valStr = energy < 0.1 ? '~0.0' : energy.toStringAsFixed(1);
    final stretch = (b.dist / b.idealDist).clamp(0.75, 2.5);
    final chipColor = stretch > 1.15
        ? Color.lerp(
            Colors.orangeAccent,
            Colors.redAccent,
            ((stretch - 1.15) / 0.5).clamp(0.0, 1.0),
          )!
        : Colors.blueGrey.shade400;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: chipColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(
              color: Colors.orangeAccent,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${b.index}',
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${b.a1.symbol}–${b.a2.symbol}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '$valStr kcal/mol',
                style: TextStyle(color: chipColor, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(Color c, String l) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.withValues(alpha: 0.45)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(l,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8), fontSize: 9)),
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

  double _s(double t) => t * t * (3 - 2 * t);
  double _l(double a, double b, double t) => a + (b - a) * t;

  List<Atom> _lerpAtoms(List<Atom> from, List<Atom> to, double t) {
    if (from.length != to.length) return from;
    return List.generate(from.length, (i) {
      final a = from[i], b = to[i];
      return Atom(a.symbol, _l(a.x, b.x, t), _l(a.y, b.y, t),
          _l(a.z, b.z, t), a.color, a.radius, a.covalentRadius);
    });
  }

  List<Atom> _buildAtoms(double t) {
    if (t < _t1) {
      final progress = _s(t / _t1);
      if (_rMolecules.length >= 2) {
        final combined = <Atom>[];
        for (int m = 0; m < _rMolecules.length; m++) {
          final side = m == 0 ? -1.0 : 1.0;
          final offset = side * 3.5 * (1.0 - progress);
          for (final a in _rMolecules[m]) {
            combined.add(Atom(a.symbol, a.x + offset, a.y, a.z,
                a.color, a.radius, a.covalentRadius));
          }
        }
        final blended = _lerpAtoms(_rAtoms, _tsAtoms, progress * 0.4);
        return List.generate(combined.length, (i) {
          if (i >= blended.length) return combined[i];
          final a = combined[i], b = blended[i];
          return Atom(a.symbol, _l(a.x, b.x, progress * 0.5),
              _l(a.y, b.y, progress * 0.5), _l(a.z, b.z, progress * 0.5),
              a.color, a.radius, a.covalentRadius);
        });
      }
      return _lerpAtoms(_rAtoms, _tsAtoms, _s(t / _t1));
    } else if (t < _t2) {
      return _lerpAtoms(_tsAtoms, _pAtoms, _s((t - _t1) / (_t2 - _t1)));
    } else if (t < _t3) {
      final progress = _s((t - _t2) / (_t3 - _t2));
      if (_pMolecules.length >= 2) {
        final combined = <Atom>[];
        for (int m = 0; m < _pMolecules.length; m++) {
          final side = m == 0 ? -1.0 : 1.0;
          final offset = side * 3.5 * progress;
          for (final a in _pMolecules[m]) {
            combined.add(Atom(a.symbol, a.x + offset, a.y, a.z,
                a.color, a.radius, a.covalentRadius));
          }
        }
        return combined;
      }
      return _lerpAtoms(_pAtoms, _pAtoms, progress);
    } else {
      return _pAtoms;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Painter v3 — unchanged
// ─────────────────────────────────────────────────────────────────────────────
class _RxnPainterV3 extends CustomPainter {
  final List<Atom> rAtoms, tsAtoms, pAtoms;
  final List<List<Atom>> rMolecules, pMolecules;
  final Set<String> rBonds, pBonds;
  final AnimationController ctrl;
  final ValueNotifier<Offset> rotNotifier;
  final List<double> energyProfile;

  static const double _scale = 120.0;
  static const double _t1 = 0.22;
  static const double _t2 = 0.48;
  static const double _t3 = 0.70;

  _RxnPainterV3({
    required Listenable repaint,
    required this.rAtoms,
    required this.tsAtoms,
    required this.pAtoms,
    required this.rMolecules,
    required this.pMolecules,
    required this.rBonds,
    required this.pBonds,
    required this.ctrl,
    required this.rotNotifier,
    required this.energyProfile,
  }) : super(repaint: repaint);

  double _s(double t) => t * t * (3 - 2 * t);
  double _l(double a, double b, double t) => a + (b - a) * t;

  List<Atom> _lerpAtoms(List<Atom> from, List<Atom> to, double t) {
    if (from.length != to.length) return from;
    return List.generate(from.length, (i) {
      final a = from[i], b = to[i];
      return Atom(a.symbol, _l(a.x, b.x, t), _l(a.y, b.y, t),
          _l(a.z, b.z, t), a.color, a.radius, a.covalentRadius);
    });
  }

  List<Atom> _buildAtoms(double t) {
    if (t < _t1) {
      final progress = _s(t / _t1);
      if (rMolecules.length >= 2) {
        final combined = <Atom>[];
        for (int m = 0; m < rMolecules.length; m++) {
          final side = m == 0 ? -1.0 : 1.0;
          final offset = side * 10.0 * (1.0 - progress);
          for (final a in rMolecules[m]) {
            combined.add(Atom(a.symbol, a.x + offset, a.y, a.z,
                a.color, a.radius, a.covalentRadius));
          }
        }
        final blended = _lerpAtoms(rAtoms, tsAtoms, progress * 0.4);
        return List.generate(combined.length, (i) {
          if (i >= blended.length) return combined[i];
          final a = combined[i], b = blended[i];
          return Atom(a.symbol, _l(a.x, b.x, progress * 0.5),
              _l(a.y, b.y, progress * 0.5), _l(a.z, b.z, progress * 0.5),
              a.color, a.radius, a.covalentRadius);
        });
      }
      return _lerpAtoms(rAtoms, tsAtoms, _s(t / _t1));
    } else if (t < _t2) {
      return _lerpAtoms(tsAtoms, pAtoms, _s((t - _t1) / (_t2 - _t1)));
    } else if (t < _t3) {
      final progress = _s((t - _t2) / (_t3 - _t2));
      if (pMolecules.length >= 2) {
        final combined = <Atom>[];
        for (int m = 0; m < pMolecules.length; m++) {
          final side = m == 0 ? -1.0 : 1.0;
          final offset = side * 5.5 * progress;
          for (final a in pMolecules[m]) {
            combined.add(Atom(a.symbol, a.x + offset, a.y, a.z,
                a.color, a.radius, a.covalentRadius));
          }
        }
        return combined;
      }
      return pAtoms;
    } else {
      return pAtoms;
    }
  }

  double _jitter(double t, int seed) {
    if (t < _t1 * 0.85 || t > _t2) return 0.0;
    final inTS = (t - _t1 * 0.85) / (_t2 - _t1 * 0.85);
    final env = inTS < 0.5 ? inTS * 2 : (1.0 - inTS) * 2;
    return math.sin((t * (14.0 + seed % 5) + seed) * math.pi * 2) * env * 0.28;
  }

  ({double sx, double sy, double z}) _proj(
    double x, double y, double z,
    double ax, double ay, double az,
    double cx, double cy,
    double cosX, double sinX, double cosY, double sinY,
    double currentScale,
  ) {
    final dx = x - ax, dy = y - ay, dz = z - az;
    final rx  = dx * cosY - dz * sinY;
    final rz1 = dx * sinY + dz * cosY;
    final ry  = dy * cosX - rz1 * sinX;
    final rz2 = dy * sinX + rz1 * cosX;
    return (sx: cx + rx * currentScale, sy: cy + ry * currentScale, z: rz2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = ctrl.value;
    final atoms = _buildAtoms(t);
    if (atoms.isEmpty) return;

    final rot = rotNotifier.value;
    final cx = size.width / 2, cy = size.height / 2;

    double ax = 0, ay = 0, az = 0;
    for (final a in atoms) { ax += a.x; ay += a.y; az += a.z; }
    ax /= atoms.length; ay /= atoms.length; az /= atoms.length;

    double tsAx = 0, tsAy = 0, tsAz = 0;
    for (final a in tsAtoms) { tsAx += a.x; tsAy += a.y; tsAz += a.z; }
    if (tsAtoms.isNotEmpty) {
      tsAx /= tsAtoms.length; tsAy /= tsAtoms.length; tsAz /= tsAtoms.length;
    }

    double maxDistSq = 0.0;
    for (final a in tsAtoms) {
      final dx = a.x - tsAx;
      final dy = a.y - tsAy;
      final dz = a.z - tsAz;
      final distSq = dx*dx + dy*dy + dz*dz;
      if (distSq > maxDistSq) maxDistSq = distSq;
    }
    double dynamicScale = _scale;
    if (maxDistSq > 0.01) {
      final maxDist = math.sqrt(maxDistSq) + 6.0;
      final targetSize = math.min(size.width, size.height) * 0.92;
      dynamicScale = targetSize / (2 * maxDist);
      dynamicScale = dynamicScale.clamp(40.0, 240.0);
    }

    final cosX = math.cos(rot.dx), sinX = math.sin(rot.dx);
    final cosY = math.cos(rot.dy), sinY = math.sin(rot.dy);

    if (t < _t1 && rMolecules.length >= 2) {
      final progress = t / _t1;
      final alpha = (progress * progress * 0.35).clamp(0.0, 0.35);
      canvas.drawCircle(Offset(cx, cy), 55 * progress,
          Paint()
            ..color = const Color(0xFF4FC3F7).withValues(alpha: alpha)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28));
    }

    if (t >= _t1 * 0.82 && t < _t2) {
      final tsp = (t - _t1 * 0.82) / (_t2 - _t1 * 0.82);
      for (int ring = 0; ring < 4; ring++) {
        final ringT = (tsp * 3.0 + ring * 0.28) % 1.0;
        final r2 = ringT * 95;
        final a2 = (1.0 - ringT) * 0.55;
        canvas.drawCircle(Offset(cx, cy), r2, Paint()
          ..color = const Color(0xFFFFAB40).withValues(alpha: a2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      }
    }

    final proj = <_PA>[];
    for (int i = 0; i < atoms.length; i++) {
      final a = atoms[i];
      final jx = _jitter(t, i);
      final jy = _jitter(t, i + 11);
      final p = _proj(a.x + jx, a.y + jy, a.z, ax, ay, az,
          cx, cy, cosX, sinX, cosY, sinY, dynamicScale);
      proj.add(_PA(atom: a, sx: p.sx, sy: p.sy, z: p.z));
    }

    final bonds = <_BD>[];
    int bondIndexCounter = 1;
    for (int i = 0; i < atoms.length; i++) {
      for (int j = i + 1; j < atoms.length; j++) {
        final a1 = atoms[i], a2 = atoms[j];
        final dx = a1.x - a2.x, dy = a1.y - a2.y, dz = a1.z - a2.z;
        final dist = math.sqrt(dx * dx + dy * dy + dz * dz);
        final ideal = a1.covalentRadius + a2.covalentRadius;
        if (dist > ideal * 2.1) continue;

        final key = '$i:$j';
        final inR = rBonds.contains(key);
        final inP = pBonds.contains(key);
        final kind = inR && inP  ? _BK.stable
                   : inR        ? _BK.breaking
                   : inP        ? _BK.forming
                                : _BK.ts;

        bonds.add(_BD(p1: proj[i], p2: proj[j],
            z: (proj[i].z + proj[j].z) / 2,
            dist: dist, ideal: ideal, kind: kind, animT: t,
            index: bondIndexCounter++));
      }
    }

    final items = <_Item>[...proj, ...bonds];
    items.sort((a, b) => a.z.compareTo(b.z));
    for (final item in items) {
      if (item is _BD) {
        _drawBond(canvas, item, t);
      } else if (item is _PA) {
        _drawAtom(canvas, item, t, dynamicScale);
      }
    }

    _drawAxes(canvas, size, cosX, sinX, cosY, sinY);
    _drawEnergyPlot(canvas, size, t);
    _drawPhaseCaption(canvas, size, t);
  }

  void _drawBond(Canvas canvas, _BD b, double t) {
    final p1 = Offset(b.p1.sx, b.p1.sy);
    final p2 = Offset(b.p2.sx, b.p2.sy);
    final stretch = (b.dist / b.ideal).clamp(0.75, 2.5);

    switch (b.kind) {
      case _BK.stable:
        _cylBond(canvas, p1, p2, Colors.blueGrey.shade400, 6.5);
      case _BK.breaking:
        final p = ((stretch - 1.0) / 0.75).clamp(0.0, 1.0);
        final col =
            Color.lerp(Colors.blueGrey.shade400, Colors.deepOrangeAccent, p)!;
        if (stretch > 1.15) {
          _dashBond(canvas, p1, p2, col, 5.0);
          if (stretch > 1.25) {
            _energyBubble(canvas, p1, p2, b.dist, b.ideal, col, b.index);
          }
        } else {
          _cylBond(canvas, p1, p2, col, 6.5);
        }
      case _BK.forming:
        final p = (1.0 - ((stretch - 1.0) / 0.75).clamp(0.0, 1.0));
        final col =
            const Color(0xFF66BB6A).withValues(alpha: p.clamp(0.15, 1.0));
        if (stretch > 1.12) {
          _dashBond(canvas, p1, p2, col, 4.5);
          if (p > 0.3) {
            _energyBubble(canvas, p1, p2, b.dist, b.ideal,
                const Color(0xFF66BB6A), b.index);
          }
        } else {
          _cylBond(canvas, p1, p2, const Color(0xFF66BB6A), 6.5);
        }
      case _BK.ts:
        if (t >= _t1 * 0.7 && t < _t2 * 1.05) {
          _dashBond(canvas, p1, p2, Colors.amber.withValues(alpha: 0.5), 3.0);
        }
    }
  }

  void _cylBond(Canvas canvas, Offset p1, Offset p2, Color col, double w) {
    canvas.drawLine(p1, p2, Paint()
      ..color = Colors.black.withValues(alpha: 0.26)
      ..strokeWidth = w + 2.5
      ..strokeCap = StrokeCap.round);
    canvas.drawLine(p1, p2, Paint()
      ..color = col
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round);
    final dir = p2 - p1;
    final len = dir.distance;
    if (len > 4) {
      final perp = Offset(-dir.dy, dir.dx) / len * (w * 0.22);
      final q1 = p1 + perp + (p2 - p1) * 0.08;
      final q2 = (p1 + p2) / 2 + perp;
      canvas.drawLine(q1, q2, Paint()
        ..color = Colors.white.withValues(alpha: 0.22)
        ..strokeWidth = w * 0.35
        ..strokeCap = StrokeCap.round);
    }
  }

  void _dashBond(Canvas canvas, Offset p1, Offset p2, Color col, double w) {
    const dash = 7.0, gap = 5.0;
    final dir = p2 - p1;
    final rem = dir.distance;
    final norm = rem > 0 ? dir / rem : Offset.zero;
    double cur = 0;
    while (cur < rem) {
      final end = math.min(cur + dash, rem);
      canvas.drawLine(p1 + norm * cur, p1 + norm * end, Paint()
        ..color = col
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round);
      cur += dash + gap;
    }
  }

  void _energyBubble(Canvas canvas, Offset p1, Offset p2,
      double dist, double ideal, Color col, int index) {
    final energy = 110.0 * math.exp(-2.2 * (dist - ideal));
    if (energy < 2) return;

    final badgeRadius = 7.0;
    final midX = (p1.dx + p2.dx) / 2;
    final midY = (p1.dy + p2.dy) / 2;

    canvas.drawCircle(Offset(midX, midY), badgeRadius, Paint()..color = col);

    final textSpan = TextSpan(
      text: '$index',
      style: const TextStyle(
        color: Colors.black87,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    );
    final textPainter = TextPainter(
        text: textSpan, textDirection: TextDirection.ltr)
      ..layout();
    textPainter.paint(
        canvas,
        Offset(midX - textPainter.width / 2,
            midY - textPainter.height / 2));
  }

  void _drawAtom(Canvas canvas, _PA p, double t, double dynamicScale) {
    double glowExtra = 0;
    if (t < _t1) { glowExtra = 0.08 * (t / _t1); }
    if (t >= _t1 * 0.85 && t < _t2) {
      final tsT = (t - _t1 * 0.85) / (_t2 - _t1 * 0.85);
      glowExtra = 0.20 * math.sin(tsT * math.pi);
    }

    final r = p.atom.radius * dynamicScale * 0.25;
    final c = Offset(p.sx, p.sy);

    if (p.atom.symbol != 'H') {
      canvas.drawCircle(c, r * (1.5 + glowExtra), Paint()
        ..color = p.atom.color.withValues(alpha: 0.10 + glowExtra)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    }

    canvas.drawCircle(c + const Offset(2, 2.5), r,
        Paint()..color = Colors.black.withValues(alpha: 0.32));

    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(c, r, Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.85),
          p.atom.color,
          p.atom.color.withValues(alpha: 0.6),
        ],
        stops: const [0.0, 0.40, 1.0],
        center: const Alignment(-0.30, -0.38),
      ).createShader(rect));

    final dark = (1.0 - ((p.z + 12) / 22.0).clamp(0.1, 1.0)) * 0.40;
    if (dark > 0) {
      canvas.drawCircle(c, r,
          Paint()..color = Colors.black.withValues(alpha: dark));
    }

    canvas.drawCircle(c, r, Paint()
      ..color = Colors.black.withValues(alpha: 0.52)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8);

    if (p.atom.symbol != 'H' || r > 8) {
      final tp = TextPainter(
        text: TextSpan(
          text: p.atom.symbol,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.93),
            fontSize: (r * 0.70).clamp(7.5, 17.0),
            fontWeight: FontWeight.bold,
            shadows: const [
              Shadow(color: Colors.black87, blurRadius: 4)
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));
    }
  }

  void _drawAxes(Canvas canvas, Size size,
      double cosX, double sinX, double cosY, double sinY) {
    const len = 26.0;
    final ox = 44.0, oy = size.height - 50.0;

    void axis(double dx, double dy, double dz, Color color, String lbl) {
      final rx  = dx * cosY - dz * sinY;
      final rz1 = dx * sinY + dz * cosY;
      final ry  = dy * cosX - rz1 * sinX;
      final ex = ox + rx * len, ey = oy + ry * len;
      canvas.drawLine(Offset(ox, oy), Offset(ex, ey), Paint()
        ..color = color.withValues(alpha: 0.6)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round);
      final tp = TextPainter(
        text: TextSpan(
            text: lbl,
            style: TextStyle(
                color: color.withValues(alpha: 0.75), fontSize: 9)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(ex - tp.width / 2, ey - tp.height / 2));
    }

    axis(1, 0, 0, Colors.red, 'x');
    axis(0, 1, 0, Colors.greenAccent, 'y');
    axis(0, 0, 1, Colors.blueAccent, 'z');
  }

  void _drawEnergyPlot(Canvas canvas, Size size, double t) {
    final profile = energyProfile;
    if (profile.length < 4) return;

    const w = 160.0, h = 60.0, pad = 10.0;
    final left = size.width - w - 16;
    final top = size.height - h - 38;

    final bg = RRect.fromRectAndRadius(
        Rect.fromLTWH(left - pad, top - pad, w + pad * 2, h + pad * 2),
        const Radius.circular(10));
    canvas.drawRRect(bg, Paint()..color = Colors.black.withValues(alpha: 0.55));
    canvas.drawRRect(bg, Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8);

    final minE = profile.reduce((a, b) => a < b ? a : b);
    final maxE = profile.reduce((a, b) => a > b ? a : b);
    final rangeE = (maxE - minE).abs() < 0.001 ? 1.0 : maxE - minE;
    final n = profile.length;

    double px(int i) => left + w * i / (n - 1);
    double py(double v) => top + h - h * (v - minE) / rangeE;

    final fillPath = Path()..moveTo(px(0), top + h);
    for (int i = 0; i < n; i++) {
      fillPath.lineTo(px(i), py(profile[i]));
    }
    fillPath.lineTo(px(n - 1), top + h);
    fillPath.close();
    canvas.drawPath(fillPath, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFFFAB40).withValues(alpha: 0.35),
          const Color(0xFF4FC3F7).withValues(alpha: 0.05),
        ],
      ).createShader(Rect.fromLTWH(left, top, w, h)));

    final linePath = Path();
    for (int i = 0; i < n; i++) {
      i == 0
          ? linePath.moveTo(px(i), py(profile[i]))
          : linePath.lineTo(px(i), py(profile[i]));
    }
    canvas.drawPath(linePath, Paint()
      ..color = const Color(0xFF4FC3F7).withValues(alpha: 0.9)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round);

    final cursorIdx = (t * (n - 1)).clamp(0.0, (n - 1).toDouble());
    final ci = cursorIdx.floor().clamp(0, n - 2);
    final ct = cursorIdx - ci;
    final cx2 = _l(px(ci), px(ci + 1), ct);
    final cy2 = _l(py(profile[ci]), py(profile[ci + 1]), ct);
    final currentEnergy = _l(profile[ci], profile[ci + 1], ct);

    canvas.drawCircle(Offset(cx2, cy2), 4.5,
        Paint()..color = const Color(0xFFFFAB40).withValues(alpha: 0.95));
    canvas.drawCircle(Offset(cx2, cy2), 4.5, Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2);

    final valTp = TextPainter(
      text: TextSpan(
        text: '${currentEnergy.toStringAsFixed(1)} kcal/mol',
        style: const TextStyle(
          color: Color(0xFFFFAB40),
          fontSize: 9,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black, blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    valTp.paint(
        canvas, Offset(cx2 - valTp.width / 2, cy2 - valTp.height - 8));

    final ltp = TextPainter(
      text: const TextSpan(
          text: 'IRC Energy Profile',
          style: TextStyle(color: Colors.white38, fontSize: 8)),
      textDirection: TextDirection.ltr,
    )..layout();
    ltp.paint(canvas, Offset(left, top - pad + 2));
  }

  void _drawPhaseCaption(Canvas canvas, Size size, double t) {
    final (label, color) = t < _t1
        ? ('${rMolecules.length} reactant molecule${rMolecules.length == 1 ? '' : 's'} approaching',
            const Color(0xFF4FC3F7))
        : t < _t2
            ? ('Transition State — bonds rearranging',
                const Color(0xFFFFAB40))
            : t < _t3
                ? ('${pMolecules.length} product molecule${pMolecules.length == 1 ? '' : 's'} separating',
                    const Color(0xFF80DEEA))
                : ('Reaction complete — ${pMolecules.length} stable product${pMolecules.length == 1 ? '' : 's'}',
                    const Color(0xFF66BB6A));

    final tp = TextPainter(
      text: TextSpan(
          text: label,
          style: TextStyle(
              color: color.withValues(alpha: 0.72),
              fontSize: 10,
              fontWeight: FontWeight.w500)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas,
        Offset((size.width - tp.width) / 2, size.height - 28));

    final wm = TextPainter(
      text: TextSpan(
        text: 'Encrypted Copyright © Ammar (ID: 9x8A4M2C)',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.15),
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    wm.paint(canvas, Offset(8, size.height - 18));
  }

  @override
  bool shouldRepaint(covariant _RxnPainterV3 old) =>
      rAtoms != old.rAtoms || pAtoms != old.pAtoms;
}

// ─────────────────────────────────────────────────────────────────────────────
// Data helpers
// ─────────────────────────────────────────────────────────────────────────────
enum _BK { stable, breaking, forming, ts }
abstract class _Item { double get z; }

class _PA implements _Item {
  final Atom atom;
  final double sx, sy;
  @override
  final double z;
  _PA({required this.atom, required this.sx, required this.sy,
       required this.z});
}

class _BD implements _Item {
  final _PA p1, p2;
  @override
  final double z;
  final double dist, ideal;
  final _BK kind;
  final double animT;
  final int index;
  _BD({required this.p1, required this.p2, required this.z,
       required this.dist, required this.ideal, required this.kind,
       required this.animT, required this.index});
}

class _CalculatedBond {
  final Atom a1, a2;
  final double dist, idealDist;
  final int index;
  _CalculatedBond(this.a1, this.a2, this.dist, this.idealDist, this.index);
}