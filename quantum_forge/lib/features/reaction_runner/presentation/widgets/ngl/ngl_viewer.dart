// ============================================================================
// NglViewer — the 3D surface of the reaction animation
// ----------------------------------------------------------------------------
// A thin, platform-neutral shell around `NglEngine`. It owns no WebGL and no
// JavaScript: it renders an `HtmlElementView` when the engine is available, an
// explanatory panel when it is not, and exposes the structure-loading calls the
// animation widget needs.
//
// Structures are handed over as **SDF text**, not XYZ, because NGL cannot parse
// XYZ — see `avogadro_sdf.dart` for the evidence. Coordinates and bonds are
// produced in Dart, so this layer only moves strings.
//
// The camera is deliberately sticky. Loading a new structure leaves the viewer's
// orientation and zoom untouched, so a researcher who has orbited to look down a
// forming bond keeps that view for the whole trajectory, and stepping frames
// never re-frames. Only an explicit `resetView` moves the camera.
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';

import 'ngl_axes_triad.dart';
import 'ngl_bond_label.dart';

// Re-exported so callers importing the viewer get the label type with it.
export 'ngl_bond_label.dart' show BondLabel;
import 'ngl_engine.dart';
import 'ngl_style.dart';

class NglViewer extends StatefulWidget {
  const NglViewer({
    super.key,
    this.width = double.infinity,
    this.height = double.infinity,
    this.showAxesTriad = true,
  });

  final double width;
  final double height;

  /// Whether to draw the x/y/z orientation triad in the corner.
  ///
  /// NGL 2.5.0 has no orientation widget of its own — `setParameters({axes:
  /// true})` is ignored, `NGL.Axes` is undefined, and no viewer property
  /// appears — so the triad is drawn in Flutter on top of the canvas and kept in
  /// step by polling the viewer's orientation. See [NglAxesTriad].
  final bool showAxesTriad;

  @override
  State<NglViewer> createState() => NglViewerState();
}

class NglViewerState extends State<NglViewer> {
  NglEngine? _engine;

  /// A load issued before the platform view existed, replayed on attach.
  _QueuedStructure? _queued;

  /// The viewer orientation last read, fed to the triad overlay.
  List<double>? _orientation;

  /// Badge labels requested before the platform view existed.
  ///
  /// Badges are pushed from the animation widget's `initState`, which always runs
  /// before the browser has created the platform view, so this cannot be a
  /// fire-and-forget call — without the queue the very first badge push is
  /// silently dropped and the badges never appear at all.
  List<BondLabel>? _queuedLabels;

  Timer? _orientationPoll;

  /// True once an engine has been adopted for this widget's platform view.
  bool get isAttached => _engine != null;

  @override
  void initState() {
    super.initState();
    // Idempotent, and required before the first `HtmlElementView` is built.
    NglEngine.ensureViewFactory();
    if (widget.showAxesTriad) _startOrientationPoll();
  }

  @override
  void dispose() {
    _orientationPoll?.cancel();
    _engine?.dispose();
    _engine = null;
    super.dispose();
  }

  /// Polls the camera orientation so the triad can follow a drag.
  ///
  /// A poll rather than an event because NGL does not expose an orientation
  /// change signal, and because the rotation is driven by the browser's own
  /// pointer handling inside the canvas — Flutter never sees those events, so
  /// there is nothing to listen to. 33 ms is one frame at ~30 Hz: fast enough
  /// that the triad tracks the molecule, cheap enough that reading 16 doubles
  /// and repainting a 72 px box is not measurable next to the WebGL render.
  void _startOrientationPoll() {
    _orientationPoll?.cancel();
    _orientationPoll = Timer.periodic(
      const Duration(milliseconds: 33),
      (_) => _refreshOrientation(),
    );
  }

  void _refreshOrientation() {
    if (!mounted) return;
    final next = _engine?.cameraOrientation();
    if (next == null) return;
    final previous = _orientation;
    if (previous != null && _sameOrientation(previous, next)) return;
    setState(() => _orientation = next);
  }

