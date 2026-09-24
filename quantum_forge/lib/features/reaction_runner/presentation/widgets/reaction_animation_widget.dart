// ============================================================================
// ReactionAnimationWidget — Avogadro "Player tool" parity
// ----------------------------------------------------------------------------
// The reaction path is drawn by NGL (WebGL) and driven by this widget, which
// reproduces Avogadro 2's Animation Tool — upstream
// `avogadro/qtplugins/playertool/playertool.cpp` — control for control:
//
//   Avogadro control          | here
//   --------------------------|------------------------------------------------
//   `<` / `>` buttons         | same, and they call Avogadro's `animate(±1)`
//   `Frame:` spinbox `N/M`    | same, 1-based, with the `/<count>` suffix
//   slider (0-based)          | same
//   `Start:` / `End:`         | same, 1-based, and they bound playback
//   `Dynamic bonding?`        | same, default off, re-perceived every frame
//   `Frame rate:` N FPS       | same, default 5, range 0..1000
//   `Play` / `Pause`          | same label swap
//   Space / ← → / Shift+← →   | same, plus ↑ = Start and ↓ = End
//
// Three behaviours are worth stating explicitly because they are easy to get
// subtly wrong, and each was verified against the upstream source rather than
// guessed:
//
//   1. **Frames are discrete.** `PlayerTool::setFrame` calls
//      `Molecule::setCoordinate3d`, which replaces the whole position array.
//      There is no interpolation anywhere in the plugin, so neither is there
//      here — an NEB image is a computed geometry and blending two of them would
//      draw a structure that no calculation produced.
//   2. **Playback loops unconditionally, within `[Start, End]`.** Avogadro has
//      no loop checkbox; `animate()` wraps with
//      `first + ((frame - first) % span + span) % span`. That is exactly the
//      default here. The loop-mode chips are a Quantum Forge extension on top
//      (kept from the earlier ColabReaction-parity work); `forward` is
//      Avogadro's behaviour, and the other two are opt-in.
//   3. **`Frame rate: 0` means 5 FPS**, not "as fast as possible" — Avogadro
//      does `if (fps < 0.00001) fps = 5;`.
//
// The one deliberate deviation is autoplay, carried over from the previous
// release: Avogadro's panel starts stopped and waits for Play, but a static
// molecule in a scrolling results page reads as a broken widget. The Play/Pause
// button is the first thing in the Avogadro control group either way.
//
// Geometry is Avogadro's, not NGL's — see `ngl/avogadro_geometry.dart` for why
// NGL's own representations cannot express Avogadro's radii, and what that file
// does instead.
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
///
/// Avogadro's player has no such control — it always wraps forwards over
/// `[Start, End]`, which is [forward] here. [backward] and [pingpong] are
/// Quantum Forge extensions kept from the earlier ColabReaction-parity work.
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
  });

  /// One XYZ document per trajectory image, in path order.
  final List<String> trajectoryFrames;

  /// Relative energies in kcal/mol, one per frame.
  final List<double>? energyProfile;

  /// Absolute UMA potential energies in eV, one per frame.
  final List<double>? energyProfileEv;

  /// Highest-energy image index from the backend, 0-based.
  final int? maxEnergyIndex;

  /// Starting frame rate in FPS, overriding Avogadro's default of 5.
  final int? frameRateOverride;

  /// Display type to start in. Avogadro's own default is Ball and Stick.
  final AvogadroDisplayType displayType;

  /// Whether to start with `Dynamic bonding?` ticked.
  ///
  /// Avogadro's Player tool ships it unchecked (`m_dynamicBonding->setChecked(
  /// false)`), which is the default here. Exposed so an embedding can start in
  /// the mode it needs — and so the browser harness can exercise the
  /// re-perception path end to end without synthesising a click.
  final bool dynamicBonding;

  /// Whether to start with bond-number badges drawn on the structure.
  ///
  /// Off by default: a figure usually wants the structure clean, and the numbers
  /// are a working aid for cross-referencing a bond. Exposed so an embedding (and
  /// the browser harness) can start with them on.
  final bool showBondNumbers;

  /// Avogadro's `m_animationFPS` default: `setValue(5)`.
  static const int defaultFrameRate = 5;

  /// Avogadro's `m_animationFPS` minimum: `setMinimum(0)`. Zero is remapped to
  /// [defaultFrameRate] rather than meaning "unbounded".
  static const int minFrameRate = 0;

  /// Avogadro's `m_animationFPS` maximum: `setMaximum(1000)`.
  static const int maxFrameRate = 1000;

  @override
  State<ReactionAnimationWidget> createState() =>
      _ReactionAnimationWidgetState();
}

