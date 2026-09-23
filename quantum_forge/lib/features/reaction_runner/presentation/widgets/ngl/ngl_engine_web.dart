// ============================================================================
// NGL engine — web (ngl.js + WebGL) implementation
// ----------------------------------------------------------------------------
// Wraps the two globals the page loads before Flutter boots:
//
//   window.NGL             — the vendored NGL Viewer bundle (web/ngl/ngl.js)
//   window.QuantumForgeNgl — the NGL glue, which owns every version-specific
//                            detail (web/ngl/quantum_forge_ngl.js)
//
// The division of labour matters: this file manages the stage lifecycle and
// moves strings and numbers across the JS boundary, and the glue does the NGL
// API work. That keeps the Dart side free of the several non-obvious NGL calls
// (the SDF-not-XYZ loader, `addTrajectory` before `trajList`, the nested frame
// setter, `addScheme` wanting a function) and leaves them in one reviewable
// place with the reasoning attached.
//
// Two lifecycle details here are load-bearing:
//
//   * `NGL.Stage` is an ES class, so it must be invoked with `new`.
//   * Flutter attaches and lays out the platform view *after* the stage exists,
//     so a stage built against a 0x0 box has to be re-measured and the camera
//     re-fitted once the canvas acquires a real size. Without that, an
//     orthographic camera fits itself to nothing and the pane renders black.
// ============================================================================

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:web/web.dart' as web;

import 'package:quantum_forge/core/utils/avogadro_element_data.dart';

import 'avogadro_geometry.dart' show AvogadroDisplayType;
import 'ngl_bond_label.dart';
import 'ngl_style.dart';

/// `window.NGL`, or null when the bundle did not load.
@JS('NGL')
external JSObject? get _nglGlobal;

/// `window.QuantumForgeNgl`, or null when the glue did not load.
@JS('QuantumForgeNgl')
external JSObject? get _glue;

class NglEngine {
  NglEngine._(this._viewId, this._element);

  /// Platform-view type name. Must match `NglEngine.viewType` in the stub.
  static const String viewType = 'quantum-forge-ngl-viewer';

  /// Background colour NGL is created with.
  ///
  /// Avogadro's shipped default is opaque black — `settings.value(
  /// "backgroundColor", QColor(0, 0, 0, 255))` in avogadroapp's
  /// `MainWindow::setupInterface()` — so an animation here and the same
  /// structure on the desktop sit on the same background. NGL's own default is
  /// also black, so this is belt and braces.
  static const String backgroundColor = '#000000';

  /// Camera projection.
  ///
  /// Orthographic by explicit request: no size distortion with depth, which is
  /// what makes it the right choice for a publication figure.
  ///
  /// Not claimed as Avogadro parity, because it is not: Avogadro's
  /// `Rendering::Camera` constructor sets `m_projectionType(Perspective)`
  /// (`avogadro/rendering/camera.cpp`), and NGL's own default is
  /// `'perspective'`. This is a deliberate divergence.
  static const String cameraType = 'orthographic';

  /// Near clip plane distance from the camera target, in angstrom.
  ///
  /// NGL's default is `0`, which clips anything at or behind the target plane.
  /// A negative near plane puts the clip well behind the molecule so a large
  /// structure cannot lose its back half while orbiting.
  static const int clipNear = -100;

  /// Far clip plane distance from the camera target, in angstrom.
  static const int clipFar = 100;

  /// Multisample level. NGL's default is `0`; `2` is 4x MSAA.
  static const int sampleLevel = 2;

  /// Directional (key) light intensity. NGL's default is `1.2`.
  static const double lightIntensity = 1.0;

  /// Ambient light intensity. NGL's default is `0.3`; raised slightly so
  /// surfaces facing away from the key light keep their element colour instead
  /// of going to near-black, which matters for reading CPK colours off a figure.
  static const double ambientIntensity = 0.4;

