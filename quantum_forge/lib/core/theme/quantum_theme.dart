// ============================================================================
// Quantum Forge — Theme Presets
// ----------------------------------------------------------------------------
// Every preset in this file is derived from a real convention in computational
// chemistry, spectroscopy or scientific publishing, so that the visual language
// of the workstation matches the mental model of the researcher using it:
//
//   Dark Matter      — deep-field background, emission-line accent (default)
//   Quantum Blue     — Cherenkov / orbital-isosurface blue
//   Neon Synth       — laser + emission-spectrum neon on a violet vacuum
//   Electron Cloud   — cyan electron-density isosurface, high VDW opacity
//   Spectroscopy     — low-glare slate tuned for reading IR / UV-Vis traces
//   Scientific Light — print-quality light theme for figures and projection
//   Journal Mono     — Okabe–Ito colour-blind safe, greyscale-first for print
//
// A preset is more than a ColorScheme: it also carries the palette used by the
// hand-written 2D/3D painters (energy profile, Arrhenius plot, IR sticks,
// ball-and-stick renderer) so plots stay readable on every background.
// ============================================================================

import 'package:flutter/material.dart';

/// Rendering style used by the custom molecular painters.
enum AtomRenderStyle {
  /// Classic ball-and-stick with specular highlight (default).
  ballAndStick,

  /// Flatter, matte spheres — fastest to paint, best for large systems.
  matte,

  /// Metallic / chrome look for presentation screenshots.
  metallic,

  /// Translucent spheres so buried atoms stay visible.
  glass,
}

/// All colours and rendering hints a theme contributes to the workstation.
@immutable
class QuantumTheme {
  final String id;

  /// Human readable name, e.g. `Electron Cloud`.
  final String label;

  /// Scientific family this preset belongs to, e.g. `Spectroscopy`.
  final String family;

  /// One-line explanation shown under the name in Settings → Appearance.
  final String description;

  final Brightness brightness;
  final Color accent;
  final Color accentAlt;

  final Color scaffold;
  final Color panel;
  final Color panelAlt;
  final Color border;

  /// Page background gradient (top-left → bottom-right).
  final List<Color> backgroundGradient;

  /// Background used behind the 3D viewport / code editor.
  final Color viewport;

  /// Shadow colour used for glowing accents (use alpha 0 for neutral themes).
  final Color glow;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  /// Background for the app drawer.
  final Color drawer;
  final List<Color> drawerGradient;

  /// Colours used to outline "good / warning / danger" states.
  final Color success;
  final Color warning;
  final Color danger;

  /// Categorical palette for charts (energy profile, Arrhenius, IR, orbitals).
  /// Ordered for maximum separation on the theme background.
  final List<Color> plotPalette;

  /// Grid lines and axis labels for the hand-painted charts.
  final Color plotGrid;
  final Color plotAxis;

  /// Molecule viewer specifics.
  final Color bondColor;
  final Color bondHighlight;
  final AtomRenderStyle atomStyle;

  /// Default opacity for van-der-Waals / electron-cloud surfaces (0.0–1.0).
  final double vdwOpacity;

  const QuantumTheme({
    required this.id,
    required this.label,
    required this.family,
    required this.description,
    required this.brightness,
    required this.accent,
    required this.accentAlt,
    required this.scaffold,
    required this.panel,
    required this.panelAlt,
    required this.border,
    required this.backgroundGradient,
    required this.viewport,
    required this.glow,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.drawer,
    required this.drawerGradient,
    required this.success,
    required this.warning,
    required this.danger,
    required this.plotPalette,
    required this.plotGrid,
    required this.plotAxis,
    required this.bondColor,
    required this.bondHighlight,
    required this.atomStyle,
    required this.vdwOpacity,
  });

  bool get isLight => brightness == Brightness.light;

  /// Panels that sit on top of a light background need dark text, and vice
  /// versa. Widgets use this instead of hard-coding `Colors.white`.
  Color get onPanel => isLight ? const Color(0xFF10151C) : Colors.white;

  Color get onAccent =>
      ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
          ? Colors.white
          : const Color(0xFF06121A);

