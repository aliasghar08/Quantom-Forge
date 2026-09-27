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
//
// ── WebGL context-loss hardening (added after a crash on 2026-09-27) ─────────
//
// Symptom: during a running reaction, `NglEngine.setFrame` propagated a
// `TypeError: Cannot read properties of null (reading 'trim')` out of
// three.js's `renderBufferDirect` → `getUniforms`. The Flutter isolate died,
// five hot-restart attempts failed in a row, and the app was un-recoverable.
//
// Cause: Chrome reclaimed the WebGL context (MSAA + a canvas inside a Flutter
// platform view is a well-known trigger on Windows). three.js held program
// objects whose GL handles were gone, and on the next render it dereferenced
// a null shader source.
//
// Fixes:
//   1. `sampleLevel` 2 → 0 and `antialias` true → false. Both reduce the
//      chance the context is lost in the first place.
//   2. A `webglcontextlost` listener on the canvas. When the context is lost,
//      the engine tears down the dead stage and rebuilds it, replaying the
//      last load so the molecule comes back rather than a blank pane.
//   3. Every `glue.callMethod` / `stage.callMethod` that touches a live
//      component (setFrame, applyStyle, resetView) is wrapped in try/catch.
//      If three.js throws after a context loss, the exception is contained at
//      the Dart boundary instead of escaping into the frame callback and
//      killing the isolate.
//
// All three are required. Fix 1 alone makes loss less frequent but does not
// make it recoverable. Fix 3 alone stops the crash but leaves the canvas
// black after a loss. Fix 2 is what makes the widget usable again.
// ============================================================================

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;
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
  static const String backgroundColor = '#000000';

  /// Camera projection.
  ///
  /// Orthographic by explicit request: no size distortion with depth.
  static const String cameraType = 'orthographic';

  static const int clipNear = -100;
  static const int clipFar = 100;

  /// Multisample level.
  ///
  /// **[FIX 1a]** Was `2` (4× MSAA). MSAA on a WebGL canvas that lives inside
  /// a Flutter platform view on Chrome/Windows is a well-known trigger for
  /// `webglcontextlost`: the compositor occasionally reclaims the context
  /// under MSAA resolve pressure, three.js keeps stale program objects, and
  /// the next render crashes on a null shader source. `0` disables MSAA. The
  /// visual difference on a small molecule is negligible; the stability gain
  /// is not.
  static const int sampleLevel = 0;

  static const double lightIntensity = 1.0;
  static const double ambientIntensity = 0.4;

  static const int fogNear = 100;
  static const int fogFar = 200;

  static bool _factoryRegistered = false;
  static final Map<int, NglEngine> _engines = <int, NglEngine>{};

  static String? _avogadroSchemeId;

  final int _viewId;
  final web.HTMLDivElement _element;

  JSObject? _stage;
  JSObject? _component;
  JSObject? _bondLabelComponent;

  List<BondLabel>? _queuedBondLabels;

  web.ResizeObserver? _resizeObserver;

  _PendingLoad? _queuedLoad;
  bool _loadInFlight = false;
  _PendingLoad? _coalescedLoad;

  bool _stageInitScheduled = false;
  bool _disposed = false;
  int _sizeSyncAttempts = 0;
  bool _canvasSized = false;

  // ── [FIX 2] Last-load memory for context-loss recovery ────────────────────
  //
  // When the WebGL context is lost we throw the dead stage away and build a
  // new one. Without remembering what was on screen, the rebuilt stage would
  // be empty and the user would see a black canvas after every loss. These
  // fields record the last load request so it can be replayed.
  String? _lastLoadedSdf;
  String? _lastLoadedPdbUrl;
  String? _lastLoadedDcdUrl;
  NglStyle? _lastLoadedStyle;
  bool _lastLoadedAsTrajectory = false;
  int? _lastLoadedFrame;

  /// Guards against scheduling two recoveries for one loss (both the `lost`
  /// event and a timeout can fire the same recovery).
  bool _recoveryScheduled = false;

  static bool get isSupported => _nglGlobal != null && _glue != null;

  static void ensureViewFactory() {
    if (_factoryRegistered) return;
    _factoryRegistered = true;

    // Hot Restart cleanup: Dart isolate restarts leave old DOM nodes alive,
    // holding WebGL contexts. Without this cleanup, 5–6 hot restarts exhaust
    // the browser's 16-context limit and crash CanvasKit.
    try {
      final oldElements = web.document.querySelectorAll(
        'div[id^="quantum-forge-ngl-"]',
      );
      for (var i = 0; i < oldElements.length; i++) {
        final el = oldElements.item(i) as web.Element;
        final canvases = el.getElementsByTagName('canvas');
        if (canvases.length > 0) {
          final canvas = canvases.item(0) as web.HTMLCanvasElement;
          final gl = canvas.getContext('webgl2') ?? canvas.getContext('webgl');
          if (gl != null) {
            final ext = (gl).callMethod(
              'getExtension'.toJS,
              'WEBGL_lose_context'.toJS,
            );
            if (ext != null) {
              (ext as JSObject).callMethod('loseContext'.toJS);
            }
          }
        }
        el.remove();
      }
    } catch (_) {
      // Ignore cleanup errors
    }

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

  static NglEngine? forView(int viewId) {
    final engine = _engines[viewId];
    engine?._scheduleStageInit();
    return engine;
  }

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

    // ── [FIX 2b] Install the context-loss listener as soon as the stage
    // exists and its canvas is in the DOM.
    _installContextLossListener();

    final queued = _queuedLoad;
    _queuedLoad = null;
    if (queued != null) {
      if (queued.sdf != null) {
        if (queued.asTrajectory) {
          loadTrajectory(
            queued.sdf!,
            queued.style,
            resetView: queued.resetView,
          );
        } else {
          loadFrame(queued.sdf!, queued.style);
        }
      } else if (queued.pdbUrl != null && queued.dcdUrl != null) {
        loadRemoteMd(
          queued.pdbUrl!,
          queued.dcdUrl!,
          queued.style,
          resetView: queued.resetView,
        );
      }
    }

    final queuedLabels = _queuedBondLabels;
    _queuedBondLabels = null;
    if (queuedLabels != null) setBondLabels(queuedLabels);
  }

  void _applySceneParameters(JSObject stage) {
    try {
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
          ..setProperty('lightIntensity'.toJS, lightIntensity.toJS)
          ..setProperty('ambientIntensity'.toJS, ambientIntensity.toJS)
          ..setProperty('pixelRatio'.toJS, devicePixelRatio.toJS)
          // ── [FIX 1b] Was `true`. See the sampleLevel comment.
          ..setProperty('antialias'.toJS, false.toJS),
      );
    } catch (error, stack) {
      assert(() {
        // ignore: avoid_print
        print('Quantum Forge: NGL setParameters failed — $error\n$stack');
        return true;
      }());
    }
  }

  void _syncCanvasSize() {
    if (_disposed) return;
    final stage = _stage;
    if (stage == null) return;

    if (_element.clientWidth > 0 && _element.clientHeight > 0) {
      try {
        stage.callMethod('handleResize'.toJS);
      } catch (_) {
        // A dead stage after context loss; recovery is already in flight.
      }

      if (!_canvasSized) {
        _canvasSized = true;
        if (_component != null) resetView();
      }
      return;
    }

    if (_sizeSyncAttempts++ < 120) {
      _afterNextFrame(_syncCanvasSize);
    }
  }

  void _installResizeObserver() {
    if (_resizeObserver != null || _disposed) return;
    try {
      _resizeObserver = web.ResizeObserver(
        ((JSAny entries, JSAny observer) {
          if (_disposed) return;
          try {
            _stage?.callMethod('handleResize'.toJS);
          } catch (_) {
            // Context-loss recovery handles this; do not re-enter.
          }
        }).toJS,
      );
      _resizeObserver!.observe(_element);
    } catch (_) {
      _resizeObserver = null;
    }
  }

  // ── [FIX 2c] Context-loss recovery ────────────────────────────────────────

  /// Listens for `webglcontextlost` on the NGL canvas.
  ///
  /// When Chrome reclaims the context, three.js does not rebuild its program
  /// objects automatically and the next render crashes on a null shader
  /// source. Listening for the loss lets us tear down and rebuild the stage
  /// before that crash happens, and replay the last structure so the user
  /// sees the molecule come back.
  void _installContextLossListener() {
    if (_disposed) return;
    try {
      final canvases = _element.getElementsByTagName('canvas');
      if (canvases.length == 0) return;
      final canvas = canvases.item(0) as JSObject;

      final onLost = ((JSAny event) {
        try {
          // If we don't preventDefault, the browser will not attempt to
          // restore the context, and we get no second chance.
          (event as JSObject).callMethod('preventDefault'.toJS);
        } catch (_) {}
        // ignore: avoid_print
        print('[QA] WebGL context LOST on NGL canvas — scheduling recovery');
        _scheduleContextRecovery();
      }).toJS;

      canvas.callMethod(
        'addEventListener'.toJS,
        'webglcontextlost'.toJS,
        onLost,
      );
    } catch (error) {
      // ignore: avoid_print
      print('[QA] failed to install context-loss listener: $error');
    }
  }

  /// Schedules a single recovery, debounced so that both the `lost` event and
  /// any future `restored` event cannot kick off two rebuilds.
  void _scheduleContextRecovery() {
    if (_recoveryScheduled || _disposed) return;
    _recoveryScheduled = true;

    // A short delay gives the browser time to finish its own teardown of the
    // dead context. Rebuilding too eagerly can race with it.
    Future<void>.delayed(const Duration(milliseconds: 500), () {
      _recoveryScheduled = false;
      if (_disposed) return;
      _rebuildStage();
    });
  }

  /// Tears down the dead stage and rebuilds it, replaying the last load.
  void _rebuildStage() {
    if (_disposed) return;
    // ignore: avoid_print
    print('[QA] rebuilding NGL stage after context loss');

    // Capture what was on screen so it can be replayed.
    final replaySdf = _lastLoadedSdf;
    final replayPdb = _lastLoadedPdbUrl;
    final replayDcd = _lastLoadedDcdUrl;
    final replayStyle = _lastLoadedStyle;
    final replayAsTrajectory = _lastLoadedAsTrajectory;
    final replayFrame = _lastLoadedFrame;

    // Dispose the dead stage. This can throw: three.js's `dispose()` walks
    // its scene graph, and every program handle in there is invalid. The
    // try/catch is not a nicety, it is the difference between a clean rebuild
    // and another crash.
    try {
      _stage?.callMethod('dispose'.toJS);
    } catch (_) {}

    _stage = null;
    _component = null;
    _bondLabelComponent = null;
    _canvasSized = false;
    _stageInitScheduled = false;

    // Remove any leftover canvas elements. NGL's dispose should remove its
    // own, but if the JS-side dispose threw (which is why we are here), they
    // may still be attached and would confuse the new stage.
    //
    // `canvases.item(i)` is `web.Element?` in `package:web`, so the call is
    // null-guarded with `?.`. Without that, `remove()` is an unchecked
    // invocation on a possibly-null receiver.
    try {
      final canvases = _element.getElementsByTagName('canvas');
      for (var i = canvases.length - 1; i >= 0; i--) {
        canvases.item(i)?.remove();
      }
    } catch (_) {}

    // Re-create the stage. `_scheduleStageInit` defers by two animation
    // frames, which is the same warm-up the original stage got.
    _scheduleStageInit();

    // Replay the last structure once the new stage is ready. 200 ms is
    // enough for two `requestAnimationFrame` callbacks plus the NGL stage
    // constructor to complete.
    Future<void>.delayed(const Duration(milliseconds: 200), () {
      if (_disposed || _stage == null) return;

      if (replayPdb != null && replayDcd != null && replayStyle != null) {
        loadRemoteMd(replayPdb, replayDcd, replayStyle, resetView: false).then((
          _,
        ) {
          if (replayFrame != null) setFrame(replayFrame);
        });
      } else if (replaySdf != null && replayStyle != null) {
        if (replayAsTrajectory) {
          loadTrajectory(replaySdf, replayStyle, resetView: false).then((_) {
            if (replayFrame != null) setFrame(replayFrame);
          });
        } else {
          loadFrame(replaySdf, replayStyle).then((_) {
            if (replayFrame != null) setFrame(replayFrame);
          });
        }
      }
    });
  }

  // ── Colour scheme ─────────────────────────────────────────────────────────

  String _colorSchemeFor(NglPalette palette) {
    if (palette == NglPalette.cpkJmol) return 'element';
    final cached = _avogadroSchemeId;
    if (cached != null) return cached;

    final glue = _glue;
    if (glue == null) return 'element';

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
      ..setProperty('quality'.toJS, 'high'.toJS);
    if (style.displayType != AvogadroDisplayType.wireframe) {
      options
        ..setProperty('radiusScale'.toJS, style.radiusScale.toJS)
        ..setProperty('aspectRatio'.toJS, style.aspectRatio.toJS);
    }
    return options;
  }

  // ── Structures ────────────────────────────────────────────────────────────

  Future<void> loadTrajectory(
    String sdf,
    NglStyle style, {
    bool resetView = true,
  }) {
    // [FIX 2d] Remember this for context-loss replay.
    _lastLoadedSdf = sdf;
    _lastLoadedPdbUrl = null;
    _lastLoadedDcdUrl = null;
    _lastLoadedStyle = style;
    _lastLoadedAsTrajectory = true;

    return _enqueueLoad(
      _PendingLoad(sdf, style, asTrajectory: true, resetView: resetView),
    );
  }

  Future<void> loadRemoteMd(
    String pdbUrl,
    String dcdUrl,
    NglStyle style, {
    bool resetView = true,
  }) {
    _lastLoadedSdf = null;
    _lastLoadedPdbUrl = pdbUrl;
    _lastLoadedDcdUrl = dcdUrl;
    _lastLoadedStyle = style;
    _lastLoadedAsTrajectory = true;

    return _enqueueLoad(
      _PendingLoad.md(pdbUrl, dcdUrl, style, resetView: resetView),
    );
  }

  Future<void> loadFrame(String sdf, NglStyle style) {
    _lastLoadedSdf = sdf;
    _lastLoadedPdbUrl = null;
    _lastLoadedDcdUrl = null;
    _lastLoadedStyle = style;
    _lastLoadedAsTrajectory = false;

    return _enqueueLoad(
      _PendingLoad(sdf, style, asTrajectory: false, resetView: false),
    );
  }

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
    final result = await _load(request);
    if (result == null || _disposed) return;

    _component = result;

    // [FIX 3a] Removing the previous component touches a live GL handle. If
    // the context was lost since the component was created, three.js throws
    // here. Catching keeps the load path from crashing the isolate.
    if (previous != null && !identical(previous, result)) {
      try {
        glue.callMethod('removeComponent'.toJS, stage, previous);
      } catch (error) {
        // ignore: avoid_print
        print('[QA] removeComponent caught (likely post-context-loss): $error');
      }
    }
  }

  Future<JSObject?> _load(_PendingLoad request) async {
    final stage = _stage;
    final glue = _glue;
    if (stage == null || glue == null) return null;

    try {
      final options = _optionsFor(
        request.style,
        asTrajectory: request.asTrajectory,
        autoView: request.resetView,
      );

      final JSPromise promise;
      if (request.sdf != null) {
        promise =
            glue.callMethod('loadSdf'.toJS, stage, request.sdf!.toJS, options)
                as JSPromise;
      } else {
        promise =
            glue.callMethod(
                  'loadRemoteMd'.toJS,
                  stage,
                  request.pdbUrl!.toJS,
                  request.dcdUrl!.toJS,
                  options,
                )
                as JSPromise;
      }
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
  ///
  /// **[FIX 3b]** This is the crash site in the reported issue: `setFrame` →
  /// `glue.setFrame` → NGL → three.js `renderBufferDirect` → `getUniforms`
  /// → `.trim()` on null. The exception was escaping back into Dart and
  /// killing the isolate. It is caught here, at the boundary.
  void setFrame(int frame) {
    if (_disposed) return;
    final component = _component;
    final glue = _glue;
    if (component == null || glue == null) return;

    // Remember the frame so a context-loss replay lands on the same image.
    _lastLoadedFrame = frame;

    try {
      glue.callMethod('setFrame'.toJS, component, frame.toJS);
    } catch (error) {
      // After a context loss, three.js's programs are stale and the first
      // render after will throw. The context-loss listener is already
      // recovering; catching here is what keeps the exception from
      // propagating into the Flutter frame callback.
      // ignore: avoid_print
      print('[QA] setFrame caught (likely post-context-loss): $error');
    }
  }

  /// Rebuilds the representation after a display-type or palette change.
  void applyStyle(NglStyle style) {
    if (_disposed) return;
    final component = _component;
    final glue = _glue;
    if (component == null || glue == null) return;
    final options = _optionsFor(style, asTrajectory: false, autoView: false);

    // [FIX 3c] Same reasoning as setFrame.
    try {
      glue.callMethod('replaceRepresentation'.toJS, component, options);
    } catch (error) {
      // ignore: avoid_print
      print('[QA] applyStyle caught (likely post-context-loss): $error');
    }
  }

  /// Draws numbered badges at bond midpoints, or clears them when [labels] is
  /// empty.
  void setBondLabels(List<BondLabel> labels) {
    if (_disposed) return;
    final stage = _stage;
    final ngl = _nglGlobal;
    if (stage == null || ngl == null) {
      _queuedBondLabels = labels;
      return;
    }

    final previous = _bondLabelComponent;
    _bondLabelComponent = null;
    if (previous != null) {
      try {
        stage.callMethod('removeComponent'.toJS, previous);
      } catch (_) {
        // Stale handle after a context loss; the next push rebuilds it.
      }
    }

    if (labels.isEmpty) return;

    try {
      final shapeConstructor = ngl.getProperty<JSFunction>('Shape'.toJS);
      final shape = shapeConstructor.callAsConstructor<JSObject>(
        'bond-labels'.toJS,
      );

      final labelColor = <JSAny>[1.0.toJS, 0.85.toJS, 0.25.toJS].toJS;

      // Dynamic label sizing based on the spatial extent of the molecule.
      double minX = double.infinity, maxX = double.negativeInfinity;
      double minY = double.infinity, maxY = double.negativeInfinity;
      double minZ = double.infinity, maxZ = double.negativeInfinity;

      for (final label in labels) {
        if (label.x < minX) minX = label.x;
        if (label.x > maxX) maxX = label.x;
        if (label.y < minY) minY = label.y;
        if (label.y > maxY) maxY = label.y;
        if (label.z < minZ) minZ = label.z;
        if (label.z > maxZ) maxZ = label.z;
      }

      final extX = maxX - minX;
      final extY = maxY - minY;
      final extZ = maxZ - minZ;
      final diagonal = math.sqrt(extX * extX + extY * extY + extZ * extZ);

      final effectiveDiagonal = math.max(10.0, diagonal);
      final scaleFactor = math.sqrt(effectiveDiagonal / 10.0);

      final double markerRadius = 0.25 * scaleFactor;
      final double labelSize = 0.35 * scaleFactor;

      for (final label in labels) {
        final position = <JSAny>[label.x.toJS, label.y.toJS, label.z.toJS].toJS;

        shape.callMethod(
          'addSphere'.toJS,
          position,
          labelColor,
          markerRadius.toJS,
        );
        shape.callMethod(
          'addLabel'.toJS,
          position,
          labelColor,
          labelSize.toJS,
          label.index.toString().toJS,
        );
      }

      final component = stage.callMethod('addComponentFromObject'.toJS, shape);
      if (component == null || !component.isA<JSObject>()) {
        // ignore: avoid_print
        print('Quantum Forge: addComponentFromObject returned null');
        return;
      }

      (component as JSObject).callMethod(
        'addRepresentation'.toJS,
        'buffer'.toJS,
      );
      _bondLabelComponent = component;
    } catch (error, stack) {
      _bondLabelComponent = null;
      // ignore: avoid_print
      print('Quantum Forge: NGL bond labels failed — $error\n$stack');
    }
  }

  /// Zooms the camera by the given number of wheel-delta units.
  void zoomBy(double delta) {
    if (_disposed || delta == 0) return;
    final stage = _stage;
    if (stage == null) return;
    try {
      final controls = stage.getProperty<JSObject?>('viewerControls'.toJS);
      if (controls == null) return;
      final factor = math.exp(delta * 0.001).clamp(0.5, 2.0);
      controls.callMethod('zoom'.toJS, factor.toJS);
    } catch (error, stack) {
      assert(() {
        // ignore: avoid_print
        print('Quantum Forge: NGL zoom failed — $error\n$stack');
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

    // [FIX 3d] Same reasoning as setFrame.
    try {
      glue.callMethod('autoView'.toJS, stage);
    } catch (error) {
      // ignore: avoid_print
      print('[QA] resetView caught (likely post-context-loss): $error');
    }
  }

  void handleResize() {
    if (_disposed) return;
    _sizeSyncAttempts = 0;
    _syncCanvasSize();
  }

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

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _engines.remove(_viewId);
    _component = null;
    _bondLabelComponent = null;

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

        final canvases = _element.getElementsByTagName('canvas');
        if (canvases.length > 0) {
          final canvas = canvases.item(0) as web.HTMLCanvasElement;
          final gl = canvas.getContext('webgl2') ?? canvas.getContext('webgl');
          if (gl != null) {
            final ext = (gl).callMethod(
              'getExtension'.toJS,
              'WEBGL_lose_context'.toJS,
            );
            if (ext != null) {
              (ext as JSObject).callMethod('loseContext'.toJS);
            }
          }
        }
      } catch (_) {
        // NGL can throw from dispose() when the context is already lost.
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
  }) : pdbUrl = null,
       dcdUrl = null;

  const _PendingLoad.md(
    this.pdbUrl,
    this.dcdUrl,
    this.style, {
    required this.resetView,
  }) : sdf = null,
       asTrajectory = true;

  final String? sdf;
  final String? pdbUrl;
  final String? dcdUrl;
  final NglStyle style;
  final bool asTrajectory;
  final bool resetView;
}