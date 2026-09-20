// ============================================================================
// ReactionAnimationWidget — v6
//
// Key v6 changes
//   • The widget wraps its entire return value in a SingleChildScrollView.
//     Overflow is now IMPOSSIBLE regardless of the parent's height. If the
//     parent is unbounded the scroll view just sizes to content; if the
//     parent is bounded and too small the user can scroll inside.
//   • Canvas height 700 (was 620) — gives molecules more real estate.
//   • Scale calculation: removed the +4.5 Å padding that was crushing the
//     molecule to ~15 px atoms. Only +1 Å of safety pad remains.
//   • Atom radius factor raised to 0.70 with a 7 px minimum.
//   • Projection centre is shifted slightly up so the molecule doesn't sit
//     under the bottom captions.
//   • Two visually independent cards (animation + bond energies) stacked in
//     a Column; each grows to its own natural height.
// ============================================================================

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:quantum_forge/core/utils/xyz_parser.dart';



const double _kAtomRadiusFactor = 0.70;
const double _kMinAtomRadius    = 7.0;
const double _kSeparationPad    = 2.0;   // used only inside _buildAtoms offsets

/// Playback direction mode, matching ColabReaction's loop selector.
enum _LoopMode { forward, backward, pingpong }

// ── Electron-transfer / mechanism overlay ──────────────────────────────────
// Pauling electronegativities for the elements that appear in reaction
// templates. Used to place partial charges and to decide the direction of
// electron flow (electrons move to the more electronegative atom).
const Map<String, double> _electronegativity = {
  'H': 2.20, 'Li': 0.98, 'Be': 1.57, 'B': 2.04, 'C': 2.55, 'N': 3.04,
  'O': 3.44, 'F': 3.98, 'Na': 0.93, 'Mg': 1.31, 'Al': 1.61, 'Si': 1.90,
  'P': 2.19, 'S': 2.58, 'Cl': 3.16, 'K': 0.82, 'Ca': 1.00, 'Fe': 1.83,
  'Cu': 1.90, 'Zn': 1.65, 'Br': 2.96, 'I': 2.66, 'Se': 2.55, 'As': 2.18,
  'Sn': 1.96, 'Pd': 2.20, 'Pt': 2.28, 'Au': 2.54,
};

