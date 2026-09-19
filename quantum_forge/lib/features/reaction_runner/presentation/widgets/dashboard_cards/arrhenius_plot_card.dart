import 'dart:math';
import 'package:flutter/material.dart';
import 'package:quantum_forge/core/theme/theme_provider.dart';
import 'research_ui.dart';

class ArrheniusPlotCard extends StatelessWidget {
  final double ea;
  final double? eaUncertainty;
  final List<double> rateVsTemp;

  /// 1σ band width in natural-log (ln k) units.
  final double? lnUncertainty;

  const ArrheniusPlotCard({
    super.key,
    required this.ea,
    required this.rateVsTemp,
    this.eaUncertainty,
    this.lnUncertainty,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ThemeNotifier.paletteOf(context);
    return AspectRatio(
      aspectRatio: 2.5,
      child: ResearchCard(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_down, color: palette.accent, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Arrhenius Plot — ln(k) vs Temperature (200 → 1000 K)',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: palette.panelAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: palette.border),
                  ),
                  child: Text(
                    'Ea = ${ea.toStringAsFixed(1)}'
                    '${eaUncertainty != null ? ' ± ${eaUncertainty!.toStringAsFixed(1)}' : ''} kcal·mol⁻¹',
                    style: TextStyle(color: palette.textSecondary, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: CustomPaint(
                painter: _ArrheniusPlotPainter(
                  lnKValues: rateVsTemp,
                  lnUncertainty: lnUncertainty,
                  lineColor: palette.accent,
                  bandColor: palette.accent,
                  gridColor: palette.plotGrid,
                  labelColor: palette.textMuted,
                ),
                size: Size.infinite,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArrheniusPlotPainter extends CustomPainter {
  final List<double> lnKValues;
  final double? lnUncertainty;
  final Color lineColor;
  final Color bandColor;
  final Color gridColor;
  final Color labelColor;

  _ArrheniusPlotPainter({
    required this.lnKValues,
    required this.lnUncertainty,
    required this.lineColor,
    required this.bandColor,
    required this.gridColor,
    required this.labelColor,
  });

  static const _leftPad = 52.0;
  static const _bottomPad = 28.0;
  static const _topPad = 10.0;
  static const _rightPad = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (lnKValues.length < 2) return;

    final double minY = lnKValues.reduce((a, b) => a < b ? a : b);
    final double maxY = lnKValues.reduce((a, b) => a > b ? a : b);
    final double rangeY = (maxY - minY).abs() < 0.0001 ? 1.0 : maxY - minY;
    final int n = lnKValues.length;

    final plotW = size.width - _leftPad - _rightPad;
    final plotH = size.height - _bottomPad - _topPad;

    double px(int i) => _leftPad + plotW * i / (n - 1);
    double py(double v) => _topPad + plotH - plotH * (v - minY) / rangeY;

    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.14)
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = labelColor.withValues(alpha: 0.25)
      ..strokeWidth = 1.2;
    final ts = TextStyle(color: labelColor.withValues(alpha: 0.6), fontSize: 10);

    const yDivs = 5;
    for (int i = 0; i <= yDivs; i++) {
      final v = minY + rangeY * i / yDivs;
      final y = py(v);
      canvas.drawLine(Offset(_leftPad, y), Offset(size.width - _rightPad, y), gridPaint);
      final tp = TextPainter(text: TextSpan(text: v.toStringAsFixed(1), style: ts), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(_leftPad - tp.width - 6, y - tp.height / 2));
    }

    final temps = [200, 300, 400, 500, 600, 700, 800, 900, 1000];
    for (final T in temps) {
      final xi = ((T - 200) / 80.0).round().clamp(0, n - 1);
      final x = px(xi);
      if (x < _leftPad || x > size.width - _rightPad) continue;
      canvas.drawLine(Offset(x, _topPad), Offset(x, size.height - _bottomPad), gridPaint);
      final tp = TextPainter(text: TextSpan(text: '${T}K', style: ts), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height - _bottomPad + 4));
    }

    canvas.drawLine(Offset(_leftPad, _topPad), Offset(_leftPad, size.height - _bottomPad), axisPaint);
    canvas.drawLine(Offset(_leftPad, size.height - _bottomPad), Offset(size.width - _rightPad, size.height - _bottomPad), axisPaint);

    final yLabel = TextPainter(
      text: TextSpan(text: 'ln(k / s⁻¹)', style: TextStyle(color: labelColor.withValues(alpha: 0.6), fontSize: 10)),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(10, _topPad + plotH / 2 + yLabel.width / 2);
    canvas.rotate(-pi / 2);
    yLabel.paint(canvas, Offset.zero);
    canvas.restore();

    // ── Uncertainty band ───────────────────────────────────────────────────
    if (lnUncertainty != null && lnUncertainty! > 0) {
      final band = Path();
      band.moveTo(px(0), py(lnKValues[0] + lnUncertainty!));
      for (int i = 1; i < n; i++) {
        band.lineTo(px(i), py(lnKValues[i] + lnUncertainty!));
      }
      for (int i = n - 1; i >= 0; i--) {
        band.lineTo(px(i), py(lnKValues[i] - lnUncertainty!));
      }
      band.close();
      canvas.drawPath(band, Paint()..color = bandColor.withValues(alpha: 0.14));
    }

    // Filled area + line
    final fillPath = Path()..moveTo(px(0), size.height - _bottomPad);
    for (int i = 0; i < n; i++) {
      fillPath.lineTo(px(i), py(lnKValues[i]));
    }
    fillPath.lineTo(px(n - 1), size.height - _bottomPad);
    fillPath.close();
    canvas.drawPath(fillPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [lineColor.withValues(alpha: 0.28), lineColor.withValues(alpha: 0.04)],
          ).createShader(Rect.fromLTWH(_leftPad, _topPad, plotW, plotH)));

    final path = Path();
    for (int i = 0; i < n; i++) {
      final x = px(i), y = py(lnKValues[i]);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(path,
        Paint()
          ..color = lineColor
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);

    for (int i = 0; i < n; i++) {
      final x = px(i), y = py(lnKValues[i]);
      canvas.drawCircle(Offset(x, y), 4.5, Paint()..color = lineColor.withValues(alpha: 0.9));
      canvas.drawCircle(Offset(x, y), 4.5, Paint()..color = Colors.white.withValues(alpha: 0.5)..style = PaintingStyle.stroke..strokeWidth = 1);
    }
  }

  @override
  bool shouldRepaint(covariant _ArrheniusPlotPainter old) =>
      old.lnKValues != lnKValues || old.lnUncertainty != lnUncertainty;
}
