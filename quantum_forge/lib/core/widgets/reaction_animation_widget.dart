// ============================================================================
// ReactionAnimationWidget — Avogadro "Player tool" parity
// ----------------------------------------------------------------------------
// (header unchanged)
// ============================================================================

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:quantum_forge/core/utils/xyz_parser.dart';
import 'package:quantum_forge/state/settings_provider.dart';
import 'ngl/avogadro_geometry.dart';
import 'ngl/avogadro_sdf.dart';
import 'ngl/ngl_bond_label.dart';
import 'ngl/ngl_style.dart';
import 'ngl/ngl_viewer.dart';

/// Playback direction.
enum AnimationLoopMode { forward, backward, pingpong }

class ReactionAnimationWidget extends StatefulWidget {
  const ReactionAnimationWidget({
    super.key,
    required this.trajectoryFrames,
    this.energyProfile,
    this.energyProfileEv,
    this.maxEnergyIndex,
    this.frameRateOverride,
    this.displayType = AvogadroDisplayType.ballAndStick,
    this.dynamicBonding = false,
    this.showBondNumbers = false,
    this.compactMode = false,
    this.pdbUrl,
    this.dcdUrl,
    this.mdFrameCount,
  });

  final List<String> trajectoryFrames;
  final bool compactMode;
  final List<double>? energyProfile;
  final List<double>? energyProfileEv;
  final int? maxEnergyIndex;
  final int? frameRateOverride;
  final AvogadroDisplayType displayType;
  final bool dynamicBonding;
  final bool showBondNumbers;
  final String? pdbUrl;
  final String? dcdUrl;
  final int? mdFrameCount;

  static const int defaultFrameRate = 5;
  static const int minFrameRate = 0;
  static const int maxFrameRate = 1000;

  @override
  State<ReactionAnimationWidget> createState() =>
      _ReactionAnimationWidgetState();
}

class _ReactionAnimationWidgetState extends State<ReactionAnimationWidget> {
  final GlobalKey<NglViewerState> _viewerKey = GlobalKey<NglViewerState>();
  final FocusNode _playerFocus = FocusNode(debugLabel: 'reaction-player');

  List<List<Atom>?> _parsedFrames = const <List<Atom>?>[];
  List<PerceivedBond> _staticBonds = const <PerceivedBond>[];
  String? _trajectorySdf;

  int _reactantFragments = 0;
  int _productFragments = 0;
  int _transitionStateFrame = 0;

  int _frame = 0;
  int _startFrame = 0;
  int _endFrame = 0;
  int _frameRate = ReactionAnimationWidget.defaultFrameRate;
  bool _dynamicBonding = false;
  bool _playing = true;
  bool _fpsUserSet = false;

  Timer? _ticker;
  int _direction = 1;
  AnimationLoopMode _loopMode = AnimationLoopMode.forward;
  AvogadroDisplayType _displayType = AvogadroDisplayType.ballAndStick;
  NglPalette _palette = NglPalette.avogadro;

  bool _showBondNumbers = true;
  bool _showBondEnergies = true;

  List<BondLabel>? _pendingBondLabels;
  int _labelFlushAttempts = 0;

  bool _loaded = false;

  /// Once true, the card stays on screen through every subsequent reload.
  ///
  /// Without this, a rebuild that lands while `_load()` has `_loaded = false`,
  /// or a rebuild that hands in an empty `trajectoryFrames` for one frame,
  /// causes `build()` to return the placeholder — which unmounts the NGL
  /// platform view. The next rebuild re-mounts it, and the user sees the
  /// animation flicker in and out. This flag makes the placeholder a
  /// first-load-only state.
  bool _hasLoadedOnce = false;

  bool _viewFramed = false;

  static const double _t1 = 0.30;
  static const double _t2 = 0.70;
  static const double _t3 = 0.85;

