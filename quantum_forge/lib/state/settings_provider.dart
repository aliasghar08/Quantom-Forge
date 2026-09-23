// ============================================================================
// Quantum Settings Provider
// Persistent state for all researcher-controlled computation parameters.
// Saved through `AppStorage` so settings survive app restarts and, in the web
// build, a plain browser refresh — no re-hydration dance required.
// Includes: catalyst selection, solvent, MLIP model, optimizer, analysis flags.
//
// Storage note: this used to go through `LocalPrefs`, a bespoke localStorage
// wrapper built on `dart:js_interop`. That made the module — and every widget
// importing it — uncompilable off the web, so none of it could be unit-tested.
// It then went through `shared_preferences`, which on this web build threw
// `MissingPluginException` on every read. It now uses `AppStorage`, the same
// backend as the workspace settings, so there is one storage story again.
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:quantum_forge/core/services/app_storage.dart';

class QuantumSettings {
  // --- System ---
  final int charge;
  final int spinMultiplicity;
  final String mlipModel;
  final String solventModel;
  final double temperatureK;

  // --- Optimizer ---
  final String optimizerAlgorithm;
  final int maxSteps;
  final String convergence;
  final String dmfConvergence;
  final int nmove;
  final bool updateTeval;
  final double maxForceNorm;
  final int nebImages;
  final double springConstant;

  // --- Credentials ---
  final String hfToken;

  // --- Catalyst ---
  final String catalyst;

  // --- Analysis ---
  final bool zpeCorrection;
  final bool computeThermochemistry;
  final bool runIrc;
  final bool frequencyAnalysis;
  final String exportFormat;
  final bool conformationalSearch;

