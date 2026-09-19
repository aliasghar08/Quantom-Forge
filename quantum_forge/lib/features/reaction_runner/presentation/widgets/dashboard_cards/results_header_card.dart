// ============================================================================
// Results header — method, conditions, and confidence at a glance
// ----------------------------------------------------------------------------
// A research report opens with its methods. This card does the same for a
// reaction: which surrogate produced the numbers, under what conditions, and
// with what confidence — so a user can tell at a glance whether a value is a
// converged result or an order-of-magnitude estimate.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:quantum_forge/core/theme/theme_provider.dart';
import 'package:quantum_forge/features/reaction_runner/data/models/results_summary.dart';
import 'research_ui.dart';

class ResultsHeaderCard extends StatelessWidget {
  final ResultsSummary summary;
  final String? reactionName;

  const ResultsHeaderCard({super.key, required this.summary, this.reactionName});

  @override
  Widget build(BuildContext context) {
    final palette = ThemeNotifier.paletteOf(context);
    final s = summary.settings;

    return ResearchCard(
      accent: palette.accent,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  reactionName ?? 'Reaction Results',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              QualityBadge(quality: summary.overallQuality),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(icon: Icons.memory, label: summary.methodLabel),
              _MetaChip(icon: Icons.thermostat, label: '${s.temperatureK.toStringAsFixed(1)} K'),
              _MetaChip(icon: Icons.water_drop_outlined, label: s.solventModel),
              _MetaChip(icon: Icons.auto_awesome, label: s.mlipModel),
              _MetaChip(icon: Icons.account_tree_outlined, label: s.optimizerAlgorithm),
              _MetaChip(icon: Icons.tune, label: 'charge ${s.charge} · 2S+1=${s.spinMultiplicity}'),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: palette.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: palette.warning.withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 15, color: palette.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Values are surrogate estimates (no ab initio engine) with '
                    '±1σ error bars. The energy profile carries a '
                    '±${summary.profileUncertainty.toStringAsFixed(1)} kcal·mol⁻¹ band. '
                    'Use for planning, not publication.',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (summary.eaError != null) ...[
            const SizedBox(height: 10),
            _AccuracyRow(summary: summary),
          ],
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final palette = ThemeNotifier.paletteOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: palette.textMuted),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: palette.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _AccuracyRow extends StatelessWidget {
  final ResultsSummary summary;
  const _AccuracyRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    final palette = ThemeNotifier.paletteOf(context);
    final err = summary.eaError!;
    final within = err.abs() <= 1.6;
    final color = within ? palette.success : palette.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(within ? Icons.verified : Icons.error_outline, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'vs literature Ea ${summary.referenceEa!.toStringAsFixed(1)} kcal·mol⁻¹: '
              '${err >= 0 ? '+' : ''}${err.toStringAsFixed(1)} kcal·mol⁻¹ '
              '(${err >= 0 ? '+' : ''}${summary.eaErrorPct!.toStringAsFixed(0)}%)',
              style: TextStyle(color: palette.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