  /// Convenience accessor for charts: colour `i` of the categorical palette.
  Color plotColor(int i) => plotPalette[i % plotPalette.length];

  /// Builds the Material [ThemeData] that wraps the palette.
  ThemeData toThemeData() {
    final scheme = isLight
        ? ColorScheme.fromSeed(
            seedColor: accent,
            brightness: Brightness.light,
          ).copyWith(
            primary: accent,
            secondary: accentAlt,
            surface: panel,
            surfaceTint: Colors.transparent,
            onSurface: textPrimary,
          )
        : ColorScheme.fromSeed(
            seedColor: accent,
            brightness: Brightness.dark,
          ).copyWith(
            primary: accent,
            secondary: accentAlt,
            surface: panel,
            surfaceTint: Colors.transparent,
            onSurface: textPrimary,
          );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      canvasColor: panel,
      dividerColor: border,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: panel,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: border),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: panel,
        surfaceTintColor: Colors.transparent,
      ),
      drawerTheme: DrawerThemeData(backgroundColor: drawer),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panelAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: accent, width: 1.4),
        ),
        labelStyle: TextStyle(color: textSecondary),
        hintStyle: TextStyle(color: textMuted),
      ),
      textTheme: _textTheme(),
      iconTheme: IconThemeData(color: textSecondary, size: 20),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: panelAlt,
        contentTextStyle: TextStyle(color: textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: panelAlt,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: border),
        ),
        textStyle: TextStyle(color: textPrimary, fontSize: 12),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? accent : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? accent.withValues(alpha: 0.4)
              : null,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        thumbColor: accent,
        inactiveTrackColor: accent.withValues(alpha: 0.18),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),
      listTileTheme: ListTileThemeData(
        iconColor: textSecondary,
        textColor: textPrimary,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: panelAlt,
        selectedColor: accent.withValues(alpha: 0.22),
        side: BorderSide(color: border),
        labelStyle: TextStyle(color: textPrimary, fontSize: 12),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: panelAlt,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border),
        ),
      ),
    );

    return base;
  }

  TextTheme _textTheme() {
    final base = isLight ? Typography.blackMountainView : Typography.whiteMountainView;
    return base.copyWith(
      bodyLarge: base.bodyLarge?.copyWith(color: textPrimary),
      bodyMedium: base.bodyMedium?.copyWith(color: textSecondary),
      bodySmall: base.bodySmall?.copyWith(color: textMuted),
      titleLarge: base.titleLarge?.copyWith(color: textPrimary, fontWeight: FontWeight.w700),
      titleMedium: base.titleMedium?.copyWith(color: textPrimary, fontWeight: FontWeight.w600),
      labelLarge: base.labelLarge?.copyWith(color: textSecondary),
    );
  }

  @override
  bool operator ==(Object other) => other is QuantumTheme && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// The built-in preset catalogue, keyed by stable id.
class QuantumThemes {
  const QuantumThemes._();

  // ── 1. Dark Matter ────────────────────────────────────────────────────────
  static const darkMatter = QuantumTheme(
    id: 'dark_matter',
    label: 'Dark Matter',
    family: 'Deep field',
    description:
        'Deep-field background with an emission-line accent. Low glare for long '
        'optimisation runs.',
    brightness: Brightness.dark,
    accent: Color(0xFF4FC3F7),
    accentAlt: Color(0xFF80DEEA),
    scaffold: Color(0xFF0F2027),
    panel: Color(0xFF13232B),
    panelAlt: Color(0xFF1B2E38),
    border: Color(0x1AFFFFFF),
    backgroundGradient: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
    viewport: Color(0xFF0A1519),
    glow: Color(0x4D4FC3F7),
    textPrimary: Color(0xFFF2F7FA),
    textSecondary: Color(0xFFBFD3DC),
    textMuted: Color(0xFF7E97A3),
    drawer: Color(0xFF0D1B2A),
    drawerGradient: [Color(0xFF0D1B2A), Color(0xFF1B263B)],
    success: Color(0xFF69F0AE),
    warning: Color(0xFFFFAB40),
    danger: Color(0xFFFF5252),
    plotPalette: [
      Color(0xFF4FC3F7),
      Color(0xFFFFAB40),
      Color(0xFF69F0AE),
      Color(0xFFB39DDB),
      Color(0xFFFF80AB),
      Color(0xFF80CBC4),
    ],
    plotGrid: Color(0x1AFFFFFF),
    plotAxis: Color(0x66FFFFFF),
    bondColor: Color(0xFFB0BEC5),
    bondHighlight: Color(0xFF4FC3F7),
    atomStyle: AtomRenderStyle.ballAndStick,
    vdwOpacity: 0.18,
  );

