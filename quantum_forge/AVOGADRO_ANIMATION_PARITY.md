# Reaction animation — NGL renderer and Avogadro parity

The reaction animation draws a computed reaction path with **NGL (WebGL)**. This
document records what is implemented, what was *measured* rather than assumed,
and — importantly — where the result matches Avogadro 2 and where it does not.

Everything below was verified against the actual library in a browser, not read
off documentation. The measurement is repeatable: `tool/ngl_probe.cjs` drives
headless Chrome against `tool/ngl_harness.dart` and asserts each property on a
live stage.

---

## 1. XYZ cannot be loaded — the trajectory is SDF

**The single most consequential finding.** The animation cannot hand a trajectory
to NGL as multi-frame XYZ. NGL has no XYZ parser:

```
Error: autoLoad: ext 'xyz' unknown
```

This is not a version quirk. Every format NGL supports appears as a quoted
extension string inside the shipped bundle — `pdb` (9 occurrences), `cif` (4),
`sdf` (6), `gro`, `mol2`, `mmtf`, `pqr`, `pdbqt`, `psf`, `prmtop`, `top`, `dcd`,
`xtc`, `trr`, `nctraj`, `cube`, `dx`, `obj`, `ply`, `kin`, `netcdf` — while
`"xyz"` appears **zero** times, in `ngl@2.5.0` and in the `ngl@2.0.0-dev.39`
prerelease the old CDN link pinned alike. Upstream has no `xyz-parser` source
file. In NGL, XYZ is only ever a *coordinate* format to attach to an existing
topology, never a structure file.

**Consequence:** `loadTrajectory(frames.join('\n'))` cannot work, and neither can
the per-frame `loadMolecule(frame)` fallback — there is no third option, because
the format itself is unsupported. The working equivalent is a **multi-model SDF**,
which NGL does support and which carries both coordinates *and* connectivity.

`lib/features/reaction_runner/presentation/widgets/ngl/avogadro_sdf.dart` writes
it. Connectivity in every model comes from `AvogadroBondPerception` — Avogadro's
own `perceiveBondsSimple` rule — so the drawn bonds are the bonds the rest of the
app reasons about.

## 2. How the trajectory is loaded and scrubbed

Loading an SDF with `{asTrajectory: true}` fills `structure.frames` but creates
**no player**: `comp.trajList` stays empty and there is no `setFrame` on either
the structure or the component. `comp.addTrajectory()` is what populates
`trajList`, and the entry it adds is what moves the coordinates. The setter is
nested:

```js
component.addTrajectory();
component.trajList[0].setFrame(n);              // works
component.trajList[0].trajectory.frame = n;     // also works
component.trajList[0].frame = n;                // silently does nothing
component.trajList[0].frameCount;               // undefined
component.trajList[0].trajectory.frameCount;    // the real count
```

Two loading paths exist, and the checkbox picks between them:

