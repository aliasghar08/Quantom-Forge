// ============================================================================
// Quantum Forge — NGL glue
// ----------------------------------------------------------------------------
// The only JavaScript in the reaction animation. Everything scientific — which
// atoms are bonded, what colour an element gets, which frame is on screen —
// is decided in Dart; this file owns the parts that are specific to NGL's
// version and API, and nothing else.
//
// Every non-obvious call below was established by driving the real library in a
// browser (see tool/ngl_probe.cjs and AVOGADRO_ANIMATION_PARITY.md), because
// several of them are not what the obvious code would be:
//
//   * **XYZ cannot be loaded.** `loadFile(..., {ext:'xyz'})` fails with
//     "autoLoad: ext 'xyz' unknown". It is absent from `ngl@2.5.0` and from the
//     `2.0.0-dev.39` prerelease alike — every format NGL does support appears as
//     a quoted extension in the bundle, and `"xyz"` appears zero times. So the
//     trajectory is handed over as a multi-model **SDF**, which carries both
//     coordinates and connectivity.
//   * **`asTrajectory` alone gives frames, not a player.** Loading an SDF with
//     `{asTrajectory:true}` fills `structure.frames` (atomCount 3, 3 frames for a
//     3-model file) but leaves `comp.trajList` empty: there is no `setFrame` on
//     the structure or the component. `comp.addTrajectory()` is what populates
//     `trajList`, and the entry it adds is what moves the coordinates.
//   * **The frame setter is nested.** `trajList[0].setFrame(n)` works, and so
//     does `trajList[0].trajectory.frame = n` — but `trajList[0].frame` alone
//     does nothing, and `trajList[0].frameCount` is undefined; the count lives on
//     `trajList[0].trajectory.frameCount`.
//   * **A custom colour scheme must be a function, not source text.** Passing a
//     string throws `TypeError: e.call is not a function`. A function whose
//     `atomColor` returns a *numeric* `0xRRGGBB` lands in the geometry buffer
//     byte-exactly — a scheme returning `0x7F7F7F` reads back `#7F7F7F`. An array
//     return does not work (it renders black), and pre-linearising is not needed.
//   * **NGL's `element` scheme is the Jmol table**, measured at `#909090` for
//     carbon. Avogadro's carbon is `#7F7F7F`, so the Avogadro palette needs the
//     custom scheme rather than `colorScheme:'element'`.
//
// Exposed as `window.QuantumForgeNgl`, dependency-free so the probe can exercise
// it directly.
// ============================================================================