  @override
  void initState() {
    super.initState();
    _displayType = widget.displayType;
    _dynamicBonding = widget.dynamicBonding;
    _showBondNumbers = widget.showBondNumbers;
    if (widget.frameRateOverride != null) {
      _frameRate = widget.frameRateOverride!.clamp(
        ReactionAnimationWidget.minFrameRate,
        ReactionAnimationWidget.maxFrameRate,
      );
      _fpsUserSet = true;
    }
    _load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _playerFocus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ReactionAnimationWidget old) {
    super.didUpdateWidget(old);

    // Value comparison, not reference comparison.
    //
    // The parent rebuilds this widget on every notifier tick. If it
    // constructs a fresh `trajectoryFrames` list on each of those rebuilds —
    // for example with `reactionStatus?.trajectoryFrames ?? []` — then
    // `!identical(old, widget)` is true every frame and `_load()` runs every
    // frame, tearing the NGL stage down and rebuilding it. That is the
    // flicker.
    final framesChanged = !_framesEqual(
      old.trajectoryFrames,
      widget.trajectoryFrames,
    );

    // The MD path has no `trajectoryFrames`; a different simulation shows up
    // only as changed URLs.
    final mdUrlsChanged =
        old.pdbUrl != widget.pdbUrl || old.dcdUrl != widget.dcdUrl;

    if (framesChanged || mdUrlsChanged) {
      _load();
      return;
    }

    if (old.frameRateOverride != widget.frameRateOverride &&
        widget.frameRateOverride != null &&
        !_fpsUserSet) {
      setState(() {
        _frameRate = widget.frameRateOverride!.clamp(
          ReactionAnimationWidget.minFrameRate,
          ReactionAnimationWidget.maxFrameRate,
        );
      });
      _restartTicker();
    }
  }

