import 'package:flutter/material.dart';
import 'package:quantum_forge/core/theme/theme_provider.dart';
import 'package:quantum_forge/features/reaction_runner/data/models/results_summary.dart';
import 'research_ui.dart';

/// The full complement of thermodynamic/kinetic properties, each with its ±1σ
/// error, quality tier and provenance method.
class ThermoPropertiesGrid extends StatelessWidget {
  final List<MetricEstimate> metrics;

  const ThermoPropertiesGrid({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final palette = ThemeNotifier.paletteOf(context);
    return ResearchCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.functions, size: 16, color: palette.accent),
              const SizedBox(width: 8),
              Text(
                'Comprehensive Thermodynamic Properties',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '±1σ · tabular figures',
                style: TextStyle(color: palette.textMuted, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 240,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 96,
            ),
            itemCount: metrics.length,
            itemBuilder: (context, index) => _MetricTile(metric: metrics[index]),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final MetricEstimate metric;
  const _MetricTile({required this.metric});

  @override
  Widget build(BuildContext context) {
    final palette = ThemeNotifier.paletteOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: metric.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: metric.accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(metric.icon, color: metric.accent, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Tooltip(
                  message: '${metric.method} · ${metric.quality.description}',
                  child: Text(
                    metric.label,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    metric.formattedValue,
                    style: TextStyle(
                      color: metric.accent,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  metric.formattedUncertainty,
                  style: TextStyle(
                    color: palette.warning,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                metric.unit,
                style: TextStyle(color: palette.textMuted, fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