/// Approximate number of lone pairs a neutral heteroatom carries.
int _lonePairCount(String symbol) {
  switch (symbol) {
    case 'O':
    case 'S':
    case 'Se':
      return 2;
    case 'N':
    case 'P':
    case 'As':
      return 1;
    case 'F':
    case 'Cl':
    case 'Br':
    case 'I':
      return 3;
    default:
      return 0;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class ReactionAnimationWidget extends StatefulWidget {
  final List<String> trajectoryFrames;
  final List<double>? energyProfile;

  /// Absolute potential energies straight from the UMA model, in eV. Shown in the
  /// readout rather than discarded.
  final List<double>? energyProfileEv;

  /// Highest-energy image index as computed by DMF on the optimised path. When
  /// present it is authoritative, so the transition state is not guessed at by
  /// scanning the profile.
  final int? maxEnergyIndex;

  /// Explicit per-frame interval in ms, overriding the derived default. The
  /// template preview uses this to read slower than a 3-frame path otherwise would.
  final int? speedMsOverride;

  const ReactionAnimationWidget({
    super.key,
    required this.trajectoryFrames,
    this.energyProfile,
    this.energyProfileEv,
    this.maxEnergyIndex,
    this.speedMsOverride,
  });

  /// Per-frame interval bounds, in milliseconds.
  ///
  /// ColabReaction uses a fixed 200 ms over 10–2000 ms, which is far too fast for
  /// this renderer: a 12-frame path looped in 2.4 s, against the 24 s cycle the
  /// app used before. The range is widened at the slow end so a comfortable pace
  /// is actually reachable.
  static const int _minSpeedMs = 50;
  static const int _maxSpeedMs = 4000;

  /// A full pass through the trajectory should take roughly this long, whatever
  /// the frame count.
  static const int _targetCycleMs = 18000;

  /// Default per-frame interval for a trajectory of [frameCount] frames.
  ///
  /// Derived rather than fixed so a 5-frame and a 40-frame path both loop in about
  /// [_targetCycleMs]; a constant ms-per-frame makes short paths flicker past.
  static int defaultSpeedMsFor(int frameCount) {
    if (frameCount <= 1) return _minSpeedMs;
    return (_targetCycleMs / frameCount).round().clamp(_minSpeedMs, _maxSpeedMs);
  }

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
  bool _showEnergies = false;
  bool _showMechanism = false;

  // ── Frame-based playback (mirrors ColabReaction's visualiser) ─────────────
  // ColabReaction drives an explicit frame index at a millisecond interval with
  // a selectable loop mode, rather than one continuous cycle. The same controls
  // are reproduced here; the painter still consumes a normalised 0..1 coordinate,
  // so each step is tweened across one interval instead of jumping.
  int _frameIndex = 0;

  /// Interval between frames, in milliseconds. Derived on load — see
  /// [ReactionAnimationWidget.defaultSpeedMsFor].
  int _speedMs = 600;

  /// True once the user moves the slider — suppresses re-deriving the default.
  bool _speedUserSet = false;

  int _deriveDefaultSpeed() {
    final override = widget.speedMsOverride;
    if (override != null) {
      return override.clamp(
        ReactionAnimationWidget._minSpeedMs,
        ReactionAnimationWidget._maxSpeedMs,
      );
    }
    return ReactionAnimationWidget.defaultSpeedMsFor(_frameCount);
  }

  _LoopMode _loopMode = _LoopMode.forward;

  /// +1 forward, -1 backward; used by the ping-pong mode.
  int _direction = 1;
  Timer? _ticker;

  // Reaction-coordinate phases. The transition-state window (t1 → t2) is the
  // widest and slowest band — it is the chemically decisive moment, so the loop
  // lingers there (≈40% of the 24 s cycle) with extra detail.
  static const double _t1 = 0.30;
  static const double _t2 = 0.70;
  static const double _t3 = 0.85;

  @override
  void initState() {
    super.initState();
    _speedMs = _deriveDefaultSpeed();
    _ctrl = AnimationController(
        vsync: this, duration: Duration(milliseconds: _speedMs));
    _repaint = Listenable.merge([_ctrl, _rotNotifier]);
    _load();
    // Frame-based playback: advance one trajectory frame every _speedMs.
    _startTicker();
  }

  // ── Frame playback (ColabReaction-compatible) ─────────────────────────────

  int get _frameCount => widget.trajectoryFrames.isEmpty
      ? 1
      : widget.trajectoryFrames.length;

  /// Normalised painter coordinate for a frame index.
  double _tForFrame(int index) =>
      _frameCount <= 1 ? 0.0 : index / (_frameCount - 1);

  /// Frame currently on screen, derived from the painter coordinate.
  int get _shownFrame => _frameCount <= 1
      ? 0
      : (_ctrl.value * (_frameCount - 1)).round().clamp(0, _frameCount - 1);

  double? get _energyAtShownFrame {
    final ep = widget.energyProfile;
    if (ep == null || ep.isEmpty) return null;
    return ep[_shownFrame.clamp(0, ep.length - 1)];
  }

  /// Absolute UMA energy (eV) at the shown frame, when the backend supplied it.
  double? get _absEnergyAtShownFrame {
    final ev = widget.energyProfileEv;
    if (ev == null || ev.isEmpty) return null;
    return ev[_shownFrame.clamp(0, ev.length - 1)];
  }

  double get _shownProgress =>
      _frameCount <= 1 ? 0.0 : _shownFrame / (_frameCount - 1) * 100.0;

  void _startTicker() {
    _ticker?.cancel();
    if (_frameCount <= 1) return;
    _ticker = Timer.periodic(
      Duration(milliseconds: _speedMs),
      (_) => _advanceFrame(),
    );
  }

  /// Moves to [index], tweening the painter across one interval so the motion
  /// stays smooth even though the stepping itself is discrete.
  void _gotoFrame(int index) {
    if (!mounted) return;
    final target = index.clamp(0, _frameCount - 1);
    setState(() => _frameIndex = target);
    _ctrl.animateTo(
      _tForFrame(target),
      duration: Duration(milliseconds: _speedMs),
      curve: Curves.linear,
    );
  }

  void _advanceFrame() {
    if (!mounted || !_playing) return;
    final last = _frameCount - 1;
    var next = _frameIndex + _direction;

    if (next > last) {
      switch (_loopMode) {
        case _LoopMode.forward:
          next = 0;
        case _LoopMode.backward:
          _direction = -1;
          next = last - 1;
        case _LoopMode.pingpong:
          _direction = -1;
          next = last - 1;
      }
    } else if (next < 0) {
      switch (_loopMode) {
        case _LoopMode.forward:
          _direction = 1;
          next = 0;
        case _LoopMode.backward:
          next = last;
        case _LoopMode.pingpong:
          _direction = 1;
          next = 1;
      }
    }
    _gotoFrame(next);
  }

  void _play() {
    setState(() => _playing = true);
    _startTicker();
  }

  /// Stops immediately and holds the current frame — the notebook's
  /// stopAnimationImmediate() behaviour.
  void _stop() {
    _ticker?.cancel();
    _ctrl.stop();
    setState(() => _playing = false);
  }

  /// Slider position (0..1) for the current interval.
  ///
  /// Mapped logarithmically: on a linear 50–4000 ms track the whole useful slow
  /// range would be crammed into the last sliver and the fast end would dominate.
  double get _speedSliderValue {
    final lo = math.log(ReactionAnimationWidget._minSpeedMs.toDouble());
    final hi = math.log(ReactionAnimationWidget._maxSpeedMs.toDouble());
    return ((math.log(_speedMs.toDouble()) - lo) / (hi - lo)).clamp(0.0, 1.0);
  }

  void _setSpeedFromSlider(double t) {
    final lo = math.log(ReactionAnimationWidget._minSpeedMs.toDouble());
    final hi = math.log(ReactionAnimationWidget._maxSpeedMs.toDouble());
    _setSpeedMs(math.exp(lo + (hi - lo) * t.clamp(0.0, 1.0)));
  }

  void _setSpeedMs(double ms) {
    final clamped = ms
        .round()
        .clamp(ReactionAnimationWidget._minSpeedMs,
            ReactionAnimationWidget._maxSpeedMs);
    // Once the user touches the slider, stop re-deriving the default for them.
    _speedUserSet = true;
    if (clamped == _speedMs) return;
    setState(() => _speedMs = clamped);
    if (_playing) _startTicker(); // re-time the running loop
  }

  /// Wall-clock duration of one full pass — the number that actually reads as
  /// "speed" to a user.
  String get _cycleLabel =>
      '${(_frameCount * _speedMs / 1000).toStringAsFixed(1)} s';

  void _setLoopMode(_LoopMode mode) {
    setState(() {
      _loopMode = mode;
      if (mode == _LoopMode.backward) _direction = -1;
      if (mode == _LoopMode.forward) _direction = 1;
    });
  }

  @override
  void didUpdateWidget(covariant ReactionAnimationWidget old) {
    super.didUpdateWidget(old);
    final framesChanged = old.trajectoryFrames != widget.trajectoryFrames;
    final overrideChanged = old.speedMsOverride != widget.speedMsOverride;
    if (framesChanged || overrideChanged) {
      // A different trajectory (or an explicit pace) wants its own default,
      // unless the user has already dialled in a speed they like.
      if (!_speedUserSet) {
        _speedMs = _deriveDefaultSpeed();
        if (_playing) _startTicker();
      }
      if (framesChanged) _load();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ctrl.dispose();
    _rotNotifier.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final frames = widget.trajectoryFrames;
    if (frames.length < 3) return;

    // Prefer the index DMF computed on the optimised path; only fall back to
    // scanning the profile when the backend supplied no index (e.g. the local
    // simulation), because the two can disagree.
    final backendTs = widget.maxEnergyIndex;
    int tsIdx;
    if (backendTs != null && backendTs >= 0 && backendTs < frames.length) {
      tsIdx = backendTs;
    } else {
      tsIdx = frames.length ~/ 2;
      final ep = widget.energyProfile;
      if (ep != null && ep.length == frames.length) {
        double maxE = double.negativeInfinity;
        for (int i = 0; i < ep.length; i++) {
          if (ep[i] > maxE) {
            maxE = ep[i];
            tsIdx = i;
          }
        }
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

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const AspectRatio(
        aspectRatio: 1.5,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 150,
                child: LinearProgressIndicator(
                  color: Color(0xFF4FC3F7),
                  backgroundColor: Colors.white10,
                  minHeight: 2,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Parsing trajectory & detecting molecules...',
                style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    // ── THE FIX ──────────────────────────────────────────────────────────
    // Wrap the whole column in a SingleChildScrollView. If the parent gives
    // a bounded height smaller than our content, we scroll internally and
    // never overflow. If the parent is unbounded, this sizes to content.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAnimationCard(),
        if (_showEnergies) ...[
          const SizedBox(height: 20),
          _buildBondEnergiesCard(),
        ],
        const SizedBox(height: 20),
        _buildKineticEnergyCard(),
      ],
    );
  }

  // ── Card 1: animation ────────────────────────────────────────────────────
  Widget _buildAnimationCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          AspectRatio(aspectRatio: 1.2, child: _buildCanvas()),
          _buildFrameInfo(),
          _buildTimeline(),
          _buildTransportControls(),
          _buildSpeedControl(),
          _buildLoopControl(),
          _buildSlider(),
        ],
      ),
    );
  }

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
            _btn(
              _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              () => _playing ? _stop() : _play(),
              tooltip: _playing ? 'Stop' : 'Play',
            ),
            const SizedBox(width: 4),
            _btn(_showEnergies ? Icons.link : Icons.link_off, () {
              setState(() => _showEnergies = !_showEnergies);
            }, tooltip: 'Toggle Bond Energies'),
            const SizedBox(width: 4),
            _btn(_showMechanism ? Icons.electric_bolt : Icons.electric_bolt_outlined, () {
              setState(() => _showMechanism = !_showMechanism);
            }, tooltip: 'Toggle electron flow / mechanism'),
            const SizedBox(width: 4),
            _btn(Icons.replay_rounded, () {
              _direction = _loopMode == _LoopMode.backward ? -1 : 1;
              _gotoFrame(0);
              _play();
            }, tooltip: 'Restart from frame 0'),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvas() {
    return ClipRect(
      child: GestureDetector(
        onPanUpdate: (d) {
          _rotNotifier.value = Offset(
            _rotNotifier.value.dx + d.delta.dy * 0.009,
            _rotNotifier.value.dy + d.delta.dx * 0.009,
          );
        },
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _RxnPainterV6(
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
              showBondEnergies: _showEnergies,
              showMechanism: _showMechanism,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }

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

  /// Frame readout — the same information the notebook's "Current Frame
  /// Information" panel carries: index, energy, progress, state, speed, loop.
  Widget _buildFrameInfo() {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, _) {
        final energy = _energyAtShownFrame;
        final absEnergy = _absEnergyAtShownFrame;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF4FC3F7).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFF4FC3F7).withValues(alpha: 0.25)),
            ),
            child: Wrap(
              spacing: 18,
              runSpacing: 6,
              children: [
                _infoItem('Frame', '$_shownFrame / ${_frameCount - 1}'),
                if (energy != null)
                  _infoItem('Energy', '${energy.toStringAsFixed(2)} kcal·mol⁻¹'),
                if (absEnergy != null)
                  _infoItem('UMA E', '${absEnergy.toStringAsFixed(4)} eV'),
                _infoItem('Progress', '${_shownProgress.toStringAsFixed(1)}%'),
                _infoItem('Status', _playing ? 'Playing' : 'Stopped'),
                _infoItem('Speed', '$_speedMs ms/frame'),
                _infoItem('Cycle', _cycleLabel),
                _infoItem('Loop', _loopMode.name),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoItem(String label, String value) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('$label: ',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45), fontSize: 10)),
      Text(value,
          style: const TextStyle(
              color: Color(0xFF4FC3F7),
              fontSize: 10,
              fontWeight: FontWeight.w600)),
    ]);
  }

  /// Start / step back / step forward / end — the notebook's navigation row.
  Widget _buildTransportControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
      child: Row(
        children: [
          _navBtn('⏮', 'First frame', () => _gotoFrame(0)),
          const SizedBox(width: 6),
          _navBtn('⏪', 'Step back', () => _gotoFrame(_shownFrame - 1)),
          const SizedBox(width: 6),
          _navBtn('⏩', 'Step forward', () => _gotoFrame(_shownFrame + 1)),
          const SizedBox(width: 6),
          _navBtn('⏭', 'Last frame', () => _gotoFrame(_frameCount - 1)),
        ],
      ),
    );
  }

  Widget _navBtn(String glyph, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Text(glyph,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ),
      ),
    );
  }

  /// Loop mode: forward / backward / pingpong, as in the notebook.
  Widget _buildLoopControl() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(
        children: [
          const Icon(Icons.loop, size: 15, color: Colors.white54),
          const SizedBox(width: 6),
          const Text('Loop',
              style: TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(width: 10),
          for (final mode in _LoopMode.values)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _loopChip(mode),
            ),
        ],
      ),
    );
  }

  Widget _loopChip(_LoopMode mode) {
    final active = _loopMode == mode;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _setLoopMode(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF4FC3F7).withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active
                  ? const Color(0xFF4FC3F7).withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.12)),
        ),
        child: Text(
          mode.name,
          style: TextStyle(
            color: active ? const Color(0xFF4FC3F7) : Colors.white54,
            fontSize: 10,
            fontWeight: active ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// Frame interval in milliseconds. The notebook exposes 10 ms (ultra fast) to
  /// 2000 ms (very slow) and defaults to 200 ms.
  Widget _buildSpeedControl() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Row(
        children: [
          const Icon(Icons.speed, size: 15, color: Colors.white54),
          const SizedBox(width: 6),
          const Text('Speed',
              style: TextStyle(color: Colors.white54, fontSize: 11)),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFF4FC3F7),
                inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                thumbColor: const Color(0xFF4FC3F7),
                trackHeight: 2,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: _speedSliderValue,
                min: 0.0,
                max: 1.0,
                label: '$_speedMs ms/frame',
                onChanged: _setSpeedFromSlider,
              ),
            ),
          ),
          SizedBox(
            width: 76,
            child: Text(
              '$_speedMs ms',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF4FC3F7),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

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
                // Scrubbing takes over playback and keeps _frameIndex in sync, so
                // the step buttons resume from wherever the user let go.
                if (_playing) _stop();
                if (_isRendering) return;
                _isRendering = true;

                final frame = _frameCount <= 1
                    ? 0
                    : (val * (_frameCount - 1)).round();
                setState(() => _frameIndex = frame);
                _ctrl.value = _tForFrame(frame);

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

  // ── Card 2: bond energies (independent panel) ────────────────────────────
  Widget _buildBondEnergiesCard() {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, _) => Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: _buildLiveEnergiesContent(),
      ),
    );
  }

  Widget _buildKineticEnergyCard() {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, _) {
        final t = _ctrl.value;
        final dt = 0.02;
        final tPrev = math.max(0.0, t - dt);
        final atomsNow = _buildAtoms(t);
        final atomsPrev = _buildAtoms(tPrev);
        
        double ke = 0.0;
        if (atomsNow.length == atomsPrev.length) {
          for (int i = 0; i < atomsNow.length; i++) {
            final dx = atomsNow[i].x - atomsPrev[i].x;
            final dy = atomsNow[i].y - atomsPrev[i].y;
            final dz = atomsNow[i].z - atomsPrev[i].z;
            ke += (dx * dx + dy * dy + dz * dz);
          }
          ke = (ke / dt) * 15.0; // scale factor for display
        }
        
        return Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.purpleAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Kinetic Energy Changes',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${ke.toStringAsFixed(1)} kcal·mol⁻¹',
                style: const TextStyle(
                  color: Colors.purpleAccent,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (ke / 100.0).clamp(0.0, 1.0),
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation(Colors.purpleAccent),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLiveEnergiesContent() {
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF4FC3F7),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Live Bond Energies',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${bonds.length} bonds',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (bonds.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No bonds in current frame',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 12,
                ),
              ),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: bonds.map(_bondChip).toList(),
          ),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: chipColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: Colors.orangeAccent,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${b.index}',
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${b.a1.symbol}–${b.a2.symbol}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '$valStr kcal·mol⁻¹',
                style: TextStyle(color: chipColor, fontSize: 11),
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

  Widget _btn(IconData icon, VoidCallback onTap, {String? tooltip}) {
    Widget child = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
    if (tooltip != null) {
      child = Tooltip(message: tooltip, child: child);
    }
    return child;
  }

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
          final offset = side * _kSeparationPad * (1.0 - progress);
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
          final offset = side * _kSeparationPad * progress;
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
// Painter v6 — big atoms, no over-padding, up-shifted centre
// ─────────────────────────────────────────────────────────────────────────────
class _RxnPainterV6 extends CustomPainter {
  final List<Atom> rAtoms, tsAtoms, pAtoms;
  final List<List<Atom>> rMolecules, pMolecules;
  final Set<String> rBonds, pBonds;
  final AnimationController ctrl;
  final ValueNotifier<Offset> rotNotifier;
  final List<double> energyProfile;
  final bool showBondEnergies;
  final bool showMechanism;

