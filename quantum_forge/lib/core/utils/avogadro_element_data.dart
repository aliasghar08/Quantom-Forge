// ============================================================================
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

  // ── Colours ───────────────────────────────────────────────────────────────

  /// RGB colour per atomic number, as `0xRRGGBB`. Index == atomic number.
  static const List<int> colors = <int>[
    0x117FB2,
    0xF0F0F0,
    0xD9FFFF,
    0xCC80FF,
    0xC2FF00,
    0xFFB5B5,
    0x7F7F7F,
    0x3050FF,
    0xFF0D0D,
    0xB2FFFF,
    0xB2E3F5,
    0xAB5BF2,
    0x8AFF00,
    0xBFA6A6,
    0xF0C8A0,
    0xFF8000,
    0xFFFF30,
    0x1FF01F,
    0x80D1E3,
    0x8F40D4,
    0x3DFF00,
    0xE6E6E6,
    0xBFC2C7,
    0xA6A6AB,
    0x8A99C7,
    0x9C7AC7,
    0xE06633,
    0xF090A0,
    0x50D050,
    0xC88033,
    0x7D80B0,
    0xC28F8F,
    0x668F8F,
    0xBD80E3,
    0xFFA100,
    0xA62929,
    0x5CB8D1,
    0x702EB0,
    0x00FF00,
    0x94FFFF,
    0x94E0E0,
    0x73C2C9,
    0x54B5B5,
    0x3B9E9E,
    0x248F8F,
    0x0A7D8C,
    0x006985,
    0xC0C0C0,
    0xFFD98F,
    0xA67573,
    0x668080,
    0x9E63B5,
    0xD37A00,
    0x940094,
    0x429EB0,
    0x57178F,
    0x00C900,
    0x70D4FF,
    0xFFFFC7,
    0xD9FFC7,
    0xC7FFC7,
    0xA3FFC7,
    0x8FFFC7,
    0x61FFC7,
    0x45FFC7,
    0x30FFC7,
    0x1FFFC7,
    0x00FF9C,
    0x00E675,
    0x00D452,
    0x00BF38,
    0x00AB24,
    0x4DC2FF,
    0x4DA6FF,
    0x2194D6,
    0x266696,
    0x266696,
    0x175487,
    0xD0D0E0,
    0xFFD123,
    0xB8C2D0,
    0xA6544D,
    0x575961,
    0x9E4FB5,
    0xAB5C00,
    0x754F45,
    0x428296,
    0x420066,
    0x007C00,
    0x70AAF9,
    0x00BAFF,
    0x00A0FF,
    0x008EFF,
    0x007FFF,
    0x006BFF,
    0x545BF2,
    0x775BE2,
    0x894FE2,
    0xA035D3,
    0xB21ED3,
    0xB21EBA,
    0xB20CA5,
    0xBC0C87,
    0xC60066,
    0xCC0059,
    0xD1004F,
    0xD80044,
    0xE00038,
    0xE5002D,
    0xE80026,
    0xEA0023,
    0xED0021,
    0xEF001E,
    0xF2001C,
    0xF40019,
    0xF70016,
    0xF90014,
    0xFC0011,
    0xFF000F,
  ];

  // ── Radii ─────────────────────────────────────────────────────────────────

  /// Van der Waals radius in angstrom per atomic number (Alvarez radii).
  static const List<double> vanDerWaalsRadii = <double>[
    0.69,
    1.2,
    1.43,
    2.12,
    1.98,
    1.91,
    1.77,
    1.66,
    1.50,
    1.46,
    1.58,
    2.50,
    2.51,
    2.25,
    2.19,
    1.90,
    1.89,
    1.82,
    1.83,
    2.73,
    2.62,
    2.58,
    2.46,
    2.42,
    2.45,
    2.45,
    2.44,
    2.40,
    2.40,
    2.38,
    2.39,
    2.32,
    2.29,
    1.88,
    1.82,
    1.86,
    2.25,
    3.21,
    2.84,
    2.75,
    2.52,
    2.56,
    2.45,
    2.44,
    2.46,
    2.44,
    2.15,
    2.53,
    2.49,
    2.43,
    2.42,
    2.47,
    1.99,
    2.04,
    2.06,
    3.48,
    3.03,
    2.98,
    2.88,
    2.92,
    2.95,
    2.90,
    2.87,
    2.83,
    2.79,
    2.87,
    2.81,
    2.83,
    2.79,
    2.80,
    2.74,
    2.63,
    2.53,
    2.57,
    2.49,
    2.48,
    2.41,
    2.29,
    2.32,
    2.45,
    2.47,
    2.60,
    2.54,
    2.5,
    2.5,
    2.5,
    2.5,
    2.5,
    2.8,
    2.93,
    2.88,
    2.71,
    2.82,
    2.81,
    2.83,
    3.05,
    3.38,
    3.05,
    3.0,
    3.0,
    3.0,
    3.0,
    3.0,
    3.0,
    3.0,
    3.0,
    3.0,
    3.0,
    3.0,
    3.0,
    3.0,
    3.0,
    3.0,
    3.0,
    3.0,
    3.0,
    3.0,
    3.0,
    3.0,
  ];

  /// Covalent radius in angstrom per atomic number (Pyykko radii).
  static const List<double> covalentRadii = <double>[
    0.18,
    0.32,
    0.46,
    1.33,
    1.02,
    0.85,
    0.75,
    0.71,
    0.63,
    0.64,
    0.67,
    1.55,
    1.39,
    1.26,
    1.16,
    1.11,
    1.03,
    0.99,
    0.96,
    1.96,
    1.71,
    1.48,
    1.36,
    1.34,
    1.22,
    1.19,
    1.16,
    1.11,
    1.10,
    1.12,
    1.18,
    1.24,
    1.21,
    1.21,
    1.16,
    1.14,
    1.17,
    2.10,
    1.85,
    1.63,
    1.54,
    1.47,
    1.38,
    1.28,
    1.25,
    1.25,
    1.20,
    1.28,
    1.36,
    1.42,
    1.40,
    1.40,
    1.36,
    1.33,
    1.31,
    2.32,
    1.96,
    1.80,
    1.63,
    1.76,
    1.74,
    1.73,
    1.72,
    1.68,
    1.69,
    1.68,
    1.67,
    1.66,
    1.65,
    1.64,
    1.70,
    1.62,
    1.52,
    1.46,
    1.37,
    1.31,
    1.29,
    1.22,
    1.23,
    1.24,
    1.33,
    1.44,
    1.44,
    1.51,
    1.45,
    1.47,
    1.42,
    2.23,
    2.01,
    1.86,
    1.75,
    1.69,
    1.70,
    1.71,
    1.72,
    1.66,
    1.66,
    1.68,
    1.68,
    1.65,
    1.67,
    1.73,
    1.76,
    1.61,
    1.57,
    1.49,
    1.43,
    1.41,
    1.34,
    1.29,
    1.28,
    1.21,
    1.22,
    1.36,
    1.43,
    1.62,
    1.75,
    1.65,
    1.57,
  ];

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