  // ── 2. Quantum Blue ───────────────────────────────────────────────────────
  static const quantumBlue = QuantumTheme(
    id: 'quantum_blue',
    label: 'Quantum Blue',
    family: 'Orbital',
    description:
        'Cherenkov-blue chrome over near-black carbon. Isosurface-style accents '
        'for orbital and density plots.',
    brightness: Brightness.dark,
    accent: Color(0xFF29B6F6),
    accentAlt: Color(0xFF18FFFF),
    scaffold: Color(0xFF101820),
    panel: Color(0xFF14202B),
    panelAlt: Color(0xFF1B2A38),
    border: Color(0x1F29B6F6),
    backgroundGradient: [Color(0xFF0B1218), Color(0xFF101820), Color(0xFF16324A)],
    viewport: Color(0xFF080E14),
    glow: Color(0x5529B6F6),
    textPrimary: Color(0xFFEAF6FF),
    textSecondary: Color(0xFFA8C6DE),
    textMuted: Color(0xFF6E8CA6),
    drawer: Color(0xFF0C141C),
    drawerGradient: [Color(0xFF0C141C), Color(0xFF12283C)],
    success: Color(0xFF64FFDA),
    warning: Color(0xFFFFC400),
    danger: Color(0xFFFF5370),
    plotPalette: [
      Color(0xFF29B6F6),
      Color(0xFF18FFFF),
      Color(0xFF7C4DFF),
      Color(0xFF64FFDA),
      Color(0xFFFFC400),
      Color(0xFFFF5370),
    ],
    plotGrid: Color(0x1F29B6F6),
    plotAxis: Color(0x8029B6F6),
    bondColor: Color(0xFF9FB8CC),
    bondHighlight: Color(0xFF18FFFF),
    atomStyle: AtomRenderStyle.metallic,
    vdwOpacity: 0.22,
  );

  // ── 3. Neon Synth ─────────────────────────────────────────────────────────
  static const neonSynth = QuantumTheme(
    id: 'neon_synth',
    label: 'Neon Synth',
    family: 'Spectroscopy',
    description:
        'Laser pink and cyan on a violet vacuum — the classic emission-spectrum '
        'duo for outreach and demos.',
    brightness: Brightness.dark,
    accent: Color(0xFFFF4FA3),
    accentAlt: Color(0xFF00E5FF),
    scaffold: Color(0xFF210029),
    panel: Color(0xFF2A0634),
    panelAlt: Color(0xFF360942),
    border: Color(0x33FF4FA3),
    backgroundGradient: [Color(0xFF170020), Color(0xFF210029), Color(0xFF3A0B52)],
    viewport: Color(0xFF12001A),
    glow: Color(0x66FF4FA3),
    textPrimary: Color(0xFFFDEBFF),
    textSecondary: Color(0xFFD9B6E8),
    textMuted: Color(0xFF9C7BAB),
    drawer: Color(0xFF1B0023),
    drawerGradient: [Color(0xFF1B0023), Color(0xFF3A0B52)],
    success: Color(0xFF00E676),
    warning: Color(0xFFFFD740),
    danger: Color(0xFFFF1744),
    plotPalette: [
      Color(0xFFFF4FA3),
      Color(0xFF00E5FF),
      Color(0xFFFFD740),
      Color(0xFFB388FF),
      Color(0xFF00E676),
      Color(0xFFFF6E40),
    ],
    plotGrid: Color(0x33FF4FA3),
    plotAxis: Color(0x80FF4FA3),
    bondColor: Color(0xFFCBB2D6),
    bondHighlight: Color(0xFF00E5FF),
    atomStyle: AtomRenderStyle.glass,
    vdwOpacity: 0.3,
  );

