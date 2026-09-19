import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:quantum_forge/core/utils/xyz_parser.dart';
import 'package:quantum_forge/features/reaction_runner/providers/settings_provider.dart';

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
  final double _scale = 60.0;
  bool _electronCloudMode = false;
  bool _showBondData = false;
  List<Atom> _atoms = [];
  List<Atom> _selectedAtoms = [];

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

  void _handleTap(TapUpDetails details, BoxConstraints constraints) {
    if (_atoms.isEmpty) return;

    final cx = constraints.maxWidth / 2;
    final cy = constraints.maxHeight / 2;

    double avgX = 0, avgY = 0, avgZ = 0;
    for (final a in _atoms) {
      avgX += a.x;
      avgY += a.y;
      avgZ += a.z;
    }
    avgX /= _atoms.length;
    avgY /= _atoms.length;
    avgZ /= _atoms.length;

    final cosX = math.cos(_rotationX);
    final sinX = math.sin(_rotationX);
    final cosY = math.cos(_rotationY);
    final sinY = math.sin(_rotationY);

    double maxDistSq = 0.0;
    for (final a in _atoms) {
      final dx = a.x - avgX;
      final dy = a.y - avgY;
      final dz = a.z - avgZ;
      final distSq = dx*dx + dy*dy + dz*dz;
      if (distSq > maxDistSq) maxDistSq = distSq;
    }

    double dynamicScale = _scale;
    if (maxDistSq > 0.01) {
      final maxDist = math.sqrt(maxDistSq);
      final targetSize = math.min(constraints.maxWidth, constraints.maxHeight) * 0.85;
      dynamicScale = targetSize / (2 * maxDist);
      dynamicScale = dynamicScale.clamp(25.0, 200.0);
    }

    Atom? closestAtom;
    double minScreenDistSq = double.infinity;

    for (final atom in _atoms) {
      final dx = atom.x - avgX;
      final dy = atom.y - avgY;
      final dz = atom.z - avgZ;

      final rx = dx * cosY - dz * sinY;
      final rz1 = dx * sinY + dz * cosY;

      final ry = dy * cosX - rz1 * sinX;

      final screenX = cx + rx * dynamicScale;
      final screenY = cy + ry * dynamicScale;

      final tapDx = screenX - details.localPosition.dx;
      final tapDy = screenY - details.localPosition.dy;
      final tapDistSq = tapDx * tapDx + tapDy * tapDy;

      final radius = atom.radius * dynamicScale * 0.25;
      final tapRadiusSq = (radius * 1.5) * (radius * 1.5); 

      if (tapDistSq < tapRadiusSq && tapDistSq < minScreenDistSq) {
        minScreenDistSq = tapDistSq;
        closestAtom = atom;
      }
    }

    if (closestAtom != null) {
      final atom = closestAtom!;
      setState(() {
        if (_selectedAtoms.contains(atom)) {
          _selectedAtoms.remove(atom);
        } else {
          if (_selectedAtoms.length < 3) {
            _selectedAtoms.add(atom);
          } else {
            _selectedAtoms.removeAt(0);
            _selectedAtoms.add(atom);
          }
        }
      });
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

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        _rotationY += details.delta.dx * 0.01;
                        _rotationX += details.delta.dy * 0.01;
                      });
                    },
                    onTapUp: (details) => _handleTap(details, constraints),
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _MolecularPainter(
                          atoms: _atoms,
                          selectedAtoms: _selectedAtoms,
                          rotationX: _rotationX,
                          rotationY: _rotationY,
                          scale: _scale,
                          electronCloudMode: _electronCloudMode,
                          showBondData: _showBondData,
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
                        const Text('Electron Cloud', style: TextStyle(color: Colors.white, fontSize: 12)),
                        Switch(
                          value: _electronCloudMode,
                          onChanged: (val) => setState(() => _electronCloudMode = val),
                          activeTrackColor: Colors.purpleAccent,
                        ),
                        const SizedBox(width: 8),
                        const Text('Bond Energies', style: TextStyle(color: Colors.white, fontSize: 12)),
                        Switch(
                          value: _showBondData,
                          onChanged: (val) => setState(() => _showBondData = val),
                          activeTrackColor: Colors.orangeAccent,
                        ),
                      ],
                    ),
                  ),
                  if (_selectedAtoms.isNotEmpty)
                    Positioned(
                      top: 50,
                      left: 12,
                      child: _buildMeasurementOverlay(),
                    ),
                ],
              ),
            ),
            if (_showBondData)
              _buildBondEnergiesPanel(),
          ],
        );
      },
    );
  }

  Widget _buildMeasurementOverlay() {
    String message = 'Selected: ${_selectedAtoms.map((a) => a.symbol).join("-")}';
    if (_selectedAtoms.length == 2) {
      final a1 = _selectedAtoms[0];
      final a2 = _selectedAtoms[1];
      final dist = math.sqrt(math.pow(a1.x-a2.x, 2) + math.pow(a1.y-a2.y, 2) + math.pow(a1.z-a2.z, 2));
      message += '\nDistance: ${dist.toStringAsFixed(3)} Å';
    } else if (_selectedAtoms.length == 3) {
      final a1 = _selectedAtoms[0];
      final a2 = _selectedAtoms[1]; // Vertex
      final a3 = _selectedAtoms[2];
      
      final v1x = a1.x - a2.x, v1y = a1.y - a2.y, v1z = a1.z - a2.z;
      final v2x = a3.x - a2.x, v2y = a3.y - a2.y, v2z = a3.z - a2.z;
      final dot = v1x*v2x + v1y*v2y + v1z*v2z;
      final mag1 = math.sqrt(v1x*v1x + v1y*v1y + v1z*v1z);
      final mag2 = math.sqrt(v2x*v2x + v2y*v2y + v2z*v2z);
      final angle = math.acos(dot / (mag1 * mag2)) * 180.0 / math.pi;
      message += '\nAngle: ${angle.toStringAsFixed(1)}°';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF4FC3F7).withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4)),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54, size: 18),
            onPressed: () => setState(() => _selectedAtoms.clear()),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          )
        ],
      ),
    );
  }

  Widget _buildBondEnergiesPanel() {
    final bonds = <_CalculatedBond>[];
    int bondIdx = 1;
    for (int i = 0; i < _atoms.length; i++) {
      for (int j = i + 1; j < _atoms.length; j++) {
        final a1 = _atoms[i], a2 = _atoms[j];
        final dx = a1.x - a2.x, dy = a1.y - a2.y, dz = a1.z - a2.z;
        final dist = math.sqrt(dx*dx + dy*dy + dz*dz);
        final idealDist = a1.covalentRadius + a2.covalentRadius;
        if (dist < idealDist * 1.6) {
          bonds.add(_CalculatedBond(a1, a2, dist, idealDist, bondIdx++));
        }
      }
    }

    if (bonds.isEmpty) return const SizedBox.shrink();

    double scaleFactor = widget.settings?.temperatureK != null ? (widget.settings!.temperatureK / 300.0) : 1.0;
    if (widget.settings?.solventModel != null && widget.settings!.solventModel != 'Vacuum') scaleFactor *= 0.85;
    if (widget.settings?.mlipModel == 'ANI-2x') scaleFactor *= 1.05;
    final chargeShift = (widget.settings?.charge ?? 0) * 1.5;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Bond Energies', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: bonds.map((b) {
              final energy = 100 * math.exp(-2.0 * (b.dist - b.idealDist)) * scaleFactor + chargeShift;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.orangeAccent, shape: BoxShape.circle),
                    child: Text('${b.index}', style: const TextStyle(color: Colors.black87, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 6),
                  Text('${b.a1.symbol}–${b.a2.symbol}: ${energy.toStringAsFixed(1)} kcal/mol',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11)),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _CalculatedBond {
  final Atom a1, a2;
  final double dist, idealDist;
  final int index;
  _CalculatedBond(this.a1, this.a2, this.dist, this.idealDist, this.index);
}


