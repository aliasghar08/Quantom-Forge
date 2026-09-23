# Vendored NGL

`ngl.js` is the [NGL Viewer](https://github.com/nglviewer/ngl) library, vendored
so the reaction animation renders identically regardless of network access or
CDN state.

| | |
| --- | --- |
| Version | **2.5.0** (current stable on npm — `npm view ngl dist-tags` → `latest: 2.5.0`) |
| Source | `https://cdn.jsdelivr.net/npm/ngl@2.5.0/dist/ngl.js` |
| Size | 1 292 474 bytes |
| SHA-256 | `CEAB08A04B246CD4BA799749FCE0A822C370E34B7366A3C090530EA5E8D48507` |
| Licence | MIT |

## Why vendored, and why 2.5.0

The original integration loaded
`https://cdn.jsdelivr.net/npm/ngl@2.0.0-dev.39/dist/ngl.js` from a CDN. Two
problems with that:

1. **`2.0.0-dev.39` is a 2017 pre-release**, not a stable release. `2.0.0` was
   never published to npm as a final version; the npm `latest` tag has been on
   the `2.5.x` line for years. Pinning a dev prerelease meant the app was
   running a build that no upstream release notes describe.
2. **A CDN round-trip is a single point of failure** for a tool whose whole
   purpose is producing figures that have to render the same way in a thesis,
   a seminar room, and an offline lab machine.

The API surface this project depends on is identical in both versions —
`NGL.Stage`, `NGL.Shape` (`addSphere` / `addCylinder`), `stage.addComponentFromObject`,
`stage.removeComponent`, `component.addRepresentation('buffer')`,
`stage.autoView`, `stage.handleResize` — all verified present in the 2.5.0
bundle, so the upgrade is behavioural, not API-breaking.

## Updating

```powershell
Invoke-WebRequest https://cdn.jsdelivr.net/npm/ngl@<version>/dist/ngl.js -OutFile web/ngl/ngl.js
(Get-FileHash web/ngl/ngl.js -Algorithm SHA256).Hash   # record it in the table above
```

Then re-run the browser harness (`tool/ngl_probe.cjs`) — it asserts that a stage
mounts and that frame geometry reaches NGL, which is the only thing that can
regress silently on an NGL upgrade.

## `quantum_forge_ngl.js`

Our own ~120-line bridge, loaded straight after `ngl.js`. It exists because NGL
cannot express Avogadro's geometry through its built-in representations — see
the file header, and `lib/features/reaction_runner/presentation/widgets/ngl/avogadro_geometry.dart`
for the reasoning and the scientific numbers.
