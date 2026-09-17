// ============================================================================
// Quantum Settings Provider
// Persistent state for all researcher-controlled computation parameters.
// Saved to SharedPreferences so settings survive app restarts.
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:quantum_forge/core/utils/local_prefs.dart';

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
  final double maxForceNorm;
  final int nebImages;
  final double springConstant;

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
    // Optimizer
    this.optimizerAlgorithm = 'NEB-CI',
    this.maxSteps = 300,
    this.convergence = 'Normal',
    this.maxForceNorm = 0.05,
    this.nebImages = 12,
    this.springConstant = 0.1,
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
      other.optimizerAlgorithm == optimizerAlgorithm &&
      other.maxSteps == maxSteps &&
      other.convergence == convergence &&
      other.maxForceNorm == maxForceNorm &&
      other.nebImages == nebImages &&
      other.springConstant == springConstant &&
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
      optimizerAlgorithm,
      maxSteps,
      convergence,
      maxForceNorm,
      nebImages,
      springConstant,
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
    String? optimizerAlgorithm,
    int? maxSteps,
    String? convergence,
    double? maxForceNorm,
    int? nebImages,
    double? springConstant,
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
      optimizerAlgorithm: optimizerAlgorithm ?? this.optimizerAlgorithm,
      maxSteps: maxSteps ?? this.maxSteps,
      convergence: convergence ?? this.convergence,
      maxForceNorm: maxForceNorm ?? this.maxForceNorm,
      nebImages: nebImages ?? this.nebImages,
      springConstant: springConstant ?? this.springConstant,
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
        'optimizer_algorithm': optimizerAlgorithm,
        'max_steps': maxSteps,
        'convergence': convergence,
        'max_force_norm': maxForceNorm,
        'neb_images': nebImages,
        'spring_constant': springConstant,
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

  static const _keyCharge = 'qs_charge';
  static const _keySpin = 'qs_spin';
  static const _keyMlip = 'qs_mlip';
  static const _keySolvent = 'qs_solvent';
  static const _keyTemp = 'qs_temp';
  static const _keyAlgo = 'qs_algo';
  static const _keySteps = 'qs_steps';
  static const _keyConv = 'qs_conv';
  static const _keyForce = 'qs_force';
  static const _keyImages = 'qs_images';
  static const _keySpring = 'qs_spring';
  static const _keyZpe = 'qs_zpe';
  static const _keyThermo = 'qs_thermo';
  static const _keyIrc = 'qs_irc';
  static const _keyFreq = 'qs_freq';
  static const _keyExport = 'qs_export';
  static const _keyConf = 'qs_conf';

  Future<void> _load() async {
    final prefs = await LocalPrefs.getInstance();
    value = QuantumSettings(
      charge: prefs.getInt(_keyCharge) ?? 0,
      spinMultiplicity: prefs.getInt(_keySpin) ?? 1,
      mlipModel: prefs.getString(_keyMlip) ?? 'UMA-SM',
      solventModel: prefs.getString(_keySolvent) ?? 'Vacuum',
      temperatureK: prefs.getDouble(_keyTemp) ?? 298.15,
      optimizerAlgorithm: prefs.getString(_keyAlgo) ?? 'NEB-CI',
      maxSteps: prefs.getInt(_keySteps) ?? 300,
      convergence: prefs.getString(_keyConv) ?? 'Normal',
      maxForceNorm: prefs.getDouble(_keyForce) ?? 0.05,
      nebImages: prefs.getInt(_keyImages) ?? 12,
      springConstant: prefs.getDouble(_keySpring) ?? 0.1,
      zpeCorrection: prefs.getBool(_keyZpe) ?? true,
      computeThermochemistry: prefs.getBool(_keyThermo) ?? true,
      runIrc: prefs.getBool(_keyIrc) ?? false,
      frequencyAnalysis: prefs.getBool(_keyFreq) ?? true,
      exportFormat: prefs.getString(_keyExport) ?? 'XYZ',
      conformationalSearch: prefs.getBool(_keyConf) ?? false,
    );
  }

  Future<void> _save(QuantumSettings s) async {
    final prefs = await LocalPrefs.getInstance();
    await prefs.setInt(_keyCharge, s.charge);
    await prefs.setInt(_keySpin, s.spinMultiplicity);
    await prefs.setString(_keyMlip, s.mlipModel);
    await prefs.setString(_keySolvent, s.solventModel);
    await prefs.setDouble(_keyTemp, s.temperatureK);
    await prefs.setString(_keyAlgo, s.optimizerAlgorithm);
    await prefs.setInt(_keySteps, s.maxSteps);
    await prefs.setString(_keyConv, s.convergence);
    await prefs.setDouble(_keyForce, s.maxForceNorm);
    await prefs.setInt(_keyImages, s.nebImages);
    await prefs.setDouble(_keySpring, s.springConstant);
    await prefs.setBool(_keyZpe, s.zpeCorrection);
    await prefs.setBool(_keyThermo, s.computeThermochemistry);
    await prefs.setBool(_keyIrc, s.runIrc);
    await prefs.setBool(_keyFreq, s.frequencyAnalysis);
    await prefs.setString(_keyExport, s.exportFormat);
  }

  void update(QuantumSettings Function(QuantumSettings) updater) {
    value = updater(value);
    _save(value);
  }
}


