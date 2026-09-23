// ============================================================================
// Theme provider — holds the active scientific theme and persists it.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quantum_forge/core/services/app_storage.dart';

import 'quantum_theme.dart';

export 'quantum_theme.dart' show QuantumTheme, QuantumThemes, AtomRenderStyle;

/// Stable identifiers for the built-in presets.
///
/// The enum names are kept short for the settings UI; [preset] maps each one to
/// the full [QuantumTheme] palette.
enum AppTheme {
  darkMatter,
  quantumBlue,
  neonSynth,
  electronCloud,
  spectroscopy,
  scientificLight,
  journalMono;

  /// The palette behind this preset.
  QuantumTheme get preset => switch (this) {
        AppTheme.darkMatter => QuantumThemes.darkMatter,
        AppTheme.quantumBlue => QuantumThemes.quantumBlue,
        AppTheme.neonSynth => QuantumThemes.neonSynth,
        AppTheme.electronCloud => QuantumThemes.electronCloud,
        AppTheme.spectroscopy => QuantumThemes.spectroscopy,
        AppTheme.scientificLight => QuantumThemes.scientificLight,
        AppTheme.journalMono => QuantumThemes.journalMono,
      };

  String get id => preset.id;
  String get label => preset.label;
  String get family => preset.family;
  String get description => preset.description;
  IconData get icon => switch (this) {
        AppTheme.darkMatter => Icons.nightlight_round,
        AppTheme.quantumBlue => Icons.blur_circular,
        AppTheme.neonSynth => Icons.bolt,
        AppTheme.electronCloud => Icons.cloud_outlined,
        AppTheme.spectroscopy => Icons.graphic_eq,
        AppTheme.scientificLight => Icons.light_mode_outlined,
        AppTheme.journalMono => Icons.menu_book_outlined,
      };

  /// `darkMatter` → `Dark Matter`
  String get displayName => label;

  static AppTheme fromId(String? id) => AppTheme.values.firstWhere(
        (t) => t.id == id,
        orElse: () => AppTheme.darkMatter,
      );
}

class ThemeNotifier extends ChangeNotifier {
  ThemeNotifier({AppTheme? initialTheme})
      : _currentTheme = initialTheme ?? AppTheme.darkMatter {
    if (initialTheme == null) {
      _restore();
    } else {
      _isInitialized = true;
    }
  }

  static const String storageKey = 'qf_theme_id';

  AppTheme _currentTheme;
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  AppTheme get currentTheme => _currentTheme;

  /// The active palette — the single source of truth for colours.
  QuantumTheme get palette => _currentTheme.preset;

  ThemeData get themeData => palette.toThemeData();

  bool get isLight => palette.isLight;

  Future<void> _restore() async {
    try {
      _currentTheme = AppTheme.fromId(AppStorage.getString(storageKey));
    } catch (e) {
      debugPrint('ThemeNotifier: could not restore theme — $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Switches the active theme and writes the choice to disk.
  Future<void> setTheme(AppTheme theme) async {
    if (theme == _currentTheme) return;
    _currentTheme = theme;
    notifyListeners();
    try {
      AppStorage.setString(storageKey, theme.id);
    } catch (e) {
      debugPrint('ThemeNotifier: could not persist theme — $e');
    }
  }

  /// Cycles to the next preset (used by the keyboard shortcut / drawer button).
  Future<void> cycleTheme() {
    final next = AppTheme.values[(_currentTheme.index + 1) % AppTheme.values.length];
    return setTheme(next);
  }

  /// Resets to the factory default.
  Future<void> reset() => setTheme(AppTheme.darkMatter);

  /// Convenience: the active palette for a widget that rebuilds on theme change.
  static QuantumTheme paletteOf(BuildContext context) =>
      Provider.of<ThemeNotifier>(context, listen: true).palette;
}