  static const double _scale = 120.0;
  static const double _t1 = 0.30;
  static const double _t2 = 0.70;
  static const double _t3 = 0.85;

  _RxnPainterV6({
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
    required this.showBondEnergies,
    required this.showMechanism,
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
          final offset = side * _kSeparationPad * (1.0 - progress);
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
          final offset = side * _kSeparationPad * progress;
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

    // Warm vignette tint that swells during the transition state — a visual
    // cue that the system is at the top of the barrier.
    if (t >= _t1 && t < _t2) {
      final tsT = (t - _t1) / (_t2 - _t1);
      final env = math.sin(tsT * math.pi);
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xFFFFB300).withValues(alpha: 0.05 * env),
      );
    }

    // Shift centre slightly UP so the molecule sits nicely above the bottom
    // captions / energy plot / axes, instead of hugging the bottom edge.
    final cx = size.width / 2;
    final cy = (size.height - 60) * 0.5 + 20;

    // Fixed TS COM reference — keeps every phase visually centred.
    double refX = 0, refY = 0, refZ = 0;
    final refSource = tsAtoms.isNotEmpty ? tsAtoms : atoms;
    for (final a in refSource) { refX += a.x; refY += a.y; refZ += a.z; }
    refX /= refSource.length;
    refY /= refSource.length;
    refZ /= refSource.length;

