import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:quantum_forge/features/reaction_runner/data/models/reaction_models.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/kinetic_chart_widget.dart';
import 'package:quantum_forge/state/reaction_provider.dart';
import 'package:quantum_forge/state/settings_provider.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  /// Mock profile used when the backend has not produced one yet.
  ///
  /// A parabola peaking at index 10, so the chart always has a non-empty,
  /// strictly finite shape to draw even before the first real result
  /// arrives.
  final List<double> _mockFrames = List<double>.generate(20, (i) {
    final x = i / 10.0 - 1.0;
    final energy = 30.0 - 30.0 * (x * x);
    return energy < 0 ? 0 : energy;
  });

  /// The last successfully-rendered model.
  ///
  /// `ReactionNotifier` fires far more often than the analytics actually
  /// change — during a backend run it notifies on every second of simulated
  /// progress and on every poll event. Each notification rebuilds this
  /// screen. If one of those rebuilds lands on a transient state (a settings
  /// field momentarily null, `temperatureK == 0`, a bad constraint from a
  /// route transition), letting the exception reach `RenderObject` paints a
  /// single grey frame before the next notification recovers it — which is
  /// exactly the "stable → grey → stable → grey" flicker. Holding the last
  /// good model and re-rendering it in the catch clause makes that flicker
  /// unobservable.
  _AnalyticsModel? _lastGood;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<QuantumSettings>(
      valueListenable: context.read<QuantumSettingsNotifier>(),
      builder: (context, settings, _) {
        return ValueListenableBuilder<ReactionStatusResponse?>(
          valueListenable: context.read<ReactionNotifier>(),
          builder: (context, reactionStatus, _) {
            try {
              final model = _compute(settings, reactionStatus);
              _lastGood = model;
              return _render(model);
            } catch (_) {
              final fallback = _lastGood;
              if (fallback != null) return _render(fallback);
              // First-ever build before any good state: render an empty
              // scaffold rather than letting the exception paint grey.
              return const ColoredBox(color: Color(0xFF0D0D12));
            }
          },
        );
      },
    );
  }

  // ── Compute ───────────────────────────────────────────────────────────────

  /// Extracts every settings field with a safe fallback, clamps temperature to
  /// a strictly positive range, and runs every derived scalar through
  /// [_finite].
  ///
  /// Returns a fully-computed, immutable model that [_render] can draw without
  /// any further null checks or arithmetic. If any input is unusable in a way
  /// that cannot be sanitised, this throws — and the caller's catch clause
  /// above turns that into "render the previous frame" rather than a grey
  /// flash.
  _AnalyticsModel _compute(
    QuantumSettings settings,
    ReactionStatusResponse? reactionStatus,
  ) {
    // Null-safe reads. On a field that is already non-nullable, `??` is only
    // an analyzer hint; on a nullable field, this is the reason the screen
    // does not flicker when the settings notifier is mid-reload.
    final double temperatureK =
        (settings.temperatureK ?? 300.0).clamp(1.0, 1.0e6);
    final String solventModel = settings.solventModel ?? 'Vacuum';
    final String mlipModel = settings.mlipModel ?? '';
    final num charge = settings.charge ?? 0.0;
    final int spinMultiplicity = settings.spinMultiplicity ?? 1;

    final List<double> baseProfile =
        (reactionStatus?.energyProfile?.isNotEmpty == true)
            ? reactionStatus!.energyProfile!
            : _mockFrames;

    double scaleFactor = temperatureK / 300.0;
    if (solventModel != 'Vacuum') scaleFactor *= 0.85;
    if (mlipModel == 'ANI-2x') scaleFactor *= 1.05;

    final double chargeShift = charge * 4.5;
    final double spinShift = (spinMultiplicity - 1) * 8.0;
    final double totalShift = chargeShift + spinShift;

    final List<double> scaledProfile = <double>[
      for (final e in baseProfile) _finite((e * scaleFactor) + totalShift),
    ];

    // ── Thermodynamic quantities, all finite by construction ────────────
    final double baseEnthalpy = _finite(25.4 * scaleFactor + totalShift);

    double baseEntropy = -12.3 + (temperatureK / 300.0) * 1.5;
    if (solventModel != 'Vacuum') baseEntropy += 2.0;
    baseEntropy = _finite(baseEntropy);

    final double gibbs = _finite(
      baseEnthalpy - (temperatureK * baseEntropy / 1000.0),
    );
    final double imagFreq = _finite(-452.1 * scaleFactor);
    final double ea = _finite(
      baseEnthalpy + (1.987 * temperatureK / 1000.0),
    );

    const double kb = 1.380649e-23;
    const double h = 6.62607015e-34;
    final double gibbsJ = gibbs * 4184.0;
    final double rateConst = _finite(
      (kb * temperatureK / h) * exp(-gibbsJ / (8.314 * temperatureK)),
    );

    final double zpe = _finite(14.5 * scaleFactor + chargeShift / 3);
    final double dipole = _finite(2.4 + (charge * 0.5).abs());
    final double gap = _finite(5.2 - (spinMultiplicity * 0.1));
    final double polar = _finite(
      45.2 + (solventModel != 'Vacuum' ? 12.0 : 0.0),
    );
    final double rmsGrad =
        _finite(0.00034 * (scaleFactor > 0 ? scaleFactor : 1));
    final double partFunc = _finite(
      exp(-gibbsJ / (8.314 * temperatureK)) * 1e12,
    );

    final List<_MetricCard> metrics = <_MetricCard>[
      _MetricCard(
        'Enthalpy (ΔH‡)',
        '${baseEnthalpy.toStringAsFixed(1)} kcal·mol⁻¹',
        Icons.thermostat,
      ),
      _MetricCard(
        'Entropy (ΔS‡)',
        '${baseEntropy.toStringAsFixed(1)} cal·mol⁻¹·K⁻¹',
        Icons.shuffle,
      ),
      _MetricCard(
        'Gibbs Free Energy (ΔG‡)',
        '${gibbs.toStringAsFixed(1)} kcal·mol⁻¹',
        Icons.bolt,
      ),
      _MetricCard(
        'Imaginary Freq. (v‡)',
        '${imagFreq.toStringAsFixed(1)} cm⁻¹',
        Icons.waves,
      ),
      _MetricCard(
        'Activation Energy (Ea)',
        '${ea.toStringAsFixed(1)} kcal·mol⁻¹',
        Icons.local_fire_department,
      ),
      _MetricCard(
        'Rate Constant (k)',
        '${rateConst.toStringAsExponential(2)} s⁻¹',
        Icons.speed,
      ),
      _MetricCard(
        'ZPE Correction',
        '${zpe.toStringAsFixed(2)} kcal·mol⁻¹',
        Icons.compress,
      ),
      _MetricCard(
        'Dipole Moment (μ)',
        '${dipole.toStringAsFixed(2)} D',
        Icons.compare_arrows,
      ),
      _MetricCard(
        'HOMO-LUMO Gap',
        '${gap.toStringAsFixed(2)} eV',
        Icons.swap_vert,
      ),
      _MetricCard(
        'Polarizability (α)',
        '${polar.toStringAsFixed(1)} Bohr³',
        Icons.blur_on,
      ),
      _MetricCard(
        'RMS Gradient',
        '${rmsGrad.toStringAsExponential(2)} a.u.',
        Icons.show_chart,
      ),
      _MetricCard(
        'Partition Func (q)',
        partFunc.toStringAsExponential(2),
        Icons.pie_chart,
      ),
    ];

    return _AnalyticsModel(
      scaledProfile: scaledProfile,
      referenceEa: _finite(27.5 * scaleFactor + totalShift),
      metrics: metrics,
    );
  }

  // ── Render ────────────────────────────────────────────────────────────────

  Widget _render(_AnalyticsModel model) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double pad = 24.0;
        const double gutter = 16.0;

        // The scroll view below applies `EdgeInsets.all(pad)`, so its child
        // is laid out with `maxW - 2 * pad` of usable width. Card widths are
        // computed from that *inner* width; computing them from the outer
        // width made the row of cards 48 px wider than its box, which `Wrap`
        // cannot repair.
        //
        // The fallback chain handles three bad cases without throwing:
        //   * `constraints.maxWidth` non-finite → use the media query width
        //   * `MediaQuery` unavailable in this subtree → use 1024 px
        //   * any residual non-finite or non-positive value → 1024 px again
        double outer = constraints.maxWidth;
        if (!outer.isFinite || outer <= 0) {
          outer = MediaQuery.maybeOf(context)?.size.width ?? 1024.0;
        }
        if (!outer.isFinite || outer <= 0) outer = 1024.0;

        final double inner = max(1.0, outer - 2 * pad);

        int cols = 4;
        if (inner < 800) cols = 2;
        if (inner < 500) cols = 1;

        final double cardWidth = cols > 1
            ? (inner - (cols - 1) * gutter) / cols
            : inner;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────────────────
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Advanced Analytics',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.download),
                    label: const Text('Export CSV'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white12,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Main chart ──────────────────────────────────────────
              // Fixed height: it does not participate in the scroll view's
              // unbounded height, and it cannot resize itself mid-build from
              // a bad constraint.
              SizedBox(
                height: 500,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Multi-Path Energy Profile (Overlay)',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: KineticChartWidget(
                          energyProfile: model.scaledProfile,
                          referenceEa: model.referenceEa,
                          onPointSelected: (idx) {},
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Thermodynamics cards ────────────────────────────────
              // Wrap with explicit per-card widths. No IntrinsicHeight: the
              // card's Column already sizes to its own content, and Wrap
              // gives every child the same column width via the SizedBox, so
              // they align without a second layout pass per card.
              Wrap(
                spacing: gutter,
                runSpacing: gutter,
                children: [
                  for (final m in model.metrics)
                    SizedBox(
                      width: cardWidth,
                      child: _buildThermoCard(m.title, m.value, m.icon),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThermoCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF4FC3F7), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fully-computed render model, produced once per build.
///
/// The whole point of this class is that [_AnalyticsScreenState._render]
/// takes a value of this type and no arithmetic, no casting and no field
/// access happens inside the widget tree itself.
class _AnalyticsModel {
  const _AnalyticsModel({
    required this.scaledProfile,
    required this.referenceEa,
    required this.metrics,
  });

  final List<double> scaledProfile;
  final double referenceEa;
  final List<_MetricCard> metrics;
}

/// One card's worth of text and icon. A concrete type rather than a
/// `Map<String, dynamic>`, so `m['title'] as String` cannot fail at runtime.
class _MetricCard {
  const _MetricCard(this.title, this.value, this.icon);

  final String title;
  final String value;
  final IconData icon;
}

/// Returns [value] when it is finite, otherwise `0.0`.
///
/// NaN and ±Infinity propagate silently through arithmetic and only become
/// visible when a widget tries to lay out or paint using them — at which
/// point the frame is dropped and the previous frame shows through. Every
/// number that ends up on screen passes through this.
double _finite(double value) => value.isFinite ? value : 0.0;