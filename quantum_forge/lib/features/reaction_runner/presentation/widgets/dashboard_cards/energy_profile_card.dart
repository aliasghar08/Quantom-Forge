import 'package:flutter/material.dart';
import 'package:quantum_forge/core/theme/theme_provider.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/kinetic_chart_widget.dart';
import 'research_ui.dart';

class EnergyProfileCard extends StatelessWidget {
  final List<double> energyProfile;
  final double? referenceEa;
  final ValueChanged<int> onPointSelected;

  /// 1σ band width in kcal/mol.
  final double? uncertainty;

  const EnergyProfileCard({
    super.key,
    required this.energyProfile,
    this.referenceEa,
    required this.onPointSelected,
    this.uncertainty,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ThemeNotifier.paletteOf(context);
    return ResearchCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Reaction Energy Profile',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (uncertainty != null)
                  _LegendDot(
                    color: palette.accent,
                    label: '±${uncertainty!.toStringAsFixed(1)} kcal/mol (1σ)',
                  ),
                if (referenceEa != null)
                  _LegendDot(
                    color: palette.warning,
                    label: 'Lit. Ea ${referenceEa!.toStringAsFixed(1)}',
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 280,
            child: KineticChartWidget(
              energyProfile: energyProfile,
              referenceEa: referenceEa,
              onPointSelected: onPointSelected,
              uncertainty: uncertainty,
              lineColor: palette.accent,
              bandColor: palette.accent,
              refColor: palette.warning,
              gridColor: palette.plotGrid,
              labelColor: palette.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final palette = ThemeNotifier.paletteOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: palette.textMuted, fontSize: 10.5)),
      ],
    );
  }
}