class _ReactionAnimationWidgetState extends State<ReactionAnimationWidget> {
  final GlobalKey<NglViewerState> _viewerKey = GlobalKey<NglViewerState>();
  final FocusNode _playerFocus = FocusNode(debugLabel: 'reaction-player');

  // ── Trajectory ────────────────────────────────────────────────────────────
  List<List<Atom>?> _parsedFrames = const <List<Atom>?>[];

  /// Bonds perceived from the first frame, reused for every frame while
  /// `Dynamic bonding?` is off — which is what Avogadro does: it perceives bonds
  /// once when the coordinate sets are read, and only re-perceives them per
  /// frame when the checkbox is ticked.
  List<PerceivedBond> _staticBonds = const <PerceivedBond>[];

  /// The whole path as one multi-model SDF, rebuilt whenever the frames change.
  ///
  /// Built once per trajectory rather than per frame: NGL scrubs between its
  /// models, so 40 images cost one parse instead of 40.
  String? _trajectorySdf;

  int _reactantFragments = 0;
  int _productFragments = 0;

  /// Frame index of the transition state, 0-based, from the backend when it
  /// supplies one and otherwise from the maximum of the relative profile.
  int _transitionStateFrame = 0;

  // ── Playback (Avogadro's PlayerTool state) ────────────────────────────────
  int _frame = 0; // `m_currentFrame`, 0-based
  int _startFrame = 0; // `m_firstFrameIdx->value() - 1`
  int _endFrame = 0; // `m_lastFrameIdx->value() - 1`
  int _frameRate = ReactionAnimationWidget.defaultFrameRate;
  bool _dynamicBonding = false; // `m_dynamicBonding->setChecked(false)`
  bool _playing = true; // deviation: Avogadro starts stopped
  bool _fpsUserSet = false;

  Timer? _ticker;
  int _direction = 1;
  AnimationLoopMode _loopMode = AnimationLoopMode.forward;
  AvogadroDisplayType _displayType = AvogadroDisplayType.ballAndStick;

  /// Element palette. Avogadro's own table is the default; the Jmol/CPK table
  /// NGL calls `'element'` is selectable so the two can be compared side by side
  /// on the same structure.
  NglPalette _palette = NglPalette.avogadro;

  /// Whether numbered bond badges are drawn on the 3D structure.
  ///
  /// Off by default: a figure for a paper or a thesis usually wants the structure
  /// clean, and numbers are a working aid for cross-referencing a bond table.
  bool _showBondNumbers = true;

  /// Whether to show the bond energies panel.
  bool _showBondEnergies = true;

  /// Badge labels waiting for the viewer's platform view to exist.
  List<BondLabel>? _pendingBondLabels;
  int _labelFlushAttempts = 0;

  bool _loaded = false;
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

    final framesChanged = !identical(
      old.trajectoryFrames,
      widget.trajectoryFrames,
    );
    if (framesChanged) {
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
      // Parse the first frame eagerly: it fixes the bond set that every later
      // frame reuses when dynamic bonding is off, and it is what the first
      // paint shows. Remaining frames are parsed lazily on first display, so a
      // long path does not block the first build.
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

      // The whole path as one multi-model SDF, so NGL scrubs between images
      // instead of re-parsing one per frame. Connectivity comes from the first
      // image, which is NGL's `asTrajectory` contract; the dynamic-bonding path
      // bypasses this entirely.
      _trajectorySdf = AvogadroSdfWriter.writeTrajectory([
        for (var i = 0; i < frames.length; i++) _atomsAt(i),
      ], _staticBonds);

      _startFrame = 0;
      _endFrame = frames.length - 1;
      _frame = 0;
      _direction = 1;
      _transitionStateFrame = _resolveTransitionStateFrame(frames.length);
    } else {
      _startFrame = 0;
      _endFrame = 0;
      _frame = 0;
      _transitionStateFrame = 0;
    }