  static bool _sameOrientation(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // ── Structure loading ─────────────────────────────────────────────────────

  /// Loads a multi-model SDF trajectory once, ready for frame scrubbing.
  ///
  /// Safe to call before the platform view exists; the load is replayed on
  /// attach. Use this when the bond set is constant across the path, since NGL
  /// takes connectivity from the first model.
  Future<void> loadTrajectory(
    String sdf,
    NglStyle style, {
    bool resetView = true,
  }) async {
    final engine = _engine;
    if (engine == null) {
      _queued = _QueuedStructure(
        sdf,
        style,
        asTrajectory: true,
        resetView: resetView,
      );
      return;
    }
    await engine.loadTrajectory(sdf, style, resetView: resetView);
  }

  /// Loads an MD simulation natively using remote URLs for topology and trajectory.
  Future<void> loadRemoteMd(
    String pdbUrl,
    String dcdUrl,
    NglStyle style, {
    bool resetView = true,
  }) async {
    final engine = _engine;
    if (engine == null) {
      _queued = _QueuedStructure.md(
        pdbUrl,
        dcdUrl,
        style,
        resetView: resetView,
      );
      return;
    }
    await engine.loadRemoteMd(pdbUrl, dcdUrl, style, resetView: resetView);
  }

  /// Loads a single-model SDF, replacing the previous structure.
  ///
  /// This is the dynamic-bonding path: the bond block changes per frame, so the
  /// whole structure is re-sent rather than a frame being selected.
  Future<void> loadFrame(String sdf, NglStyle style) async {
    final engine = _engine;
    if (engine == null) {
      _queued = _QueuedStructure(
        sdf,
        style,
        asTrajectory: false,
        resetView: false,
      );
      return;
    }
    await engine.loadFrame(sdf, style);
  }

  /// Moves a loaded trajectory to an absolute 0-based frame.
  void setFrame(int frame) => _engine?.setFrame(frame);

  /// Rebuilds the representation after a display-type or palette change.
  void applyStyle(NglStyle style) => _engine?.applyStyle(style);

  /// Draws numbered badges at bond midpoints, or clears them when [labels] is
  /// empty.
  void setBondLabels(List<BondLabel> labels) {
    final engine = _engine;
    if (engine == null) {
      // Called before the platform view exists; replayed on attach.
      _queuedLabels = labels;
      return;
    }
    engine.setBondLabels(labels);
  }

  /// Fits the camera to the structure currently on screen.
  void resetView() => _engine?.resetView();

  /// Re-measures the canvas, for callers that know the layout changed.
  void handleResize() => _engine?.handleResize();

  /// The viewer's orientation, for a Flutter-drawn axes triad.
  ///
  /// Returns null when no stage exists or the value is unusable, so callers can
  /// skip a paint rather than guard every field.
  List<double>? cameraOrientation() => _engine?.cameraOrientation();

  void _onPlatformViewCreated(int viewId) {
    final engine = NglEngine.forView(viewId);
    if (engine == null) return;

    final previous = _engine;
    if (previous != null && !identical(previous, engine)) {
      // A replacement view: the previous stage's element is gone with it.
      previous.dispose();
    }
    _engine = engine;

    final queued = _queued;
    _queued = null;
    if (queued != null) {
      if (queued.sdf != null) {
        if (queued.asTrajectory) {
          engine.loadTrajectory(
            queued.sdf!,
            queued.style,
            resetView: queued.resetView,
          );
        } else {
          engine.loadFrame(queued.sdf!, queued.style);
        }
      } else if (queued.pdbUrl != null && queued.dcdUrl != null) {
        engine.loadRemoteMd(
          queued.pdbUrl!,
          queued.dcdUrl!,
          queued.style,
          resetView: queued.resetView,
        );
      }
    }

    final labels = _queuedLabels;
    _queuedLabels = null;
    if (labels != null) engine.setBondLabels(labels);
  }

  @override
  Widget build(BuildContext context) {
    if (!NglEngine.isSupported) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const _UnsupportedNotice(),
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        children: [
          Positioned.fill(
            child: HtmlElementView(
              viewType: NglEngine.viewType,
              onPlatformViewCreated: _onPlatformViewCreated,
            ),
          ),
          if (widget.showAxesTriad)
            // Positioned, not centred: `NglAxesTriad` asks for a square box via
            // SizedBox, so inside a plain Stack it would be stretched by the
            // stack's tight constraints.
            Positioned(
              right: 8,
              bottom: 8,
              child: IgnorePointer(
                // The triad is an indicator. Letting it absorb pointers would
                // steal drags from the camera right where orbit gestures are
                // most likely to end.
                child: NglAxesTriad(orientation: _orientation),
              ),
            ),
        ],
      ),
    );
  }
}

/// A structure load that arrived before the platform view existed.
class _QueuedStructure {
  const _QueuedStructure(
    this.sdf,
    this.style, {
    required this.asTrajectory,
    required this.resetView,
  }) : pdbUrl = null, dcdUrl = null;

  const _QueuedStructure.md(
    this.pdbUrl,
    this.dcdUrl,
    this.style, {
    required this.resetView,
  }) : sdf = null, asTrajectory = true;

  final String? sdf;
  final String? pdbUrl;
  final String? dcdUrl;
  final NglStyle style;
  final bool asTrajectory;
  final bool resetView;
}

/// Shown when the vendored NGL bundle is not on the page.
///
/// Deliberately an explanation rather than an empty box: a blank 3D pane in a
/// results page reads as a rendering bug, and the actual cause — a blocked
/// `ngl/ngl.js` — is not guessable from the picture.
class _UnsupportedNotice extends StatelessWidget {
  const _UnsupportedNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF000000),
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.view_in_ar_outlined,
            color: Colors.white38,
            size: 34,
          ),
          const SizedBox(height: 12),
          const Text(
            '3D viewer unavailable',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            NglEngine.isSupported
                ? 'The WebGL surface could not be created on this platform.'
                : 'This build is running without the bundled NGL viewer, so the '
                      'WebGL surface is not available. On the web build it is '
                      'served from web/ngl/ngl.js.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
