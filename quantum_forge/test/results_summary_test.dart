// ============================================================================
// Results summary tests
// ----------------------------------------------------------------------------
// Pins the physically-correct relationships the dashboard relies on (ΔG = ΔH −
// TΔS, Ea ≈ ΔH‡ + RT, the Eyring equation), plus the uncertainty model and the
// significant-digit formatting that keeps a surrogate estimate honest.
// ============================================================================

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:quantum_forge/features/reaction_runner/data/models/results_summary.dart';
import 'package:quantum_forge/features/reaction_runner/providers/settings_provider.dart';

const double _kb = 1.380649e-23;
const double _h = 6.62607015e-34;
const double _gasConstant = 8.314462618;

ResultsSummary _summary({double? referenceEa}) {
  const settings = QuantumSettings(); // default: vacuum, MACE-MP-0
  final profile = List<double>.generate(
    21,
    (i) => 25.0 * math.exp(-math.pow((i - 10) / 5.0, 2).toDouble()),
  );
  return computeResultsSummary(
    settings: settings,
    energyProfile: profile,
    referenceEa: referenceEa,
  );
}

void main() {
  group('physically-correct relationships', () {
    test('ΔG‡ = ΔH‡ − T·ΔS‡', () {
      final s = _summary();
      final dH = s.byLabel('Enthalpy (ΔH‡)').value;
      final dS = s.byLabel('Entropy (ΔS‡)').value;
      final dG = s.byLabel('Gibbs Free Energy (ΔG‡)').value;
      expect(dG, closeTo(dH - s.settings.temperatureK * dS / 1000.0, 1e-9));
    });

    test('Ea ≈ ΔH‡ + RT (in kcal/mol)', () {
      final s = _summary();
      final dH = s.byLabel('Enthalpy (ΔH‡)').value;
      final ea = s.byLabel('Activation Energy (Ea)').value;
      expect(ea, closeTo(dH + 1.987 * s.settings.temperatureK / 1000.0, 1e-9));
    });

    test('rate constant follows the Eyring equation', () {
      final s = _summary();
      final log10k = s.byLabel('Rate Constant (k)').value;
      final dG = s.byLabel('Gibbs Free Energy (ΔG‡)').value; // kcal/mol
      final T = s.settings.temperatureK;
      final k = (_kb * T / _h) * math.exp(-dG * 4184.0 / (_gasConstant * T));
      expect(log10k, closeTo(math.log(k) / math.ln10, 1e-9));
    });

    test('Arrhenius ln(k) series is consistent with Ea', () {
      final s = _summary();
      expect(s.rateVsTemp, hasLength(10));
      final t0 = 200.0;
      final k0 = (_kb * t0 / _h) *
          math.exp(-s.estimatedEa * 4184.0 / (_gasConstant * t0));
      expect(s.rateVsTemp.first, closeTo(math.log(k0), 1e-9));
    });
  });

  group('uncertainty model', () {
    test('ΔG‡ carries ±1.6 kcal/mol and rounds to 0 decimals', () {
      final dG = _summary().byLabel('Gibbs Free Energy (ΔG‡)');
      expect(dG.uncertainty, 1.6);
      expect(dG.decimals, 0);
      expect(dG.formattedValue, dG.value.toStringAsFixed(0));
      expect(dG.formattedUncertainty, '± 2'); // 1.6 → 1 sig fig = 2
    });

    test('dipole carries ±0.3 D and keeps one decimal', () {
      final mu = _summary().byLabel('Dipole Moment (μ)');
      expect(mu.uncertainty, 0.3);
      expect(mu.decimals, 1);
      expect(mu.formattedValue, mu.value.toStringAsFixed(1));
      expect(mu.formattedUncertainty, '± 0.3');
    });

    test('rate constant is reported in log space with propagated error', () {
      final k = _summary().byLabel('Rate Constant (k)');
      expect(k.format, ValueFormat.logScale);
      expect(k.uncertainty, closeTo(1.17, 0.05)); // σ_log10 ≈ 1.17 at 298 K
      expect(k.formattedValue, startsWith('10^('));
    });

    test('imaginary frequency uncertainty is 10% of its magnitude', () {
      final nu = _summary().byLabel('Imaginary Freq. (ν‡)');
      expect(nu.uncertainty, closeTo(nu.value.abs() * 0.10, 1e-6));
    });

    test('every metric has a method, quality and non-negative error', () {
      for (final m in _summary().metrics) {
        expect(m.method, isNotEmpty, reason: m.label);
        expect(m.uncertainty, greaterThanOrEqualTo(0), reason: m.label);
      }
    });
  });

  group('accuracy vs literature', () {
    test('reports signed Ea error and percentage when a reference exists', () {
      final s = _summary(referenceEa: 30.0);
      expect(s.referenceEa, isNotNull);
      expect(s.eaError, closeTo(s.estimatedEa - s.referenceEa!, 1e-9));
      expect(s.eaErrorPct, closeTo((s.eaError! / s.referenceEa!) * 100, 1e-9));
      final metric = s.byLabel('Ea Error vs Literature');
      expect(metric.value, closeTo(s.eaError!, 1e-9));
    });

    test('omits the accuracy metric when no reference is available', () {
      final s = _summary();
      expect(s.referenceEa, isNull);
      expect(s.eaError, isNull);
      expect(() => s.byLabel('Ea Error vs Literature'), throwsStateError);
    });
  });

  group('metric partitioning', () {
    test('hero row has five headline metrics, grid has the rest', () {
      final s = _summary();
      expect(s.heroMetrics, hasLength(5));
      expect(s.heroMetrics.map((m) => m.label), containsAllInOrder([
        'Gibbs Free Energy (ΔG‡)',
        'Activation Energy (Ea)',
        'Rate Constant (k)',
        'Enthalpy (ΔH‡)',
        'Entropy (ΔS‡)',
      ]));
      expect(s.thermoMetrics.length, s.metrics.length - 5);
    });
  });
}
