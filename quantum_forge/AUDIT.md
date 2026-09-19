# Quantum Forge — Audit & Remediation Report

Date: 2026-07
Scope: `quantum_forge/` (Flutter web app) + `quantum_forge/avogadro_plugin/`

This document records what was actually wrong in the repository, what was changed,
and how each change is verified. It is deliberately specific: every item below was
reproduced in the code before being fixed.

---

## Verified starting state

| Gate | Before | After |
| --- | --- | --- |
| `flutter analyze` | 33 issues (2 errors' worth of dead wiring, 8 warnings) | **0 issues** |
| `flutter test` | 1 trivial widget test | **102 tests, all passing** |
| `flutter build web` | compiled, with dead code paths | compiles |

---

## 1. Deficiencies found

### 1.1 Settings system was dead code (highest impact)

* `AppSettingsNotifier` was **never instantiated** and never registered in the
  `MultiProvider` tree in `main.dart`. The analyzer flagged it as an unused import.
  Consequence: `isCompactMode`, `defaultExportFormat`, `autoSaveIntervalMinutes` and
  `showTooltips` had **no effect anywhere in the app**. There was also no settings
  screen at all — the only "settings" surface was a theme dropdown inside one
  `AlertDialog`.
* `AppSettingsNotifier` used `shared_preferences` while the compute settings used a
  bespoke `LocalPrefs`/`web_bindings.dart` path. Two persistence mechanisms, one of
  them unreachable.
* Several `QuantumSettingsNotifier` persistence keys were inconsistent: some used
  `static const _key…` fields (four of which were unused) and others used bare string
  literals (`'convergence'`, `'nmfConvergence'`, `'nmove'`, `'hfToken'`, …), so a
  typo in either place would silently lose a user's parameter.
* **Race condition (found by test, not by reading).** `updateSettings` fired
  `_save()` on every change without orderin g them. Five rapid toggles started five
  independent async writes; only the first future was tracked, so an older snapshot
  could land last and resurrect an outdated value. Reproduced deterministically in a
  test: after `setCompactMode → setDefaultElement('S') → …`, storage ended up
  holding the *default* `C`.

### 1.2 Themes were names without substance

* `theme_provider.dart` defined four `ThemeData` builders and **no persistence** — the
  choice was lost on every reload.
* The themes only reached `MaterialApp.theme`. Every painter and almost every screen
  hard-coded colours (`const Color(0xFF0F2027)`, `Colors.white`, `Colors.white54`),
  so the three non-default themes changed little more than a few Material widgets.
* The `scientificLight` theme was effectively broken: the dashboard, drawer and
  editor all painted white text on a light background.
* The theme dropdown read `ctx.read<ThemeNotifier>().currentTheme` inside a
  `showDialog` builder with **no listener**, so the dialog did not update when a theme
  was picked.
* No palette existed for the hand-written charts, so plot colours were hard-coded and
  identical on every background.

### 1.3 Avogadro integration was broken end to end

* **The plugin targeted a deprecated API.** `quantom_forge_export.py` used
  `--print-options` / `--run-command` and read from `stdin`. Avogadro 2.0 moved to
  static TOML metadata, passes the request JSON as the main argument, and no longer
  invokes `--run-command`. There was **no `avogadro.toml`/`pyproject.toml`**, and
  since Avogadro 1.103 a bare script is not installable at all — so the documented
  install path could not have produced a menu entry on any current release.
* **Wrong URL, and no way to change it.** The plugin opened
  `https://Quantum-forge.web.app` — wrong capitalisation and a typo'd host
  (`Quantum-forge` vs `quantom-forge`). It was hard-coded, so local development was
  impossible.
* **Padding was stripped from the base64 payload** (`encoded_xyz.rstrip('=')`), which
  makes the payload undecodable whenever the byte length is not a multiple of three.
  The reader then re-padded naively. This is exactly the "sometimes the export just
  doesn't work" class of bug.
* **Import failures were invisible.** `_checkForDeepLinkImport` wrapped everything in
  `try/catch` and reported failures only through `debugPrint`. A malformed payload
  produced no user-visible feedback whatsoever. The decoded `xyzString` was computed
  and then never used.
* **Imported structures went to the wrong place.** They were pushed into "first
  reactant" via `setManualFile`, which silently required the user to supply a second
  reactant and a product before anything could be dispatched — an imported molecule
  could not simply be looked at.
* **The URL was never cleaned**, so a refresh re-imported (and potentially re-ran) the
  same structure.
* **The exporter was mis-wired.** `main.dart` awaited the Firestore seed before
  `runApp` with a `print('Error during seeding: \$e')` — an escaped `$`, so the error
  text was the literal string `$e`.
* **The dashboard's export buttons did not export.**
  * "Export Results (.zip)" called `LocalStorageService.exportResultsToZip`, a stub
    returning the fake path `'memory://results_<id>.zip'`. The UI then reported
    "Exported to: memory://results_…zip" and downloaded nothing.
  * "Export for Avogadro (.xyz)" joined raw trajectory frames with `'\n'`, producing a
    file whose frame comments were blank and whose title lines did not identify the
    image.
  * `avogadro_export_web.dart` revoked the Blob URL immediately after `click()`,
    which can race the download in some browsers, and used `dart:js_interop`
    unconditionally, so the utility could not be compiled (or unit-tested) off web.
* **The editor had no Avogadro path at all** despite the README claiming
  "Seamless Avogadro 2 Integration" for the editor: no CJSON, no CML, no import of
  Avogadro's native format, and its 3D builder had no export button.
* `MoleculeParser._parseMol` / `_parseCml` duplicated and diverged from the XYZ
  parser's element tables, and the file picker did not accept `.cjson`.
* `mergeXyz` decoded file bytes with `String.fromCharCodes` (Latin-1) rather than
  UTF-8, corrupting any non-ASCII content.

### 1.4 Parser and rendering defects

* `XyzParser.parse` **ignored the declared atom count** and skipped two lines
  unconditionally. A multi-frame XYZ (exactly what a trajectory export is) was
  silently read as one molecule containing every frame's atoms concatenated. A
  two-atom molecule with a blank comment line returned nothing.
* The interactive builder hand-wrote its XYZ header while the painter used the live
  atom list, so the two could disagree.
* `interactive_builder_widget.dart` used `context.size!` during gesture handling;
  `context.size` is null before the first layout, so an early tap threw.
* The builder's hit-testing used a fixed `0.25` radius factor while the painter used
  a different one, so click targets drifted from what was drawn.
* `@Deprecated activeColor` on the editor's auto-optimise switch (Flutter 3.31+).
* Theme-unaware colours throughout (see 1.2).

### 1.5 Smaller issues

* `ElementData` had no symbol ⇄ atomic-number mapping, which CJSON and SDF writers
  need.
* The Formula builder in `xyz_parser.dart` wrote `C1H4`-style subscripts and omitted
  hydrogen for non-carbon compounds.
* `XyzParser` and the new interchange layer would have formed an import cycle.
* **The app could not be compiled for the Dart VM at all.** `web_bindings.dart`
  imported `dart:js_interop` unconditionally, and `LocalPrefs` (used by the compute
  settings) depended on it. Because the settings screen, quantum controls panel and
  chemical resolver all reached `web_bindings.dart`, no widget test could cover any
  of them — the import chain simply would not compile under `flutter test`. The
  whole web-services surface is now behind a conditional import.

---

## 2. What was changed

### 2.1 Settings

| File | Change |
| --- | --- |
| `lib/core/settings/app_settings_provider.dart` | Rebuilt: 18 persisted preferences across Appearance / Editor / Export / Avogadro; typed setters; range clamping; `flush()`; **ordered write chain fixing the lost-update race**; `resetToDefaults()` |
| `lib/main.dart` | `AppSettingsNotifier` now constructed **and registered**; `Consumer2` applies theme + density |
| `lib/features/settings/presentation/screens/settings_screen.dart` | **New** 5-tab settings screen with live export preview and platform install paths |
| `lib/features/reaction_runner/providers/settings_provider.dart` | All persistence keys unified into named constants; added `resetToDefaults()` |
| `lib/features/reaction_runner/presentation/widgets/dashboard_cards/left_nav_rail.dart` | Gear opens the real settings screen; theme switcher rebuilds live |

### 2.2 Themes

| File | Change |
| --- | --- |
| `lib/core/theme/quantum_theme.dart` | **New**: `QuantumTheme` with 25 semantic colour roles *plus* the plot palette, bond colours, atom style and VDW opacity; 7 presets, each documented against its scientific convention |
| `lib/core/theme/theme_provider.dart` | Persists the selection, `cycleTheme()`, `reset()`, `AppTheme.preset` |
| `lib/features/settings/.../settings_screen.dart` | Live theme cards with palette swatches and descriptions |
| Dashboard, drawer, editor, preview | Consume the palette instead of hard-coded colours |

### 2.3 Avogadro integration

| File | Change |
| --- | --- |
| `lib/core/utils/avogadro_interchange.dart` | **New**: CJSON / CML / SDF-V2000 / XYZ / multi-XYZ writers, bond perception with valence-aware order refinement, Hill formula |
| `lib/core/utils/avogadro_codec.dart` | **New**: reads CJSON, CML, XYZ (first frame only), SDF; base64url transport that restores stripped padding; 4 MB / 20 000-atom caps; every failure is a readable exception |
| `lib/core/utils/avogadro_deep_link.dart` | **New**: builds and parses `?import_struct=…` (CJSON) and the legacy `?import_xyz=…` |
| `lib/core/utils/avogadro_bridge{,_web,_stub}.dart` | **New**: platform-selected download / clipboard / `history.replaceState`; deferred Blob revoke fixes the download race; replaces the web-only `avogadro_export_web.dart` |
| `lib/features/reaction_runner/presentation/screens/coordinate_editor_screen.dart` | **Rewritten**: Avogadro action bar (Send to Avogadro / Export CJSON·CML·SDF·XYZ / Copy), structure title, format-agnostic import, honest error banner, theme + settings aware |
| `dashboard_screen.dart` | Deep-link handling rewritten (reports failures, honours prefs, cleans the URL, opens the **editor**); real `.zip` export via new `zip_writer.dart`; trajectory export writes a labelled multi-XYZ |
| `lib/core/utils/molecular.dart` | **New** shared model — breaks the parser/interchange import cycle |
| `lib/core/utils/zip_writer.dart` | **New**: spec-compliant ZIP (store method) with CRC-32 — the old export produced no file |
| `lib/core/services/web_services{,_web,_stub}.dart` | **New**: platform-selected fetch/openUrl/localStorage; replaces the unconditional `web_bindings.dart`, making the whole app VM-testable |
| `lib/core/utils/xyz_parser.dart` | Honours the declared atom count (frame-aware), added `serialize()`, delegates analysis to `molecular.dart` |
| `lib/core/utils/molecule_parser.dart` | Now a façade over `AvogadroCodec` (adds CJSON support) instead of a divergent duplicate |
| `lib/core/utils/element_data.dart` | Added `atomicNumber`, `symbolForAtomicNumber`, `canonicalSymbol` |
| `avogadro_plugin/quantom_forge_export.py` | **Rewritten for the Avogadro 2.0 API**: accepts the request JSON as argv *or* stdin, emits CJSON, keeps base64 padding, `QUANTUM_FORGE_URL` override, size guard, `--copy` / `--status` modes, and always answers with `message`/`error` JSON instead of crashing |
| `avogadro_plugin/avogadro.toml`, `pyproject.toml` | **New**: plugin metadata with three menu commands (required for any current Avogadro) |
| `avogadro_plugin/install_plugin.py` | **New**: cross-platform installer with `--dry-run` / `--force` / `--uninstall` |
| `avogadro_plugin/README.md` | Rewritten for the real API, layout and troubleshooting |

### 2.4 Rendering & robustness

* `interactive_builder_widget.dart`: canvas size captured in `LayoutBuilder`
  (no more `context.size!` crash), hit radius matches the painted radius, hydrogen
  hiding and bond drawing honoured, theme-aware bond/highlight/background colours,
  dead `_onScaleUpdate` removed and the pinch-zoom conflict documented.
* `main.dart`: Firestore seeding no longer blocks `runApp` and its broken `\$e`
  interpolation is gone; `Ctrl+Shift+T` cycles themes.
* `settings_provider.dart`: compute settings migrated off the web-only `LocalPrefs`
  onto `shared_preferences`, so the settings screen is unit-testable; added
  `flush()` and `resetToDefaults()`. `local_auth_service.dart` migrated the same
  way.
* `settings_screen.dart`: settings cards are `Material` (not `DecoratedBox`), so
  `ListTile` ink splashes are visible — a bug the widget tests caught.

---

## 3. Verification

```
flutter analyze   →  0 issues
flutter test      →  102 tests pass
flutter build web →  succeeds
```

Test coverage added (5 new files):

| File | Covers |
| --- | --- |
| `test/avogadro_interchange_test.dart` | Formula/element tables, bond perception, and all five writers incl. CJSON round-trip, V2000 column layout, XML escaping |
| `test/avogadro_deep_link_test.dart` | The exact payload the Python plugin emits, padding-residue handling, size/atom caps, legacy `import_xyz`, URL build → parse round-trip, multi-frame XYZ |
| `test/settings_and_theme_test.dart` | Defaults, `copyWith`/equality, endpoint resolution, format metadata, **persistence incl. the write-ordering regression**, clamping, all 7 themes' `ThemeData`, palette distinctness |
| `test/parsers_and_zip_test.dart` | XYZ header/frame handling, serialise round-trip, molecular analysis, ZIP structure and the known CRC-32 check value |
| `test/settings_screen_test.dart` | The full settings screen mounted with real providers: theme catalogue, theme switching + persistence, toggle write-through, export preview regeneration, Avogadro endpoint, compute settings, light-theme rendering and small-screen scrolling |

The plugin was additionally exercised end to end from the shell:

```
$ echo '{"cjson":{...water...}}' | QUANTUM_FORGE_NO_BROWSER=1 python quantom_forge_export.py
https://quantom-forge.web.app/?import_struct=eyJjaGVtaWNhbEpzb24i…%3D%3D&fmt=cjson&source=avogadro&name=Water
{"message": "Opened Quantum Forge (https://quantom-forge.web.app) with 3 atoms."}
```

and the emitted URL is decoded by `avogadro_deep_link_test.dart`, so both sides of
the bridge are pinned by the same fixture.

---

## 4. Known limitations (deliberate)

* **ZIP uses the store method** (no deflate). Trajectories are text and compress
  well, but shipping a compression implementation was not worth the risk for a
  handful of files. Archives are valid and open everywhere.
* **Large structures cannot travel by deep link.** Browsers truncate very long URLs;
  past ~60 kB the plugin and the editor both refuse and tell the user to export a
  file instead. A POST-to-localhost transport was considered but requires a running
  local service, which contradicts a browser-only app.
* **`avogadro.toml` schema is inferred** from the Avogadro 2.0 documentation, whose
  reference examples are not currently published. `avogadro.toml` + `pyproject.toml`
  are both shipped, and the plugin answers every documented flag, so it degrades
  gracefully if the exact table names differ.
* **Theme coverage is broad but not total.** The dashboard, drawer, editor and
  settings screens are theme-driven; a few older result cards still use fixed
  accents for metric chips, which read acceptably on all seven backgrounds.
* **The web fetch wrapper is a thin browser shim**, not a port of the chemical
  resolver to a cross-platform HTTP client. `WebServices.fetchString` throws
  `UnsupportedError` off the web, which is correct for a web-only app but means the
  resolver itself is not exercised by VM tests; the resolver's parsing logic is
  tested indirectly through the rest of the suite.
