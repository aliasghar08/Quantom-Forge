import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:quantum_forge/core/utils/xyz_parser.dart';

class MolecularViewerWidget extends StatefulWidget {
  final String? currentXyzData;

  const MolecularViewerWidget({
    super.key,
    this.currentXyzData,
  });

  @override
  State<MolecularViewerWidget> createState() => _MolecularViewerWidgetState();
}

class _MolecularViewerWidgetState extends State<MolecularViewerWidget> {
  double _rotationX = 0;
  double _rotationY = 0;
  final double _scale = 20.0;
  bool _electronCloudMode = false;
  List<Atom> _atoms = [];

  @override
  void initState() {
    super.initState();
    _parseData();
  }

  @override
  void didUpdateWidget(covariant MolecularViewerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentXyzData != widget.currentXyzData) {
      _parseData();
    }
  }

  void _parseData() {
    if (widget.currentXyzData != null) {
      setState(() {
        _atoms = XyzParser.parse(widget.currentXyzData!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentXyzData == null) {
      return const Center(child: Text('No structure loaded.'));
    }

    return Stack(
      children: [
        GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              _rotationY += details.delta.dx * 0.01;
              _rotationX += details.delta.dy * 0.01;
            });
          },
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _MolecularPainter(
                atoms: _atoms,
                rotationX: _rotationX,
                rotationY: _rotationY,
                scale: _scale,
                electronCloudMode: _electronCloudMode,
              ),
              size: Size.infinite,
            ),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Row(
            children: [
              const Text('Electron Cloud Mode', style: TextStyle(color: Colors.white, fontSize: 12)),
              Switch(
                value: _electronCloudMode,
                onChanged: (val) => setState(() => _electronCloudMode = val),
                activeTrackColor: Colors.purpleAccent,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MolecularPainter extends CustomPainter {
  final List<Atom> atoms;
  final double rotationX;
  final double rotationY;
  final double scale;
  final bool electronCloudMode;

  _MolecularPainter({
    required this.atoms,
    required this.rotationX,
    required this.rotationY,
    required this.scale,
    required this.electronCloudMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Calculate center of mass to center the molecule
    double avgX = 0, avgY = 0, avgZ = 0;
    if (atoms.isNotEmpty) {
      for (final a in atoms) {
        avgX += a.x;
        avgY += a.y;
        avgZ += a.z;
      }
      avgX /= atoms.length;
      avgY /= atoms.length;
      avgZ /= atoms.length;
    }

    // Pre-calculate rotation sines and cosines
    final cosX = math.cos(rotationX);
    final sinX = math.sin(rotationX);
    final cosY = math.cos(rotationY);
    final sinY = math.sin(rotationY);

    // Project atoms
    final projected = <_ProjectedAtom>[];
    for (final atom in atoms) {
      // Center
      final dx = atom.x - avgX;
      final dy = atom.y - avgY;
      final dz = atom.z - avgZ;

      // Rotate Y
      final rx = dx * cosY - dz * sinY;
      final rz1 = dx * sinY + dz * cosY;

      // Rotate X
      final ry = dy * cosX - rz1 * sinX;
      final rz2 = dy * sinX + rz1 * cosX;

      projected.add(_ProjectedAtom(
        atom: atom,
        screenX: cx + rx * scale,
        screenY: cy + ry * scale,
        zDepth: rz2,
      ));
    }

    // Sort by depth (painters algorithm)
    projected.sort((a, b) => a.zDepth.compareTo(b.zDepth));

    // Pre-allocate Paint objects to avoid GC pressure during animation
    final spherePaint = Paint();
    final borderPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw
    for (final p in projected) {
      // Simple lighting effect based on Z depth
      final lightFactor = (p.zDepth + 10) / 20.0;
      final adjustedColor = Color.lerp(Colors.black, p.atom.color, lightFactor.clamp(0.2, 1.0))!;
      
      final radius = p.atom.radius * scale * 0.5;
      final center = Offset(p.screenX, p.screenY);

      final grad = RadialGradient(
        colors: [Colors.white.withValues(alpha: 0.8), adjustedColor, adjustedColor.withValues(alpha: 0.8)],
        stops: const [0.0, 0.4, 1.0],
        center: const Alignment(-0.3, -0.3),
      );

      final rect = Rect.fromCircle(center: center, radius: radius);
      spherePaint.shader = grad.createShader(rect);

      canvas.drawCircle(center, radius, spherePaint);
      
      // Simple border
      if (!electronCloudMode) {
        canvas.drawCircle(center, radius, borderPaint);
      } else {
        // Draw orbital glow
        final glowPaint = Paint()
          ..shader = RadialGradient(
            colors: [
              p.atom.color.withValues(alpha: 0.4),
              p.atom.color.withValues(alpha: 0.0)
            ],
            stops: const [0.3, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: radius * 2.5));
        canvas.drawCircle(center, radius * 2.5, glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MolecularPainter oldDelegate) {
    return rotationX != oldDelegate.rotationX ||
        rotationY != oldDelegate.rotationY ||
        scale != oldDelegate.scale ||
        electronCloudMode != oldDelegate.electronCloudMode ||
        atoms != oldDelegate.atoms;
  }
}

class _ProjectedAtom {
  final Atom atom;
  final double screenX;
  final double screenY;
  final double zDepth;

  _ProjectedAtom({
    required this.atom,
    required this.screenX,
    required this.screenY,
    required this.zDepth,
  });
}
