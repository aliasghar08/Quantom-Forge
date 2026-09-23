// ============================================================================
// App Settings — workspace-wide preferences
// ----------------------------------------------------------------------------
// Before this file was wired up, [AppSettingsNotifier] was never registered in
// the provider tree, so every preference it held (compact mode, export format,
// tooltips, auto-save) silently did nothing. It is now instantiated in
// `main.dart`, consumed by the dashboard/editor/settings screen, and persisted
// through `AppStorage` (a thin wrapper over the browser's `localStorage`).
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:quantum_forge/core/services/app_storage.dart';

/// Default ColabReaction (DMF/UMA) compute backend.
///
/// The deployed Hugging Face Space that hosts the FastAPI service in
/// `backend/app/main.py`. Pre-filling it means a fresh install talks to the real
/// DMF/UMA pipeline out of the box; clear the field in Settings to fall back to
/// the local illustrative simulation, or point it at `http://127.0.0.1:7860`
/// while running the backend locally.
const String kDefaultComputeBackendUrl =
    'https://aliasgharinnocent-uma-backend.hf.space';

/// Default Transition1x GNN compute backend.
///
/// The deployed Render service hosting the FastAPI GNN molecular energy prediction
/// endpoint.
const String kDefaultGnnBackendUrl = 'https://quantom-forge-1.onrender.com';

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
    (f) =>
        f.name == name ||
        f.shortLabel.toLowerCase() == (name ?? '').toLowerCase(),
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

  /// ColabReaction (DMF/UMA) compute backend base URL. Defaults to
  /// [kDefaultComputeBackendUrl]; when empty the app runs its local
  /// illustrative simulation rather than dispatching to
  /// `<backendUrl>/reactions/submit`.
  final String backendUrl;

  /// Transition1x GNN compute backend base URL. Defaults to
  /// [kDefaultGnnBackendUrl].
  final String gnnBackendUrl;

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
    this.backendUrl = kDefaultComputeBackendUrl,
    this.gnnBackendUrl = kDefaultGnnBackendUrl,
  });

  /// True when a real compute backend has been configured.
  bool get hasComputeBackend => backendUrl.trim().isNotEmpty;

  /// True when a real GNN backend has been configured.
  bool get hasGnnBackend => gnnBackendUrl.trim().isNotEmpty;

  /// Base URL used to build Avogadro deep links.
  String get bridgeBaseUrl {
    final custom = customBaseUrl.trim();
    if (bridgeTarget == BridgeTarget.custom && custom.isNotEmpty) {
      return custom.endsWith('/')
          ? custom.substring(0, custom.length - 1)
          : custom;
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
    String? backendUrl,
    String? gnnBackendUrl,
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
      autoSaveIntervalMinutes:
          autoSaveIntervalMinutes ?? this.autoSaveIntervalMinutes,
      avogadroBridgeEnabled:
          avogadroBridgeEnabled ?? this.avogadroBridgeEnabled,
      bridgeTarget: bridgeTarget ?? this.bridgeTarget,
      customBaseUrl: customBaseUrl ?? this.customBaseUrl,
      cleanUrlAfterImport: cleanUrlAfterImport ?? this.cleanUrlAfterImport,
      autoImportDeepLink: autoImportDeepLink ?? this.autoImportDeepLink,
      backendUrl: backendUrl ?? this.backendUrl,
      gnnBackendUrl: gnnBackendUrl ?? this.gnnBackendUrl,
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
        other.autoImportDeepLink == autoImportDeepLink &&
        other.backendUrl == backendUrl &&
        other.gnnBackendUrl == gnnBackendUrl;
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
    backendUrl,
    gnnBackendUrl,
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
  static const _keyBackendUrl = '${_keyPrefix}compute_backend_url';
  static const _keyGnnBackendUrl = '${_keyPrefix}gnn_backend_url';
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
      _settings = AppSettings(
        isCompactMode: AppStorage.getBool(_keyCompactMode) ?? false,
        reduceMotion: AppStorage.getBool(_keyReduceMotion) ?? false,
        showTooltips: AppStorage.getBool(_keyShowTooltips) ?? true,
        defaultElement: AppStorage.getString(_keyDefaultElement) ?? 'C',
        defaultAutoOptimize: AppStorage.getBool(_keyAutoOptimize) ?? true,
        atomScale: _atomScaleFromName(AppStorage.getString(_keyAtomScale)),
        showBonds: AppStorage.getBool(_keyShowBonds) ?? true,
        showHydrogens: AppStorage.getBool(_keyShowHydrogens) ?? true,
        bondTolerance: AppStorage.getDouble(_keyBondTolerance) ?? 1.6,
        defaultExportFormat: ExportFormat.fromName(
          AppStorage.getString(_keyDefaultExportFormat),
        ),
        exportPrecision: AppStorage.getInt(_keyExportPrecision) ?? 5,
        includeTitleLine: AppStorage.getBool(_keyIncludeTitle) ?? true,
        autoSaveIntervalMinutes: AppStorage.getInt(_keyAutoSaveInterval) ?? 5,
        avogadroBridgeEnabled: AppStorage.getBool(_keyBridgeEnabled) ?? true,
        bridgeTarget: _bridgeTargetFromName(AppStorage.getString(_keyBridgeTarget)),
        customBaseUrl: AppStorage.getString(_keyCustomBaseUrl) ?? '',
        cleanUrlAfterImport: AppStorage.getBool(_keyCleanUrl) ?? true,
        autoImportDeepLink: AppStorage.getBool(_keyAutoImport) ?? true,
        backendUrl:
            AppStorage.getString(_keyBackendUrl) ?? kDefaultComputeBackendUrl,
        gnnBackendUrl:
            AppStorage.getString(_keyGnnBackendUrl) ?? kDefaultGnnBackendUrl,
      );
    } catch (e) {
      debugPrint('AppSettingsNotifier: could not load settings — $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  static AtomScale _atomScaleFromName(String? name) => AtomScale.values
      .firstWhere((s) => s.name == name, orElse: () => AtomScale.ballAndStick);

  static BridgeTarget _bridgeTargetFromName(String? name) => BridgeTarget.values
      .firstWhere((t) => t.name == name, orElse: () => BridgeTarget.production);

  Future<void> _save(AppSettings s) async {
    try {
      AppStorage.setBool(_keyCompactMode, s.isCompactMode);
      AppStorage.setBool(_keyReduceMotion, s.reduceMotion);
      AppStorage.setBool(_keyShowTooltips, s.showTooltips);
      AppStorage.setString(_keyDefaultElement, s.defaultElement);
      AppStorage.setBool(_keyAutoOptimize, s.defaultAutoOptimize);
      AppStorage.setString(_keyAtomScale, s.atomScale.name);
      AppStorage.setBool(_keyShowBonds, s.showBonds);
      AppStorage.setBool(_keyShowHydrogens, s.showHydrogens);
      AppStorage.setDouble(_keyBondTolerance, s.bondTolerance);
      AppStorage.setString(
        _keyDefaultExportFormat,
        s.defaultExportFormat.name,
      );
      AppStorage.setInt(_keyExportPrecision, s.exportPrecision);
      AppStorage.setBool(_keyIncludeTitle, s.includeTitleLine);
      AppStorage.setInt(_keyAutoSaveInterval, s.autoSaveIntervalMinutes);
      AppStorage.setBool(_keyBridgeEnabled, s.avogadroBridgeEnabled);
      AppStorage.setString(_keyBridgeTarget, s.bridgeTarget.name);
      AppStorage.setString(_keyCustomBaseUrl, s.customBaseUrl);
      AppStorage.setBool(_keyCleanUrl, s.cleanUrlAfterImport);
      AppStorage.setBool(_keyAutoImport, s.autoImportDeepLink);
      AppStorage.setString(_keyBackendUrl, s.backendUrl);
      AppStorage.setString(_keyGnnBackendUrl, s.gnnBackendUrl);
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
  void setAutoSaveIntervalMinutes(int value) => updateSettings(
    (s) => s.copyWith(autoSaveIntervalMinutes: value.clamp(1, 120)),
  );
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

  /// Sets the ColabReaction (DMF/UMA) compute backend base URL.
  void setBackendUrl(String value) =>
      updateSettings((s) => s.copyWith(backendUrl: value.trim()));

  /// Sets the Transition1x GNN compute backend base URL.
  void setGnnBackendUrl(String value) =>
      updateSettings((s) => s.copyWith(gnnBackendUrl: value.trim()));

  void resetToDefaults() {
    updateSettings((_) => const AppSettings());
  }
}