| `Dynamic bonding?` | Path | Cost |
|---|---|---|
| **off** (Avogadro's default) | one multi-model SDF, loaded once, scrubbed with `setFrame` | one parse for the whole path |
| **on** | one single-model SDF per frame, the whole structure re-sent | one parse per frame |

The second path exists because NGL's `asTrajectory` mode takes connectivity from
its first model and exposes no way to re-perceive bonds — and re-perceiving them
is exactly what the checkbox means. At Avogadro's 5 FPS default the per-frame
parse is not a problem; at extreme frame rates it is the price of correct
chemistry.

Verified in the browser: with dynamic bonding off, the harness's 5-image path
performs **exactly one** structure load and 83 applied frames — it scrubs rather
than re-parsing. With it on, the same path performs many loads and the bond count
is observed as both `2` and `1` as the stretched C–H leaves the 1.52 Å cutoff.

## 3. What was measured about radii and colours

Two points in the original brief did not survive measurement. Both were raised
before implementation, and the current behaviour reflects the decision taken.

### Ball-and-stick proportions

`radiusScale: 0.5, aspectRatio: 2.0` — measured against NGL 2.5.0 on methane:

| | these parameters | Avogadro 2 |
|---|---|---|
| sphere radius | **0.15 Å for every element** | `0.3 × VDW(Z)`: H 0.36, C 0.531, O 0.45 |
| bond cylinder radius | **0.075 Å** | `0.1 Å`, flat |

`aspectRatio` moves the spheres and never the bonds: with the default
`radiusType: 'size'`, `sphere = 0.15 × radiusScale × aspectRatio` and
`bond = 0.15 × radiusScale`. Avogadro decouples the two — per-element spheres,
one flat bond radius — which no single `aspectRatio` can express.

The constants live in `ngl_style.dart` as `kNglBallAndStickRadiusScale` and
`kNglBallAndStickAspectRatio`, deliberately named so the consequence is one edit
away. On a small molecule the current result reads as a thin uniform-stick
figure rather than as Avogadro.

### Element colours

`colorScheme: 'element'` resolves to the **Jmol** table. Read out of the shipped
bundle as a decimal literal:

```
Gg = { H: 16777215, C: 9474192, N: 3166456, O: 16715021, F: 9494608, ... }
        = #FFFFFF     = #909090   = #3050F8   = #FF0D0D   = #90E050
```

and confirmed at runtime: the `element` scheme yields `#909090` for carbon.

Avogadro deliberately differs from Jmol on exactly three elements, as its own
header states:

```cpp
// Changes - H is not completely white to add contrast on light backgrounds
//         - C is slightly darker (i.e. 50% gray - consistent with Avo1)
//         - F is bluer to add contrast with Cl (e.g. CFC compounds)
```

| | Jmol / NGL `element` | Avogadro |
|---|---|---|
| H | `#FFFFFF` | `#F0F0F0` |
| C | `#909090` | `#7F7F7F` |
| F | `#90E050` (pale green) | `#B2FFFF` (blue) |

Both tables are available at runtime from the **Colours** picker. `Avogadro` is
the default and is registered as a custom NGL scheme from
`avogadro_element_data.dart`, which is generated from upstream's
`elementdata.h` by `tool/generate_avogadro_element_data.py`.

A custom scheme must be a **function**, not source text — `addScheme('...')`
throws `TypeError: e.call is not a function` — and its `atomColor` should return
a **numeric** `0xRRGGBB`, which lands in the geometry buffer byte-exactly (a
scheme returning `0x7F7F7F` reads back `#7F7F7F`). Array returns render black, and
no pre-linearisation is needed. This also means the existing
`applyBondEnergyColoring` pattern was correct.

## 4. Camera, lighting and quality

| Setting | Value | Note |
|---|---|---|
| `backgroundColor` | `#000000` | Avogadro's shipped default is opaque black |
| `cameraType` | `orthographic` | **not** Avogadro's default — see below |
| `clipNear` / `clipFar` | `-100` / `100` | NGL defaults are `0` / `100` |
| `sampleLevel` | `2` | 4× MSAA; NGL default is `0` |
| `antialias` | `true` | verified from the WebGL context attribute, not the request |
| `pixelRatio` | `window.devicePixelRatio` | read from the DOM, verified via three.js `getPixelRatio()` |
| `fogNear` / `fogFar` | `100` / `200` | see the caveat below |

Lighting is deliberately **not** overridden. NGL's impostor shaders carry their
own ambient, diffuse and specular terms, and disabling them is how a render stops
looking like a scientific viewer.

**Orthographic is a deliberate divergence, not parity.** Avogadro's
`Rendering::Camera` constructor sets `m_projectionType(Perspective)`
(`avogadro/rendering/camera.cpp`), and NGL's own default is `'perspective'`.
Orthographic is used here because it was requested and because it avoids size
distortion with depth, which is often what a publication figure wants — but it
should not be described as matching Avogadro.

**Depth cueing is present but inert at this scale.** Fog increases with distance,
so raising either end pushes the cueing *further away* and makes it *less*
visible. Across a ~5 Å molecule whose camera sits ~40 Å out, `100/200` leaves
every atom nearer than `fogNear`, so no fog is drawn. The `50/100` default is
mostly inert too. Visible depth cueing on a molecule this size needs a range
bracketing the molecule itself, roughly `fogNear: 20, fogFar: 60`.

## 5. The axes triad

NGL 2.5.0 has **no orientation widget**. Tested directly:
`setParameters({axes: true})` is ignored, `NGL.Axes` is undefined, and no
`axes`/`axis`/`triad` property appears on the viewer. (There is an `axes`
*representation*, but that draws world axes through the molecule, not a corner
triad.)

So the triad is drawn in Flutter on top of the canvas, kept in step by polling
`viewerControls.getOrientation()` every 33 ms — a poll rather than an event
because NGL exposes no orientation-change signal and the drag is handled by the
browser inside the canvas, where Flutter sees nothing. `NglAxesTriad` takes the
16-element column-major matrix and paints in a corner, +x red / +y green / +z
blue, with negative halves thinner and dimmer.

## 6. Behaviour kept from Avogadro's Player tool

Unchanged from the earlier work and still covered by tests: `<` / `>` calling
`animate(±1)`, the 1-based `Frame: N/M` box, the frame slider, `Start:` / `End:`
bounding playback, `Frame rate:` in FPS (default 5, with 0 remapped to 5),
discrete frames with no interpolation, unconditional wrapping within
`[Start, End]`, and Avogadro's keyboard map (Space, ← →, Shift+← →, ↑ Start,
↓ End). See the control table in `test/reaction_animation_test.dart`.

