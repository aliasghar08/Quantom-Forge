// ============================================================================
// Quantum Settings Provider
// Persistent state for all researcher-controlled computation parameters.
// Saved through shared_preferences so settings survive app restarts.
// Includes: catalyst selection, solvent, MLIP model, optimizer, analysis flags.
//
// Storage note: this used to go through `LocalPrefs`, a bespoke localStorage
// wrapper built on `dart:js_interop`. That made the module — and every widget
// importing it — uncompilable off the web, so none of it could be unit-tested.
// It now uses the same `shared_preferences` backend as the workspace settings,
// which also means one storage story instead of two.
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      final prefs = await SharedPreferences.getInstance();
      value = QuantumSettings(
        charge: prefs.getInt(_keyCharge) ?? 0,
        spinMultiplicity: prefs.getInt(_keySpin) ?? 1,
        mlipModel: prefs.getString(_keyMlip) ?? 'UMA-SM',
        solventModel: prefs.getString(_keySolvent) ?? 'Vacuum',
        temperatureK: prefs.getDouble(_keyTemp) ?? 298.15,
        catalyst: prefs.getString(_keyCatalyst) ?? 'None',
        optimizerAlgorithm: prefs.getString(_keyAlgo) ?? 'NEB-CI',
        maxSteps: prefs.getInt(_keySteps) ?? 300,
        convergence: prefs.getString(_keyConv) ?? 'Normal',
        dmfConvergence: prefs.getString(_keyDmfConv) ?? 'Normal',
        nmove: prefs.getInt(_keyNmove) ?? 20,
        updateTeval: prefs.getBool(_keyUpdateTeval) ?? false,
        maxForceNorm: prefs.getDouble(_keyForce) ?? 0.05,
        nebImages: prefs.getInt(_keyImages) ?? 12,
        springConstant: prefs.getDouble(_keySpring) ?? 0.1,
        hfToken: prefs.getString(_keyToken) ?? '',
        zpeCorrection: prefs.getBool(_keyZpe) ?? true,
        computeThermochemistry: prefs.getBool(_keyThermo) ?? true,
        runIrc: prefs.getBool(_keyIrc) ?? false,
        frequencyAnalysis: prefs.getBool(_keyFreq) ?? true,
        exportFormat: prefs.getString(_keyExport) ?? 'XYZ',
        conformationalSearch: prefs.getBool(_keyConf) ?? false,
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyCharge, s.charge);
      await prefs.setInt(_keySpin, s.spinMultiplicity);
      await prefs.setString(_keyMlip, s.mlipModel);
      await prefs.setString(_keySolvent, s.solventModel);
      await prefs.setDouble(_keyTemp, s.temperatureK);
      await prefs.setString(_keyCatalyst, s.catalyst);
      await prefs.setString(_keyAlgo, s.optimizerAlgorithm);
      await prefs.setInt(_keySteps, s.maxSteps);
      await prefs.setString(_keyConv, s.convergence);
      await prefs.setString(_keyDmfConv, s.dmfConvergence);
      await prefs.setInt(_keyNmove, s.nmove);
      await prefs.setBool(_keyUpdateTeval, s.updateTeval);
      await prefs.setDouble(_keyForce, s.maxForceNorm);
      await prefs.setInt(_keyImages, s.nebImages);
      await prefs.setDouble(_keySpring, s.springConstant);
      await prefs.setString(_keyToken, s.hfToken);
      await prefs.setBool(_keyZpe, s.zpeCorrection);
      await prefs.setBool(_keyThermo, s.computeThermochemistry);
      await prefs.setBool(_keyIrc, s.runIrc);
      await prefs.setBool(_keyFreq, s.frequencyAnalysis);
      await prefs.setString(_keyExport, s.exportFormat);
      await prefs.setBool(_keyConf, s.conformationalSearch);
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