(function () {
  'use strict';

  // ── Verification surface ──────────────────────────────────────────────────
  // Read by tool/ngl_probe.cjs, which cannot see into Dart state. `frameSeq`
  // incrementing is proof a trajectory is actually being scrubbed; the atom and
  // bond counts prove the structure reached NGL rather than an empty file.
  var loadSeq = 0;
  var frameSeq = 0;
  var badgeSeq = 0;
  var badgeCallCount = 0;
  var lastStage = null;
  var lastComponent = null;
  var lastLoad = null;
  var lastBadges = null;
  var lastError = null;

  function describe(error) {
    if (error === null || error === undefined) return String(error);
    if (typeof error === 'string') return error;
    var message = (error.name ? error.name + ': ' : '') + (error.message || String(error));
    // Include the first frame of the stack. Several NGL failures surface as a
    // bare TypeError from inside minified code, where the message alone gives no
    // clue which call threw.
    if (error.stack) {
      var frame = String(error.stack).split('\n')[1];
      if (frame) message += ' @' + frame.trim();
    }
    return message;
  }

  function requireNgl() {
    if (!window.NGL) throw new Error('NGL is not loaded');
  }

  /** A Blob URL for text, plus the revoke to run once NGL has read it. */
  function objectUrlFor(text, mimeType) {
    var blob = new Blob([text], { type: mimeType || 'text/plain' });
    var url = URL.createObjectURL(blob);
    return { url: url, revoke: function () { URL.revokeObjectURL(url); } };
  }

  /**
   * Fits a stage to whatever it is holding.
   *
   * Guarded, and never called on a frame change: `autoView()` derives its
   * framing from the canvas size, so calling it before Flutter has laid the
   * platform view out fits the camera to nothing and — with an orthographic
   * camera — renders a completely black pane.
   */
  function safeAutoView(stage) {
    try {
      if (stage.viewer && stage.viewer.width > 0 && stage.viewer.height > 0) {
        stage.autoView();
      }
    } catch (error) {
      lastError = describe(error);
    }
  }

  /**
   * Loads SDF text into a stage.
   *
   * @param {object} stage      an NGL.Stage
   * @param {string} sdfText    one model, or several separated by `$$$$`
   * @param {object} options    { asTrajectory, representation, colorScheme,
   *                              radiusScale, aspectRatio, autoView }
   * @returns {Promise<object>} a summary, never a bare component, so the caller
   *                            has something to assert on
   */
  async function loadSdf(stage, sdfText, options) {
    requireNgl();
    var settings = options || {};
    var handle = objectUrlFor(sdfText);
    try {
      var loadParams = {
        ext: 'sdf',
        defaultRepresentation: false,
        asTrajectory: settings.asTrajectory === true,
        // A worker build would make the geometry arrive later than the first
        // frame in a headless browser, and the structures here are tiny.
        useWorker: false,
      };

      var component = await stage.loadFile(handle.url, loadParams);

      // Frames exist after an asTrajectory load, but no player does until
      // addTrajectory() is called — see the header note.
      if (loadParams.asTrajectory && typeof component.addTrajectory === 'function') {
        component.addTrajectory();
      }

      if (settings.representation) {
        addRepresentation(component, settings);
      }
      if (settings.autoView !== false) {
        safeAutoView(stage);
      }

      var player = component.trajList && component.trajList[0]
        ? component.trajList[0] : null;

      loadSeq += 1;
      lastStage = stage;
      lastComponent = component;
      lastLoad = {
        seq: loadSeq,
        atoms: component.structure.atomCount,
        bonds: component.structure.bondCount,
        structureFrames: component.structure.frames ? component.structure.frames.length : 0,
        hasPlayer: !!player,
        frameCount: player && player.trajectory ? player.trajectory.frameCount : null,
        representation: settings.representation || null,
        colorScheme: settings.colorScheme || null,
        stageWidth: (stage.viewer && stage.viewer.width) || null,
        stageHeight: (stage.viewer && stage.viewer.height) || null,
      };
      lastError = null;
      return { component: component, summary: lastLoad };
    } catch (error) {
      lastError = describe(error);
      throw error;
    } finally {
      handle.revoke();
    }
  }

  /**
   * Loads an MD simulation natively using remote URLs for topology (PDB) and trajectory (DCD).
   */
  async function loadRemoteMd(stage, pdbUrl, dcdUrl, options) {
    requireNgl();
    var settings = options || {};
    try {
      var loadParams = { defaultRepresentation: false };
      var component = await stage.loadFile(pdbUrl, loadParams);

      if (dcdUrl) {
        await component.addTrajectory(dcdUrl);
      }

      if (settings.representation) {
        addRepresentation(component, settings);
      }
      if (settings.autoView !== false) {
        safeAutoView(stage);
      }

      var player = component.trajList && component.trajList[0] ? component.trajList[0] : null;

      loadSeq += 1;
      lastStage = stage;
      lastComponent = component;
      lastLoad = {
        seq: loadSeq,
        atoms: component.structure.atomCount,
        bonds: component.structure.bondCount,
        hasPlayer: !!player,
        frameCount: player && player.trajectory ? player.trajectory.frameCount : null,
        representation: settings.representation || null,
        colorScheme: settings.colorScheme || null,
      };
      lastError = null;
      return { component: component, summary: lastLoad };
    } catch (error) {
      lastError = describe(error);
      throw error;
    }
  }

  /** Adds the requested representation, replacing anything already present. */
  function addRepresentation(component, settings) {
    var params = {
      colorScheme: settings.colorScheme || 'element',
    };
    if (settings.radiusScale !== undefined) params.radiusScale = settings.radiusScale;
    if (settings.aspectRatio !== undefined) params.aspectRatio = settings.aspectRatio;
    // `quality` is a representation parameter (it resolves to sphereDetail /
    // radialSegments); the stage-level `setParameters({quality})` is ignored.
    if (settings.quality !== undefined) params.quality = settings.quality;
    // `disableImpostor: false` keeps NGL's impostor shaders, which are what give
    // smooth-edged spheres and the ambient/specular shading at any zoom.
    params.disableImpostor = false;
    if (settings.multipleBond !== undefined) params.multipleBond = settings.multipleBond;

    component.addRepresentation(settings.representation, params);
    return true;
  }

  /**
   * Removes and re-adds a component's representation, so a style change takes
   * effect without re-sending the structure.
   */
  function replaceRepresentation(component, settings) {
    if (!component) return false;
    try {
      if (typeof component.removeAllRepresentations === 'function') {
        component.removeAllRepresentations();
      }
      return addRepresentation(component, settings || {});
    } catch (error) {
      lastError = describe(error);
      return false;
    }
  }

  /**
   * Registers the Avogadro element palette as an NGL colour scheme.
   *
   * @param {Object<number, number>} table atomic number -> 0xRRGGBB
   * @returns {string} the scheme id to pass as `colorScheme`
   */
  function registerAvogadroScheme(table) {
    requireNgl();
    var colours = table || {};
    var fallback = 0x7F7F7F;
    // A function, not source text: `addScheme('...')` throws
    // "TypeError: e.call is not a function" on NGL 2.5.0.
    var scheme = function () {
      this.atomColor = function (atom) {
        var colour = colours[atom.atomicNumber];
        return colour === undefined ? fallback : colour;
      };
    };
    return window.NGL.ColormakerRegistry.addScheme(scheme);
  }

  /** Moves a trajectory to an absolute 0-based frame. */
  function setFrame(component, frame) {
    if (!component || !component.trajList || !component.trajList.length) return false;
    var player = component.trajList[0];
    try {
      if (typeof player.setFrame === 'function') {
        player.setFrame(frame);
      } else if (player.trajectory) {
        player.trajectory.frame = frame;
      } else {
        return false;
      }
      frameSeq += 1;
      lastError = null;
      return true;
    } catch (error) {
      lastError = describe(error);
      return false;
    }
  }

  /**
   * Removes a component and frees its buffers.
   *
   * `Stage.removeComponent` already calls `component.dispose()` itself —
   * `removeComponent(e){ ... e.dispose(); ... }` — so disposing again here is a
   * double-dispose: the second call walks signals whose listener arrays have
   * already been cleared and throws `TypeError: Cannot read properties of
   * undefined (reading 'length')` from inside `Signal._indexOfListener`, with
   * nothing in the message pointing at the removal. The disposable is therefore
   * left entirely to NGL.
   */
  /**
   * Draws numbered badges at bond midpoints, as 3D text that rotates with the
   * molecule.
   *
   * Every signature detail here was measured, because the obvious call throws:
   *
   *   * `Shape.addLabel` is **deprecated and misdescribes its own signature**:
   *     `addLabel(e,t,i,n){ console.warn("Shape.addLabel is deprecated, use
   *     .addText instead"); return this.addText(e,t,i,n) }`. It forwards its
   *     arguments unchanged, so despite the name its order is really
   *     `(position, color, size, text)`.
   *   * The real method is `Shape.addText(position, color, size, text)`.
   *   * The colour must be an **array** `[r, g, b]`. A hex string *or a bare
   *     number* falls through `valueToShape`'s colour branch to
   *     `buffer.push.apply(buffer, colour)`, and `Function.prototype.apply`
   *     rejects a primitive with "CreateListFromArrayLike called on non-object".
   *     A position array is fine — the same branch pushes arrays happily.
   *
   * Colours are given as 0..1 sRGB fractions, which is what NGL's colour buffers
   * hold: its own `element` scheme leaves `#909090` in the buffer as 0.5647.
   *
   * The camera is deliberately not re-fitted. Badges appear and disappear as the
   * user toggles them, and calling `autoView()` here would yank the view on every
   * frame change.
   *
   * @param {object} stage          an NGL.Stage
   * @param {object|null} previous  the badge component to remove, or null
   * @param {Float32Array} positions flat x,y,z per label
   * @param {Int32Array} indices     the 1-based number to print per label
   * @returns {object|null} the new component, or null when there is nothing to draw
   */
  function setBondLabels(stage, previous, positions, indices) {
    badgeCallCount += 1;
    if (previous) removeComponent(stage, previous);
    if (!stage || !indices || !indices.length) return null;

    try {
      var shape = new window.NGL.Shape('bond-badges');
      var colour = [1.0, 1.0, 1.0]; // White for maximum visibility
      for (var i = 0; i < indices.length; i++) {
        shape.addText(
          [positions[i * 3], positions[i * 3 + 1], positions[i * 3 + 2]],
          colour,
          4.5,
          String(indices[i])
        );
      }

      var component = stage.addComponentFromObject(shape);
      component.addRepresentation('buffer', {
        depthTest: false,
      });
      badgeSeq += 1;
      lastBadges = { seq: badgeSeq, count: indices.length };
      lastError = null;
      return component;
    } catch (error) {
      lastError = describe(error);
      return null;
    }
  }

  function removeComponent(stage, component) {
    if (!stage || !component) return;
    try {
      stage.removeComponent(component);
    } catch (error) {
      lastError = describe(error);
    }
  }

  /**
   * The viewer's current orientation, as 16 column-major doubles.
   *
   * This is what lets a Flutter-drawn axes triad follow the WebGL camera: NGL
   * 2.5.0 has no orientation widget of its own (`setParameters({axes:true})` is
   * ignored and `NGL.Axes` is undefined), so the triad has to be drawn outside
   * the canvas and kept in step from here.
   */
  function cameraOrientation(stage) {
    if (!stage || !stage.viewerControls
        || typeof stage.viewerControls.getOrientation !== 'function') {
      return null;
    }
    try {
      var elements = stage.viewerControls.getOrientation();
      if (!elements || elements.length === undefined) return null;
      return Array.prototype.slice.call(elements);
    } catch (error) {
      lastError = describe(error);
      return null;
    }
  }

  window.QuantumForgeNgl = {
    available: typeof window.NGL !== 'undefined',
    version: (window.NGL && window.NGL.version) ? window.NGL.version : null,

    loadSdf: loadSdf,
    loadRemoteMd: loadRemoteMd,
    registerAvogadroScheme: registerAvogadroScheme,
    setFrame: setFrame,
    setBondLabels: setBondLabels,
    removeComponent: removeComponent,
    cameraOrientation: cameraOrientation,
    addRepresentation: function (component, settings) {
      try {
        return addRepresentation(component, settings || {});
      } catch (error) {
        lastError = describe(error);
        return false;
      }
    },
    replaceRepresentation: replaceRepresentation,
    autoView: function (stage) { safeAutoView(stage); },

    /** Summary of the last structure handed to NGL. */
    lastLoadInfo: function () { return lastLoad; },
    /** The stage the last load went into, with its scene parameters read back. */
    lastStageInfo: function () {
      if (!lastStage) return null;
      var params = (lastStage.viewer && lastStage.viewer.parameters) || {};
      var renderer = lastStage.viewer ? lastStage.viewer.renderer : null;
      return {
        components: lastStage.compList ? lastStage.compList.length : null,
        width: (lastStage.viewer && lastStage.viewer.width) || null,
        height: (lastStage.viewer && lastStage.viewer.height) || null,
        cameraType: (lastStage.viewer && lastStage.viewer.camera)
          ? lastStage.viewer.camera.type : null,
        zoom: (lastStage.viewer && lastStage.viewer.camera)
          ? lastStage.viewer.camera.zoom : null,
        clipNear: params.clipNear,
        clipFar: params.clipFar,
        fogNear: params.fogNear,
        fogFar: params.fogFar,
        sampleLevel: params.sampleLevel,
        backgroundColor: params.backgroundColor,
        // Quality settings live on the viewer rather than in `parameters`.
        // three.js's own getPixelRatio() is the honest read-back: a
        // `parameters.pixelRatio` could be recorded without the backing store
        // having been resized, which is the whole point of setting it.
        pixelRatio: (renderer && typeof renderer.getPixelRatio === 'function')
          ? renderer.getPixelRatio()
          : ((lastStage.viewer && lastStage.viewer.pixelRatio) || null),
        devicePixelRatio: window.devicePixelRatio || null,
        antialiasRequested: params.antialias,
        antialiasActual: renderer ? renderer.getContext().getContextAttributes().antialias : null,
      };
    },
    /** How many frames have been applied, i.e. proof of scrubbing. */
    frameApplyCount: function () { return frameSeq; },
    /** Summary of the last badge set drawn, or null when badges are off. */
    lastBadgeInfo: function () { return lastBadges; },
    /** How many times setBondLabels was entered, i.e. bisects Dart vs NGL. */
    badgeCallInfo: function () { return badgeCallCount; },
    lastErrorInfo: function () { return lastError; },
    lastComponentInfo: function () {
      if (!lastComponent) return null;
      return {
        atoms: lastComponent.structure.atomCount,
        bonds: lastComponent.structure.bondCount,
        representations: lastComponent.reprList ? lastComponent.reprList.length : null,
        currentFrame: (lastComponent.trajList && lastComponent.trajList[0]
          && lastComponent.trajList[0].trajectory)
          ? lastComponent.trajList[0].trajectory.frame : null,
      };
    },
  };
}());
