
import 'package:flutter/material.dart';

class KineticChartWidget extends StatefulWidget {
  final List<double> energyProfile;
  final Function(int index)? onPointSelected;
  final double? referenceEa;

  const KineticChartWidget({
    super.key,
    required this.energyProfile,
    this.onPointSelected,
    this.referenceEa,
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
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 16, 16, 48), // Padding for labels
      child: LayoutBuilder(
        builder: (context, constraints) {
          return MouseRegion(
            onHover: (event) {
              _handleHover(event.localPosition, constraints.biggest);
            },
            onExit: (_) {
              setState(() => _hoveredIndex = null);
            },
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
    final xSpan = size.width / (widget.energyProfile.length - 1).clamp(1, double.infinity);
    final index = (localPosition.dx / xSpan).round();
    
    if (index >= 0 && index < widget.energyProfile.length) {
      if (_hoveredIndex != index) {
        setState(() => _hoveredIndex = index);
      }
    }
  }
}

class _KineticChartPainter extends CustomPainter {
  final List<double> energyProfile;
  final double? referenceEa;
  final int? hoveredIndex;

  static final Paint _gridPaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.1)
    ..strokeWidth = 1;
    
  static final Paint _linePaint = Paint()
    ..color = Colors.cyanAccent
    ..strokeWidth = 3
    ..style = PaintingStyle.stroke;
    
  static final Paint _refPaint = Paint()
    ..color = Colors.orangeAccent
    ..strokeWidth = 2
    ..style = PaintingStyle.stroke;
    
  static final Paint _normalPointPaint = Paint()
    ..color = Colors.cyan
    ..style = PaintingStyle.fill;
    
  static final Paint _hoveredPointPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;
    
  static final Paint _borderPaint = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
    
  static final Paint _tooltipPaint = Paint()..color = Colors.white;

  _KineticChartPainter({
    required this.energyProfile,
    this.referenceEa,
    this.hoveredIndex,
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
    
    // Add padding to y axis
    maxE += 15;
    minE -= 10;
    
    final yRange = maxE - minE;
    
    // Grid Lines and Labels
      
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Draw horizontal grid lines
    const int numYLabels = 5;
    for (int i = 0; i <= numYLabels; i++) {
      final yValue = minE + (yRange * i / numYLabels);
      final yPos = size.height - ((yValue - minE) / yRange) * size.height;
      
      canvas.drawLine(Offset(0, yPos), Offset(size.width, yPos), _gridPaint);
      
      textPainter.text = TextSpan(
        text: yValue.toStringAsFixed(0),
        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(-30, yPos - 6));
    }

    // Draw X labels
    for (int i = 0; i < energyProfile.length; i++) {
      final xPos = i * (size.width / (energyProfile.length - 1).clamp(1, double.infinity));
      textPainter.text = TextSpan(
        text: '$i',
        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(xPos - textPainter.width / 2, size.height + 10));
    }

    // Draw line
      
    final path = Path();
    final points = <Offset>[];

    for (int i = 0; i < energyProfile.length; i++) {
      final xPos = i * (size.width / (energyProfile.length - 1).clamp(1, double.infinity));
      final yPos = size.height - ((energyProfile[i] - minE) / yRange) * size.height;
      points.add(Offset(xPos, yPos));
    }

    if (points.isNotEmpty) {
      path.moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        // Simple cubic bezier smoothing
        final p0 = points[i - 1];
        final p1 = points[i];
        final cp1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
        final cp2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);
        path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p1.dx, p1.dy);
      }
      canvas.drawPath(path, _linePaint);
    }

    // Draw TS Reference line
    if (referenceEa != null) {
      final refY = size.height - ((referenceEa! - minE) / yRange) * size.height;
      // Draw dashed line
      const dashWidth = 5.0;
      const dashSpace = 5.0;
      double startX = 0;
      while (startX < size.width) {
        canvas.drawLine(Offset(startX, refY), Offset(startX + dashWidth, refY), _refPaint);
        startX += dashWidth + dashSpace;
      }
      
      textPainter.text = const TextSpan(
        text: 'Lit. Ea',
        style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(10, refY - 15));
    }

    // Draw Points
    for (int i = 0; i < points.length; i++) {
      final isHovered = i == hoveredIndex;
      final pointPaint = isHovered ? _hoveredPointPaint : _normalPointPaint;
      final radius = isHovered ? 6.0 : 4.0;
        
      canvas.drawCircle(points[i], radius, pointPaint);
      canvas.drawCircle(points[i], radius, _borderPaint);
      
      // Draw tooltip if hovered
      if (isHovered) {
        final text = '${energyProfile[i].toStringAsFixed(1)} kcal/mol';
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
          _tooltipPaint,
        );
        
        textPainter.paint(canvas, Offset(points[i].dx - textPainter.width / 2, points[i].dy - 31));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _KineticChartPainter oldDelegate) {
    return oldDelegate.hoveredIndex != hoveredIndex ||
           oldDelegate.energyProfile != energyProfile ||
           oldDelegate.referenceEa != referenceEa;
  }
}
