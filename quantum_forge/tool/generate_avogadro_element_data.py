#!/usr/bin/env python3
"""Regenerate ``lib/core/utils/avogadro_element_data.dart``.

The animation claims Avogadro parity, which is only meaningful if the numbers it
draws with are Avogadro's. Rather than transcribe 119 colours and 238 radii by
hand — where a single slipped digit would be invisible and wrong — the tables are
lifted mechanically out of upstream's ``avogadro/core/elementdata.h``.

Usage
-----
    # fetch the upstream header once
    curl -L -o /tmp/elementdata.h \
        https://raw.githubusercontent.com/openchemistry/avogadrolibs/master/avogadro/core/elementdata.h

    python tool/generate_avogadro_element_data.py /tmp/elementdata.h

Then re-run ``flutter analyze`` and the element-data tests.

Why a checked-in generator rather than a comment saying "generated": the whole
point is that the file can be re-derived and diffed when upstream updates its
radii (Avogadro has revised them before), instead of being an opaque blob nobody
dares touch. Two consecutive runs are byte-identical, so such a diff shows only
real upstream changes.

Output is passed through ``dart format``, so the checked-in file is always
formatter-clean and a regeneration does not produce a whitespace-only diff.
"""

from __future__ import annotations

import re
import shutil
import subprocess
import sys
from pathlib import Path

# Both upstream arrays are `element_count` long: 119 entries, index 0 being the
# dummy element `Xx`, H at 1 and Og at 118. An index is therefore an atomic
# number, which is also how Avogadro indexes them.
EXPECTED_ENTRIES = 119

OUTPUT = (
    Path(__file__).resolve().parent.parent
    / "lib"
    / "core"
    / "utils"
    / "avogadro_element_data.dart"
)

HEADER = '''// ============================================================================
// Avogadro 2 element data — colours and radii
// ----------------------------------------------------------------------------
// The three data blocks — [AvogadroElementData.colors],
// [AvogadroElementData.vanDerWaalsRadii] and
// [AvogadroElementData.covalentRadii] — are transcribed mechanically from
// openchemistry/avogadrolibs, `avogadro/core/elementdata.h` (branch `master`),
// so they carry all 119 entries rather than a hand-picked subset.
//
// Regenerate with:
//
//     curl -L -o elementdata.h https://raw.githubusercontent.com/openchemistry/avogadrolibs/master/avogadro/core/elementdata.h
//     python tool/generate_avogadro_element_data.py elementdata.h
//
// Do not hand-edit those blocks; edit the generator and re-emit. The accessors
// below them are ordinary hand-written code and are safe to change.
//
// Why this table exists at all, when `element_data.dart` already has one: the
// app-wide table is the Jmol palette with a mixed set of radii, and it is what
// the 2D painters and the exporters use. Avogadro itself uses a *different*
// palette and different radii, so an animation that claims Avogadro parity has
// to render from Avogadro's own numbers. The upstream source spells out the
// three deliberate deviations from Jmol:
//
//     // Changes - H is not completely white to add contrast on light backgrounds
//     //         - C is slightly darker (i.e. 50% gray - consistent with Avo1)
//     //         - F is bluer to add contrast with Cl (e.g. CFC compounds)
//
// So Avogadro carbon is #7F7F7F (exactly 50% grey) — neither Jmol's #909090 nor
// the #303030 seen in Avogadro 1 — and hydrogen is #F0F0F0, not pure white.
//
// Radii provenance, quoted from the same header:
//   element_VDW       — Alvarez, doi:10.1039/C3DT50599E
//   element_covalent  — Pyykko,  doi:10.1002/chem.200800987
//
// Both arrays are 119 entries: index 0 is the dummy element `Xx`, H is 1, and
// Og is 118, so an index is the atomic number. That is also how Avogadro itself
// indexes them (`Elements::color(atomicNumber)`), which is why index 0 is kept
// rather than trimmed.
// ============================================================================

import 'element_data.dart';

/// Avogadro 2 element data: the exact palette and radii the Avogadro renderer
/// draws with, so a Quantum Forge animation can be compared frame-for-frame
/// against the same structure open in Avogadro.
class AvogadroElementData {
  AvogadroElementData._();

  /// Highest atomic number covered by the upstream tables (oganesson).
  static const int maxAtomicNumber = 118;

  /// Ball-and-stick atom sphere radius factor.
  ///
  /// `ballandstick.cpp` draws `radius = Elements::radiusVDW(Z) * atomScale`
  /// with `atomScale` defaulting to 0.3 — note this scales the *van der Waals*
  /// radius, not the covalent one.
  static const double ballAndStickAtomScale = 0.3;

  /// Ball-and-stick bond cylinder radius, in angstrom.
  ///
  /// `float m_bondRadius = 0.1f;`. This is an absolute radius, deliberately
  /// decoupled from the atom spheres — which is exactly what NGL's own
  /// `ball+stick` representation cannot express, because it derives the bond
  /// radius from the atom radius through `aspectRatio`.
  static const double ballAndStickBondRadius = 0.1;

  /// Licorice draws every sphere *and* every cylinder at one fixed radius.
  ///
  /// `licorice.cpp`: `float radius(0.2f);`
  static const double licoriceRadius = 0.2;

  /// Van der Waals draws the full van der Waals radius: `Elements::radiusVDW(Z)`
  /// with no scale factor, and no bonds at all.
  static const double vanDerWaalsScale = 1.0;

  /// Wireframe half-width, in angstrom, for a single (order 1) bond.
  ///
  /// `wireframe.cpp` passes `lineWidth * WideLineGeometry::lineWidthScale`,
  /// with `lineWidth` defaulting to 1.0 and `lineWidthScale == 0.035f`. That is
  /// a *full* width, and the shader turns it into `half-width * side`, so the
  /// radius to draw with is half of it.
  static const double wireframeBondRadius = 1.0 * 0.035 / 2.0;
'''

