import 'dart:math';
import 'package:flutter/material.dart';

class ArrheniusPlotCard extends StatelessWidget {
  final double ea;
  final List<double> rateVsTemp;

  const ArrheniusPlotCard({
    super.key,
    required this.ea,
    required this.rateVsTemp,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2.5,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.trending_down, color: Color(0xFF4FC3F7), size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Arrhenius Plot — ln(k) vs Temperature (200 K → 1000 K)',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Text(
                      'Ea = ${ea.toStringAsFixed(1)} kcal/mol',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: CustomPaint(
                  painter: _ArrheniusPlotPainter(rateVsTemp),
                  size: Size.infinite,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArrheniusPlotPainter extends CustomPainter {
  final List<double> lnKValues;
  _ArrheniusPlotPainter(this.lnKValues);

  static const _leftPad  = 52.0;
  static const _bottomPad = 28.0;
  static const _topPad    = 10.0;
  static const _rightPad  = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (lnKValues.length < 2) return;

    final double minY = lnKValues.reduce((a, b) => a < b ? a : b);
    final double maxY = lnKValues.reduce((a, b) => a > b ? a : b);
    final double rangeY = (maxY - minY).abs() < 0.0001 ? 1.0 : maxY - minY;
    final int n = lnKValues.length;

    final plotW = size.width  - _leftPad - _rightPad;
    final plotH = size.height - _bottomPad - _topPad;

    double px(int i) => _leftPad + plotW * i / (n - 1);
    double py(double v) => _topPad + plotH - plotH * (v - minY) / rangeY;

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 1.2;
    final ts = TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 10);

    // ── Grid & Y-axis labels ──────────────────────────────────────────────
    const yDivs = 5;
    for (int i = 0; i <= yDivs; i++) {
      final v = minY + rangeY * i / yDivs;
      final y = py(v);
      canvas.drawLine(Offset(_leftPad, y), Offset(size.width - _rightPad, y), gridPaint);
      // Y label
      final tp = TextPainter(
        text: TextSpan(text: v.toStringAsFixed(1), style: ts),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(_leftPad - tp.width - 6, y - tp.height / 2));
    }

    // ── X-axis grid & labels ──────────────────────────────────────────────
    final temps = [200, 300, 400, 500, 600, 700, 800, 900, 1000];
    for (final T in temps) {
      final xi = ((T - 200) / 80.0).round().clamp(0, n - 1);
      final x = px(xi);
      if (x < _leftPad || x > size.width - _rightPad) continue;
      canvas.drawLine(
        Offset(x, _topPad), Offset(x, size.height - _bottomPad), gridPaint);
      final tp = TextPainter(
        text: TextSpan(text: '${T}K', style: ts),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height - _bottomPad + 4));
    }

    // ── Axes ──────────────────────────────────────────────────────────────
    canvas.drawLine(
        Offset(_leftPad, _topPad), Offset(_leftPad, size.height - _bottomPad), axisPaint);
    canvas.drawLine(
        Offset(_leftPad, size.height - _bottomPad),
        Offset(size.width - _rightPad, size.height - _bottomPad), axisPaint);

    // Y-axis label
    final yLabel = TextPainter(
      text: TextSpan(
          text: 'ln(k / s⁻¹)',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10)),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(10, _topPad + plotH / 2 + yLabel.width / 2);
    canvas.rotate(-pi / 2);
    yLabel.paint(canvas, Offset.zero);
    canvas.restore();

    // ── Filled area under curve ───────────────────────────────────────────
    final fillPath = Path();
    fillPath.moveTo(px(0), size.height - _bottomPad);
    for (int i = 0; i < n; i++) {
      fillPath.lineTo(px(i), py(lnKValues[i]));
    }
    fillPath.lineTo(px(n - 1), size.height - _bottomPad);
    fillPath.close();

    final fillGrad = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF4FC3F7).withValues(alpha: 0.28),
        const Color(0xFF4FC3F7).withValues(alpha: 0.04),
      ],
    );
    canvas.drawPath(fillPath,
        Paint()..shader = fillGrad.createShader(
            Rect.fromLTWH(_leftPad, _topPad, plotW, plotH)));

    // ── Gradient line ─────────────────────────────────────────────────────
    final lineGrad = const LinearGradient(
      colors: [Color(0xFF80DEEA), Color(0xFF4FC3F7), Color(0xFF1565C0)],
    );
    final linePaint = Paint()
      ..shader = lineGrad.createShader(
          Rect.fromLTWH(_leftPad, _topPad, plotW, plotH))
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    for (int i = 0; i < n; i++) {
      final x = px(i), y = py(lnKValues[i]);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(path, linePaint);

    // ── Data dots ─────────────────────────────────────────────────────────
    for (int i = 0; i < n; i++) {
      final x = px(i), y = py(lnKValues[i]);
      canvas.drawCircle(Offset(x, y), 4.5, Paint()
        ..color = const Color(0xFF4FC3F7).withValues(alpha: 0.9));
      canvas.drawCircle(Offset(x, y), 4.5, Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1);
    }
  }

  @override
  bool shouldRepaint(covariant _ArrheniusPlotPainter old) =>
      old.lnKValues != lnKValues;
}
