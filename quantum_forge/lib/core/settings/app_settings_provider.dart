// ============================================================================
// App Settings — workspace-wide preferences
// ----------------------------------------------------------------------------
// Before this file was wired up, [AppSettingsNotifier] was never registered in
// the provider tree, so every preference it held (compact mode, export format,
// tooltips, auto-save) silently did nothing. It is now instantiated in
// `main.dart`, consumed by the dashboard/editor/settings screen, and persisted
// through SharedPreferences.
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where exported structures are stored when handed to Avogadro.
///
/// Avogadro 2 has no desktop "read from URL" hook, so Quantum Forge ships the
/// structure inside a deep link. Research users usually run the local dev
/// server while modelling, so both targets are first-class.
enum BridgeTarget {
  production,
  localhost,
  custom;

  String get label => switch (this) {
        BridgeTarget.production => 'Quantum Forge (hosted)',
        BridgeTarget.localhost => 'Local dev server (localhost)',
        BridgeTarget.custom => 'Custom URL',
      };

  String? get defaultBaseUrl => switch (this) {
        BridgeTarget.production => 'https://quantom-forge.web.app',
        BridgeTarget.localhost => 'http://localhost:8080',
        BridgeTarget.custom => null,
      };
}

/// Structure formats Quantum Forge can write.
enum ExportFormat {
  xyz,
  cjson,
  cml,
  sdf;

  String get label => switch (this) {
        ExportFormat.xyz => 'XYZ — universal cartesian coordinates',
        ExportFormat.cjson => 'CJSON — native Avogadro 2 format',
        ExportFormat.cml => 'CML — Chemical Markup Language',
        ExportFormat.sdf => 'SDF / MOL — V2000 connection table',
      };

  String get shortLabel => switch (this) {
        ExportFormat.xyz => 'XYZ',
        ExportFormat.cjson => 'CJSON',
        ExportFormat.cml => 'CML',
        ExportFormat.sdf => 'SDF',
      };

  /// File extension (without the dot) used for downloads.
  String get extension => name;

  /// MIME type used for the browser download.
  String get mimeType => switch (this) {
        ExportFormat.xyz => 'chemical/x-xyz',
        ExportFormat.cjson => 'chemical/x-cjson',
        ExportFormat.cml => 'chemical/x-cml',
        ExportFormat.sdf => 'chemical/x-mdl-molfile',
      };

  bool get isAvogadroNative => this == ExportFormat.cjson;

  static ExportFormat fromName(String? name) => ExportFormat.values.firstWhere(
        (f) => f.name == name || f.shortLabel.toLowerCase() == (name ?? '').toLowerCase(),
        orElse: () => ExportFormat.xyz,
      );
}

/// Atom decoration used by the molecular painters.
enum AtomScale {
  ballAndStick,
  spaceFilling,
  wireframe;

  String get label => switch (this) {
        AtomScale.ballAndStick => 'Ball & stick',
        AtomScale.spaceFilling => 'Space filling (VDW)',
        AtomScale.wireframe => 'Wireframe',
      };

  double get radiusFactor => switch (this) {
        AtomScale.ballAndStick => 0.25,
        AtomScale.spaceFilling => 1.0,
        AtomScale.wireframe => 0.10,
      };
}

@immutable
class AppSettings {
  // ── Appearance ────────────────────────────────────────────────────────────
  final bool isCompactMode;
  final bool reduceMotion;
  final bool showTooltips;

  // ── Editor / viewer ───────────────────────────────────────────────────────
  final String defaultElement;
  final bool defaultAutoOptimize;
  final AtomScale atomScale;
  final bool showBonds;
  final bool showHydrogens;
  final double bondTolerance;

  // ── Export ────────────────────────────────────────────────────────────────
  final ExportFormat defaultExportFormat;
  final int exportPrecision;
  final bool includeTitleLine;
  final int autoSaveIntervalMinutes;

  // ── Avogadro bridge ───────────────────────────────────────────────────────
  final bool avogadroBridgeEnabled;
  final BridgeTarget bridgeTarget;
  final String customBaseUrl;
  final bool cleanUrlAfterImport;
  final bool autoImportDeepLink;

  const AppSettings({
    this.isCompactMode = false,
    this.reduceMotion = false,
    this.showTooltips = true,
    this.defaultElement = 'C',
    this.defaultAutoOptimize = true,
    this.atomScale = AtomScale.ballAndStick,
    this.showBonds = true,
    this.showHydrogens = true,
    this.bondTolerance = 1.6,
    this.defaultExportFormat = ExportFormat.xyz,
    this.exportPrecision = 5,
    this.includeTitleLine = true,
    this.autoSaveIntervalMinutes = 5,
    this.avogadroBridgeEnabled = true,
    this.bridgeTarget = BridgeTarget.production,
    this.customBaseUrl = '',
    this.cleanUrlAfterImport = true,
    this.autoImportDeepLink = true,
  });