ACCESSORS = '''
  // ── Accessors ─────────────────────────────────────────────────────────────

  /// `0xRRGGBB` colour for an atomic number, falling back to the dummy element
  /// colour `#117FB2` for anything out of range — the same fallback
  /// `Elements::color()` performs for an invalid element.
  static int colorForAtomicNumber(int atomicNumber) {
    if (atomicNumber < 0 || atomicNumber >= colors.length) return colors[0];
    return colors[atomicNumber];
  }

  /// Van der Waals radius in angstrom, or `null` for an out-of-range element.
  ///
  /// Atomic number `0` is a real entry — it is Avogadro's dummy element `Xx`
  /// (0.69 Å) — so unknown symbols resolve to a sensible radius instead of
  /// falling off the table.
  static double? vanDerWaalsRadius(int atomicNumber) {
    if (atomicNumber < 0 || atomicNumber >= vanDerWaalsRadii.length) {
      return null;
    }
    return vanDerWaalsRadii[atomicNumber];
  }

  /// Covalent radius in angstrom, or `null` for an out-of-range element.
  ///
  /// As with [vanDerWaalsRadius], atomic number `0` resolves to the dummy
  /// element `Xx` (0.18 Å).
  static double? covalentRadius(int atomicNumber) {
    if (atomicNumber < 0 || atomicNumber >= covalentRadii.length) return null;
    return covalentRadii[atomicNumber];
  }

  /// Colour for an element *symbol*, resolved through the app-wide element
  /// table so `C`, `c`, `CL` and `Cl` all land on the same entry. Unknown
  /// symbols get the dummy element colour rather than a bright placeholder, so
  /// an unexpected element never shouts louder than the chemistry.
  static int colorForSymbol(String symbol) =>
      colorForAtomicNumber(atomicNumberForSymbol(symbol));

  /// Van der Waals radius for an element symbol, or `null` when unknown.
  static double? vanDerWaalsRadiusForSymbol(String symbol) =>
      vanDerWaalsRadius(atomicNumberForSymbol(symbol));

  /// Covalent radius for an element symbol, or `null` when unknown.
  static double? covalentRadiusForSymbol(String symbol) =>
      covalentRadius(atomicNumberForSymbol(symbol));

  /// Atomic number for an element symbol, or `0` when the symbol is unknown —
  /// which is precisely how Avogadro signals a dummy atom.
  static int atomicNumberForSymbol(String symbol) =>
      ElementData.atomicNumber(symbol);
}
'''


def strip_comments(source: str) -> str:
    """Remove C comments so numeric literals inside prose are never parsed."""
    source = re.sub(r"/\*.*?\*/", "", source, flags=re.DOTALL)
    return re.sub(r"//[^\n]*", "", source)