## 7. Bugs the browser probe found

Each of these produced a blank or broken pane with no error in the Flutter
console, which is why the probe exists rather than trusting the code to be right:

| Symptom | Cause |
|---|---|
| Pane permanently blank | NGL sized its canvas while Flutter's platform view was still 0×0; nothing re-measured it afterwards |
| Pane blank *only* after switching to orthographic | `autoView()` computed against a 0×0 canvas fits the camera to nothing; with a perspective camera that is merely wrong-looking, with orthographic it collapses the zoom. Fixed by re-fitting once the canvas first acquires a real box |
| `TypeError: … reading 'length'` from `Signal._indexOfListener` | Calling `component.dispose()` after `stage.removeComponent()`, which already disposes — a double-dispose walking cleared listener arrays |
| Intermittent failure under dynamic bonding | NGL parses asynchronously, so the frame ticker's next load overlapped the previous one and left the engine holding an already-removed component. Loads are now serialised, coalescing to the newest request |
| Custom colour scheme had no effect | `addScheme` needs a function, not source text |

## 8. Verification

```powershell
flutter analyze                      # clean
flutter test                         # 248 tests
```

**Headless unit tests** cover what can be checked without a GPU: the SDF writer's
exact column widths (`test/avogadro_sdf_test.dart`), Avogadro's bond perception
and element tables (`test/avogadro_geometry_test.dart`), the triad's projection
maths (`test/ngl_axes_triad_test.dart`), and Avogadro's playback semantics
(`test/reaction_animation_test.dart`).

**The browser probe** covers what unit tests cannot:

```powershell
flutter build web --release -t tool/ngl_harness.dart
python -m http.server 8101 --directory build/web
$env:HARNESS_URL = "http://127.0.0.1:8101/"
node tool/ngl_probe.cjs              # exit 0 when clean
```

It navigates twice — once with dynamic bonding off, once on — and asserts on a
live stage: that NGL and the glue loaded; that the canvas is sized; that the SDF
was accepted and produced a 5-frame trajectory with a player; that the static run
performs exactly **one** structure load while applying many frames; that the
dynamic run's bond count varies; that the camera is orthographic with the
expected clip planes, sample level, pixel ratio, antialias flag, fog range and
background; and that the canvas region of a real screenshot is not uniformly
black.

The screenshot is written to `build/ngl_probe.png`. A same-page `drawImage` of a
WebGL canvas is always black without `preserveDrawingBuffer`, which is why the
pixel check reloads the captured PNG instead.

## 9. Retained but unused

`ReactionFrameGeometry` in `avogadro_geometry.dart` builds per-frame sphere and
cylinder buffers from Avogadro's exact radii, with its own tests. It is no longer
used by the renderer — the native representation path replaced it — but it is the
implementation that *would* reproduce Avogadro's sphere and bond radii exactly,
since decoupling them is precisely what it does. It is kept for now because it is
the natural first step if the radii decision in §3 is revisited, and can be
deleted with its tests with no impact on the animation.

## 10. Deploying

Live at **https://quantom-forge.web.app**, built and deployed from the
`colab-animation` branch:

```powershell
git checkout colab-animation
cd quantum_forge
flutter build web --release
firebase deploy --only hosting
```

`main` deliberately does **not** contain this work, so **do not deploy from
`main`** — that would rebuild the live site without the animation and silently
revert it.

Verify the live bundle rather than trusting the deploy status:

```powershell
$js = (Invoke-WebRequest https://quantom-forge.web.app/main.dart.js).Content
$js.Contains('Dynamic bonding?')
$js.Contains('CPK (Jmol)')
$js.Contains('loadSdf')
$ngl = (Invoke-WebRequest https://quantom-forge.web.app/ngl/ngl.js).Content
$ngl.Length -gt 1000000
```

`quantum_forge/.firebase/` holds the CLI's deploy cache; it is regenerated on
every deploy and git-ignored.
