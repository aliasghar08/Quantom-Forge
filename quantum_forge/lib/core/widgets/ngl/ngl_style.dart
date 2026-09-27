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
    AvogadroDisplayType.hyperball => 'hyperball',
    AvogadroDisplayType.surface => 'surface',
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
const double kNglBallAndStickRadiusScale = 0.5;
const double kNglBallAndStickAspectRatio = 2.0;

/// Quality settings
enum NglQuality { low, medium, high }

/// Camera projections
enum NglCameraType { perspective, orthographic, stereo }

/// Everything the renderer needs to draw a structure.
class NglStyle {
  const NglStyle({
    this.displayType = AvogadroDisplayType.ballAndStick,
    this.palette = NglPalette.avogadro,
    this.radiusScale = kNglBallAndStickRadiusScale,
    this.aspectRatio = kNglBallAndStickAspectRatio,
    this.quality = NglQuality.high,
    this.cameraType = NglCameraType.orthographic,
    this.backgroundColor = '#000000',
    this.lightIntensity = 1.0,
    this.ambientIntensity = 0.4,
    this.spin = false,
  });

  final AvogadroDisplayType displayType;
  final NglPalette palette;
  final double radiusScale;
  final double aspectRatio;
  final NglQuality quality;
  final NglCameraType cameraType;
  final String backgroundColor;
  final double lightIntensity;
  final double ambientIntensity;
  final bool spin;

  NglStyle copyWith({
    AvogadroDisplayType? displayType,
    NglPalette? palette,
    double? radiusScale,
    double? aspectRatio,
    NglQuality? quality,
    NglCameraType? cameraType,
    String? backgroundColor,
    double? lightIntensity,
    double? ambientIntensity,
    bool? spin,
  }) =>
      NglStyle(
        displayType: displayType ?? this.displayType,
        palette: palette ?? this.palette,
        radiusScale: radiusScale ?? this.radiusScale,
        aspectRatio: aspectRatio ?? this.aspectRatio,
        quality: quality ?? this.quality,
        cameraType: cameraType ?? this.cameraType,
        backgroundColor: backgroundColor ?? this.backgroundColor,
        lightIntensity: lightIntensity ?? this.lightIntensity,
        ambientIntensity: ambientIntensity ?? this.ambientIntensity,
        spin: spin ?? this.spin,
      );

  @override
  bool operator ==(Object other) =>
      other is NglStyle &&
      other.displayType == displayType &&
      other.palette == palette &&
      other.radiusScale == radiusScale &&
      other.aspectRatio == aspectRatio &&
      other.quality == quality &&
      other.cameraType == cameraType &&
      other.backgroundColor == backgroundColor &&
      other.lightIntensity == lightIntensity &&
      other.ambientIntensity == ambientIntensity &&
      other.spin == spin;

  @override
  int get hashCode => Object.hash(
        displayType,
        palette,
        radiusScale,
        aspectRatio,
        quality,
        cameraType,
        backgroundColor,
        lightIntensity,
        ambientIntensity,
        spin,
      );
}
