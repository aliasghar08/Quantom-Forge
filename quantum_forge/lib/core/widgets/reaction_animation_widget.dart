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

import 'package:flutter/foundation.dart';
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

part 'reaction_animation_header.dart';
part 'reaction_animation_canvas.dart';
part 'reaction_animation_timeline.dart';
part 'reaction_animation_readout.dart';
part 'reaction_animation_player.dart';
part 'reaction_animation_bond_energies.dart';
part 'reaction_animation_spinbox.dart';
part 'reaction_animation_state_core.dart';
part 'reaction_animation_state_playback.dart';
part 'reaction_animation_state_computed.dart';
part 'reaction_animation_state_components.dart';


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
    this.compactMode = false,
    this.pdbUrl,
    this.dcdUrl,
    this.mdFrameCount,
  });

  /// One XYZ document per trajectory image, in path order.
  final List<String> trajectoryFrames;

  /// Whether to render in compact mode (only the 3D canvas, no toolbars).
  final bool compactMode;

  /// Relative energies in kcal/mol, one per frame.
  final List<double>? energyProfile;

  /// Absolute MLIP potential energies in eV, one per frame.
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

  /// Optional remote PDB topology for MD.
  final String? pdbUrl;

  /// Optional remote DCD trajectory for MD.
  final String? dcdUrl;

  /// Number of frames in the remote MD trajectory.
  final int? mdFrameCount;

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
  // ═══════════════════════════════════════════════════════════════════════
  // QA counters
  // ─────────────────────────────────────────────────────────────────────
  // All counters are static, so they accumulate across instances. If
  // `initCount` goes above 1 for a single logical animation, the widget is
  // being destroyed and recreated by a parent — which unmounts the NGL
  // platform view and is the root cause of "appears and disappears".
  //
  // `reloadCount` counts `_load()` invocations. If it goes above 1 without
  // the trajectory actually changing, the equality check in
  // `didUpdateWidget` is being bypassed.
  //
  // `_instanceId` is unique per State instance, so a log line can be
  // attributed to the specific mount that emitted it.
  // ═══════════════════════════════════════════════════════════════════════
  static int buildCount = 0;
  static int reloadCount = 0;
  static int initCount = 0;
  static int disposeCount = 0;
  static int didUpdateCount = 0;

  late final int _instanceId;

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

  // ═══════════════════════════════════════════════════════════════════════
  // Lifecycle
  // ═══════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    initCount++;
    _instanceId = initCount;
    if (kDebugMode) {
      debugPrint(
        '[QA] anim.initState  instance=#$_instanceId  '
        'initCount=$initCount  disposeCount=$disposeCount  '
        'frames=${widget.trajectoryFrames.length}  '
        'pdbUrl=${widget.pdbUrl != null}  '
        'dcdUrl=${widget.dcdUrl != null}  '
        'compact=${widget.compactMode}',
      );
    }

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
    disposeCount++;
    if (kDebugMode) {
      debugPrint(
        '[QA] anim.dispose    instance=#$_instanceId  '
        'disposeCount=$disposeCount  '
        'buildCount=$buildCount  reloadCount=$reloadCount',
      );
    }
    _ticker?.cancel();
    _playerFocus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ReactionAnimationWidget old) {
    super.didUpdateWidget(old);
    didUpdateCount++;

    final framesIdentical =
        identical(old.trajectoryFrames, widget.trajectoryFrames);
    final framesSameLength =
        old.trajectoryFrames.length == widget.trajectoryFrames.length;
    final sameFirstFrame = old.trajectoryFrames.isNotEmpty &&
        widget.trajectoryFrames.isNotEmpty &&
        old.trajectoryFrames.first == widget.trajectoryFrames.first;
    final sameLastFrame = old.trajectoryFrames.isNotEmpty &&
        widget.trajectoryFrames.isNotEmpty &&
        old.trajectoryFrames.last == widget.trajectoryFrames.last;

    final pdbChanged = old.pdbUrl != widget.pdbUrl;
    final dcdChanged = old.dcdUrl != widget.dcdUrl;
    final mdFrameCountChanged = old.mdFrameCount != widget.mdFrameCount;
    final displayTypeChanged = old.displayType != widget.displayType;
    final dynamicBondingChanged = old.dynamicBonding != widget.dynamicBonding;
    final showBondNumbersChanged =
        old.showBondNumbers != widget.showBondNumbers;
    final compactModeChanged = old.compactMode != widget.compactMode;
    final frameRateOverrideChanged =
        old.frameRateOverride != widget.frameRateOverride;
    final energyProfileChanged =
        !identical(old.energyProfile, widget.energyProfile);
    final maxEnergyIndexChanged =
        old.maxEnergyIndex != widget.maxEnergyIndex;

    if (kDebugMode) {
      debugPrint(
        '[QA] anim.didUpdateWidget  instance=#$_instanceId  '
        '#$didUpdateCount  '
        'framesIdentical=$framesIdentical  '
        'sameLen=$framesSameLength  '
        'firstFrameSame=$sameFirstFrame  lastFrameSame=$sameLastFrame  '
        'old.len=${old.trajectoryFrames.length}  '
        'new.len=${widget.trajectoryFrames.length}  '
        'pdbChanged=$pdbChanged  dcdChanged=$dcdChanged  '
        'mdFrameCountChanged=$mdFrameCountChanged  '
        'displayTypeChanged=$displayTypeChanged  '
        'dynamicBondingChanged=$dynamicBondingChanged  '
        'showBondNumbersChanged=$showBondNumbersChanged  '
        'compactModeChanged=$compactModeChanged  '
        'frameRateOverrideChanged=$frameRateOverrideChanged  '
        'energyProfileChanged=$energyProfileChanged  '
        'maxEnergyIndexChanged=$maxEnergyIndexChanged',
      );
    }

    // Current behaviour uses identity, which is over-eager: a parent that
    // rebuilds the frame list on every tick will trigger a reload every tick.
    // The diagnostic above prints enough to identify whether that is happening.
    final framesChanged =
        !identical(old.trajectoryFrames, widget.trajectoryFrames);
    if (framesChanged) {
      if (kDebugMode) {
        debugPrint(
          '[QA] anim.didUpdateWidget -> framesChanged=true, '
          'calling _load()  instance=#$_instanceId  '
          'reloadCount_before=$reloadCount',
        );
      }
      _load();
      return;
    }

    if (old.frameRateOverride != widget.frameRateOverride &&
        widget.frameRateOverride != null &&
        !_fpsUserSet) {
      if (kDebugMode) {
        debugPrint(
          '[QA] anim.didUpdateWidget -> frameRateOverride changed, '
          'restarting ticker  instance=#$_instanceId',
        );
      }
      setState(() {
        _frameRate = widget.frameRateOverride!.clamp(
          ReactionAnimationWidget.minFrameRate,
          ReactionAnimationWidget.maxFrameRate,
        );
      });
      _restartTicker();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    buildCount++;
    if (kDebugMode) {
      debugPrint(
        '[QA] anim.build  instance=#$_instanceId  '
        'buildCount=$buildCount  reloadCount=$reloadCount  '
        '_loaded=$_loaded  '
        'frames=${widget.trajectoryFrames.length}  '
        'frame=$_frame  '
        'playing=$_playing  '
        'ticker=${_ticker != null}',
      );
    }

    if (!_loaded || widget.trajectoryFrames.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          '[QA] anim.build -> PLACEHOLDER branch  '
          'instance=#$_instanceId  '
          '_loaded=$_loaded  framesEmpty=${widget.trajectoryFrames.isEmpty}  '
          'pdbUrlNull=${widget.pdbUrl == null}  '
          'dcdUrlNull=${widget.dcdUrl == null}',
        );
      }
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
          if (kDebugMode) {
            debugPrint(
              '[QA] anim.LayoutBuilder  instance=#$_instanceId  '
              'maxW=${constraints.maxWidth}  maxH=${constraints.maxHeight}  '
              'isUnbounded=$isUnbounded',
            );
          }
          return _buildCard(isUnbounded, constraints);
        },
      ),
    );
  }

  Widget _buildCard(bool isUnbounded, BoxConstraints constraints) {
    if (kDebugMode) {
      debugPrint(
        '[QA] anim._buildCard  instance=#$_instanceId  '
        'isUnbounded=$isUnbounded  '
        'compactMode=${widget.compactMode}  '
        'showBondEnergies=$_showBondEnergies  '
        'frameCount=$_frameCount  '
        'calling _buildCanvasSlot{Unbounded|Bounded} and '
        '_buildHeader/_buildBondEnergiesPanel/_buildTimeline/'
        '_buildReadout/_buildPlayerControls',
      );
    }

    if (widget.compactMode) {
      if (kDebugMode) {
        debugPrint(
          '[QA] anim._buildCard -> COMPACT branch  instance=#$_instanceId',
        );
      }
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

    if (kDebugMode) {
      debugPrint(
        '[QA] anim._buildCard -> FULL branch  instance=#$_instanceId  '
        'canvasSlot=${isUnbounded ? "Unbounded" : "Bounded"}',
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

  /// Bounds the 3D canvas to a sane height on wide viewports.
  ///
  /// A fixed `AspectRatio(1.2)` gives the canvas a height of
  /// `width / 1.2` — 1022 px at a 1228 px viewport, which alone exceeds the
  /// whole card's slot. We keep the 1.2 ratio on narrow screens (so phones
  /// still look right), but clamp the height to `[220, 420]` so desktop
  /// layouts do not blow up. The outer scroll view handles any residual
  /// overflow past the clamp.
  
  // ── Header: phase, fragment counts, display type, reset view ──────────────
  
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
  
  // ── Phase timeline ────────────────────────────────────────────────────────
  
  // ── Readout ───────────────────────────────────────────────────────────────

  /// The bonds the current frame is drawn with.
  ///
  /// Recomputed when dynamic bonding is on, so the count in the readout always
  /// describes the picture rather than a stale first frame.
  
  // ── Avogadro's Player panel ───────────────────────────────────────────────
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