  const QuantumSettings({
    // System
    this.charge = 0,
    this.spinMultiplicity = 1,
    this.mlipModel = 'UMA-SM',
    this.solventModel = 'Vacuum',
    this.temperatureK = 298.15,
    // Catalyst
    this.catalyst = 'None',
    // Optimizer
    this.optimizerAlgorithm = 'NEB-CI',
    this.maxSteps = 300,
    this.convergence = 'Normal',
    this.dmfConvergence = 'Normal',
    this.nmove = 20,
    this.updateTeval = false,
    this.maxForceNorm = 0.05,
    this.nebImages = 12,
    this.springConstant = 0.1,
    // Credentials
    this.hfToken = '',
    // Analysis
    this.zpeCorrection = true,
    this.computeThermochemistry = true,
    this.runIrc = false,
    this.frequencyAnalysis = true,
    this.exportFormat = 'XYZ',
    this.conformationalSearch = false,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is QuantumSettings &&
      other.charge == charge &&
      other.spinMultiplicity == spinMultiplicity &&
      other.mlipModel == mlipModel &&
      other.solventModel == solventModel &&
      other.temperatureK == temperatureK &&
      other.catalyst == catalyst &&
      other.optimizerAlgorithm == optimizerAlgorithm &&
      other.maxSteps == maxSteps &&
      other.convergence == convergence &&
      other.dmfConvergence == dmfConvergence &&
      other.nmove == nmove &&
      other.updateTeval == updateTeval &&
      other.maxForceNorm == maxForceNorm &&
      other.nebImages == nebImages &&
      other.springConstant == springConstant &&
      other.hfToken == hfToken &&
      other.zpeCorrection == zpeCorrection &&
      other.computeThermochemistry == computeThermochemistry &&
      other.runIrc == runIrc &&
      other.frequencyAnalysis == frequencyAnalysis &&
      other.exportFormat == exportFormat &&
      other.conformationalSearch == conformationalSearch;
  }

  @override
  int get hashCode {
    return Object.hashAll([
      charge,
      spinMultiplicity,
      mlipModel,
      solventModel,
      temperatureK,
      catalyst,
      optimizerAlgorithm,
      maxSteps,
      convergence,
      dmfConvergence,
      nmove,
      updateTeval,
      maxForceNorm,
      nebImages,
      springConstant,
      hfToken,
      zpeCorrection,
      computeThermochemistry,
      runIrc,
      frequencyAnalysis,
      exportFormat,
      conformationalSearch,
    ]);
  }

  QuantumSettings copyWith({
    int? charge,
    int? spinMultiplicity,
    String? mlipModel,
    String? solventModel,
    double? temperatureK,
    String? catalyst,
    String? optimizerAlgorithm,
    int? maxSteps,
    String? convergence,
    String? dmfConvergence,
    int? nmove,
    bool? updateTeval,
    double? maxForceNorm,
    int? nebImages,
    double? springConstant,
    String? hfToken,
    bool? zpeCorrection,
    bool? computeThermochemistry,
    bool? runIrc,
    bool? frequencyAnalysis,
    String? exportFormat,
    bool? conformationalSearch,
  }) {
    return QuantumSettings(
      charge: charge ?? this.charge,
      spinMultiplicity: spinMultiplicity ?? this.spinMultiplicity,
      mlipModel: mlipModel ?? this.mlipModel,
      solventModel: solventModel ?? this.solventModel,
      temperatureK: temperatureK ?? this.temperatureK,
      catalyst: catalyst ?? this.catalyst,
      optimizerAlgorithm: optimizerAlgorithm ?? this.optimizerAlgorithm,
      maxSteps: maxSteps ?? this.maxSteps,
      convergence: convergence ?? this.convergence,
      dmfConvergence: dmfConvergence ?? this.dmfConvergence,
      nmove: nmove ?? this.nmove,
      updateTeval: updateTeval ?? this.updateTeval,
      maxForceNorm: maxForceNorm ?? this.maxForceNorm,
      nebImages: nebImages ?? this.nebImages,
      springConstant: springConstant ?? this.springConstant,
      hfToken: hfToken ?? this.hfToken,
      zpeCorrection: zpeCorrection ?? this.zpeCorrection,
      computeThermochemistry: computeThermochemistry ?? this.computeThermochemistry,
      runIrc: runIrc ?? this.runIrc,
      frequencyAnalysis: frequencyAnalysis ?? this.frequencyAnalysis,
      exportFormat: exportFormat ?? this.exportFormat,
      conformationalSearch: conformationalSearch ?? this.conformationalSearch,
    );
  }

  Map<String, dynamic> toFirestoreMap() => {
        'charge': charge,
        'spin_multiplicity': spinMultiplicity,
        'mlip_model': mlipModel,
        'solvent_model': solventModel,
        'temperature_k': temperatureK,
        'catalyst': catalyst,
        'optimizer_algorithm': optimizerAlgorithm,
        'max_steps': maxSteps,
        'convergence': convergence,
        'dmf_convergence': dmfConvergence,
        'nmove': nmove,
        'update_teval': updateTeval,
        'max_force_norm': maxForceNorm,
        'neb_images': nebImages,
        'spring_constant': springConstant,
        'hf_token': hfToken,
        'zpe_correction': zpeCorrection,
        'compute_thermochemistry': computeThermochemistry,
        'run_irc': runIrc,
        'frequency_analysis': frequencyAnalysis,
        'export_format': exportFormat,
        'conformational_search': conformationalSearch,
      };
}

// -------------------------------------------------------------------------
// StateNotifier
// -------------------------------------------------------------------------
class QuantumSettingsNotifier extends ValueNotifier<QuantumSettings> {
  QuantumSettingsNotifier() : super(const QuantumSettings()) {
    _load();
  }

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// The in-flight persistence write, if any (see [flush]).
  Future<void>? _pendingWrite;

  static const _k = 'qs_';
  static const _keyCharge = '${_k}charge';
  static const _keySpin = '${_k}spin';
  static const _keyMlip = '${_k}mlip';
  static const _keySolvent = '${_k}solvent';
  static const _keyTemp = '${_k}temp';
  static const _keyAlgo = '${_k}algo';
  static const _keySteps = '${_k}steps';
  static const _keyConv = '${_k}conv';
  static const _keyDmfConv = '${_k}dmf_conv';
  static const _keyNmove = '${_k}nmove';
  static const _keyUpdateTeval = '${_k}update_teval';
  static const _keyForce = '${_k}force';
  static const _keyImages = '${_k}images';
  static const _keySpring = '${_k}spring';
  static const _keyToken = '${_k}hf_token';
  static const _keyZpe = '${_k}zpe';
  static const _keyThermo = '${_k}thermo';
  static const _keyIrc = '${_k}irc';
  static const _keyFreq = '${_k}freq';
  static const _keyExport = '${_k}export';
  static const _keyConf = '${_k}conf';
  static const _keyCatalyst = '${_k}catalyst';

