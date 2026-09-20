# ColabReaction animation parity

The reaction animation in
`lib/features/reaction_runner/presentation/widgets/reaction_animation_widget.dart`
mirrors the visualiser shipped with **ColabReaction** — the notebook cell titled
*"Latest Molecule Animation Visualizer"*.

Upstream reference: `BILAB/ColabReaction` → `ColabReaction.ipynb`.
The notebook uses `panel_3dmol.Mol3DViewer` plus `param` for its controls.

> Note on the two copies of the notebook: the local working copy carries saved
> cell outputs (≈12.5 MB, mostly embedded Bokeh/Panel JS), while the upstream
> source is ≈0.13 MB. The animation code is identical in both.

## What was matched

| ColabReaction | Quantum Forge |
|---|---|
| `current_frame = param.Integer(0, bounds=(0, n-1))` | `_frameIndex`, clamped to the trajectory length |
| `animation_speed = param.Integer(200, bounds=(10, 2000))` | speed slider in **ms per frame**, 10–2000, default 200 |
| `loop_mode = param.Selector('forward', ['forward','backward','pingpong'])` | loop chips: `forward` / `backward` / `pingpong` |
| `Mol3DViewer(animate=False, current_frame=0, total_frames=n)` | starts at frame 0, driven by `_startTicker()` |
| `mol_viewer.addFrames(xyz_frames, 'xyz')` | trajectory frames parsed from the API response or bundled XYZ |
| ⏮ Start · ⏪ Step · ⏩ Step · ⏭ End | identical navigation row (`_buildTransportControls`) |
| "Current Frame Information": frame, energy, progress, status, speed, loop | `_buildFrameInfo()` readout |
| `stopAnimationImmediate()` | `_stop()` — cancels the ticker and calls `AnimationController.stop()`, holding the current frame |
| energy plot cursor follows the current frame | `_drawEnergyPlot` cursor, driven by the same coordinate |

## Deliberate differences

- **Time base.** ColabReaction sets a discrete frame index; the painter here consumes a
  normalised `0..1` coordinate. `_gotoFrame()` therefore tweens the controller to the
  target across exactly one interval, so stepping is discrete and controllable without the
  motion jumping between frames.
- **Autoplay.** The notebook builds its viewer with `animate=False` and waits for Play.
  The dashboard card autoplays instead, because a frozen molecule in a scrolling results
  page reads as a broken widget. Play/Stop sits in the card header.
- **No transition-state dwell.** The previous continuous cycle lingered ≈40 % of its loop
  at the transition state. Uniform frame stepping — what the notebook does — removes that.
  The phase band labels (*Approach → Transition State → Separation → Products*) still track
  position, so the TS is still called out; it simply is not slowed down.

## Testing note

A freshly scheduled ticker takes its **first tick at elapsed 0**, so a single
`pump(duration)` leaves a tween at its starting value. Frame-stepping tests must pump
twice:

```dart
inkWell.onTap!();
await tester.pump();                                    // ticker starts
await tester.pump(const Duration(milliseconds: 250));   // tween advances
```

Steps that assert the frame index read it back out of the `N / M` readout rather than
matching a literal string, so the assertions survive changes to the surrounding copy.

## Deployment

The animation is live at **https://quantom-forge.web.app**, built and deployed from
**this branch**:

```powershell
git checkout colab-animation
cd quantum_forge
flutter build web --release
firebase deploy --only hosting
```

`main` deliberately does **not** contain this work, so **do not deploy from `main`** —
that would rebuild the live site without the animation and silently revert it. If the work
should join the mainline later, fast-forward `main` to this branch; the build output is a
pure function of the source, so no redeploy is needed.

Verify the live bundle rather than trusting the deploy status — these strings are compiled
into `main.dart.js`:

```powershell
$js = (Invoke-WebRequest https://quantom-forge.web.app/main.dart.js).Content
$js.Contains('pingpong')      # loop mode
$js.Contains('Step forward')  # navigation row
$js.Contains('ms/frame')      # frame-interval slider
```

`quantum_forge/.firebase/` holds the CLI's deploy cache. It is regenerated on every deploy,
so it is git-ignored rather than tracked.