  /// Base URL used to build Avogadro deep links.
  String get bridgeBaseUrl {
    final custom = customBaseUrl.trim();
    if (bridgeTarget == BridgeTarget.custom && custom.isNotEmpty) {
      return custom.endsWith('/') ? custom.substring(0, custom.length - 1) : custom;
    }
    return bridgeTarget.defaultBaseUrl ?? 'https://quantom-forge.web.app';
  }

  AppSettings copyWith({
    bool? isCompactMode,
    bool? reduceMotion,
    bool? showTooltips,
    String? defaultElement,
    bool? defaultAutoOptimize,
    AtomScale? atomScale,
    bool? showBonds,
    bool? showHydrogens,
    double? bondTolerance,
    ExportFormat? defaultExportFormat,
    int? exportPrecision,
    bool? includeTitleLine,
    int? autoSaveIntervalMinutes,
    bool? avogadroBridgeEnabled,
    BridgeTarget? bridgeTarget,
    String? customBaseUrl,
    bool? cleanUrlAfterImport,
    bool? autoImportDeepLink,
  }) {
    return AppSettings(
      isCompactMode: isCompactMode ?? this.isCompactMode,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      showTooltips: showTooltips ?? this.showTooltips,
      defaultElement: defaultElement ?? this.defaultElement,
      defaultAutoOptimize: defaultAutoOptimize ?? this.defaultAutoOptimize,
      atomScale: atomScale ?? this.atomScale,
      showBonds: showBonds ?? this.showBonds,
      showHydrogens: showHydrogens ?? this.showHydrogens,
      bondTolerance: bondTolerance ?? this.bondTolerance,
      defaultExportFormat: defaultExportFormat ?? this.defaultExportFormat,
      exportPrecision: exportPrecision ?? this.exportPrecision,
      includeTitleLine: includeTitleLine ?? this.includeTitleLine,
      autoSaveIntervalMinutes: autoSaveIntervalMinutes ?? this.autoSaveIntervalMinutes,
      avogadroBridgeEnabled: avogadroBridgeEnabled ?? this.avogadroBridgeEnabled,
      bridgeTarget: bridgeTarget ?? this.bridgeTarget,
      customBaseUrl: customBaseUrl ?? this.customBaseUrl,
      cleanUrlAfterImport: cleanUrlAfterImport ?? this.cleanUrlAfterImport,
      autoImportDeepLink: autoImportDeepLink ?? this.autoImportDeepLink,
    );
  }

  /// Vertical rhythm multiplier — 1.0 relaxed, ~0.85 compact.
  double get density => isCompactMode ? 0.82 : 1.0;

  /// Scales a spacing constant according to the compact-mode preference.
  double gap(double base) => base * density;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppSettings &&
        other.isCompactMode == isCompactMode &&
        other.reduceMotion == reduceMotion &&
        other.showTooltips == showTooltips &&
        other.defaultElement == defaultElement &&
        other.defaultAutoOptimize == defaultAutoOptimize &&
        other.atomScale == atomScale &&
        other.showBonds == showBonds &&
        other.showHydrogens == showHydrogens &&
        other.bondTolerance == bondTolerance &&
        other.defaultExportFormat == defaultExportFormat &&
        other.exportPrecision == exportPrecision &&
        other.includeTitleLine == includeTitleLine &&
        other.autoSaveIntervalMinutes == autoSaveIntervalMinutes &&
        other.avogadroBridgeEnabled == avogadroBridgeEnabled &&
        other.bridgeTarget == bridgeTarget &&
        other.customBaseUrl == customBaseUrl &&
        other.cleanUrlAfterImport == cleanUrlAfterImport &&
        other.autoImportDeepLink == autoImportDeepLink;
  }

  @override
  int get hashCode => Object.hashAll([
        isCompactMode,
        reduceMotion,
        showTooltips,
        defaultElement,
        defaultAutoOptimize,
        atomScale,
        showBonds,
        showHydrogens,
        bondTolerance,
        defaultExportFormat,
        exportPrecision,
        includeTitleLine,
        autoSaveIntervalMinutes,
        avogadroBridgeEnabled,
        bridgeTarget,
        customBaseUrl,
        cleanUrlAfterImport,
        autoImportDeepLink,
      ]);
}

class AppSettingsNotifier extends ChangeNotifier {
  AppSettingsNotifier({AppSettings? initialSettings})
      : _settings = initialSettings ?? const AppSettings() {
    if (initialSettings == null) {
      _load();
    } else {
      _isInitialized = true;
    }
  }