  // ── 4. Electron Cloud ─────────────────────────────────────────────────────
  static const electronCloud = QuantumTheme(
    id: 'electron_cloud',
    label: 'Electron Cloud',
    family: 'Density',
    description:
        'Teal density-isosurface palette with translucent atoms, tuned for '
        'van-der-Waals and electron-cloud surface inspection.',
    brightness: Brightness.dark,
    accent: Color(0xFF00E5C0),
    accentAlt: Color(0xFF69F0AE),
    scaffold: Color(0xFF08171A),
    panel: Color(0xFF0C2024),
    panelAlt: Color(0xFF11302F),
    border: Color(0x2600E5C0),
    backgroundGradient: [Color(0xFF04100F), Color(0xFF08171A), Color(0xFF0D3038)],
    viewport: Color(0xFF030C0E),
    glow: Color(0x4D00E5C0),
    textPrimary: Color(0xFFE6FFFA),
    textSecondary: Color(0xFF9FD8CE),
    textMuted: Color(0xFF648F89),
    drawer: Color(0xFF061316),
    drawerGradient: [Color(0xFF061316), Color(0xFF0D3038)],
    success: Color(0xFF69F0AE),
    warning: Color(0xFFFFD180),
    danger: Color(0xFFFF8A80),
    plotPalette: [
      Color(0xFF00E5C0),
      Color(0xFF64B5F6),
      Color(0xFFAED581),
      Color(0xFFFFF176),
      Color(0xFFBA68C8),
      Color(0xFFFF8A65),
    ],
    plotGrid: Color(0x2600E5C0),
    plotAxis: Color(0x8000E5C0),
    bondColor: Color(0xFF8FC7BF),
    bondHighlight: Color(0xFF69F0AE),
    atomStyle: AtomRenderStyle.glass,
    vdwOpacity: 0.42,
  );

  // ── 5. Spectroscopy ───────────────────────────────────────────────────────
  static const spectroscopy = QuantumTheme(
    id: 'spectroscopy',
    label: 'Spectroscopy',
    family: 'Spectroscopy',
    description:
        'Low-glare slate with warm IR and violet UV-Vis accents. Built for '
        'staring at vibrational sticks and kinetic traces for hours.',
    brightness: Brightness.dark,
    accent: Color(0xFFFFB74D),
    accentAlt: Color(0xFF9575CD),
    scaffold: Color(0xFF15181F),
    panel: Color(0xFF1C2029),
    panelAlt: Color(0xFF242A35),
    border: Color(0x1FFFFFFF),
    backgroundGradient: [Color(0xFF11131A), Color(0xFF15181F), Color(0xFF1E2430)],
    viewport: Color(0xFF0D0F14),
    glow: Color(0x33FFB74D),
    textPrimary: Color(0xFFF0F1F5),
    textSecondary: Color(0xFFB9BECB),
    textMuted: Color(0xFF7C8494),
    drawer: Color(0xFF12151B),
    drawerGradient: [Color(0xFF12151B), Color(0xFF1E2430)],
    success: Color(0xFF81C784),
    warning: Color(0xFFFFB74D),
    danger: Color(0xFFE57373),
    plotPalette: [
      Color(0xFFFFB74D),
      Color(0xFF9575CD),
      Color(0xFF4DD0E1),
      Color(0xFFAED581),
      Color(0xFFF06292),
      Color(0xFFFFF176),
    ],
    plotGrid: Color(0x1FFFFFFF),
    plotAxis: Color(0x73FFFFFF),
    bondColor: Color(0xFFAEB4C0),
    bondHighlight: Color(0xFFFFB74D),
    atomStyle: AtomRenderStyle.ballAndStick,
    vdwOpacity: 0.2,
  );