def parse_numeric_array(source: str, name: str) -> list[str]:
    match = re.search(rf"{name}\s*\[[^\]]*\]\s*=\s*\{{([^}}]*)\}}", source, re.DOTALL)
    if not match:
        raise SystemExit(f"could not find {name} in the header")

    values: list[str] = []
    for token in re.findall(r"-?\d+\.?\d*(?:[eE][-+]?\d+)?", match.group(1)):
        # C++ accepts `3.` as a double; Dart does not. `3.` in Dart parses as
        # `3 .` — a property access on an int — which is a genuinely confusing
        # way to fail, so normalise here rather than in the emitted file.
        if token.endswith("."):
            token += "0"
        values.append(token)

    if len(values) != EXPECTED_ENTRIES:
        raise SystemExit(f"{name}: expected {EXPECTED_ENTRIES} values, got {len(values)}")
    return values


def parse_colours(source: str) -> list[str]:
    match = re.search(
        r"element_color\s*\[[^\]]*\]\s*\[[^\]]*\]\s*=\s*\{(.*?)\n\};",
        source,
        re.DOTALL,
    )
    if not match:
        raise SystemExit("could not find element_color in the header")

    triples = re.findall(
        r"\{\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\}", match.group(1)
    )
    if len(triples) != EXPECTED_ENTRIES:
        raise SystemExit(
            f"element_color: expected {EXPECTED_ENTRIES} triples, got {len(triples)}"
        )
    return ["0x{:02X}{:02X}{:02X}".format(*map(int, triple)) for triple in triples]


def format_list(values: list[str], per_line: int, indent: str = "    ") -> str:
    """Emits a list body as a single line, for `dart format` to lay out.

    Deliberately not pre-wrapped. The Dart formatter decides the final layout,
    and its current tall style puts one entry per line for a collection that does
    not fit on one line — so pre-wrapping achieves nothing except making the
    regenerated file differ from the formatter's own output by whitespace.
    Emitting one long line and letting `dart format` finish the job is what keeps
    regeneration byte-identical, which is the property that makes "regenerate and
    diff it" worth having.
    """
    del per_line  # Kept in the signature so call sites read as intent.
    return indent + ", ".join(values) + ","


def format_output(path: Path) -> str:
    """Runs `dart format` over the emitted file.

    The lists are laid out to be readable, not to match the Dart formatter's
    wrapping exactly, so without this the checked-in file and a freshly generated
    one would differ by whitespace — and "regenerate and diff it", which is the
    whole point of having a generator, would produce a diff that is pure noise.
    """
    dart = shutil.which("dart")
    if dart is None:
        return "dart not on PATH — run `dart format` on the output before committing"

    result = subprocess.run(
        [dart, "format", str(path)],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        return f"dart format failed: {result.stderr.strip()}"
    return "formatted with dart format"


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(__doc__)
        return 2

    raw = Path(argv[1]).read_text(encoding="utf-8", errors="replace")
    source = strip_comments(raw)

    colours = parse_colours(source)
    vdw = parse_numeric_array(source, "element_VDW")
    covalent = parse_numeric_array(source, "element_covalent")

    body = [
        HEADER,
        "",
        "  // ── Colours ───────────────────────────────────────────────────────────────",
        "",
        "  /// RGB colour per atomic number, as `0xRRGGBB`. Index == atomic number.",
        "  static const List<int> colors = <int>[",
        format_list(colours, 6),
        "  ];",
        "",
        "  // ── Radii ─────────────────────────────────────────────────────────────────",
        "",
        "  /// Van der Waals radius in angstrom per atomic number (Alvarez radii).",
        "  static const List<double> vanDerWaalsRadii = <double>[",
        format_list(vdw, 8),
        "  ];",
        "",
        "  /// Covalent radius in angstrom per atomic number (Pyykko radii).",
        "  static const List<double> covalentRadii = <double>[",
        format_list(covalent, 8),
        "  ];",
        ACCESSORS,
    ]

    OUTPUT.write_text("\n".join(body), encoding="utf-8", newline="\n")
    note = format_output(OUTPUT)

    print(f"wrote {OUTPUT} ({OUTPUT.stat().st_size} bytes; {note})")
    print(f"  {len(colours)} colours, {len(vdw)} VDW radii, {len(covalent)} covalent radii")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