  /// Depth-cueing range, in angstrom from the camera.
  ///
  /// Chosen rather than defaulted (NGL ships `fogNear: 50`, `fogFar: 100`).
  ///
  /// Worth being explicit about what these numbers do, because the direction is
  /// counter-intuitive: fog *increases* with distance, so raising both ends
  /// pushes the cueing further away and makes it **less** visible. Across a ~5 A
  /// small molecule whose camera sits ~40 A out, `100/200` leaves every atom
  /// closer than `fogNear`, so no fog is drawn at all — as, in fairness, the
  /// `50/100` default mostly is too. Visible depth cueing on a molecule this size
  /// needs a range bracketing the molecule itself, roughly `fogNear: 20`,
  /// `fogFar: 60`. These are set as requested and left as named constants so
  /// that is a one-line change.
  static const int fogNear = 100;
  static const int fogFar = 200;

  static bool _factoryRegistered = false;
  static final Map<int, NglEngine> _engines = <int, NglEngine>{};

  /// Registered Avogadro colour-scheme id, or null until first used.
  static String? _avogadroSchemeId;

  final int _viewId;
  final web.HTMLDivElement _element;

  JSObject? _stage;
  JSObject? _component;

  /// The badge component drawn at bond midpoints, or null when badges are off.
  JSObject? _bondLabelComponent;

  /// Badge labels requested before the stage existed.
  ///
  /// There are two gaps between "the widget has labels" and "there is a stage to
  /// draw them on": the platform view must be created, which is when the engine
  /// is adopted, and the stage is then built two animation frames later. Without
  /// this queue a badge push landing in either gap is dropped without a trace —
  /// the stage is null, the call returns, and the badges simply never appear.
  List<BondLabel>? _queuedBondLabels;

  web.ResizeObserver? _resizeObserver;

  /// A load requested before the stage existed, replayed once it does.
  _PendingLoad? _queuedLoad;

  /// Whether a structure load is currently in flight.
  bool _loadInFlight = false;

  /// The most recent load requested while another was in flight.
  ///
  /// Coalescing rather than queueing: the frame ticker will happily ask for image
  /// 5 while image 4 is still parsing, and replaying every intermediate request
  /// would render frames the viewer has already moved past.
  _PendingLoad? _coalescedLoad;

  bool _stageInitScheduled = false;
  bool _disposed = false;
  int _sizeSyncAttempts = 0;
  bool _canvasSized = false;

  /// Whether both scripts loaded. Checked before building an `HtmlElementView`,
  /// so a blocked script shows an explanation rather than an empty rectangle.
  static bool get isSupported => _nglGlobal != null && _glue != null;