  static const _keyPrefix = 'app_settings_';
  static const _keyCompactMode = '${_keyPrefix}compact_mode';
  static const _keyReduceMotion = '${_keyPrefix}reduce_motion';
  static const _keyShowTooltips = '${_keyPrefix}show_tooltips';
  static const _keyDefaultElement = '${_keyPrefix}default_element';
  static const _keyAutoOptimize = '${_keyPrefix}default_auto_optimize';
  static const _keyAtomScale = '${_keyPrefix}atom_scale';
  static const _keyShowBonds = '${_keyPrefix}show_bonds';
  static const _keyShowHydrogens = '${_keyPrefix}show_hydrogens';
  static const _keyBondTolerance = '${_keyPrefix}bond_tolerance';
  static const _keyDefaultExportFormat = '${_keyPrefix}default_export';
  static const _keyExportPrecision = '${_keyPrefix}export_precision';
  static const _keyIncludeTitle = '${_keyPrefix}include_title';
  static const _keyAutoSaveInterval = '${_keyPrefix}autosave_interval';
  static const _keyBridgeEnabled = '${_keyPrefix}bridge_enabled';
  static const _keyBridgeTarget = '${_keyPrefix}bridge_target';
  static const _keyCustomBaseUrl = '${_keyPrefix}bridge_custom_url';
  static const _keyCleanUrl = '${_keyPrefix}clean_url_after_import';
  static const _keyAutoImport = '${_keyPrefix}auto_import_deep_link';

  AppSettings _settings;
  bool _isInitialized = false;

  /// The in-flight persistence write, if any.
  ///
  /// Writes stay fire-and-forget for the UI (a settings toggle must never wait
  /// on the disk), but the handle is kept so callers can await durability —
  /// tests and "save before unload" flows both need that.
  Future<void>? _pendingWrite;

  AppSettings get settings => _settings;
  bool get isInitialized => _isInitialized;

  /// Completes when every queued settings write has hit storage.
  Future<void> flush() async {
    while (_pendingWrite != null) {
      final pending = _pendingWrite;
      await pending;
      if (identical(pending, _pendingWrite)) {
        _pendingWrite = null;
      }
    }
  }

