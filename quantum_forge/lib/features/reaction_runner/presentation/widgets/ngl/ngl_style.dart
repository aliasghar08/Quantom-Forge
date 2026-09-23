// ============================================================================
// NGL style — display types, palettes and the ball-and-stick profile
// ----------------------------------------------------------------------------
// Keeps the renderer's knobs in one place so the two that were chosen against
// measurement — the radius pair and the palette — are visible and easy to
// revisit rather than buried in a call site.
//
// The representation names are NGL's own, and the mapping is deliberately one
// line per display type so it is obvious which NGL feature each Avogadro display
// type maps onto:
//
//   Ball and Stick -> `ball+stick`  (impostor spheres + cylinder bonds)
//   Licorice       -> `licorice`    (uniform 0.2 A spheres and cylinders)
//   Van der Waals  -> `spacefill`   (impostor spheres, no bonds)
//   Wireframe      -> `line`        (bonds only)
//
// All four keep NGL's impostor shaders, which is what gives smooth-edged spheres
// and the built-in ambient/diffuse/specular shading at any zoom. Nothing here
// disables lighting, fog or depth cueing.
// ============================================================================

import 'avogadro_geometry.dart' show AvogadroDisplayType;

/// Maps Avogadro's display types onto the NGL representation that draws them.
extension NglRepresentationName on AvogadroDisplayType {
  /// The NGL representation name, e.g. `ball+stick`.
  String get representation => switch (this) {
    AvogadroDisplayType.ballAndStick => 'ball+stick',
    AvogadroDisplayType.licorice => 'licorice',
    AvogadroDisplayType.vanDerWaals => 'spacefill',
    AvogadroDisplayType.wireframe => 'line',
  };
}

/// Element colour palette.
enum NglPalette {
  /// Avogadro 2's `element_color` table.
  ///
  /// Differs from Jmol on exactly three elements by design — see the upstream
  /// comment quoted in `avogadro_element_data.dart`: hydrogen is not pure white,
  /// carbon is 50 % grey (`#7F7F7F`), and fluorine is bluer to separate it from
  /// chlorine.
  avogadro('Avogadro'),

  /// The Jmol/CPK table, which is what NGL's own `colorScheme: 'element'`
  /// resolves to — measured at `#909090` for carbon.
  cpkJmol('CPK (Jmol)');

  const NglPalette(this.label);

  /// Label for the picker.
  final String label;
}

/// The ball-and-stick proportions this app renders with.
///
/// **These are not Avogadro's.** They were verified by measurement against NGL
/// 2.5.0, because the assumption that they reproduce Avogadro's ball-and-stick
/// does not survive contact with the library:
///
/// | | these parameters | Avogadro 2 |
/// |---|---|---|
/// | sphere radius | 0.15 A for **every** element | 0.3 x VDW(Z): H 0.36, C 0.531, O 0.45 |
/// | bond cylinder radius | 0.075 A | 0.1 A, flat |
///
/// NGL derives both from one `radiusSize` and cannot separate them: with the
/// default `radiusType: 'size'`, `sphere = 0.15 x radiusScale x aspectRatio` and
/// `bond = 0.15 x radiusScale`, so `aspectRatio` moves the spheres and never the
/// bonds. The Avogadro profile therefore needs per-element radii and a decoupled
/// bond radius, which is custom geometry rather than a NGL representation.
///
/// They are kept as named constants precisely so the consequence is one edit
/// away: on a small molecule this reads as a thin uniform-stick figure, not as
/// Avogadro.
const double kNglBallAndStickRadiusScale = 0.5;
const double kNglBallAndStickAspectRatio = 2.0;

/// Everything the renderer needs to draw a structure.
class NglStyle {
  const NglStyle({
    this.displayType = AvogadroDisplayType.ballAndStick,
    this.palette = NglPalette.avogadro,
    this.radiusScale = kNglBallAndStickRadiusScale,
    this.aspectRatio = kNglBallAndStickAspectRatio,
  });

  final AvogadroDisplayType displayType;
  final NglPalette palette;

  /// NGL `radiusScale`. Only meaningful for the sphere-and-cylinder types.
  final double radiusScale;

  /// NGL `aspectRatio` — applied to the spheres, not to the bonds.
  final double aspectRatio;

  NglStyle copyWith({AvogadroDisplayType? displayType, NglPalette? palette}) =>
      NglStyle(
        displayType: displayType ?? this.displayType,
        palette: palette ?? this.palette,
        radiusScale: radiusScale,
        aspectRatio: aspectRatio,
      );

  @override
  bool operator ==(Object other) =>
      other is NglStyle &&
      other.displayType == displayType &&
      other.palette == palette &&
      other.radiusScale == radiusScale &&
      other.aspectRatio == aspectRatio;

  @override
  int get hashCode =>
      Object.hash(displayType, palette, radiusScale, aspectRatio);
}