  /// Deep equality on a list of trajectory frame strings.
  ///
  /// A frame is at most a few hundred bytes, and a trajectory is at most a
  /// few dozen frames, so this costs nothing next to the SDF rewrite and NGL
  /// reload it prevents.
  static bool _framesEqual(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // ── Loading ───────────────────────────────────────────────────────────────

  void _load() {
    final frames = widget.trajectoryFrames;
    _parsedFrames = const <List<Atom>?>[];
    _staticBonds = const <PerceivedBond>[];
    _trajectorySdf = null;
    _reactantFragments = 0;
    _productFragments = 0;
    _loaded = false;
    _viewFramed = false;

    if (frames.isNotEmpty) {
      final parsed = List<List<Atom>?>.filled(frames.length, null);
      final first = XyzParser.parse(frames.first);
      parsed[0] = first;
      final last = frames.length == 1 ? first : XyzParser.parse(frames.last);

      _parsedFrames = parsed;
      _staticBonds = AvogadroBondPerception.perceive(first);
      _reactantFragments = AvogadroBondPerception.fragmentCount(
        first.length,
        _staticBonds,
      );
      final productBonds = AvogadroBondPerception.perceive(last);
      _productFragments = AvogadroBondPerception.fragmentCount(
        last.length,
        productBonds,
      );

      _trajectorySdf = AvogadroSdfWriter.writeTrajectory([
        for (var i = 0; i < frames.length; i++) _atomsAt(i),
      ], _staticBonds);

      _startFrame = 0;
      _endFrame = frames.length - 1;
      _frame = 0;
      _direction = 1;
      _transitionStateFrame = _resolveTransitionStateFrame(frames.length);
    } else if (widget.pdbUrl != null && widget.dcdUrl != null) {
      final framesLen = widget.mdFrameCount ?? 1;
      _parsedFrames = List<List<Atom>?>.filled(framesLen, null);
      _staticBonds = const <PerceivedBond>[];

      _startFrame = 0;
      _endFrame = framesLen - 1;
      _frame = 0;
      _direction = 1;
      _transitionStateFrame = 0;
    } else {
      _startFrame = 0;
      _endFrame = 0;
      _frame = 0;
      _transitionStateFrame = 0;
    }

    _loaded = true;
    _hasLoadedOnce = true;
    _restartTicker();
    _pushStructure(resetView: true);
    if (frames.isNotEmpty) {
      _pushBondLabelsForFrame(0);
    }
  }

  int _resolveTransitionStateFrame(int frameCount) {
    final backend = widget.maxEnergyIndex;
    if (backend != null && backend >= 0 && backend < frameCount) return backend;

    final profile = widget.energyProfile;
    if (profile != null && profile.length == frameCount) {
      var best = 0;
      var bestEnergy = double.negativeInfinity;
      for (var i = 0; i < profile.length; i++) {
        if (profile[i] > bestEnergy) {
          bestEnergy = profile[i];
          best = i;
        }
      }
      return best;
    }
    return frameCount ~/ 2;
  }

  List<Atom> _atomsAt(int frame) {
    if (frame < 0 || frame >= _parsedFrames.length) return const <Atom>[];
    final cached = _parsedFrames[frame];
    if (cached != null) return cached;
    if (widget.trajectoryFrames.isEmpty) return const <Atom>[];
    if (frame >= widget.trajectoryFrames.length) return const <Atom>[];
    final parsed = XyzParser.parse(widget.trajectoryFrames[frame]);
    _parsedFrames[frame] = parsed;
    return parsed;
  }

  // ── Structure push ────────────────────────────────────────────────────────

  NglStyle get _style => NglStyle(displayType: _displayType, palette: _palette);

  void _pushStructure({bool resetView = false}) {
    if (!mounted || _parsedFrames.isEmpty) return;

    final shouldFrame = resetView && !_viewFramed;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final viewer = _viewerKey.currentState;
      if (viewer == null) return;

      if (widget.pdbUrl != null && widget.dcdUrl != null) {
        _viewFramed = true;
        await viewer.loadRemoteMd(
          widget.pdbUrl!,
          widget.dcdUrl!,
          _style,
          resetView: shouldFrame,
        );
        viewer.setFrame(_frame);
        return;
      }

      if (_dynamicBonding) {
        final atoms = _atomsAt(_frame);
        if (atoms.isEmpty) return;
        _viewFramed = true;
        await viewer.loadFrame(
          AvogadroSdfWriter.writeModel(
            atoms,
            AvogadroBondPerception.perceive(atoms),
          ),
          _style,
        );
        return;
      }

      final trajectory = _trajectorySdf;
      if (trajectory == null) return;
      _viewFramed = true;
      await viewer.loadTrajectory(trajectory, _style, resetView: shouldFrame);
      viewer.setFrame(_frame);
    });
  }

  void _pushStyle() {
    if (!mounted) return;
    _viewerKey.currentState?.applyStyle(_style);
  }

  void _syncViewerFrame() {
    if (!mounted) return;
    if (_dynamicBonding && widget.pdbUrl == null) {
      _pushStructure();
      return;
    }
    _viewerKey.currentState?.setFrame(_frame);
  }

  // ── Bond badges ───────────────────────────────────────────────────────────

  void _pushBondLabelsForFrame(int frameIdx) {
    if (!mounted) return;
    if (!_showBondNumbers) {
      _pendingBondLabels = const <BondLabel>[];
      _flushBondLabels();
      return;
    }
    if (frameIdx < 0 || frameIdx >= widget.trajectoryFrames.length) return;

    final atoms = _atomsAt(frameIdx);
    if (atoms.isEmpty) return;

    _pendingBondLabels = bondLabelsForFrame(atoms);
    _flushBondLabels();
  }

  void _flushBondLabels() {
    if (!mounted) return;
    final labels = _pendingBondLabels;
    if (labels == null) return;

    final viewer = _viewerKey.currentState;
    if (viewer == null) {
      if (_labelFlushAttempts++ < 180) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _flushBondLabels());
      }
      return;
    }

    _labelFlushAttempts = 0;
    _pendingBondLabels = null;
    viewer.setBondLabels(labels);
  }

  void _setShowBondNumbers(bool enabled) {
    setState(() => _showBondNumbers = enabled);
    _pushBondLabelsForFrame(_frame);
  }

  // ── Playback ──────────────────────────────────────────────────────────────

  int get _frameCount {
    if (widget.trajectoryFrames.isNotEmpty) {
      return widget.trajectoryFrames.length;
    }
    if (widget.pdbUrl != null && widget.dcdUrl != null) {
      return widget.mdFrameCount ?? 1;
    }
    return 1;
  }

  int get _effectiveFrameRate =>
      _frameRate <= 0 ? ReactionAnimationWidget.defaultFrameRate : _frameRate;

  Duration get _frameInterval {
    final ms = (1000 / _effectiveFrameRate).round();
    return Duration(milliseconds: ms.clamp(1, 60000).toInt());
  }

  int get _span => _endFrame - _startFrame + 1;

  double get _pathT => _frameCount <= 1 ? 0.0 : _frame / (_frameCount - 1);

  void _restartTicker() {
    _ticker?.cancel();
    _ticker = null;
    if (!_playing || _span <= 1) return;
    _ticker = Timer.periodic(_frameInterval, (_) => _tick());
  }

  void _tick() {
    if (!mounted || !_playing) return;
    if (_span <= 1) return;

    var next = _frame + _direction;
    switch (_loopMode) {
      case AnimationLoopMode.forward:
        if (next > _endFrame) next = _startFrame;
        if (next < _startFrame) next = _startFrame;
      case AnimationLoopMode.backward:
        if (next < _startFrame) next = _endFrame;
        if (next > _endFrame) next = _endFrame;
      case AnimationLoopMode.pingpong:
        if (next > _endFrame) {
          _direction = -1;
          next = _endFrame - 1;
        } else if (next < _startFrame) {
          _direction = 1;
          next = _startFrame + 1;
        }
    }
    _showFrame(next);
  }

  void _animate(int advance) {
    if (_span <= 0) return;
    var frame = _frame + advance;
    if (frame < _startFrame || frame > _endFrame) {
      frame = _startFrame + ((frame - _startFrame) % _span + _span) % _span;
    }
    _showFrame(frame);
  }

  void _showFrame(int frame) {
    if (!mounted) return;
    final clamped = frame.clamp(_startFrame, _endFrame);
    if (clamped == _frame) return;
    setState(() => _frame = clamped);
    _syncViewerFrame();
    _pushBondLabelsForFrame(clamped);
  }

  void _jumpTo(int frame) => _showFrame(frame);

  void _play() {
    setState(() => _playing = true);
    _restartTicker();
  }

  void _pause() {
    _ticker?.cancel();
    _ticker = null;
    setState(() => _playing = false);
  }

  void _togglePlay() => _playing ? _pause() : _play();

  // ── Avogadro control handlers ─────────────────────────────────────────────

  void _setStartFrame(int oneBased) {
    final value = (oneBased - 1).clamp(0, _frameCount - 1);
    setState(() {
      _startFrame = value;
      if (_endFrame < _startFrame) _endFrame = _startFrame;
      if (_frame < _startFrame) _frame = _startFrame;
      if (_loopMode == AnimationLoopMode.forward) _direction = 1;
    });
    _restartTicker();
    _syncViewerFrame();
  }

  void _setEndFrame(int oneBased) {
    final value = (oneBased - 1).clamp(0, _frameCount - 1);
    setState(() {
      _endFrame = value;
      if (_startFrame > _endFrame) _startFrame = _endFrame;
      if (_frame > _endFrame) _frame = _endFrame;
    });
    _restartTicker();
    _syncViewerFrame();
  }

  void _setFrameRate(int fps) {
    final clamped = fps.clamp(
      ReactionAnimationWidget.minFrameRate,
      ReactionAnimationWidget.maxFrameRate,
    );
    _fpsUserSet = true;
    if (clamped == _frameRate) return;
    setState(() => _frameRate = clamped);
    _restartTicker();
  }

  void _setDynamicBonding(bool enabled) {
    setState(() => _dynamicBonding = enabled);
    _pushStructure();
  }

  void _setDisplayType(AvogadroDisplayType type) {
    if (type == _displayType) return;
    setState(() => _displayType = type);
    _pushStyle();
  }

  void _setPalette(NglPalette palette) {
    if (palette == _palette) return;
    setState(() => _palette = palette);
    _pushStyle();
  }

  void _setLoopMode(AnimationLoopMode mode) {
    setState(() {
      _loopMode = mode;
      if (mode == AnimationLoopMode.backward) _direction = -1;
      if (mode == AnimationLoopMode.forward) _direction = 1;
    });
    _restartTicker();
  }

  // ── Keyboard ──────────────────────────────────────────────────────────────

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final shift = HardwareKeyboard.instance.isShiftPressed;

    if (event.logicalKey == LogicalKeyboardKey.space) {
      _togglePlay();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _animate(shift ? 10 : 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _animate(shift ? -10 : -1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _jumpTo(_startFrame);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _jumpTo(_endFrame);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _claimKeyboard() {
    if (!_playerFocus.hasFocus) _playerFocus.requestFocus();
  }

  // ── Readout values ────────────────────────────────────────────────────────

  double? get _energyAtFrame {
    final profile = widget.energyProfile;
    if (profile == null || profile.isEmpty) return null;
    return profile[_frame.clamp(0, profile.length - 1)];
  }

  double? get _absoluteEnergyAtFrame {
    final profile = widget.energyProfileEv;
    if (profile == null || profile.isEmpty) return null;
    return profile[_frame.clamp(0, profile.length - 1)];
  }

  double get _progressPercent => _pathT * 100.0;
  double get _cycleSeconds => _span / _effectiveFrameRate;

  String get _phaseName {
    final t = _pathT;
    if (t < _t1) return 'Approach';
    if (t < _t2) return 'Transition State';
    if (t < _t3) return 'Separation';
    return 'Products';
  }

  Color get _phaseColor {
    final t = _pathT;
    if (t < _t1) return const Color(0xFF4FC3F7);
    if (t < _t2) return const Color(0xFFFFAB40);
    if (t < _t3) return const Color(0xFF80DEEA);
    return const Color(0xFF66BB6A);
  }

  double get _phaseProgress {
    final t = _pathT;
    if (t < _t1) return _t1 == 0 ? 1 : t / _t1;
    if (t < _t2) return (t - _t1) / (_t2 - _t1);
    if (t < _t3) return (t - _t2) / (_t3 - _t2);
    return _t3 >= 1 ? 1 : (t - _t3) / (1.0 - _t3);
  }

  IconData get _phaseIcon {
    final t = _pathT;
    if (t < _t1) return Icons.arrow_right_alt;
    if (t < _t2) return Icons.bolt;
    if (t < _t3) return Icons.call_split;
    return Icons.check_circle_outline;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Only show the placeholder before the first successful load.
    //
    // Once the widget has ever had data, it stays on screen through any
    // subsequent reload — during which `_loaded` is false and the parent may
    // momentarily hand us an empty list — rather than unmounting the NGL
    // platform view and re-mounting it a frame later. That unmount/remount
    // cycle is exactly what reads as "the animation flickers in and out".
    if (!_hasLoadedOnce &&
        widget.trajectoryFrames.isEmpty &&
        (widget.pdbUrl == null || widget.dcdUrl == null)) {
      return const AspectRatio(
        aspectRatio: 1.5,
        child: Center(
          child: Text(
            'No trajectory frames to animate',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ),
      );
    }

    return Focus(
      focusNode: _playerFocus,
      onKeyEvent: _onKeyEvent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isUnbounded = constraints.maxHeight.isInfinite;
          return _buildCard(isUnbounded, constraints);
        },
      ),
    );
  }

  Widget _buildCard(bool isUnbounded, BoxConstraints constraints) {
    if (widget.compactMode) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: isUnbounded
              ? _buildCanvasSlotUnbounded(constraints)
              : _buildCanvasSlotBounded(constraints),
        ),
      );
    }

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
          isUnbounded
              ? _buildCanvasSlotUnbounded(constraints)
              : _buildCanvasSlotBounded(constraints),
          if (_showBondEnergies) _buildBondEnergiesPanel(),
          if (_frameCount > 1) ...[
            _buildTimeline(),
            _buildReadout(),
            const Divider(height: 18, thickness: 1, color: Colors.white12),
            _buildPlayerControls(),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildCanvasSlotUnbounded(BoxConstraints constraints) {
    final media = MediaQuery.maybeOf(context);
    final screenH = media?.size.height ?? 800.0;
    final screenW = media?.size.width ?? 1200.0;
    final height = (screenW < 600) ? screenH * 0.40 : screenH * 0.75;
    return SizedBox(
      height: height,
      child: GestureDetector(
        onTap: () {
          _claimKeyboard();
          _togglePlay();
        },
        child: _buildCanvas(),
      ),
    );
  }

  Widget _buildCanvasSlotBounded(BoxConstraints constraints) {
    final media = MediaQuery.maybeOf(context);
    final maxH = math.max(220.0, (media?.size.height ?? 800.0) * 0.50);
    final byRatio =
        constraints.maxWidth.isFinite ? constraints.maxWidth / 1.2 : maxH;
    final height = byRatio.clamp(220.0, maxH);
    return SizedBox(
      height: height,
      child: GestureDetector(
        onTap: () {
          _claimKeyboard();
          _togglePlay();
        },
        child: _buildCanvas(),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _phaseChip(),
          SizedBox(
            width: 120,
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
          _fragmentChip(),
          _displayTypePicker(),
          _palettePicker(),
          _iconButton(
            (_showBondNumbers && _showBondEnergies)
                ? Icons.analytics
                : Icons.analytics_outlined,
            () {
              _claimKeyboard();
              final newState = !(_showBondNumbers && _showBondEnergies);
              setState(() => _showBondEnergies = newState);
              _setShowBondNumbers(newState);
            },
            tooltip: 'Toggle Analysis Overlay (Bond Numbers & Energies)',
            key: const Key('qf-analysis-overlay'),
          ),
          _iconButton(Icons.center_focus_strong, () {
            _claimKeyboard();
            _viewerKey.currentState?.resetView();
          }, tooltip: 'Reset view (fit molecule)'),
        ],
      ),
    );
  }

  Widget _phaseChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: _phaseColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _phaseColor.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_phaseIcon, color: _phaseColor, size: 14),
          const SizedBox(width: 6),
          Text(
            _phaseName,
            style: TextStyle(
              color: _phaseColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fragmentChip() {
    return Tooltip(
      message:
          'Distinct molecules, from the bonds Avogadro\'s perception rule '
          'produces on the first and last frame',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Text(
          '$_reactantFragments R → $_productFragments P',
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
      ),
    );
  }

  Widget _displayTypePicker() {
    return PopupMenuButton<AvogadroDisplayType>(
      key: const Key('qf-display-type'),
      tooltip: 'Display type (Avogadro)',
      color: const Color(0xFF1B1B22),
      onSelected: (type) {
        _claimKeyboard();
        _setDisplayType(type);
      },
      itemBuilder: (context) => [
        for (final type in AvogadroDisplayType.values)
          CheckedPopupMenuItem<AvogadroDisplayType>(
            value: type,
            checked: type == _displayType,
            child: Text(
              type.label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.category_outlined,
              size: 13,
              color: Colors.white54,
            ),
            const SizedBox(width: 6),
            Text(
              _displayType.label,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
            const Icon(Icons.arrow_drop_down, size: 16, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  Widget _palettePicker() {
    return PopupMenuButton<NglPalette>(
      key: const Key('qf-palette'),
      tooltip: 'Element colours',
      color: const Color(0xFF1B1B22),
      onSelected: (palette) {
        _claimKeyboard();
        _setPalette(palette);
      },
      itemBuilder: (context) => [
        for (final palette in NglPalette.values)
          CheckedPopupMenuItem<NglPalette>(
            value: palette,
            checked: palette == _palette,
            child: Text(
              palette.label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.palette_outlined, size: 13, color: Colors.white54),
            const SizedBox(width: 6),
            Text(
              _palette.label,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
            const Icon(Icons.arrow_drop_down, size: 16, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvas() {
    return NglViewer(
      key: _viewerKey,
      width: double.infinity,
      height: double.infinity,
    );
  }

  // ── Phase timeline ────────────────────────────────────────────────────────

  Widget _buildTimeline() {
    final segments = [
      ('Approach', 0.0, _t1, const Color(0xFF4FC3F7)),
      ('Transition State', _t1, _t2, const Color(0xFFFFAB40)),
      ('Separation', _t2, _t3, const Color(0xFF80DEEA)),
      ('Products', _t3, 1.0, const Color(0xFF66BB6A)),
    ];
    final t = _pathT;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Row(
        children: segments.map((segment) {
          final (label, start, end, color) = segment;
          final isActive = t >= start && t < end;
          final isDone = t >= end;
          final segT =
              isActive ? (t - start) / (end - start) : (isDone ? 1.0 : 0.0);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isActive
                          ? color
                          : Colors.white.withValues(alpha: 0.25),
                      fontSize: 9,
                      fontWeight:
                          isActive ? FontWeight.bold : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: segT,
                      minHeight: 4,
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      valueColor: AlwaysStoppedAnimation(
                        color.withValues(alpha: isActive ? 1.0 : 0.25),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Readout ───────────────────────────────────────────────────────────────

  Widget _buildReadout() {
    final energy = _energyAtFrame;
    final absolute = _absoluteEnergyAtFrame;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF4FC3F7).withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF4FC3F7).withValues(alpha: 0.25),
          ),
        ),
        child: Wrap(
          spacing: 18,
          runSpacing: 6,
          children: [
            _infoItem('Frame', '${_frame + 1} / $_frameCount'),
            if (energy != null)
              _infoItem('Energy', '${energy.toStringAsFixed(2)} kcal·mol⁻¹'),
            if (absolute != null)
              _infoItem('MLIP E', '${absolute.toStringAsFixed(4)} eV'),
            _infoItem('Progress', '${_progressPercent.toStringAsFixed(1)}%'),
            _infoItem('Status', _playing ? 'Playing' : 'Stopped'),
            _infoItem('Speed', '$_effectiveFrameRate FPS'),
            _infoItem('Cycle', '${_cycleSeconds.toStringAsFixed(1)} s'),
            _infoItem('Loop', _loopMode.name),
            _infoItem(
              'TS frame',
              '${_transitionStateFrame + 1} / $_frameCount',
            ),
            _infoItem('Bonds', '${_bondsForCurrentFrame().length}'),
          ],
        ),
      ),
    );
  }

  List<PerceivedBond> _bondsForCurrentFrame() {
    if (!_dynamicBonding) return _staticBonds;
    final atoms = _atomsAt(_frame);
    if (atoms.isEmpty) return const <PerceivedBond>[];
    return AvogadroBondPerception.perceive(atoms);
  }

  Widget _infoItem(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 10,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF4FC3F7),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ── Player panel ──────────────────────────────────────────────────────────

  Widget _buildPlayerControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _stepButton('<', 'Step back one frame (←)', () {
                _claimKeyboard();
                _animate(-1);
              }),
              const SizedBox(width: 10),
              Tooltip(
                message:
                    'Keyboard: Space plays and pauses, ← / → step one '
                    'frame, Shift + ← / → step ten, ↑ jumps to Start and ↓ to '
                    'End. Click a control first to give the player focus.',
                child: const Text(
                  'Frame:',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),
              const SizedBox(width: 6),
              _SpinBox(
                key: const Key('qf-frame-spinbox'),
                label: 'Frame',
                value: _frame + 1,
                min: 1,
                max: _frameCount,
                suffix: '/$_frameCount',
                onChanged: (value) {
                  _claimKeyboard();
                  _showFrame(value - 1);
                },
              ),
              const SizedBox(width: 10),
              _stepButton('>', 'Step forward one frame (→)', () {
                _claimKeyboard();
                _animate(1);
              }),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFF4FC3F7),
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                    thumbColor: Colors.white,
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                  ),
                  child: Slider(
                    value: _frame.toDouble(),
                    min: 0,
                    max: (_frameCount - 1).toDouble(),
                    divisions: _frameCount > 1 ? _frameCount - 1 : null,
                    label: '${_frame + 1}',
                    onChanged: (value) => _showFrame(value.round()),
                  ),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Start:',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(width: 6),
              _SpinBox(
                key: const Key('qf-start-spinbox'),
                label: 'Start frame',
                value: _startFrame + 1,
                min: 1,
                max: _frameCount,
                onChanged: _setStartFrame,
              ),
              const SizedBox(width: 18),
              const Text(
                'End:',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(width: 6),
              _SpinBox(
                key: const Key('qf-end-spinbox'),
                label: 'End frame',
                value: _endFrame + 1,
                min: 1,
                max: _frameCount,
                onChanged: _setEndFrame,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: Checkbox(
                  key: const Key('qf-dynamic-bonding'),
                  value: _dynamicBonding,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  activeColor: const Color(0xFF4FC3F7),
                  onChanged: (value) {
                    _claimKeyboard();
                    _setDynamicBonding(value ?? false);
                  },
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Dynamic bonding?',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
              const SizedBox(width: 6),
              Tooltip(
                message:
                    'Re-perceive every bond from the current frame\'s '
                    'coordinates, exactly as Avogadro does: covalent radii plus '
                    'a 0.45 Å tolerance, hydrogen–hydrogen and the noble gases '
                    'excluded. Off, the first frame\'s bonds are reused.',
                child: Icon(
                  Icons.info_outline,
                  size: 13,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Frame rate:',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(width: 6),
              _SpinBox(
                key: const Key('qf-framerate-spinbox'),
                label: 'Frame rate in frames per second',
                value: _frameRate,
                min: ReactionAnimationWidget.minFrameRate,
                max: ReactionAnimationWidget.maxFrameRate,
                onChanged: _setFrameRate,
              ),
              const SizedBox(width: 6),
              Text(
                'FPS',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(Icons.loop, size: 14, color: Colors.white38),
              for (final mode in AnimationLoopMode.values) _loopChip(mode),
              const SizedBox(width: 6),
              FilledButton.icon(
                key: const Key('qf-play-button'),
                onPressed: () {
                  _claimKeyboard();
                  _togglePlay();
                },
                icon: Icon(
                  _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 17,
                ),
                label: Text(_playing ? 'Pause' : 'Play'),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      const Color(0xFF4FC3F7).withValues(alpha: 0.2),
                  foregroundColor: const Color(0xFF4FC3F7),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepButton(String glyph, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: 34,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Text(
            glyph,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ),
      ),
    );
  }

  Widget _loopChip(AnimationLoopMode mode) {
    final active = _loopMode == mode;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        _claimKeyboard();
        _setLoopMode(mode);
      },
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
                : Colors.white.withValues(alpha: 0.12),
          ),
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

  Widget _iconButton(
    IconData icon,
    VoidCallback onTap, {
    String? tooltip,
    Key? key,
  }) {
    Widget child = InkWell(
      key: key,
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

  Widget _buildBondEnergiesPanel() {
    final atoms = _atomsAt(_frame);
    if (atoms.isEmpty) return const SizedBox.shrink();

    final bonds = <_CalculatedBond>[];
    int bondIdx = 1;
    final perceivedBonds = _bondsForCurrentFrame();

    for (int b = 0; b < perceivedBonds.length; b++) {
      final bond = perceivedBonds[b];
      final a1 = atoms[bond.a], a2 = atoms[bond.b];
      final dx = a1.x - a2.x, dy = a1.y - a2.y, dz = a1.z - a2.z;
      final dist = math.sqrt(dx * dx + dy * dy + dz * dz);
      final idealDist = a1.covalentRadius + a2.covalentRadius;
      bonds.add(_CalculatedBond(a1, a2, dist, idealDist, bondIdx++));
    }

    if (bonds.isEmpty) return const SizedBox.shrink();

    final settings = context.watch<QuantumSettingsNotifier>().value;

    double scaleFactor = (settings.temperatureK / 300.0);
    if (settings.solventModel != 'Vacuum') {
      scaleFactor *= 0.85;
    }
    if (settings.mlipModel == 'ANI-2x') scaleFactor *= 1.05;
    final chargeShift = settings.charge * 1.5;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bond Energies',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: bonds.map((b) {
              final energy = 100 *
                      math.exp(-2.0 * (b.dist - b.idealDist)) *
                      scaleFactor +
                  chargeShift;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.orangeAccent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${b.index}',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${b.a1.symbol}–${b.a2.symbol}: '
                    '${energy.toStringAsFixed(1)} kcal·mol⁻¹',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 11,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _CalculatedBond {
  final Atom a1, a2;
  final double dist, idealDist;
  final int index;
  _CalculatedBond(this.a1, this.a2, this.dist, this.idealDist, this.index);
}

// ============================================================================
// Spin box
// ============================================================================

class _SpinBox extends StatefulWidget {
  const _SpinBox({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.label,
    this.suffix,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final String label;
  final String? suffix;

  @override
  State<_SpinBox> createState() => _SpinBoxState();
}

class _SpinBoxState extends State<_SpinBox> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.value}');
    _focusNode = FocusNode(debugLabel: widget.label);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(covariant _SpinBox old) {
    super.didUpdateWidget(old);
    if (!_focusNode.hasFocus && widget.value != old.value) {
      _controller.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _commit() {
    final parsed = int.tryParse(_controller.text.trim());
    final clamped = (parsed ?? widget.value).clamp(widget.min, widget.max);
    _controller.text = '$clamped';
    if (clamped != widget.value) widget.onChanged(clamped);
  }

  void _step(int delta) {
    final next = (widget.value + delta).clamp(widget.min, widget.max);
    _controller.text = '$next';
    if (next != widget.value) widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 46,
          height: 26,
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (_) => _commit(),
            style: const TextStyle(
              color: Color(0xFF4FC3F7),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 6,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFF4FC3F7)),
              ),
            ),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _caret(Icons.arrow_drop_up, 'Increase ${widget.label}', 1),
            _caret(Icons.arrow_drop_down, 'Decrease ${widget.label}', -1),
          ],
        ),
        if (widget.suffix != null)
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(
              widget.suffix!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 10,
              ),
            ),
          ),
      ],
    );
  }

  Widget _caret(IconData icon, String tooltip, int delta) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => _step(delta),
        child: SizedBox(
          width: 15,
          height: 13,
          child: Icon(
            icon,
            size: 15,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}