  /// Registers the platform-view factory. Safe to call from every viewer's
  /// `initState`: only the first call does anything.
  static void ensureViewFactory() {
    if (_factoryRegistered) return;
    _factoryRegistered = true;

    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final element = web.HTMLDivElement()
        ..id = 'quantum-forge-ngl-$viewId'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.position = 'relative'
        ..style.backgroundColor = backgroundColor;

      final engine = NglEngine._(viewId, element);
      _engines[viewId] = engine;
      return element;
    });
  }

  /// Adopts the engine the factory built for [viewId].
  ///
  /// Returns null when no factory has run for that id, which is the case off the
  /// web. The caller (the viewer widget) decides what to do about it.
  static NglEngine? forView(int viewId) {
    final engine = _engines[viewId];
    engine?._scheduleStageInit();
    return engine;
  }

  /// Whether a stage exists and can accept structures.
  bool get hasStage => _stage != null;

  // ── Stage lifecycle ───────────────────────────────────────────────────────

  void _scheduleStageInit() {
    if (_stageInitScheduled || _disposed) return;
    _stageInitScheduled = true;

    // Two frames of deferral on purpose. The first lets Flutter attach the
    // element to the document, the second lets the browser lay it out — NGL
    // reads `getBoundingClientRect()` while constructing the stage, and a
    // detached element measures 0x0.
    _afterNextFrame(() => _afterNextFrame(_createStage));
  }

  static void _afterNextFrame(void Function() callback) {
    web.window.requestAnimationFrame(((JSAny _) => callback()).toJS);
  }

  void _createStage() {
    if (_disposed || _stage != null) return;

    final ngl = _nglGlobal;
    if (ngl == null) return;

    try {
      final stageConstructor = ngl.getProperty<JSFunction>('Stage'.toJS);
      final params = JSObject()
        ..setProperty('backgroundColor'.toJS, backgroundColor.toJS);
      _stage = stageConstructor.callAsConstructor<JSObject>(
        _element as JSAny,
        params,
      );
    } catch (error, stack) {
      // A stage that cannot be created leaves `hasStage` false, which the
      // widget turns into a visible message instead of a crash inside a build.
      _stage = null;
      assert(() {
        // ignore: avoid_print
        print('Quantum Forge: NGL stage creation failed — $error\n$stack');
        return true;
      }());
      return;
    }

    _applySceneParameters(_stage!);
    _syncCanvasSize();
    _installResizeObserver();

    final queued = _queuedLoad;
    _queuedLoad = null;
    if (queued != null) {
      if (queued.asTrajectory) {
        loadTrajectory(queued.sdf, queued.style, resetView: queued.resetView);
      } else {
        loadFrame(queued.sdf, queued.style);
      }
    }

    // Badges asked for while the stage was still being built.
    final queuedLabels = _queuedBondLabels;
    _queuedBondLabels = null;
    if (queuedLabels != null) setBondLabels(queuedLabels);
  }

  /// Applies the camera, quality and scene parameters, after the stage exists.
  ///
  /// Called as a separate `setParameters` rather than folded into the `Stage`
  /// constructor because that is the path verified against NGL 2.5.0: an
  /// ignored `cameraType` would otherwise leave the pane in perspective with no
  /// visible error. `tool/ngl_probe.cjs` reads every one of these back off the
  /// live stage, so "the call was made" is never mistaken for "the setting took
  /// effect".
  ///
  /// Lighting is deliberately not touched. NGL's impostor shaders carry their
  /// own ambient, diffuse and specular terms; overriding them is how a render
  /// stops looking like a scientific viewer.
  void _applySceneParameters(JSObject stage) {
    try {
      // Read from the DOM rather than assuming 1.0: on a 4K display or a Retina
      // panel the backing store needs to be dpr times the CSS size or the render
      // is soft, which is exactly the failure that only shows up on the
      // projector it was presented on.
      final devicePixelRatio = web.window.devicePixelRatio;
      stage.callMethod(
        'setParameters'.toJS,
        JSObject()
          ..setProperty('backgroundColor'.toJS, backgroundColor.toJS)
          ..setProperty('cameraType'.toJS, cameraType.toJS)
          ..setProperty('clipNear'.toJS, clipNear.toJS)
          ..setProperty('clipFar'.toJS, clipFar.toJS)
          ..setProperty('fogNear'.toJS, fogNear.toJS)
          ..setProperty('fogFar'.toJS, fogFar.toJS)
          ..setProperty('sampleLevel'.toJS, sampleLevel.toJS)
          // Both verified real against NGL 2.5.0: `lightIntensity` exists and
          // defaults to 1.2, `ambientIntensity` to 0.3.
          ..setProperty('lightIntensity'.toJS, lightIntensity.toJS)
          ..setProperty('ambientIntensity'.toJS, ambientIntensity.toJS)
          // Requested, and honest about the result: measured against 2.5.0,
          // neither of these keys is in `viewer.parameters` and neither has any
          // observable effect — not through `setParameters`, and not through the
          // `Stage` constructor either, where `{antialias: false}` still yields a
          // context reporting antialias true and `{pixelRatio: 0.5}` still yields
          // 1. The values they ask for are what NGL already does: three.js
          // creates the context with antialiasing, and the pixel ratio follows
          // `window.devicePixelRatio`. That is why the probe asserts the
          // *effective* values — the WebGL context attribute and three.js's own
          // `getPixelRatio()` — rather than that these two lines ran.
          ..setProperty('pixelRatio'.toJS, devicePixelRatio.toJS)
          ..setProperty('antialias'.toJS, true.toJS),
      );
    } catch (error, stack) {
      // A stage that renders with NGL's defaults is far better than no stage.
      assert(() {
        // ignore: avoid_print
        print('Quantum Forge: NGL setParameters failed — $error\n$stack');
        return true;
      }());
    }
  }

  /// Keeps the WebGL canvas the same size as its element.
  ///
  /// This is the fix for a bug that renders as a permanently blank 3D pane:
  /// NGL sizes its canvas from `getBoundingClientRect()` while the stage is
  /// being constructed, and Flutter attaches (and then lays out) the platform
  /// view *after* that. No window resize event accompanies Flutter's layout pass,
  /// so nothing tells NGL to re-measure and the canvas stays 0x0 while the
  /// element around it measures 898x748.
  void _syncCanvasSize() {
    if (_disposed) return;
    final stage = _stage;
    if (stage == null) return;

    if (_element.clientWidth > 0 && _element.clientHeight > 0) {
      stage.callMethod('handleResize'.toJS);

      // Re-fit the camera the first time the canvas acquires a real box.
      //
      // `autoView()` derives the framing from the canvas dimensions, so one
      // computed against a 0x0 element fits the camera to nothing. With the
      // default perspective camera that is merely wrong-looking; with an
      // orthographic camera it collapses the zoom and the pane renders
      // completely black, which is how this was found — the harness went from
      // ~10 000 lit pixels to zero when the camera became orthographic.
      if (!_canvasSized) {
        _canvasSized = true;
        if (_component != null) resetView();
      }
      return;
    }

    // ~2 seconds of frames. A viewer that never gets a box is inside a
    // collapsed or unlaid-out subtree, and there is nothing useful to draw.
    if (_sizeSyncAttempts++ < 120) {
      _afterNextFrame(_syncCanvasSize);
    }
  }

  /// Re-measures on any later layout change that does not fire a window resize.
  void _installResizeObserver() {
    if (_resizeObserver != null || _disposed) return;
    try {
      _resizeObserver = web.ResizeObserver(
        ((JSAny entries, JSAny observer) {
          if (_disposed) return;
          _stage?.callMethod('handleResize'.toJS);
        }).toJS,
      );
      _resizeObserver!.observe(_element);
    } catch (_) {
      // No ResizeObserver in this browser. The retry loop above has already
      // handled the initial layout, so this only costs us late resizes.
      _resizeObserver = null;
    }
  }

  // ── Colour scheme ─────────────────────────────────────────────────────────

  /// The `colorScheme` value to hand NGL for [palette].
  ///
  /// `'element'` is NGL's own scheme, which is the **Jmol** table — measured at
  /// `#909090` for carbon. The Avogadro palette is registered as a custom scheme
  /// returning numeric hex values, which the measurement showed lands in the
  /// geometry buffer byte-exactly.
  String _colorSchemeFor(NglPalette palette) {
    if (palette == NglPalette.cpkJmol) return 'element';
    final cached = _avogadroSchemeId;
    if (cached != null) return cached;

    final glue = _glue;
    if (glue == null) return 'element';

    // Index == atomic number, including index 0 for the dummy element.
    final table = JSObject();
    final colours = AvogadroElementData.colors;
    for (var atomicNumber = 0; atomicNumber < colours.length; atomicNumber++) {
      table.setProperty(
        atomicNumber.toString().toJS,
        colours[atomicNumber].toJS,
      );
    }

    final id = glue.callMethod('registerAvogadroScheme'.toJS, table);
    final schemeId = id.isA<JSString>() ? (id as JSString).toDart : 'element';
    _avogadroSchemeId = schemeId;
    return schemeId;
  }

  /// The style in the shape the glue expects.
  JSObject _optionsFor(
    NglStyle style, {
    required bool asTrajectory,
    required bool autoView,
  }) {
    final options = JSObject()
      ..setProperty('asTrajectory'.toJS, asTrajectory.toJS)
      ..setProperty('autoView'.toJS, autoView.toJS)
      ..setProperty(
        'representation'.toJS,
        style.displayType.representation.toJS,
      )
      ..setProperty('colorScheme'.toJS, _colorSchemeFor(style.palette).toJS)
      // `quality: 'high'` is a *representation* parameter, not a stage one —
      // `setParameters({quality: 'high'})` is silently ignored. Verified on
      // ball+stick: it resolves to sphereDetail 2 / radialSegments 20.
      //
      // Note that `sphereSegments` and `cylinderSegments` do not exist in NGL at
      // all, and would not matter here anyway: with impostors enabled the spheres
      // are ray-traced as perfect spheres in the fragment shader, so their mesh
      // tessellation never reaches the screen. `smoothSheet` belongs to the
      // ribbon/cartoon representation and has no meaning for ball+stick.
      ..setProperty('quality'.toJS, 'high'.toJS);
    // `line` takes no radius; passing one is harmless, but omitting it keeps the
    // wireframe request honest about what it is asking for.
    if (style.displayType != AvogadroDisplayType.wireframe) {
      options
        ..setProperty('radiusScale'.toJS, style.radiusScale.toJS)
        ..setProperty('aspectRatio'.toJS, style.aspectRatio.toJS);
    }
    return options;
  }

  // ── Structures ────────────────────────────────────────────────────────────

  /// Loads a multi-model SDF once and prepares frame scrubbing.
  ///
  /// Connectivity comes from the first model — NGL's `asTrajectory` contract —
  /// so this is the right path when the bond set is constant across the path.
  Future<void> loadTrajectory(
    String sdf,
    NglStyle style, {
    bool resetView = true,
  }) => _enqueueLoad(
    _PendingLoad(sdf, style, asTrajectory: true, resetView: resetView),
  );

  /// Loads a single-model SDF, replacing the previous structure.
  ///
  /// Used when the bond set changes per frame (Avogadro's "Dynamic bonding?"),
  /// where connectivity cannot be taken from one model. The replacement is added
  /// before the previous component is removed, so the canvas is never
  /// momentarily empty, and the camera is left alone so the view does not jump.
  Future<void> loadFrame(String sdf, NglStyle style) => _enqueueLoad(
    _PendingLoad(sdf, style, asTrajectory: false, resetView: false),
  );

  /// Runs structure loads one at a time, keeping only the newest pending one.
  ///
  /// NGL parses asynchronously, so two loads started close together interleave.
  /// The frame ticker makes that the normal case rather than the exception: at
  /// 4 FPS a 3-atom model parses faster than a frame, but a larger path does not,
  /// and an interleaved pair leaves the engine holding a component that a
  /// concurrent removal has already disposed — which surfaced as a `TypeError`
  /// from inside NGL's own `removeComponent`, with nothing in the message
  /// pointing back at the cause.
  ///
  /// Only the latest request survives the wait, which is also the behaviour a
  /// scrubber wants: skipping directly to the newest frame is correct, replaying
  /// every frame in between is not.
  Future<void> _enqueueLoad(_PendingLoad request) async {
    if (_disposed) return;
    if (_loadInFlight) {
      _coalescedLoad = request;
      return;
    }

    _loadInFlight = true;
    try {
      await _performLoad(request);
    } finally {
      _loadInFlight = false;
    }

    final next = _coalescedLoad;
    _coalescedLoad = null;
    if (next != null) await _enqueueLoad(next);
  }

  Future<void> _performLoad(_PendingLoad request) async {
    if (_disposed) return;
    final stage = _stage;
    final glue = _glue;
    if (stage == null || glue == null) {
      _queuedLoad = request;
      _scheduleStageInit();
      return;
    }

    final previous = _component;
    final result = await _load(
      request.sdf,
      request.style,
      asTrajectory: request.asTrajectory,
      autoView: request.resetView,
    );
    if (result == null || _disposed) return;

    _component = result;
    if (previous != null && !identical(previous, result)) {
      glue.callMethod('removeComponent'.toJS, stage, previous);
    }
  }

  Future<JSObject?> _load(
    String sdf,
    NglStyle style, {
    required bool asTrajectory,
    required bool autoView,
  }) async {
    final stage = _stage;
    final glue = _glue;
    if (stage == null || glue == null) return null;

    try {
      final options = _optionsFor(
        style,
        asTrajectory: asTrajectory,
        autoView: autoView,
      );
      final promise =
          glue.callMethod('loadSdf'.toJS, stage, sdf.toJS, options)
              as JSPromise;
      final result = await promise.toDart;
      final summary = (result as JSObject).getProperty('component'.toJS);
      return summary as JSObject?;
    } catch (error, stack) {
      assert(() {
        // ignore: avoid_print
        print('Quantum Forge: NGL structure load failed — $error\n$stack');
        return true;
      }());
      return null;
    }
  }

  /// Moves a loaded trajectory to an absolute 0-based frame.
  void setFrame(int frame) {
    if (_disposed) return;
    final component = _component;
    final glue = _glue;
    if (component == null || glue == null) return;
    glue.callMethod('setFrame'.toJS, component, frame.toJS);
  }

  /// Rebuilds the representation after a display-type or palette change.
  ///
  /// Replaces rather than adds: `addRepresentation` would stack a second
  /// representation on the same structure, so switching Ball and Stick → Licorice
  /// → back would leave three overlapping models drawn at once.
  void applyStyle(NglStyle style) {
    if (_disposed) return;
    final component = _component;
    final glue = _glue;
    if (component == null || glue == null) return;
    final options = _optionsFor(style, asTrajectory: false, autoView: false);
    glue.callMethod('replaceRepresentation'.toJS, component, options);
  }

  /// Draws numbered badges at bond midpoints, or clears them when [labels] is
  /// empty.
  ///
  /// The badges are a separate `NGL.Shape` component, so they rotate with the
  /// molecule and depth-sort against it, and so toggling them never disturbs the
  /// structure, the representation or the camera. Passing an empty list removes
  /// the component rather than drawing nothing, which keeps the stage free of a
  /// component that would otherwise sit in every `compList` count.
  void setBondLabels(List<BondLabel> labels) {
    if (_disposed) return;
    final stage = _stage;
    final glue = _glue;
    if (stage == null || glue == null) {
      // The stage is not up yet; replay on creation.
      _queuedBondLabels = labels;
      return;
    }

    if (labels.isEmpty) {
      final previous = _bondLabelComponent;
      _bondLabelComponent = null;
      if (previous != null) {
        glue.callMethod('removeComponent'.toJS, stage, previous);
      }
      return;
    }

    final positions = Float32List(labels.length * 3);
    final indices = Int32List(labels.length);
    for (var i = 0; i < labels.length; i++) {
      final label = labels[i];
      positions[i * 3] = label.x;
      positions[i * 3 + 1] = label.y;
      positions[i * 3 + 2] = label.z;
      indices[i] = label.index;
    }

    try {
      final result = glue.callMethod(
        'setBondLabels'.toJS,
        stage,
        _bondLabelComponent,
        positions.toJS,
        indices.toJS,
      );
      _bondLabelComponent = result.isA<JSObject>() ? result as JSObject : null;
    } catch (error, stack) {
      _bondLabelComponent = null;
      assert(() {
        // ignore: avoid_print
        print('Quantum Forge: NGL bond labels failed — $error\n$stack');
        return true;
      }());
    }
  }

  /// Fits the camera to the current structure.
  void resetView() {
    if (_disposed) return;
    final stage = _stage;
    final glue = _glue;
    if (stage == null || glue == null) return;
    glue.callMethod('autoView'.toJS, stage);
  }

  /// Re-measures the canvas, for callers that know the layout changed.
  void handleResize() {
    if (_disposed) return;
    _sizeSyncAttempts = 0;
    _syncCanvasSize();
  }

  /// The viewer's orientation, for a Flutter-drawn axes triad.
  List<double>? cameraOrientation() {
    if (_disposed) return null;
    final stage = _stage;
    final glue = _glue;
    if (stage == null || glue == null) return null;
    try {
      final result = glue.callMethod('cameraOrientation'.toJS, stage);
      if (!result.isA<JSArray>()) return null;
      final list = (result as JSArray).toDart;
      if (list.length != 16) return null;
      final values = <double>[];
      for (final element in list) {
        final number = element as JSNumber?;
        if (number == null) return null;
        final value = number.toDartDouble;
        if (!value.isFinite) return null;
        values.add(value);
      }
      return values;
    } catch (_) {
      return null;
    }
  }

  // ── Teardown ──────────────────────────────────────────────────────────────

  /// Tears the stage down. Called from the viewer's `dispose`, never from a
  /// rebuild — the widget keeps its engine across `setState`.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _engines.remove(_viewId);
    _component = null;

    try {
      _resizeObserver?.disconnect();
    } catch (_) {
      // Already detached.
    }
    _resizeObserver = null;

    final stage = _stage;
    _stage = null;
    if (stage != null) {
      try {
        stage.callMethod('dispose'.toJS);
      } catch (_) {
        // NGL can throw from dispose() when the context is already lost (a
        // canvas reclaimed by the browser, or a hot restart). Nothing to do.
      }
    }
    _element.remove();
  }
}

/// A load requested before the stage existed.
class _PendingLoad {
  const _PendingLoad(
    this.sdf,
    this.style, {
    required this.asTrajectory,
    required this.resetView,
  });

  final String sdf;
  final NglStyle style;
  final bool asTrajectory;
  final bool resetView;
}
