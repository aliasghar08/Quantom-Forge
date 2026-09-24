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

class _MetricTile extends StatefulWidget {
  final MetricEstimate metric;
  const _MetricTile({required this.metric});

  @override
  State<_MetricTile> createState() => _MetricTileState();
}

class _MetricTileState extends State<_MetricTile> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHover(bool isHovered) {
    if (isHovered) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemeNotifier.paletteOf(context);
    final metric = widget.metric;

    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Color.lerp(
                  metric.accent.withValues(alpha: 0.06),
                  metric.accent.withValues(alpha: 0.12),
                  _glowAnimation.value,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Color.lerp(
                    metric.accent.withValues(alpha: 0.22),
                    metric.accent.withValues(alpha: 0.6),
                    _glowAnimation.value,
                  )!,
                ),
                boxShadow: [
                  if (_glowAnimation.value > 0)
                    BoxShadow(
                      color: metric.accent.withValues(alpha: 0.15 * _glowAnimation.value),
                      blurRadius: 10 * _glowAnimation.value,
                      spreadRadius: 1 * _glowAnimation.value,
                    ),
                ],
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
            ),
          );
        },
      ),
    );
  }
}
