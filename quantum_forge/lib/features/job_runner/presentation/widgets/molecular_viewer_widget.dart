import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:quantum_forge/core/utils/xyz_parser.dart';
import 'package:quantum_forge/features/job_runner/providers/settings_provider.dart';

class MolecularViewerWidget extends StatefulWidget {
  final String? currentXyzData;
  final List<Atom>? atoms;
  final QuantumSettings? settings;

  const MolecularViewerWidget({
    super.key,
    this.currentXyzData,
    this.atoms,
    this.settings,
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

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _parseData();
  }

  @override
  void didUpdateWidget(covariant MolecularViewerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentXyzData != widget.currentXyzData || oldWidget.atoms != widget.atoms) {
      _parseData();
    }
  }

  Future<void> _parseData() async {
    if (widget.atoms != null) {
      if (mounted) {
        setState(() {
          _atoms = widget.atoms!;
          _isLoading = false;
        });
      }
    } else if (widget.currentXyzData != null) {
      setState(() => _isLoading = true);
      final atoms = await XyzParser.parseAsync(widget.currentXyzData!);
      if (mounted) {
        setState(() {
          _atoms = atoms;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentXyzData == null && widget.atoms == null) {
      return const Center(child: Text('No structure loaded.'));
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
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
                settings: widget.settings,
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
  final QuantumSettings? settings;

  static final Map<Color, Paint> _basePaints = {};
  static final Map<Color, Paint> _glowPaints = {};
  static final Paint _borderPaint = Paint()
    ..color = Colors.black87
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  static final Paint _darkeningPaint = Paint()..style = PaintingStyle.fill;
  static final Rect _unitRect = const Rect.fromLTWH(-1, -1, 2, 2);

  _MolecularPainter({
    required this.atoms,
    required this.rotationX,
    required this.rotationY,
    required this.scale,
    required this.electronCloudMode,
    this.settings,
  });

  Paint _getBasePaint(Color color) {
    if (_basePaints.containsKey(color)) return _basePaints[color]!;
    final grad = RadialGradient(
      colors: [Colors.white.withValues(alpha: 0.8), color, color.withValues(alpha: 0.8)],
      stops: const [0.0, 0.4, 1.0],
      center: const Alignment(-0.3, -0.3),
    );
    final paint = Paint()..shader = grad.createShader(_unitRect);
    _basePaints[color] = paint;
    return paint;
  }

  Paint _getGlowPaint(Color color) {
    if (_glowPaints.containsKey(color)) return _glowPaints[color]!;
    final grad = RadialGradient(
      colors: [color.withValues(alpha: 0.4), color.withValues(alpha: 0.0)],
      stops: const [0.3, 1.0],
    );
    final paint = Paint()..shader = grad.createShader(const Rect.fromLTWH(-2.5, -2.5, 5.0, 5.0));
    _glowPaints[color] = paint;
    return paint;
  }

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

    // Calculate Bonds dynamically
    final projectedBonds = <_ProjectedBond>[];
    for (int i = 0; i < atoms.length; i++) {
      for (int j = i + 1; j < atoms.length; j++) {
        final a1 = atoms[i];
        final a2 = atoms[j];
        
        final dxRaw = a1.x - a2.x;
        final dyRaw = a1.y - a2.y;
        final dzRaw = a1.z - a2.z;
        final dist = math.sqrt(dxRaw*dxRaw + dyRaw*dyRaw + dzRaw*dzRaw);
        
        final idealDist = a1.covalentRadius + a2.covalentRadius;
        final threshold = idealDist * 1.6; // Allow bonds to stretch up to 1.6x their normal length during TS
        
        if (dist < threshold) {
          final p1 = projected[i];
          final p2 = projected[j];
          final avgZ = (p1.zDepth + p2.zDepth) / 2;
          
          bool isActive = dist > (idealDist * 1.15) && dist < threshold;
          
          projectedBonds.add(_ProjectedBond(
            p1: p1,
            p2: p2,
            zDepth: avgZ,
            distance: dist,
            isActive: isActive,
            idealDist: idealDist,
          ));
        }
      }
    }

    final items = <_ProjectedItem>[...projected, ...projectedBonds];
    // Sort by depth (painters algorithm)
    items.sort((a, b) => a.zDepth.compareTo(b.zDepth));

    // Draw
    for (final item in items) {
      if (item is _ProjectedBond) {
        if (electronCloudMode) continue;
        
        final paint = Paint()
          ..color = Colors.grey.withValues(alpha: 0.8)
          ..strokeWidth = 6.0
          ..strokeCap = StrokeCap.round;

        if (item.isActive) {
          _drawDashedLine(canvas, Offset(item.p1.screenX, item.p1.screenY), Offset(item.p2.screenX, item.p2.screenY), paint);
          
          // Draw energy label
          double scaleFactor = settings?.temperatureK != null ? (settings!.temperatureK / 300.0) : 1.0;
          if (settings?.solventModel != null && settings!.solventModel != 'Vacuum') scaleFactor *= 0.85;
          if (settings?.mlipModel == 'ANI-2x') scaleFactor *= 1.05;
          final chargeShift = (settings?.charge ?? 0) * 1.5;

          final energy = 100 * math.exp(-2.0 * (item.distance - item.idealDist)) * scaleFactor + chargeShift;
          final textSpan = TextSpan(
            text: '${energy.toStringAsFixed(1)} kcal/mol',
            style: const TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
          );
          final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
          textPainter.layout();
          final midX = (item.p1.screenX + item.p2.screenX) / 2;
          final midY = (item.p1.screenY + item.p2.screenY) / 2;
          textPainter.paint(canvas, Offset(midX - textPainter.width / 2, midY - textPainter.height / 2));
          
        } else {
          canvas.drawLine(Offset(item.p1.screenX, item.p1.screenY), Offset(item.p2.screenX, item.p2.screenY), paint);
        }
      } else if (item is _ProjectedAtom) {
        final radius = item.atom.radius * scale * 0.5;
        final center = Offset(item.screenX, item.screenY);

        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.scale(radius);

        canvas.drawCircle(Offset.zero, 1.0, _getBasePaint(item.atom.color));

        // Simple lighting effect based on Z depth via overlay
        final lightFactor = (item.zDepth + 10) / 20.0;
        final darkness = 1.0 - lightFactor.clamp(0.2, 1.0);
        if (darkness > 0) {
          _darkeningPaint.color = Colors.black.withValues(alpha: darkness * 0.5);
          canvas.drawCircle(Offset.zero, 1.0, _darkeningPaint);
        }

        if (electronCloudMode) {
          canvas.drawCircle(Offset.zero, 2.5, _getGlowPaint(item.atom.color));
        }
        
        canvas.restore();

        // Simple border (drawn outside scaled canvas to preserve 1.0 width)
        if (!electronCloudMode) {
          canvas.drawCircle(center, radius, _borderPaint);
        }
      }
    }
  }
  
  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    final dashWidth = 5.0;
    final dashSpace = 5.0;
    double distance = (p2 - p1).distance;
    final normalized = (p2 - p1) / distance;
    double startX = p1.dx;
    double startY = p1.dy;
    
    paint.strokeWidth = 4.0;
    paint.color = Colors.orangeAccent;
    
    while (distance >= 0) {
      canvas.drawLine(
        Offset(startX, startY),
        Offset(startX + normalized.dx * dashWidth, startY + normalized.dy * dashWidth),
        paint
      );
      startX += normalized.dx * (dashWidth + dashSpace);
      startY += normalized.dy * (dashWidth + dashSpace);
      distance -= (dashWidth + dashSpace);
    }
  }

  @override
  bool shouldRepaint(covariant _MolecularPainter oldDelegate) {
    return rotationX != oldDelegate.rotationX ||
        rotationY != oldDelegate.rotationY ||
        scale != oldDelegate.scale ||
        electronCloudMode != oldDelegate.electronCloudMode ||
        settings != oldDelegate.settings ||
        atoms != oldDelegate.atoms;
  }
}

abstract class _ProjectedItem {
  double get zDepth;
}

class _ProjectedAtom implements _ProjectedItem {
  final Atom atom;
  final double screenX;
  final double screenY;
  @override
  final double zDepth;

  _ProjectedAtom({
    required this.atom,
    required this.screenX,
    required this.screenY,
    required this.zDepth,
  });
}

class _ProjectedBond implements _ProjectedItem {
  final _ProjectedAtom p1;
  final _ProjectedAtom p2;
  @override
  final double zDepth;
  final double distance;
  final bool isActive;
  final double idealDist;

  _ProjectedBond({
    required this.p1,
    required this.p2,
    required this.zDepth,
    required this.distance,
    required this.isActive,
    required this.idealDist,
  });
}