    _loaded = true;
    _restartTicker();
    _pushStructure(resetView: true);
    _pushBondLabelsForFrame(0);
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
    final parsed = XyzParser.parse(widget.trajectoryFrames[frame]);
    _parsedFrames[frame] = parsed;
    return parsed;
  }

  // ── Structure push ────────────────────────────────────────────────────────

  /// The style the renderer is currently drawing with.
  NglStyle get _style => NglStyle(displayType: _displayType, palette: _palette);

  /// Sends the current path to the viewer.
  ///
  /// Two paths, because NGL's trajectory mode takes connectivity from the first
  /// model and nothing else can express a bond set that changes:
  ///
  ///  * **Dynamic bonding off** — one multi-model SDF is loaded once and frames
  ///    are scrubbed with `trajList[0].setFrame(n)`. This is the cheap path and
  ///    the one the spec's `loadTrajectory` was reaching for.
  ///  * **Dynamic bonding on** — Avogadro re-perceives every bond from each
  ///    frame's coordinates, so the bond block differs per frame and the whole
  ///    model is re-sent. That costs a parse per frame; at Avogadro's 5 FPS
  ///    default it is not a problem, and at extreme frame rates it is the price
  ///    of correct chemistry.
  void _pushStructure({bool resetView = false}) {
    if (!mounted || _parsedFrames.isEmpty) return;

    // Only the first frame of a trajectory is allowed to move the camera.
    final shouldFrame = resetView && !_viewFramed;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final viewer = _viewerKey.currentState;
      if (viewer == null) return;

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

  /// Applies a style change without re-sending the coordinates where possible.
  void _pushStyle() {
    if (!mounted) return;
    // A representation change is enough for a palette or display-type switch:
    // the structure on the GPU is unchanged, so nothing needs re-parsing.
    _viewerKey.currentState?.applyStyle(_style);
  }

  /// Moves the viewer to [_frame].
  void _syncViewerFrame() {
    if (!mounted) return;
    if (_dynamicBonding) {
      _pushStructure();
      return;
    }
    _viewerKey.currentState?.setFrame(_frame);
  }

  // ── Bond badges ───────────────────────────────────────────────────────────

  /// Builds numbered badges for [frameIdx] and hands them to the viewer.
  ///
  /// The numbering comes from [AvogadroBondPerception] — the *same* perception
  /// that writes the SDF bond block, and therefore the same bonds the viewer is
  /// drawing. That is the only referent that makes a number meaningful: a badge
  /// on a pair that is not drawn, or a drawn bond with no badge, leaves the
  /// reader counting something that is not on screen.
  ///
  /// Numbering is 1-based in (i, j) index order over the atom list, so it is
  /// stable for a given frame and reproducible.
  ///
  /// The labels are held here first and flushed once the platform view exists.
  /// `initState` pushes frame 0's badges, and at that moment the viewer's state
  /// does not exist yet, so a direct `_viewerKey.currentState?.` call would be
  /// silently swallowed by the null-aware operator — badges would simply never
  /// appear, with nothing logged.
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

  /// Hands the held badge labels to the viewer, retrying until it exists.
  void _flushBondLabels() {
    if (!mounted) return;
    final labels = _pendingBondLabels;
    if (labels == null) return;

    final viewer = _viewerKey.currentState;
    if (viewer == null) {
      // Bounded: an unattached viewer after ~3 s of frames is a collapsed or
      // off-screen subtree, and retrying forever would be a quiet leak.
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

  int get _frameCount =>
      widget.trajectoryFrames.isEmpty ? 1 : widget.trajectoryFrames.length;

  /// Avogadro's effective frame rate: `if (fps < 0.00001) fps = 5;`
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

  /// One playback step, honouring the loop mode.
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

  /// Avogadro's `animate(advance)`.
  ///
  /// The wrap is `first + ((frame - first) % span + span) % span`, which is what
  /// makes `<` at the start of the range land on `End` and `>` at the end land
  /// on `Start`. Shift+arrow uses the same function with ±10.
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
      // `firstFramePositionChanged` raises the frame spinbox's minimum; the
      // current frame follows so the range is never inconsistent.
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
    // The bond set itself changes, so this is not a representation swap: NGL's
    // trajectory mode takes connectivity from its first model and cannot be
    // re-perceived, which is why this switches between two loading paths.
    _pushStructure();
  }

  void _setDisplayType(AvogadroDisplayType type) {
    if (type == _displayType) return;
    setState(() => _displayType = type);
    // The structure on the GPU is unchanged, so only the representation needs
    // replacing — no re-parse, no camera movement.
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

  // ── Keyboard (Avogadro's PlayerTool::keyPressEvent) ───────────────────────

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

  /// Gives the panel keyboard focus, so the shortcuts above apply.
  ///
  /// Bound to the transport controls rather than autofocused: an autofocused
  /// card deep in a scrolling dashboard would swallow the arrow keys the reader
  /// is using to scroll it.
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
    if (!_loaded || widget.trajectoryFrames.isEmpty) {
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

    // The card's natural height (header + 3D canvas + bond panel + timeline +
    // readout + transport controls) is often taller than the slot a caller
    // gives it — a 1228 px-wide viewport can easily produce >1000 px of
    // content. Wrapping in a scroll view turns the caller's
    // `BoxConstraints(maxHeight: …)` into a scrollable viewport rather than a
    // hard ceiling, so nothing overflows no matter how small the slot is.
    return Focus(
      focusNode: _playerFocus,
      onKeyEvent: _onKeyEvent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isUnbounded = constraints.maxHeight.isInfinite;
          final card = _buildCard(isUnbounded, constraints);
          
          if (isUnbounded) {
            return SingleChildScrollView(
              primary: false,
              child: card,
            );
          } else {
            return card;
          }
        },
      ),
    );
  }

  Widget _buildCard(bool isUnbounded, BoxConstraints constraints) {
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
              : Expanded(child: _buildCanvasSlotBounded()),
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

  /// Bounds the 3D canvas to a sane height on wide viewports.
  ///
  /// A fixed `AspectRatio(1.2)` gives the canvas a height of
  /// `width / 1.2` — 1022 px at a 1228 px viewport, which alone exceeds the
  /// whole card's slot. We keep the 1.2 ratio on narrow screens (so phones
  /// still look right), but clamp the height to `[220, 420]` so desktop
  /// layouts do not blow up. The outer scroll view handles any residual
  /// overflow past the clamp.
  Widget _buildCanvasSlotUnbounded(BoxConstraints constraints) {
    final maxH = MediaQuery.of(context).size.height * 0.75;
    final byRatio = constraints.maxWidth.isFinite
        ? constraints.maxWidth / 1.2
        : maxH;
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

  Widget _buildCanvasSlotBounded() {
    return GestureDetector(
      onTap: () {
        _claimKeyboard();
        _togglePlay();
      },
      child: _buildCanvas(),
    );
  }

  // ── Header: phase, fragment counts, display type, reset view ──────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Wrap(
        spacing: 10,
        runSpacing: 6,
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
            (_showBondNumbers && _showBondEnergies) ? Icons.analytics : Icons.analytics_outlined,
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

  // ── 3D canvas ─────────────────────────────────────────────────────────────

  /// Element-colour palette picker.
  ///
  /// Both tables are CPK in the everyday sense — element to conventional colour
  /// — but they are not the same table, and the difference lands on carbon,
  /// which is in nearly every organic molecule. Avogadro's own header explains
  /// why: hydrogen is not pure white, carbon is 50 % grey (`#7F7F7F`), and
  /// fluorine is bluer, all three chosen so figures read on light and dark
  /// backgrounds and so F does not collide with Cl. NGL's built-in `element`
  /// scheme is the Jmol table, which is what most web viewers show. Offering
  /// both makes the comparison a click instead of an argument.
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
          final segT = isActive
              ? (t - start) / (end - start)
              : (isDone ? 1.0 : 0.0);
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
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.normal,
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
              _infoItem('UMA E', '${absolute.toStringAsFixed(4)} eV'),
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

  /// The bonds the current frame is drawn with.
  ///
  /// Recomputed when dynamic bonding is on, so the count in the readout always
  /// describes the picture rather than a stale first frame.
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

  // ── Avogadro's Player panel ───────────────────────────────────────────────

  Widget _buildPlayerControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row 1 — `<`  Frame: [N/M]  `>`
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

          // Row 2 — the frame slider.
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

          // Row 3 — Start / End, which bound playback.
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

          // Row 4 — Dynamic bonding?
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

          // Row 5 — Frame rate: [N] FPS
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

          // Row 6 — loop mode extension + Play / Pause.
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
                  backgroundColor: const Color(
                    0xFF4FC3F7,
                  ).withValues(alpha: 0.2),
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

  Widget _iconButton(IconData icon, VoidCallback onTap,
      {String? tooltip, Key? key}) {
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
    final chargeShift = (settings.charge ?? 0) * 1.5;

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
// ----------------------------------------------------------------------------
// Flutter has no `QSpinBox`. This is the closest equivalent: a small numeric
// field with caret buttons either side of it, matching what Avogadro's controls
// actually look like and, more importantly, behaving the same way — typing a
// value commits it, out-of-range input is clamped rather than rejected, and the
// external value wins whenever the field is not being edited.
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

  /// Accessible name; also the tooltip subject.
  final String label;

  /// Optional trailing text drawn beside the field, e.g. `/25`.
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
    // Commit on blur as well as on submit, so clicking away does not silently
    // discard an edit.
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(covariant _SpinBox old) {
    super.didUpdateWidget(old);
    // Only overwrite the field when it is not being typed into, or the caret
    // would jump on every rebuild.
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