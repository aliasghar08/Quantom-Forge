import 'package:flutter/material.dart';

/// Smoothly-drawn reaction energy profile with hover inspection and an optional
/// ±1σ uncertainty band around the curve.
class KineticChartWidget extends StatefulWidget {
  final List<double> energyProfile;
  final Function(int index)? onPointSelected;
  final double? referenceEa;

  /// 1σ band width (in the profile's own energy units).
  final double? uncertainty;
  final Color lineColor;
  final Color bandColor;
  final Color refColor;
  final Color gridColor;
  final Color labelColor;

  const KineticChartWidget({
    super.key,
    required this.energyProfile,
    this.onPointSelected,
    this.referenceEa,
    this.uncertainty,
    this.lineColor = Colors.cyanAccent,
    this.bandColor = Colors.cyanAccent,
    this.refColor = Colors.orangeAccent,
    this.gridColor = Colors.white,
    this.labelColor = Colors.white,
  });

  @override
  State<KineticChartWidget> createState() => _KineticChartWidgetState();
}

class _KineticChartWidgetState extends State<KineticChartWidget> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.energyProfile.isEmpty) {
      return Center(
        child: Text('No kinetic data available.',
            style: TextStyle(color: widget.labelColor.withValues(alpha: 0.4))),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 16, 16, 48),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return MouseRegion(
            onHover: (event) =>
                _handleHover(event.localPosition, constraints.biggest),
            onExit: (_) => setState(() => _hoveredIndex = null),
            child: GestureDetector(
              onTapUp: (details) {
                if (_hoveredIndex != null && widget.onPointSelected != null) {
                  widget.onPointSelected!(_hoveredIndex!);
                }
              },
              child: RepaintBoundary(
                child: CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: _KineticChartPainter(
                    energyProfile: widget.energyProfile,
                    referenceEa: widget.referenceEa,
                    hoveredIndex: _hoveredIndex,
                    uncertainty: widget.uncertainty,
                    lineColor: widget.lineColor,
                    bandColor: widget.bandColor,
                    refColor: widget.refColor,
                    gridColor: widget.gridColor,
                    labelColor: widget.labelColor,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _handleHover(Offset localPosition, Size size) {
    final xSpan =
        size.width / (widget.energyProfile.length - 1).clamp(1, double.infinity);
    final index = (localPosition.dx / xSpan).round();
    if (index >= 0 && index < widget.energyProfile.length) {
      if (_hoveredIndex != index) setState(() => _hoveredIndex = index);
    }
  }
}

class _KineticChartPainter extends CustomPainter {
  final List<double> energyProfile;
  final double? referenceEa;
  final int? hoveredIndex;
  final double? uncertainty;
  final Color lineColor;
  final Color bandColor;
  final Color refColor;
  final Color gridColor;
  final Color labelColor;

  _KineticChartPainter({
    required this.energyProfile,
    this.referenceEa,
    this.hoveredIndex,
    this.uncertainty,
    required this.lineColor,
    required this.bandColor,
    required this.refColor,
    required this.gridColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (energyProfile.isEmpty) return;

    double maxE = energyProfile[0];
    double minE = energyProfile[0];
    for (int i = 1; i < energyProfile.length; i++) {
      if (energyProfile[i] > maxE) maxE = energyProfile[i];
      if (energyProfile[i] < minE) minE = energyProfile[i];
    }
    maxE += 15;
    minE -= 10;
    final yRange = maxE - minE;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    double xPos(int i) =>
        i * (size.width / (energyProfile.length - 1).clamp(1, double.infinity));
    double yPos(double v) =>
        size.height - ((v - minE) / yRange) * size.height;

    // Grid + labels
    const int numYLabels = 5;
    for (int i = 0; i <= numYLabels; i++) {
      final yValue = minE + (yRange * i / numYLabels);
      final y = yPos(yValue);
      canvas.drawLine(
          Offset(0, y), Offset(size.width, y),
          Paint()
            ..color = gridColor.withValues(alpha: 0.1)
            ..strokeWidth = 1);
      textPainter.text = TextSpan(
        text: yValue.toStringAsFixed(0),
        style: TextStyle(color: labelColor.withValues(alpha: 0.4), fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(-30, y - 6));
    }

    final points = <Offset>[
      for (int i = 0; i < energyProfile.length; i++)
        Offset(xPos(i), yPos(energyProfile[i])),
    ];

    // ── Uncertainty band (±1σ) ────────────────────────────────────────────
    if (uncertainty != null && uncertainty! > 0) {
      final bandPath = Path();
      bandPath.moveTo(points.first.dx, yPos(energyProfile.first + uncertainty!));
      for (int i = 1; i < points.length; i++) {
        bandPath.lineTo(points[i].dx, yPos(energyProfile[i] + uncertainty!));
      }
      for (int i = points.length - 1; i >= 0; i--) {
        bandPath.lineTo(points[i].dx, yPos(energyProfile[i] - uncertainty!));
      }
      bandPath.close();
      canvas.drawPath(
        bandPath,
        Paint()..color = bandColor.withValues(alpha: 0.16),
      );
      // Thin band edges for a publication-figure look.
      final edgePath = Path()
        ..moveTo(points.first.dx, yPos(energyProfile.first + uncertainty!));
      for (int i = 1; i < points.length; i++) {
        edgePath.lineTo(points[i].dx, yPos(energyProfile[i] + uncertainty!));
      }
      canvas.drawPath(
        edgePath,
        Paint()
          ..color = bandColor.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    // Line (smoothed)
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final p0 = points[i - 1];
      final p1 = points[i];
      path.cubicTo(
        p0.dx + (p1.dx - p0.dx) / 2, p0.dy,
        p0.dx + (p1.dx - p0.dx) / 2, p1.dy,
        p1.dx, p1.dy,
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );

    // Literature reference line
    if (referenceEa != null) {
      final refY = yPos(referenceEa!);
      const dashWidth = 5.0, dashSpace = 5.0;
      double startX = 0;
      while (startX < size.width) {
        canvas.drawLine(
          Offset(startX, refY), Offset(startX + dashWidth, refY),
          Paint()
            ..color = refColor
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke,
        );
        startX += dashWidth + dashSpace;
      }
      textPainter.text = TextSpan(
        text: 'Lit. Ea',
        style: TextStyle(color: refColor, fontSize: 10, fontWeight: FontWeight.bold),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(10, refY - 15));
    }

    // Points + tooltip
    for (int i = 0; i < points.length; i++) {
      final isHovered = i == hoveredIndex;
      final radius = isHovered ? 6.0 : 4.0;
      canvas.drawCircle(points[i], radius,
          Paint()..color = isHovered ? Colors.white : lineColor);
      canvas.drawCircle(points[i], radius,
          Paint()
            ..color = Colors.black
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
      if (isHovered) {
        final text = '${energyProfile[i].toStringAsFixed(1)} kcal·mol⁻¹';
        textPainter.text = TextSpan(
          text: text,
          style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold),
        );
        textPainter.layout();
        final tooltipRect = Rect.fromLTWH(
          points[i].dx - textPainter.width / 2 - 8,
          points[i].dy - 35,
          textPainter.width + 16,
          24,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(tooltipRect, const Radius.circular(4)),
          Paint()..color = Colors.white,
        );
        textPainter.paint(
            canvas, Offset(points[i].dx - textPainter.width / 2, points[i].dy - 31));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _KineticChartPainter oldDelegate) =>
      oldDelegate.hoveredIndex != hoveredIndex ||
      oldDelegate.energyProfile != energyProfile ||
      oldDelegate.referenceEa != referenceEa ||
      oldDelegate.uncertainty != uncertainty;
}
