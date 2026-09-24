// ============================================================================
// Research-grade card primitives shared by the results/analytics surface.
// ----------------------------------------------------------------------------
// A cohesive visual language for the metrics cards: a subtle panel surface, a
// tinted accent bar, tabular-figure values, a subdued uncertainty line and a
// colour-coded quality badge. Every colour comes from the active quantum theme
// so the results look right on all seven presets.
// ============================================================================

import 'dart:ui' as dart_ui;
import 'package:flutter/material.dart';
import 'package:quantum_forge/core/theme/theme_provider.dart';
import 'package:quantum_forge/features/reaction_runner/data/models/results_summary.dart';

/// Colour code for a metric's quality tier.
Color qualityColor(BuildContext context, MetricQuality quality) {
  final palette = ThemeNotifier.paletteOf(context);
  return switch (quality) {
    MetricQuality.computed => palette.success,
    MetricQuality.surrogate => palette.warning,
    MetricQuality.empirical => palette.accent,
    MetricQuality.illustrative => palette.danger,
  };
}

/// A small colour-coded chip labelling a metric's provenance tier.
class QualityBadge extends StatelessWidget {
  final MetricQuality quality;
  const QualityBadge({super.key, required this.quality});

  @override
  Widget build(BuildContext context) {
    final color = qualityColor(context, quality);
    return Tooltip(
      message: quality.description,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Text(
          quality.label,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

/// A themed panel with an optional left accent bar, used for every metric card.
class ResearchCard extends StatefulWidget {
  final Widget child;
  final Color? accent;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const ResearchCard({
    super.key,
    required this.child,
    this.accent,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  State<ResearchCard> createState() => _ResearchCardState();
}

class _ResearchCardState extends State<ResearchCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
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
    final accentColor = widget.accent ?? palette.accent;

    Widget content = AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            padding: widget.padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: palette.panel.withValues(alpha: 0.6),
              border: Border.all(
                color: Color.lerp(
                  palette.border,
                  accentColor.withValues(alpha: 0.5),
                  _glowAnimation.value,
                )!,
                width: 1 + (_glowAnimation.value * 0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: palette.isLight ? 0.05 : 0.18),
                  blurRadius: 14 + (10 * _glowAnimation.value),
                  offset: const Offset(0, 5),
                ),
                if (_glowAnimation.value > 0)
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.15 * _glowAnimation.value),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: dart_ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                  Padding(
                    padding: widget.accent != null ? const EdgeInsets.only(left: 18) : EdgeInsets.zero,
                    child: widget.child,
                  ),
                  if (widget.accent != null)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 4,
                      child: Container(
                        decoration: BoxDecoration(
                          color: widget.accent,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: widget.accent!.withValues(alpha: 0.6 * _glowAnimation.value),
                              blurRadius: 8,
                              spreadRadius: 1,
                            )
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );

    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: content,
      ),
    );
  }
}

/// Renders `value ± uncertainty` with tabular figures and a subdued unit.
class MetricValue extends StatelessWidget {
  final MetricEstimate metric;
  final double valueFontSize;

  const MetricValue({super.key, required this.metric, this.valueFontSize = 24});

  @override
  Widget build(BuildContext context) {
    final palette = ThemeNotifier.paletteOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
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
                    color: palette.textPrimary,
                    fontSize: valueFontSize,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              metric.formattedUncertainty,
              style: TextStyle(
                color: palette.warning,
                fontSize: (valueFontSize * 0.5).clamp(10, 13),
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          metric.unit,
          style: TextStyle(
            color: metric.accent,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
