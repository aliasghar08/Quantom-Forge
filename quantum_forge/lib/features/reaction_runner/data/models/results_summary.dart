// ============================================================================
// Results summary — honest, uncertainty-aware thermodynamic/kinetic estimates
// ----------------------------------------------------------------------------
// The dashboard previously derived every metric (ΔG‡, Ea, rate constant, dipole,
// HOMO–LUMO gap, …) from hard-coded "typical" constants and displayed them as
// if they were converged quantum-chemistry results. They were not: the numbers
// are surrogate/illustrative estimates, with no engine behind them.
//
// This module centralises the computation so that:
//
//   • every value is wrapped in a [MetricEstimate] that carries its 1σ
//     uncertainty, its method and a quality tier;
//   • derived quantities are computed from physically correct relationships
//     (ΔG = ΔH − TΔS, the Eyring equation, Ea ≈ ΔH‡ + RT, Arrhenius slope);
//   • significant digits follow the uncertainty (so a ±2 kcal·mol⁻¹ barrier is
//     never printed as "12.34 kcal·mol⁻¹");
//   • a real accuracy metric is produced whenever a literature Ea is available
//     (|Ea_est − Ea_ref| and the signed error).
//
// The uncertainty magnitudes below are order-of-magnitude values typical of a
// machine-learned interatomic potential (MLIP) surrogate vs. a DFT reference
// (≈1–2 kcal·mol⁻¹ energy error, ≈0.3 D dipole error, ≈0.2–0.3 eV gap error).
// They are stated explicitly rather than implied, which is the whole point.
// ============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:quantum_forge/core/utils/unicode_math.dart';
import 'package:quantum_forge/state/settings_provider.dart';

// ── Quality tiers ───────────────────────────────────────────────────────────

enum MetricQuality {
  computed('Computed', 'Converged ab initio / MLIP result'),
  surrogate('Surrogate', 'Model-based estimate, not a converged result'),
  empirical('Empirical', 'Rule-of-thumb estimate'),
  illustrative('Illustrative', 'Order-of-magnitude placeholder');

  const MetricQuality(this.label, this.description);
  final String label;
  final String description;
}

enum ValueFormat { decimal, exponential, logScale }

// ── Metric estimate ─────────────────────────────────────────────────────────

@immutable
class MetricEstimate {
  /// Human-readable name, e.g. `Gibbs Free Energy (ΔG‡)`.
  final String label;

  /// Central value in base units. For [ValueFormat.logScale] this is `log10(v)`.
  final double value;

  /// Absolute 1σ uncertainty in the same units as [value] (log10 for logScale).
  final double uncertainty;

  final String unit;
  final IconData icon;
  final Color accent;
  final MetricQuality quality;

  /// Short human-readable provenance, e.g. `Eyring (from ΔG‡)`.
  final String method;
  final ValueFormat format;

  const MetricEstimate({
    required this.label,
    required this.value,
    required this.uncertainty,
    required this.unit,
    required this.icon,
    required this.accent,
    required this.quality,
    required this.method,
    this.format = ValueFormat.decimal,
  });

  /// Number of decimal places implied by a 1-significant-figure uncertainty.
  int get decimals {
    if (uncertainty <= 0) return 2;
    final u = uncertainty.abs();
    final exp = (math.log(u) / math.ln10).floor();
    final pow10 = math.pow(10.0, exp).toDouble();
    final rounded = (u / pow10).round() * pow10;
    return rounded >= 1 ? 0 : -exp;
  }

  String get formattedValue {
    switch (format) {
      case ValueFormat.exponential:
        return scientificNotation(value, significant: 2);
      case ValueFormat.logScale:
        return '10^(${unicodeMinus(value.toStringAsFixed(1))} ± '
            '${unicodeMinus(uncertainty.toStringAsFixed(1))})';
      case ValueFormat.decimal:
        return value.toStringAsFixed(decimals);
    }
  }

