// ============================================================================
// Results UI smoke test
// ----------------------------------------------------------------------------
// Renders the whole research results surface (header, energy profile with error
// band, hero metrics, Arrhenius, thermo grid) inside a scroll view so any
// unbounded-height layout bug — e.g. a stretched side bar — throws here first.
// ============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:quantum_forge/core/theme/theme_provider.dart';
import 'package:quantum_forge/features/reaction_runner/data/models/results_summary.dart';
import 'package:quantum_forge/features/reaction_runner/providers/settings_provider.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/dashboard_cards/arrhenius_plot_card.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/dashboard_cards/energy_profile_card.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/dashboard_cards/hero_metrics_row.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/dashboard_cards/results_header_card.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/dashboard_cards/thermo_properties_grid.dart';

void main() {
  testWidgets('results cards render without layout errors', (tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final summary = computeResultsSummary(
      settings: const QuantumSettings(),
      energyProfile: List<double>.generate(
        21,
        (i) => 25.0 * math.exp(-math.pow((i - 10) / 5.0, 2).toDouble()),
      ),
      referenceEa: 30.0,
    );

    final theme = ThemeNotifier(initialTheme: AppTheme.darkMatter);
    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeNotifier>.value(
        value: theme,
        child: Consumer<ThemeNotifier>(
          builder: (context, t, _) => MaterialApp(
            theme: t.themeData,
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ResultsHeaderCard(summary: summary, reactionName: 'Test Reaction'),
                    const SizedBox(height: 12),
                    EnergyProfileCard(
                      energyProfile: summary.energyProfile,
                      referenceEa: summary.referenceEa,
                      uncertainty: summary.profileUncertainty,
                      onPointSelected: (_) {},
                    ),
                    const SizedBox(height: 12),
                    HeroMetricsRow(metrics: summary.heroMetrics),
                    const SizedBox(height: 12),
                    ArrheniusPlotCard(
                      ea: summary.estimatedEa,
                      eaUncertainty: 1.6,
                      rateVsTemp: summary.rateVsTemp,
                      lnUncertainty: summary.lnUncertainty,
                    ),
                    const SizedBox(height: 12),
                    ThermoPropertiesGrid(metrics: summary.thermoMetrics),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);

    // Key labels are present and values carry an uncertainty marker.
    expect(find.text('Reaction Energy Profile'), findsOneWidget);
    expect(find.text('Comprehensive Thermodynamic Properties'), findsOneWidget);
    expect(find.textContaining('Surrogate'), findsWidgets);
  });
}