  Future<void> _load() async {
    try {
      value = QuantumSettings(
        charge: AppStorage.getInt(_keyCharge) ?? 0,
        spinMultiplicity: AppStorage.getInt(_keySpin) ?? 1,
        mlipModel: AppStorage.getString(_keyMlip) ?? 'UMA-SM',
        solventModel: AppStorage.getString(_keySolvent) ?? 'Vacuum',
        temperatureK: AppStorage.getDouble(_keyTemp) ?? 298.15,
        catalyst: AppStorage.getString(_keyCatalyst) ?? 'None',
        optimizerAlgorithm: AppStorage.getString(_keyAlgo) ?? 'NEB-CI',
        maxSteps: AppStorage.getInt(_keySteps) ?? 300,
        convergence: AppStorage.getString(_keyConv) ?? 'Normal',
        dmfConvergence: AppStorage.getString(_keyDmfConv) ?? 'Normal',
        nmove: AppStorage.getInt(_keyNmove) ?? 20,
        updateTeval: AppStorage.getBool(_keyUpdateTeval) ?? false,
        maxForceNorm: AppStorage.getDouble(_keyForce) ?? 0.05,
        nebImages: AppStorage.getInt(_keyImages) ?? 12,
        springConstant: AppStorage.getDouble(_keySpring) ?? 0.1,
        hfToken: AppStorage.getString(_keyToken) ?? '',
        zpeCorrection: AppStorage.getBool(_keyZpe) ?? true,
        computeThermochemistry: AppStorage.getBool(_keyThermo) ?? true,
        runIrc: AppStorage.getBool(_keyIrc) ?? false,
        frequencyAnalysis: AppStorage.getBool(_keyFreq) ?? true,
        exportFormat: AppStorage.getString(_keyExport) ?? 'XYZ',
        conformationalSearch: AppStorage.getBool(_keyConf) ?? false,
      );
    } catch (e) {
      debugPrint('QuantumSettingsNotifier: could not load settings — $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _save(QuantumSettings s) async {
    try {
      AppStorage.setInt(_keyCharge, s.charge);
      AppStorage.setInt(_keySpin, s.spinMultiplicity);
      AppStorage.setString(_keyMlip, s.mlipModel);
      AppStorage.setString(_keySolvent, s.solventModel);
      AppStorage.setDouble(_keyTemp, s.temperatureK);
      AppStorage.setString(_keyCatalyst, s.catalyst);
      AppStorage.setString(_keyAlgo, s.optimizerAlgorithm);
      AppStorage.setInt(_keySteps, s.maxSteps);
      AppStorage.setString(_keyConv, s.convergence);
      AppStorage.setString(_keyDmfConv, s.dmfConvergence);
      AppStorage.setInt(_keyNmove, s.nmove);
      AppStorage.setBool(_keyUpdateTeval, s.updateTeval);
      AppStorage.setDouble(_keyForce, s.maxForceNorm);
      AppStorage.setInt(_keyImages, s.nebImages);
      AppStorage.setDouble(_keySpring, s.springConstant);
      AppStorage.setString(_keyToken, s.hfToken);
      AppStorage.setBool(_keyZpe, s.zpeCorrection);
      AppStorage.setBool(_keyThermo, s.computeThermochemistry);
      AppStorage.setBool(_keyIrc, s.runIrc);
      AppStorage.setBool(_keyFreq, s.frequencyAnalysis);
      AppStorage.setString(_keyExport, s.exportFormat);
      AppStorage.setBool(_keyConf, s.conformationalSearch);
    } catch (e) {
      debugPrint('QuantumSettingsNotifier: could not persist settings — $e');
    }
  }

  void update(QuantumSettings Function(QuantumSettings) updater) {
    final updated = updater(value);
    if (updated == value) return;
    value = updated;
    _pendingWrite = _save(updated);
  }

  /// Completes when the queued write has reached storage.
  ///
  /// Writes stay fire-and-forget for the UI; this handle exists so callers that
  /// need durability (tests, "save before unload") can await it.
  Future<void> flush() async {
    while (_pendingWrite != null) {
      final pending = _pendingWrite;
      await pending;
      if (identical(pending, _pendingWrite)) {
        _pendingWrite = null;
      }
    }
  }

  /// Factory defaults — used by the "Reset" affordance in the controls panel.
  void resetToDefaults() {
    if (value == const QuantumSettings()) return;
    value = const QuantumSettings();
    _pendingWrite = _save(value);
  }
}