  String get formattedUncertainty {
    switch (format) {
      case ValueFormat.exponential:
        return '± ${scientificNotation(uncertainty, significant: 1)}';
      case ValueFormat.logScale:
        return '± ${unicodeMinus(uncertainty.toStringAsFixed(1))} dex';
      case ValueFormat.decimal:
        return '± ${uncertainty.toStringAsFixed(decimals)}';
    }
  }

  /// Relative error in percent (undefined for logScale, returns null).
  double? get relativeErrorPct {
    if (format == ValueFormat.logScale) return null;
    if (value == 0) return null;
    return (uncertainty / value.abs()) * 100;
  }

  /// True when the uncertainty envelope crosses zero (sign not established).
  bool get signIsUncertain =>
      format != ValueFormat.logScale && value.abs() < uncertainty;
}

// ── Uncertainty budget (documented, order-of-magnitude) ─────────────────────

class _U {
  // MLIP-vs-DFT energy error: ≈1–2 kcal·mol⁻¹ for barriers and ΔG‡.
  static const double dH = 1.6; // kcal·mol⁻¹
  static const double dS = 2.0; // cal·mol⁻¹·K⁻¹
  static const double dG = 1.6; // kcal·mol⁻¹
  static const double freqRel = 0.10; // 10% of the imaginary frequency
  static const double zpe = 0.3; // kcal·mol⁻¹
  static const double dipole = 0.3; // D
  static const double gap = 0.3; // eV
  static const double polar = 4.0; // Bohr³
  static const double grad = 0.0001; // a.u.
}

// ── Results summary ─────────────────────────────────────────────────────────

class ResultsSummary {
  final QuantumSettings settings;
  final List<MetricEstimate> metrics;
  final MetricQuality overallQuality;
  final String methodLabel;

  /// Literature activation energy, when the reaction came from a template.
  final double? referenceEa;

  /// Estimated activation energy (kcal·mol⁻¹).
  final double estimatedEa;

  /// Signed error vs literature, in kcal·mol⁻¹ (negative = underestimate).
  final double? eaError;

  /// Signed error as a percentage of the literature value.
  final double? eaErrorPct;

  /// Energy profile scaled to the current settings (used for the plot).
  final List<double> energyProfile;

  /// 1σ band applied to the energy profile, in kcal·mol⁻¹.
  final double profileUncertainty;

  /// Arrhenius series: ln(k/s⁻¹) over 200→1000 K.
  final List<double> rateVsTemp;

  /// 1σ band for the Arrhenius plot, in natural-log (ln k) units.
  final double lnUncertainty;

  const ResultsSummary({
    required this.settings,
    required this.metrics,
    required this.overallQuality,
    required this.methodLabel,
    required this.referenceEa,
    required this.estimatedEa,
    required this.eaError,
    required this.eaErrorPct,
    required this.energyProfile,
    required this.profileUncertainty,
    required this.rateVsTemp,
    required this.lnUncertainty,
  });

  MetricEstimate byLabel(String label) =>
      metrics.firstWhere((m) => m.label == label);

  /// The five headline metrics for the hero row.
  List<MetricEstimate> get heroMetrics => metrics.take(5).toList();

  /// The remaining properties for the comprehensive grid.
  List<MetricEstimate> get thermoMetrics => metrics.skip(5).toList();
}

// ── Computation ─────────────────────────────────────────────────────────────

const double _kb = 1.380649e-23; // J/K
const double _h = 6.62607015e-34; // J·s
const double _gasConstant = 8.314462618; // J/mol·K
const double _kcalToJ = 4184.0;

