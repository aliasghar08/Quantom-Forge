// ignore_for_file: invalid_use_of_protected_member
part of 'reaction_animation_widget.dart';

extension _ReactionAnimationCoreExt on _ReactionAnimationWidgetState {
  // ── Loading ───────────────────────────────────────────────────────────────

  void _load() {
    _ReactionAnimationWidgetState.reloadCount++;
    if (kDebugMode) {
      debugPrint('[QA] ReactionAnimationWidget._load #${_ReactionAnimationWidgetState.reloadCount} '
          '(build #${_ReactionAnimationWidgetState.buildCount}, frame=$_frame, '
          'frames=${widget.trajectoryFrames.length})');
    }
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
    } else if (widget.pdbUrl != null && widget.dcdUrl != null) {
      // It's a remote MD trajectory
      final framesLen = widget.mdFrameCount ?? 1;
      _parsedFrames = List<List<Atom>?>.filled(framesLen, null);
      _staticBonds =
          const <PerceivedBond>[]; // NGL handles bonding natively from PDB

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

}