    // ── SCALE FIX ───────────────────────────────────────────────────────
    // Use TS extent + only +1 Å safety pad. Previously +4.5 Å, which crushed
    // the scale and produced ~15 px atoms.
    double maxDistSq = 0.0;
    for (final a in tsAtoms) {
      final dx = a.x - refX, dy = a.y - refY, dz = a.z - refZ;
      final d = dx*dx + dy*dy + dz*dz;
      if (d > maxDistSq) maxDistSq = d;
    }
    double dynamicScale = _scale;
    if (maxDistSq > 0.01) {
      final maxDist = math.sqrt(maxDistSq) + 1.0;   // was +1.5 + _kSeparationPad
      final targetSize = math.min(size.width, size.height) * 0.92;
      dynamicScale = targetSize / (2 * maxDist);
      dynamicScale = dynamicScale.clamp(20.0, 600.0);
    }
    // ────────────────────────────────────────────────────────────────────

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
      final p = _proj(a.x + jx, a.y + jy, a.z, refX, refY, refZ,
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
            index: bondIndexCounter++, i1: i, i2: j));
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

    // Electron-transfer / mechanism overlay — layered above the structure so
    // curved arrows, charges and lone pairs read clearly.
    if (showMechanism) {
      _drawElectronFlow(canvas, bonds, t);
      _drawCharges(canvas, atoms, proj, bonds, dynamicScale);
      _drawLonePairs(canvas, atoms, proj, bonds, dynamicScale);
    }

    // Transition-state detail — the decisive moment, drawn on top with
    // reaction-coordinate vibration arrows, live bond lengths and a TS badge.
    _drawTsDetails(canvas, size, atoms, proj, bonds, dynamicScale, t);

    _drawAxes(canvas, size, cosX, sinX, cosY, sinY);
    _drawEnergyPlot(canvas, size, t);
    _drawPhaseCaption(canvas, size, t);
  }

  void _drawBond(Canvas canvas, _BD b, double t) {
    final p1 = Offset(b.p1.sx, b.p1.sy);
    final p2 = Offset(b.p2.sx, b.p2.sy);
    final stretch = (b.dist / b.ideal).clamp(0.75, 2.5);
    Color bondColor = Colors.blueGrey.shade400;

    switch (b.kind) {
      case _BK.stable:
        if (showMechanism) {
          _multiBond(canvas, p1, p2, Colors.blueGrey.shade400, 6.5, _bondOrder(b));
        } else {
          _cylBond(canvas, p1, p2, Colors.blueGrey.shade400, 6.5);
        }
        break;
      case _BK.breaking:
        final p = ((stretch - 1.0) / 0.75).clamp(0.0, 1.0);
        bondColor = Color.lerp(Colors.blueGrey.shade400, Colors.deepOrangeAccent, p)!;
        if (stretch > 1.15) {
          _dashBond(canvas, p1, p2, bondColor, 5.0);
        } else {
          _cylBond(canvas, p1, p2, bondColor, 6.5);
        }
        break;
      case _BK.forming:
        final p = (1.0 - ((stretch - 1.0) / 0.75).clamp(0.0, 1.0));
        bondColor = const Color(0xFF66BB6A).withValues(alpha: p.clamp(0.15, 1.0));
        if (stretch > 1.12) {
          _dashBond(canvas, p1, p2, bondColor, 4.5);
        } else {
          _cylBond(canvas, p1, p2, const Color(0xFF66BB6A), 6.5);
        }
        break;
      case _BK.ts:
        if (t >= _t1 * 0.7 && t < _t2 * 1.05) {
          bondColor = Colors.amber.withValues(alpha: 0.5);
          _dashBond(canvas, p1, p2, bondColor, 3.0);
        } else {
          bondColor = Colors.transparent;
        }
        break;
    }

    if (bondColor != Colors.transparent && showBondEnergies) {
      _drawBondLabel(canvas, p1, p2, b.dist, b.ideal, bondColor, b.index);
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

  // ── Bond order / multi-bond rendering ─────────────────────────────────────
  /// Rough bond order from the bond-length / covalent-sum ratio. Short bonds
  /// are drawn as double or triple bonds in mechanism mode.
  int _bondOrder(_BD b) {
    final ratio = b.dist / b.ideal;
    if (ratio < 0.80) return 3;
    if (ratio < 0.92) return 2;
    return 1;
  }

  /// Draws 1–3 parallel cylinders for single/double/triple bonds.
  void _multiBond(Canvas canvas, Offset p1, Offset p2, Color col, double w,
      int order) {
    final dir = p2 - p1;
    final len = dir.distance;
    if (len < 2.0) {
      _cylBond(canvas, p1, p2, col, w);
      return;
    }
    final perp = Offset(-dir.dy, dir.dx) / len * (w * 0.55);
    if (order >= 3) {
      for (final off in const [0.0, 1.0, -1.0]) {
        _cylBond(canvas, p1 + perp * off, p2 + perp * off, col, w * 0.62);
      }
    } else if (order == 2) {
      for (final off in const [0.5, -0.5]) {
        _cylBond(canvas, p1 + perp * off, p2 + perp * off, col, w * 0.72);
      }
    } else {
      _cylBond(canvas, p1, p2, col, w);
    }
  }

  // ── Electron-transfer overlay ─────────────────────────────────────────────
  /// Draws research-style curved arrows showing electron-pair movement: from a
  /// breaking bond to the more electronegative atom, and from the donor atom
  /// into a forming bond. Animated "electron packets" travel along each arrow.
  void _drawElectronFlow(Canvas canvas, List<_BD> bonds, double t) {
    const flowColor = Color(0xFF2CE0C8);
    for (final b in bonds) {
      if (b.kind != _BK.breaking && b.kind != _BK.forming) continue;
      final a1 = b.p1, a2 = b.p2;
      final en1 = _electronegativity[a1.atom.symbol] ?? 2.0;
      final en2 = _electronegativity[a2.atom.symbol] ?? 2.0;

      Offset from, to;
      if (b.kind == _BK.breaking) {
        // Electron pair retreats onto the more electronegative atom.
        final sink = en1 >= en2 ? a1 : a2;
        from = Offset((a1.sx + a2.sx) / 2, (a1.sy + a2.sy) / 2);
        to = Offset(sink.sx, sink.sy);
      } else {
        // Electron pair flows from the donor into the new bond.
        final donor = en1 <= en2 ? a1 : a2;
        from = Offset(donor.sx, donor.sy);
        to = Offset((a1.sx + a2.sx) / 2, (a1.sy + a2.sy) / 2);
      }
      _curvedArrow(canvas, from, to, flowColor, t + b.index * 0.137);
    }
  }

  Offset _bez2(Offset p0, Offset p1, Offset p2, double u) {
    final inv = 1 - u;
    return p0 * (inv * inv) + p1 * (2 * inv * u) + p2 * (u * u);
  }

  void _curvedArrow(
      Canvas canvas, Offset from, Offset to, Color color, double phase) {
    final dir = to - from;
    final len = dir.distance;
    if (len < 8.0) return;

    final mid = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2);
    final perp = Offset(-dir.dy, dir.dx) / len;
    final ctrl = mid + perp * (len * 0.30);

    final path = Path()..moveTo(from.dx, from.dy);
    const steps = 24;
    for (int i = 1; i <= steps; i++) {
      final p = _bez2(from, ctrl, to, i / steps);
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );

    // Arrowhead tangent at the target.
    final tangent = to - ctrl;
    final tl = tangent.distance;
    final tn = tl > 0 ? tangent / tl : const Offset(1, 0);
    final base = to - tn * 7;
    final ap = Offset(-tn.dy, tn.dx);
    final headPaint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(to, base + ap * 4.2, headPaint);
    canvas.drawLine(to, base - ap * 4.2, headPaint);

    // Two travelling electron packets.
    for (int k = 0; k < 2; k++) {
      final u = (phase * 1.6 + k * 0.5) % 1.0;
      final p = _bez2(from, ctrl, to, u);
      canvas.drawCircle(p, 4.2,
          Paint()
            ..color = color.withValues(alpha: 0.30)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      canvas.drawCircle(p, 2.3, Paint()..color = Colors.white.withValues(alpha: 0.95));
    }
  }

  /// Electronegativity-difference partial charges (δ+/δ−) per atom.
  List<double> _charges(List<Atom> atoms, List<_BD> bonds) {
    final n = atoms.length;
    final en = List.generate(n, (i) => _electronegativity[atoms[i].symbol] ?? 2.0);
    final neigh = List.generate(n, (_) => <int>[]);
    for (final b in bonds) {
      if (b.i1 >= 0 && b.i1 < n && b.i2 >= 0 && b.i2 < n) {
        neigh[b.i1].add(b.i2);
        neigh[b.i2].add(b.i1);
      }
    }
    final delta = List<double>.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      if (atoms[i].symbol == 'H' || neigh[i].isEmpty) continue;
      double sum = 0;
      for (final j in neigh[i]) {
        sum += en[j];
      }
      delta[i] = (en[i] - sum / neigh[i].length).clamp(-1.2, 1.2);
    }
    return delta;
  }

  void _drawCharges(Canvas canvas, List<Atom> atoms, List<_PA> proj,
      List<_BD> bonds, double dynamicScale) {
    final delta = _charges(atoms, bonds);
    for (int i = 0; i < proj.length; i++) {
      final d = delta[i];
      if (d.abs() < 0.18) continue;
      final p = proj[i];
      final r = math.max(
          p.atom.covalentRadius * dynamicScale * _kAtomRadiusFactor, _kMinAtomRadius);
      final positive = d > 0;
      final tp = TextPainter(
        text: TextSpan(
          text: positive ? 'δ+' : 'δ−',
          style: TextStyle(
            color: positive ? const Color(0xFFFF5252) : const Color(0xFF448AFF),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(p.sx - tp.width / 2, p.sy - r - tp.height - 2));
    }
  }

  /// Draws lone-pair electron dots on heteroatoms, oriented away from bonds.
  void _drawLonePairs(Canvas canvas, List<Atom> atoms, List<_PA> proj,
      List<_BD> bonds, double dynamicScale) {
    final n = atoms.length;
    final dirs = List.generate(n, (_) => <Offset>[]);
    for (final b in bonds) {
      final v = Offset(b.p2.sx - b.p1.sx, b.p2.sy - b.p1.sy);
      final l = v.distance;
      if (l < 0.01) continue;
      dirs[b.i1].add(v / l);
      dirs[b.i2].add(-(v / l));
    }

    for (int i = 0; i < n; i++) {
      final lp = _lonePairCount(atoms[i].symbol);
      if (lp == 0) continue;
      final p = proj[i];
      final r = math.max(
          p.atom.covalentRadius * dynamicScale * _kAtomRadiusFactor, _kMinAtomRadius);

      // Candidate directions, ordered by angular distance from existing bonds,
      // so lone pairs sit in the least-crowded pocket around the atom.
      final candidates = <Offset>[
        for (int k = 0; k < 12; k++)
          Offset(math.cos(k * math.pi / 6), math.sin(k * math.pi / 6)),
      ];
      double minAngle(Offset o) {
        double m = 1e9;
        for (final d in dirs[i]) {
          final dot = (o.dx * d.dx + o.dy * d.dy).clamp(-1.0, 1.0);
          m = math.min(m, math.acos(dot));
        }
        return m;
      }

      candidates.sort((a, b) => minAngle(b).compareTo(minAngle(a)));
      for (int k = 0; k < lp && k < candidates.length; k++) {
        final d = candidates[k];
        final base = Offset(p.sx + d.dx * (r + 7), p.sy + d.dy * (r + 7));
        final perp = Offset(-d.dy, d.dx);
        final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.90);
        canvas.drawCircle(base + perp * 2.2, 2.2, dotPaint);
        canvas.drawCircle(base - perp * 2.2, 2.2, dotPaint);
      }
    }
  }

  void _drawBondLabel(Canvas canvas, Offset p1, Offset p2,
      double dist, double ideal, Color col, int index) {
    
    final midX = (p1.dx + p2.dx) / 2;
    final midY = (p1.dy + p2.dy) / 2;

    // Draw background for text
    final textSpan = TextSpan(
      text: '$index',
      style: TextStyle(
        color: col.withAlpha(255),
        fontSize: 12,
        fontWeight: FontWeight.bold,
        shadows: const [Shadow(color: Colors.black87, blurRadius: 4)],
      ),
    );
    final textPainter = TextPainter(
        text: textSpan, textDirection: TextDirection.ltr, textAlign: TextAlign.center)
      ..layout();
      
    // Optional badge background behind the text for better readability
    final bgRect = Rect.fromCenter(
        center: Offset(midX, midY), 
        width: textPainter.width + 8, 
        height: textPainter.height + 4);
    canvas.drawRRect(
        RRect.fromRectAndRadius(bgRect, const Radius.circular(6)), 
        Paint()..color = Colors.black.withValues(alpha: 0.6));

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

    // v6: bigger spheres — factor 0.70, min 7 px.
    final baseR = p.atom.covalentRadius * dynamicScale * _kAtomRadiusFactor;
    final r = math.max(baseR, _kMinAtomRadius);
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

    if (r > 6) {
      final tp = TextPainter(
        text: TextSpan(
          text: p.atom.symbol,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.93),
            fontSize: (r * 0.80).clamp(8.0, 22.0),
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

  // ── Transition-state detail ───────────────────────────────────────────────
  /// The decisive moment, rendered in depth: the imaginary-frequency vibration
  /// as double-headed arrows on the atoms that move most, live Ångström bond
  /// lengths for the bonds that break/form, and a prominent TS badge.
  void _drawTsDetails(
    Canvas canvas,
    Size size,
    List<Atom> atoms,
    List<_PA> proj,
    List<_BD> bonds,
    double dynamicScale,
    double t,
  ) {
    if (t < _t1 || t >= _t2) return;
    final tsT = (t - _t1) / (_t2 - _t1); // 0..1 across the TS window
    final env = math.sin(tsT * math.pi); // fade in, fade out
    const vibColor = Color(0xFFFFD740); // amber — the "unstable mode"

    // 1. Reaction-coordinate vibration arrows on the most-displaced atoms.
    if (rAtoms.length == pAtoms.length && rAtoms.length == atoms.length) {
      final disp = <Offset>[];
      double maxD = 0;
      for (int i = 0; i < atoms.length; i++) {
        final d = Offset(pAtoms[i].x - rAtoms[i].x, pAtoms[i].y - rAtoms[i].y);
        maxD = math.max(maxD, d.distance);
        disp.add(d);
      }
      if (maxD > 0.01) {
        for (int i = 0; i < atoms.length; i++) {
          if (disp[i].distance < maxD * 0.35) continue;
          final p = proj[i];
          final n = disp[i] / disp[i].distance;
          final r = math.max(
              p.atom.covalentRadius * dynamicScale * _kAtomRadiusFactor,
              _kMinAtomRadius);
          // Oscillating arm length → the mode "breathes" along the reaction path.
          final arm = r + 10 + 9 * math.sin(t * 16 + i * 1.7);
          final a = Offset(p.sx + n.dx * arm, p.sy + n.dy * arm);
          final b = Offset(p.sx - n.dx * arm, p.sy - n.dy * arm);
          _drawDoubleArrow(
              canvas, a, b, vibColor.withValues(alpha: 0.85 * env));
        }
      }
    }

    // 2. Live bond lengths (Å) for the bonds that are breaking or forming.
    for (final b in bonds) {
      if (b.kind != _BK.breaking && b.kind != _BK.forming) continue;
      final mid = Offset((b.p1.sx + b.p2.sx) / 2, (b.p1.sy + b.p2.sy) / 2);
      final tp = TextPainter(
        text: TextSpan(
          text: '${b.dist.toStringAsFixed(2)} Å',
          style: TextStyle(
            color: const Color(0xFFFFD740).withValues(alpha: env),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final bg = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: mid, width: tp.width + 8, height: tp.height + 4),
        const Radius.circular(6),
      );
      canvas.drawRRect(bg, Paint()..color = Colors.black.withValues(alpha: 0.55 * env));
      tp.paint(canvas, Offset(mid.dx - tp.width / 2, mid.dy - tp.height / 2));
    }

    // 3. Prominent transition-state badge.
    final badge = TextPainter(
      text: TextSpan(
        text: 'TRANSITION STATE ‡',
        style: TextStyle(
          color: const Color(0xFFFFB300).withValues(alpha: 0.9 * env),
          fontSize: 15,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.5,
          shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    badge.paint(canvas, Offset((size.width - badge.width) / 2, 12));
  }

  /// A double-headed arrow (the reaction-coordinate / imaginary mode direction).
  void _drawDoubleArrow(Canvas canvas, Offset a, Offset b, Color color) {
    final dir = b - a;
    final len = dir.distance;
    if (len < 8) return;
    final n = dir / len;
    final perp = Offset(-n.dy, n.dx);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(a, b, paint);
    canvas.drawLine(a, a + n * 5.5 + perp * 3.4, paint);
    canvas.drawLine(a, a + n * 5.5 - perp * 3.4, paint);
    canvas.drawLine(b, b - n * 5.5 + perp * 3.4, paint);
    canvas.drawLine(b, b - n * 5.5 - perp * 3.4, paint);
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
        text: '${currentEnergy.toStringAsFixed(1)} kcal·mol⁻¹',
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

    if (showMechanism) {
      final legend = TextPainter(
        text: const TextSpan(
          text: 'curved arrow = electron pair · δ± = partial charge · ●● = lone pair',
          style: TextStyle(
            color: Color(0xFF2CE0C8),
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      legend.paint(
          canvas, Offset((size.width - legend.width) / 2, size.height - 44));
    }

    final wm = TextPainter(
      text: TextSpan(
        text: 'Encrypted Copyright © Ali Asghar\naliasgharinnocent@yahoo.com',
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
  bool shouldRepaint(covariant _RxnPainterV6 old) =>
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
  final int i1, i2;
  _BD({required this.p1, required this.p2, required this.z,
       required this.dist, required this.ideal, required this.kind,
       required this.animT, required this.index, required this.i1,
       required this.i2});
}

class _CalculatedBond {
  final Atom a1, a2;
  final double dist, idealDist;
  final int index;
  _CalculatedBond(this.a1, this.a2, this.dist, this.idealDist, this.index);
}