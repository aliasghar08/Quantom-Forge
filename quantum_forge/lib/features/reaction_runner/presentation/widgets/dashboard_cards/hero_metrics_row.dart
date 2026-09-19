import 'package:flutter/material.dart';
import 'package:quantum_forge/core/theme/theme_provider.dart';
import 'package:quantum_forge/features/reaction_runner/data/models/results_summary.dart';
import 'research_ui.dart';

/// The five headline metrics (ΔG‡, Ea, k, ΔH‡, ΔS‡) with ±1σ error and a
/// quality badge — the first thing a researcher reads after a run.
class HeroMetricsRow extends StatelessWidget {
  final List<MetricEstimate> metrics;

  const HeroMetricsRow({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final palette = ThemeNotifier.paletteOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        int columns = (constraints.maxWidth / 170).floor();
        if (columns > 5) columns = 5;
        if (columns < 1) columns = 1;

        const spacing = 12.0;
        final cardWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: cardWidth,
                height: 150,
                child: ResearchCard(
                  accent: metric.accent,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: metric.accent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(metric.icon, size: 16, color: metric.accent),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              metric.label,
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      MetricValue(metric: metric, valueFontSize: 21),
                      const Spacer(),
                      Row(
                        children: [
                          QualityBadge(quality: metric.quality),
                          const Spacer(),
                          Flexible(
                            child: Text(
                              metric.method,
                              style: TextStyle(
                                color: palette.textMuted,
                                fontSize: 9.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