  // Convenience getters so widgets do not have to reach through `.settings`.
  bool get isCompactMode => _settings.isCompactMode;
  bool get showTooltips => _settings.showTooltips;
  AtomScale get atomScale => _settings.atomScale;
  ExportFormat get defaultExportFormat => _settings.defaultExportFormat;
  int get exportPrecision => _settings.exportPrecision;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _settings = AppSettings(
        isCompactMode: prefs.getBool(_keyCompactMode) ?? false,
        reduceMotion: prefs.getBool(_keyReduceMotion) ?? false,
        showTooltips: prefs.getBool(_keyShowTooltips) ?? true,
        defaultElement: prefs.getString(_keyDefaultElement) ?? 'C',
        defaultAutoOptimize: prefs.getBool(_keyAutoOptimize) ?? true,
        atomScale: _atomScaleFromName(prefs.getString(_keyAtomScale)),
        showBonds: prefs.getBool(_keyShowBonds) ?? true,
        showHydrogens: prefs.getBool(_keyShowHydrogens) ?? true,
        bondTolerance: prefs.getDouble(_keyBondTolerance) ?? 1.6,
        defaultExportFormat:
            ExportFormat.fromName(prefs.getString(_keyDefaultExportFormat)),
        exportPrecision: prefs.getInt(_keyExportPrecision) ?? 5,
        includeTitleLine: prefs.getBool(_keyIncludeTitle) ?? true,
        autoSaveIntervalMinutes: prefs.getInt(_keyAutoSaveInterval) ?? 5,
        avogadroBridgeEnabled: prefs.getBool(_keyBridgeEnabled) ?? true,
        bridgeTarget: _bridgeTargetFromName(prefs.getString(_keyBridgeTarget)),
        customBaseUrl: prefs.getString(_keyCustomBaseUrl) ?? '',
        cleanUrlAfterImport: prefs.getBool(_keyCleanUrl) ?? true,
        autoImportDeepLink: prefs.getBool(_keyAutoImport) ?? true,
      );
    } catch (e) {
      debugPrint('AppSettingsNotifier: could not load settings — $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  static AtomScale _atomScaleFromName(String? name) =>
      AtomScale.values.firstWhere(
        (s) => s.name == name,
        orElse: () => AtomScale.ballAndStick,
      );

  static BridgeTarget _bridgeTargetFromName(String? name) =>
      BridgeTarget.values.firstWhere(
        (t) => t.name == name,
        orElse: () => BridgeTarget.production,
      );

  Future<void> _save(AppSettings s) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyCompactMode, s.isCompactMode);
      await prefs.setBool(_keyReduceMotion, s.reduceMotion);
      await prefs.setBool(_keyShowTooltips, s.showTooltips);
      await prefs.setString(_keyDefaultElement, s.defaultElement);
      await prefs.setBool(_keyAutoOptimize, s.defaultAutoOptimize);
      await prefs.setString(_keyAtomScale, s.atomScale.name);
      await prefs.setBool(_keyShowBonds, s.showBonds);
      await prefs.setBool(_keyShowHydrogens, s.showHydrogens);
      await prefs.setDouble(_keyBondTolerance, s.bondTolerance);
      await prefs.setString(_keyDefaultExportFormat, s.defaultExportFormat.name);
      await prefs.setInt(_keyExportPrecision, s.exportPrecision);
      await prefs.setBool(_keyIncludeTitle, s.includeTitleLine);
      await prefs.setInt(_keyAutoSaveInterval, s.autoSaveIntervalMinutes);
      await prefs.setBool(_keyBridgeEnabled, s.avogadroBridgeEnabled);
      await prefs.setString(_keyBridgeTarget, s.bridgeTarget.name);
      await prefs.setString(_keyCustomBaseUrl, s.customBaseUrl);
      await prefs.setBool(_keyCleanUrl, s.cleanUrlAfterImport);
      await prefs.setBool(_keyAutoImport, s.autoImportDeepLink);
    } catch (e) {
      debugPrint('AppSettingsNotifier: could not persist settings — $e');
    }
  }

  /// Applies an arbitrary transformation and persists the result.
  void updateSettings(AppSettings Function(AppSettings) updater) {
    final newSettings = updater(_settings);
    if (newSettings == _settings) return;
    _settings = newSettings;
    notifyListeners();

    // Writes are chained rather than fired in parallel: several toggles in
    // quick succession must reach storage in order, otherwise a stale write can
    // land last and resurrect an outdated value. The whole chain is a single
    // future so [flush] has exactly one thing to await. Writes are never
    // coalesced — each one persists a complete snapshot, so skipping an
    // intermediate state could lose a change that arrived mid-write.
    final previous = _pendingWrite ?? Future<void>.value();
    final chained = previous.then((_) => _save(newSettings));
    _pendingWrite = chained;
    chained.whenComplete(() {
      if (identical(_pendingWrite, chained)) {
        _pendingWrite = null;
      }
    });
  }

  // ── Typed convenience mutators used by the settings UI ────────────────────
  void setCompactMode(bool value) =>
      updateSettings((s) => s.copyWith(isCompactMode: value));
  void setReduceMotion(bool value) =>
      updateSettings((s) => s.copyWith(reduceMotion: value));
  void setShowTooltips(bool value) =>
      updateSettings((s) => s.copyWith(showTooltips: value));
  void setDefaultElement(String value) =>
      updateSettings((s) => s.copyWith(defaultElement: value));
  void setDefaultAutoOptimize(bool value) =>
      updateSettings((s) => s.copyWith(defaultAutoOptimize: value));
  void setAtomScale(AtomScale value) =>
      updateSettings((s) => s.copyWith(atomScale: value));
  void setShowBonds(bool value) =>
      updateSettings((s) => s.copyWith(showBonds: value));
  void setShowHydrogens(bool value) =>
      updateSettings((s) => s.copyWith(showHydrogens: value));
  void setBondTolerance(double value) =>
      updateSettings((s) => s.copyWith(bondTolerance: value));
  void setDefaultExportFormat(ExportFormat value) =>
      updateSettings((s) => s.copyWith(defaultExportFormat: value));
  void setExportPrecision(int value) =>
      updateSettings((s) => s.copyWith(exportPrecision: value.clamp(2, 8)));
  void setIncludeTitleLine(bool value) =>
      updateSettings((s) => s.copyWith(includeTitleLine: value));
  void setAutoSaveIntervalMinutes(int value) =>
      updateSettings((s) => s.copyWith(autoSaveIntervalMinutes: value.clamp(1, 120)));
  void setAvogadroBridgeEnabled(bool value) =>
      updateSettings((s) => s.copyWith(avogadroBridgeEnabled: value));
  void setBridgeTarget(BridgeTarget value) =>
      updateSettings((s) => s.copyWith(bridgeTarget: value));
  void setCustomBaseUrl(String value) =>
      updateSettings((s) => s.copyWith(customBaseUrl: value.trim()));
  void setCleanUrlAfterImport(bool value) =>
      updateSettings((s) => s.copyWith(cleanUrlAfterImport: value));
  void setAutoImportDeepLink(bool value) =>
      updateSettings((s) => s.copyWith(autoImportDeepLink: value));

  void resetToDefaults() {
    updateSettings((_) => const AppSettings());
  }
}