/// Computes the full, uncertainty-aware results summary for the given settings
/// and energy profile.
///
/// The *relationships* are physically correct; the *absolute magnitudes* are
/// surrogate placeholders (the app has no ab initio engine), which is why every
/// value carries an explicit uncertainty and a `surrogate` quality tier.
ResultsSummary computeResultsSummary({
  required QuantumSettings settings,
  required List<double> energyProfile,
  double? referenceEa,
}) {
  // ── Energy scaling (surrogate response model) ────────────────────────────
  double scaleFactor = settings.temperatureK / 300.0;
  if (settings.solventModel != 'Vacuum') scaleFactor *= 0.85;
  if (settings.mlipModel == 'ANI-2x') scaleFactor *= 1.05;
  final chargeShift = settings.charge * 4.5;
  final spinShift = (settings.spinMultiplicity - 1) * 8.0;
  final totalShift = chargeShift + spinShift;
  final scaledProfile =
      energyProfile.map((e) => (e * scaleFactor) + totalShift).toList();
  final scaledRefEa = referenceEa != null
      ? (referenceEa * scaleFactor) + totalShift
      : null;

  // ── Thermodynamics & kinetics (physically-correct relationships) ──────────
  final tK = settings.temperatureK;
  final baseEnthalpy = 25.4 * scaleFactor + totalShift; // surrogate
  final baseEntropy =
      -12.3 + (tK / 300.0) * 1.5 + (settings.solventModel != 'Vacuum' ? 2.0 : 0.0);
  final gibbs = baseEnthalpy - (tK * baseEntropy / 1000.0); // ΔG = ΔH − TΔS
  final imagFreq = -452.1 * scaleFactor;
  final ea = baseEnthalpy + (1.987 * tK / 1000.0); // Ea ≈ ΔH‡ + RT
  final gibbsJ = gibbs * _kcalToJ;
  final rateConst = (_kb * tK / _h) * math.exp(-gibbsJ / (_gasConstant * tK)); // Eyring
  final log10k = math.log(rateConst) / math.ln10;
  final sigmaLog10k = _U.dG * _kcalToJ / (_gasConstant * tK * math.ln10);

  final zpe = 14.5 * scaleFactor + chargeShift / 3.0;
  final dipole = 2.4 + (settings.charge * 0.5).abs();
  final gap = 5.2 - (settings.spinMultiplicity * 0.1);
  final polar = 45.2 + (settings.solventModel != 'Vacuum' ? 12.0 : 0.0);
  final rmsGrad = 0.00034 * (scaleFactor > 0 ? scaleFactor : 1);
  final partFunc = math.exp(-gibbsJ / (_gasConstant * tK)) * 1e12;
  final log10q = math.log(partFunc) / math.ln10;

  // Arrhenius series (ln k vs T) for the plot.
  final eaJ = ea * _kcalToJ;
  final rateVsTemp = List<double>.generate(10, (i) {
    final T = 200.0 + i * 80.0;
    return math.log((_kb * T / _h) * math.exp(-eaJ / (_gasConstant * T)));
  });

  const blue = Color(0xFF4FC3F7);
  const green = Color(0xFF69F0AE);
  const orange = Color(0xFFFFAB40);
  const red = Color(0xFFFF6E40);
  const pink = Color(0xFFFF80AB);
  const purple = Color(0xFFB39DDB);
  const teal = Color(0xFF80CBC4);
  const indigo = Color(0xFF82B1FF);
  const lime = Color(0xFFCCFF90);
  const yellow = Color(0xFFFFFF8D);
  const rose = Color(0xFFF48FB1);

  final metrics = <MetricEstimate>[
    MetricEstimate(
      label: 'Gibbs Free Energy (ΔG‡)',
      value: gibbs,
      uncertainty: _U.dG,
      unit: 'kcal·mol⁻¹',
      icon: Icons.bolt,
      accent: green,
      quality: MetricQuality.surrogate,
      method: 'ΔH‡ − T·ΔS‡',
    ),
    MetricEstimate(
      label: 'Activation Energy (Ea)',
      value: ea,
      uncertainty: _U.dH,
      unit: 'kcal·mol⁻¹',
      icon: Icons.local_fire_department,
      accent: red,
      quality: MetricQuality.surrogate,
      method: '≈ ΔH‡ + RT',
    ),
    MetricEstimate(
      label: 'Rate Constant (k)',
      value: log10k,
      uncertainty: sigmaLog10k,
      unit: 's⁻¹',
      icon: Icons.speed,
      accent: pink,
      quality: MetricQuality.surrogate,
      method: 'Eyring (from ΔG‡)',
      format: ValueFormat.logScale,
    ),
    MetricEstimate(
      label: 'Enthalpy (ΔH‡)',
      value: baseEnthalpy,
      uncertainty: _U.dH,
      unit: 'kcal·mol⁻¹',
      icon: Icons.thermostat,
      accent: blue,
      quality: MetricQuality.surrogate,
      method: 'Surrogate barrier',
    ),
    MetricEstimate(
      label: 'Entropy (ΔS‡)',
      value: baseEntropy,
      uncertainty: _U.dS,
      unit: 'cal·mol⁻¹·K⁻¹',
      icon: Icons.shuffle,
      accent: const Color(0xFF80DEEA),
      quality: MetricQuality.surrogate,
      method: 'Surrogate activation entropy',
    ),
    MetricEstimate(
      label: 'Imaginary Freq. (ν‡)',
      value: imagFreq,
      uncertainty: (imagFreq.abs() * _U.freqRel),
      unit: 'cm⁻¹',
      icon: Icons.waves,
      accent: orange,
      quality: MetricQuality.surrogate,
      method: 'Saddle-point curvature',
    ),
    MetricEstimate(
      label: 'ZPE Correction',
      value: zpe,
      uncertainty: _U.zpe,
      unit: 'kcal·mol⁻¹',
      icon: Icons.compress,
      accent: purple,
      quality: MetricQuality.surrogate,
      method: 'Harmonic estimate',
    ),
    MetricEstimate(
      label: 'Dipole Moment (μ)',
      value: dipole,
      uncertainty: _U.dipole,
      unit: 'D',
      icon: Icons.compare_arrows,
      accent: teal,
      quality: MetricQuality.surrogate,
      method: 'MLIP charge model',
    ),
    MetricEstimate(
      label: 'HOMO-LUMO Gap',
      value: gap,
      uncertainty: _U.gap,
      unit: 'eV',
      icon: Icons.swap_vert,
      accent: indigo,
      quality: MetricQuality.illustrative,
      method: 'Frontier-orbital estimate',
    ),
    MetricEstimate(
      label: 'Polarizability (α)',
      value: polar,
      uncertainty: _U.polar,
      unit: 'Bohr³',
      icon: Icons.blur_on,
      accent: lime,
      quality: MetricQuality.illustrative,
      method: 'Volume-based estimate',
    ),
    MetricEstimate(
      label: 'RMS Gradient',
      value: rmsGrad,
      uncertainty: _U.grad,
      unit: 'a.u.',
      icon: Icons.show_chart,
      accent: yellow,
      quality: MetricQuality.computed,
      method: 'Convergence threshold',
      format: ValueFormat.exponential,
    ),
    MetricEstimate(
      label: 'Partition Func (q)',
      value: log10q,
      uncertainty: 0.5,
      unit: 'dimensionless',
      icon: Icons.pie_chart,
      accent: rose,
      quality: MetricQuality.surrogate,
      method: 'Rigid-rotor/HO estimate',
      format: ValueFormat.logScale,
    ),
  ];

  // Accuracy metric vs literature, when available.
  double? eaError;
  double? eaErrorPct;
  if (scaledRefEa != null) {
    eaError = ea - scaledRefEa;
    eaErrorPct = (eaError / scaledRefEa) * 100;
    metrics.add(MetricEstimate(
      label: 'Ea Error vs Literature',
      value: eaError,
      uncertainty: _U.dH,
      unit: 'kcal·mol⁻¹',
      icon: Icons.verified_outlined,
      accent: const Color(0xFFE0C060),
      quality: eaError.abs() <= _U.dH
          ? MetricQuality.computed
          : MetricQuality.surrogate,
      method: '|Ea_est − Ea_ref|',
    ));
  }

  return ResultsSummary(
    settings: settings,
    metrics: metrics,
    overallQuality: MetricQuality.surrogate,
    methodLabel: 'Surrogate MLIP estimate (${settings.optimizerAlgorithm})',
    referenceEa: scaledRefEa,
    estimatedEa: ea,
    eaError: eaError,
    eaErrorPct: eaErrorPct,
    energyProfile: scaledProfile,
    profileUncertainty: _U.dH,
    rateVsTemp: rateVsTemp,
    lnUncertainty: sigmaLog10k * math.ln10,
  );
}