  // ── 6. Scientific Light ───────────────────────────────────────────────────
  static const scientificLight = QuantumTheme(
    id: 'scientific_light',
    label: 'Scientific Light',
    family: 'Publication',
    description:
        'Print-ready light theme with AA-contrast text. Use it for figures, '
        'projectors and bright offices.',
    brightness: Brightness.light,
    accent: Color(0xFF1565C0),
    accentAlt: Color(0xFF00897B),
    scaffold: Color(0xFFF5F7FA),
    panel: Color(0xFFFFFFFF),
    panelAlt: Color(0xFFEDF1F7),
    border: Color(0x1F0B2545),
    backgroundGradient: [Color(0xFFF7F9FC), Color(0xFFEDF2F8), Color(0xFFE3EAF3)],
    viewport: Color(0xFFF2F5F9),
    glow: Color(0x00000000),
    textPrimary: Color(0xFF101828),
    textSecondary: Color(0xFF475467),
    textMuted: Color(0xFF7A8699),
    drawer: Color(0xFFFFFFFF),
    drawerGradient: [Color(0xFFFFFFFF), Color(0xFFF1F5FA)],
    success: Color(0xFF2E7D32),
    warning: Color(0xFFE65100),
    danger: Color(0xFFC62828),
    plotPalette: [
      Color(0xFF1565C0),
      Color(0xFFE65100),
      Color(0xFF2E7D32),
      Color(0xFF6A1B9A),
      Color(0xFFAD1457),
      Color(0xFF00838F),
    ],
    plotGrid: Color(0x1A0B2545),
    plotAxis: Color(0x590B2545),
    bondColor: Color(0xFF6B7785),
    bondHighlight: Color(0xFF1565C0),
    atomStyle: AtomRenderStyle.matte,
    vdwOpacity: 0.22,
  );

  // ── 7. Journal Mono ───────────────────────────────────────────────────────
  static const journalMono = QuantumTheme(
    id: 'journal_mono',
    label: 'Journal Mono',
    family: 'Publication',
    description:
        'Greyscale-first, Okabe–Ito safe palette. Maximum legibility when a '
        'figure is printed in black and white.',
    brightness: Brightness.light,
    accent: Color(0xFF0072B2),
    accentAlt: Color(0xFFD55E00),
    scaffold: Color(0xFFFCFCFC),
    panel: Color(0xFFFFFFFF),
    panelAlt: Color(0xFFF0F0F0),
    border: Color(0x29000000),
    backgroundGradient: [Color(0xFFFFFFFF), Color(0xFFF7F7F7), Color(0xFFEFEFEF)],
    viewport: Color(0xFFFFFFFF),
    glow: Color(0x00000000),
    textPrimary: Color(0xFF000000),
    textSecondary: Color(0xFF3C3C3C),
    textMuted: Color(0xFF6E6E6E),
    drawer: Color(0xFFFFFFFF),
    drawerGradient: [Color(0xFFFFFFFF), Color(0xFFF0F0F0)],
    success: Color(0xFF009E73),
    warning: Color(0xFFE69F00),
    danger: Color(0xFFD55E00),
    plotPalette: [
      Color(0xFF0072B2), // Okabe–Ito blue
      Color(0xFFD55E00), // vermillion
      Color(0xFF009E73), // bluish green
      Color(0xFFCC79A7), // reddish purple
      Color(0xFFE69F00), // orange
      Color(0xFF56B4E9), // sky blue
    ],
    plotGrid: Color(0x1F000000),
    plotAxis: Color(0x66000000),
    bondColor: Color(0xFF4D4D4D),
    bondHighlight: Color(0xFF0072B2),
    atomStyle: AtomRenderStyle.matte,
    vdwOpacity: 0.25,
  );

  /// All presets in display order.
  static const List<QuantumTheme> all = [
    darkMatter,
    quantumBlue,
    neonSynth,
    electronCloud,
    spectroscopy,
    scientificLight,
    journalMono,
  ];

  static QuantumTheme byId(String id) => all.firstWhere(
        (t) => t.id == id,
        orElse: () => darkMatter,
      );

  /// Presets grouped for the settings UI: family → presets.
  static Map<String, List<QuantumTheme>> get byFamily {
    final grouped = <String, List<QuantumTheme>>{};
    for (final theme in all) {
      grouped.putIfAbsent(theme.family, () => []).add(theme);
    }
    return grouped;
  }
}