class _MolecularPainter extends CustomPainter {
  final List<Atom> atoms;
  final List<Atom> selectedAtoms;
  final double rotationX;
  final double rotationY;
  final double scale;
  final bool electronCloudMode;
  final bool showBondData;
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
    required this.selectedAtoms,
    required this.rotationX,
    required this.rotationY,
    required this.scale,
    required this.electronCloudMode,
    required this.showBondData,
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

    // Calculate maximum distance from center of mass for stable auto-scaling
    double maxDistSq = 0.0;
    if (atoms.isNotEmpty) {
      for (final a in atoms) {
        final dx = a.x - avgX;
        final dy = a.y - avgY;
        final dz = a.z - avgZ;
        final distSq = dx*dx + dy*dy + dz*dz;
        if (distSq > maxDistSq) maxDistSq = distSq;
      }
    }

    double dynamicScale = scale;
    if (maxDistSq > 0.01) {
      final maxDist = math.sqrt(maxDistSq);
      // Target 85% of the smallest screen dimension — gives atoms plenty of breathing room
      final targetSize = math.min(size.width, size.height) * 0.85;
      dynamicScale = targetSize / (2 * maxDist);
      dynamicScale = dynamicScale.clamp(25.0, 200.0);
    }

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
        screenX: cx + rx * dynamicScale,
        screenY: cy + ry * dynamicScale,
        zDepth: rz2,
      ));
    }

    // Calculate Bonds dynamically
    final projectedBonds = <_ProjectedBond>[];
    int bondIndexCounter = 1;
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
            index: bondIndexCounter++,
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
        } else {
          canvas.drawLine(Offset(item.p1.screenX, item.p1.screenY), Offset(item.p2.screenX, item.p2.screenY), paint);
        }
        
        if (showBondData) {
          // Draw badge
          final badgeRadius = 7.0;
          final midX = (item.p1.screenX + item.p2.screenX) / 2;
          final midY = (item.p1.screenY + item.p2.screenY) / 2;
          
          canvas.drawCircle(
            Offset(midX, midY), 
            badgeRadius, 
            Paint()..color = Colors.orangeAccent
          );
          
          final textSpan = TextSpan(
            text: '${item.index}',
            style: const TextStyle(
              color: Colors.black87, 
              fontSize: 10, 
              fontWeight: FontWeight.bold
            ),
          );
          final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
          textPainter.paint(canvas, Offset(midX - textPainter.width / 2, midY - textPainter.height / 2));
        }
      } else if (item is _ProjectedAtom) {
        final radius = item.atom.radius * scale * 0.25;
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
          
          if (selectedAtoms.contains(item.atom)) {
            final highlightPaint = Paint()
              ..color = const Color(0xFF4FC3F7)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3.0;
            canvas.drawCircle(center, radius + 4.0, highlightPaint);
          }
        }
      }
    }

    // Draw lines between selected atoms
    if (selectedAtoms.length > 1) {
      final pAtoms = selectedAtoms.map((a) => projected.firstWhere((p) => p.atom == a)).toList();
      final linePaint = Paint()
        ..color = const Color(0xFF4FC3F7).withValues(alpha: 0.8)
        ..strokeWidth = 4.0
        ..style = PaintingStyle.stroke;
      
      canvas.drawLine(Offset(pAtoms[0].screenX, pAtoms[0].screenY), Offset(pAtoms[1].screenX, pAtoms[1].screenY), linePaint);
      
      if (selectedAtoms.length == 3) {
        canvas.drawLine(Offset(pAtoms[1].screenX, pAtoms[1].screenY), Offset(pAtoms[2].screenX, pAtoms[2].screenY), linePaint);
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
        showBondData != oldDelegate.showBondData ||
        settings != oldDelegate.settings ||
        selectedAtoms != oldDelegate.selectedAtoms ||
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
  final int index;

  _ProjectedBond({
    required this.p1,
    required this.p2,
    required this.zDepth,
    required this.distance,
    required this.isActive,
    required this.idealDist,
    required this.index,
  });
}
