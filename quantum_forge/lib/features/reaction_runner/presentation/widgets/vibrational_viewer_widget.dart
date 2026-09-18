import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:quantum_forge/core/utils/xyz_parser.dart';
import 'package:quantum_forge/features/reaction_runner/data/models/reaction_models.dart';

class VibrationalViewerWidget extends StatefulWidget {
  final List<Atom> atoms;
  final List<VibrationalMode> modes;

  const VibrationalViewerWidget({
    super.key,
    required this.atoms,
    required this.modes,
  });

  @override
  State<VibrationalViewerWidget> createState() => _VibrationalViewerWidgetState();
}

class _VibrationalViewerWidgetState extends State<VibrationalViewerWidget>
    with SingleTickerProviderStateMixin {
  double _rotationX = 0;
  double _rotationY = 0;
  final double _scale = 45.0;
  
  late AnimationController _ctrl;
  int _activeModeIdx = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.atoms.isEmpty || widget.modes.isEmpty) {
      return const Center(child: Text('No vibrational data available.'));
    }

    final activeMode = widget.modes[_activeModeIdx];

    return Column(
      children: [
        // Mode Selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.black.withValues(alpha: 0.3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Imaginary Frequency:', style: TextStyle(color: Colors.white70, fontSize: 13)),
              DropdownButton<int>(
                value: _activeModeIdx,
                dropdownColor: const Color(0xFF2C2C2C),
                underline: const SizedBox(),
                items: List.generate(widget.modes.length, (i) {
                  return DropdownMenuItem(
                    value: i,
                    child: Text(
                      '${widget.modes[i].frequency.toStringAsFixed(1)} cm⁻¹',
                      style: const TextStyle(color: Color(0xFFFFAB40), fontWeight: FontWeight.bold),
                    ),
                  );
                }),
                onChanged: (val) {
                  if (val != null) setState(() => _activeModeIdx = val);
                },
              )
            ],
          ),
        ),
        
        // Viewer
        Expanded(
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _rotationY += details.delta.dx * 0.01;
                _rotationX += details.delta.dy * 0.01;
              });
            },
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, child) {
                // Compute displaced atoms
                final t = _ctrl.value * 2 * math.pi;
                // Displacement scales with the frequency (just for visual effect)
                final amplitude = 0.5; 
                final phase = math.sin(t) * amplitude;

                final displacedAtoms = <Atom>[];
                for (int i = 0; i < widget.atoms.length; i++) {
                  final base = widget.atoms[i];
                  double dx = 0, dy = 0, dz = 0;
                  if (i < activeMode.vectors.length) {
                    dx = activeMode.vectors[i][0] * phase;
                    dy = activeMode.vectors[i][1] * phase;
                    dz = activeMode.vectors[i][2] * phase;
                  }
                  displacedAtoms.add(Atom(
                    base.symbol,
                    base.x + dx,
                    base.y + dy,
                    base.z + dz,
                    base.color,
                    base.radius,
                    base.covalentRadius,
                  ));
                }

                return RepaintBoundary(
                  child: CustomPaint(
                    painter: _VibrationalPainter(
                      atoms: displacedAtoms,
                      baseAtoms: widget.atoms,
                      mode: activeMode,
                      phase: phase,
                      rotationX: _rotationX,
                      rotationY: _rotationY,
                      scale: _scale,
                    ),
                    size: Size.infinite,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _VibrationalPainter extends CustomPainter {
  final List<Atom> atoms;
  final List<Atom> baseAtoms;
  final VibrationalMode mode;
  final double phase;
  final double rotationX;
  final double rotationY;
  final double scale;

  _VibrationalPainter({
    required this.atoms,
    required this.baseAtoms,
    required this.mode,
    required this.phase,
    required this.rotationX,
    required this.rotationY,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF121212));

    final cx = size.width / 2;
    final cy = size.height / 2;
    final cosX = math.cos(rotationX);
    final sinX = math.sin(rotationX);
    final cosY = math.cos(rotationY);
    final sinY = math.sin(rotationY);

    // Compute bounding box
    double minX = double.infinity, maxX = double.negativeInfinity;
    double minY = double.infinity, maxY = double.negativeInfinity;
    for (final a in atoms) {
      if (a.x < minX) minX = a.x;
      if (a.x > maxX) maxX = a.x;
      if (a.y < minY) minY = a.y;
      if (a.y > maxY) maxY = a.y;
    }
    final molCx = (minX + maxX) / 2;
    final molCy = (minY + maxY) / 2;

    _ProjectedAtom proj(Atom a) {
      final dx = a.x - molCx;
      final dy = a.y - molCy;
      final dz = a.z;

      final rx = dx * cosY - dz * sinY;
      final rz1 = dx * sinY + dz * cosY;
      final ry = dy * cosX - rz1 * sinX;
      final rz2 = dy * sinX + rz1 * cosX;

      return _ProjectedAtom(
        a,
        cx + rx * scale,
        cy + ry * scale,
        rz2,
      );
    }

    final projected = atoms.map(proj).toList();
    final baseProjected = baseAtoms.map(proj).toList();

    // Draw bonds
    final bonds = <_ProjectedBond>[];
    for (int i = 0; i < projected.length; i++) {
      for (int j = i + 1; j < projected.length; j++) {
        final a1 = projected[i];
        final a2 = projected[j];
        final dx = a1.atom.x - a2.atom.x;
        final dy = a1.atom.y - a2.atom.y;
        final dz = a1.atom.z - a2.atom.z;
        final dist = math.sqrt(dx*dx + dy*dy + dz*dz);
        final idealDist = a1.atom.covalentRadius + a2.atom.covalentRadius;
        if (dist < idealDist * 1.4) {
          bonds.add(_ProjectedBond(a1, a2, (a1.z + a2.z) / 2));
        }
      }
    }

    final items = <_ProjectedItem>[...projected, ...bonds];
    items.sort((a, b) => a.z.compareTo(b.z));

    for (final item in items) {
      if (item is _ProjectedBond) {
        final p = Paint()
          ..color = Colors.white.withValues(alpha: 0.6)
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(item.a1.sx, item.a1.sy), Offset(item.a2.sx, item.a2.sy), p);
      } else if (item is _ProjectedAtom) {
        final r = item.atom.covalentRadius * scale * 0.45;
        
        // Draw atom
        final p = Paint()..color = item.atom.color;
        canvas.drawCircle(Offset(item.sx, item.sy), r, p);
        
        // Draw specular highlight
        final sh = Paint()
          ..color = Colors.white.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
        canvas.drawCircle(Offset(item.sx - r * 0.3, item.sy - r * 0.3), r * 0.3, sh);
      }
    }
    
    // Draw displacement vectors for active mode
    for (int i = 0; i < projected.length; i++) {
       if (i < mode.vectors.length) {
         final vec = mode.vectors[i];
         final vecMag = math.sqrt(vec[0]*vec[0] + vec[1]*vec[1] + vec[2]*vec[2]);
         if (vecMag > 0.05) { // Only draw significant vectors
            final base = baseProjected[i];
            
            // Project the end of the vector
            final endAtom = Atom('Ghost', baseAtoms[i].x + vec[0], baseAtoms[i].y + vec[1], baseAtoms[i].z + vec[2], Colors.transparent, 0.0, 0.0);
            final endProj = proj(endAtom);
            
            final vecPaint = Paint()
               ..color = const Color(0xFF4FC3F7).withValues(alpha: 0.8)
               ..strokeWidth = 2.0
               ..strokeCap = StrokeCap.round;
               
            // Draw vector arrow from base pos to (base pos + vector)
            canvas.drawLine(Offset(base.sx, base.sy), Offset(endProj.sx, endProj.sy), vecPaint);
            
            // Draw arrowhead
            final dirX = endProj.sx - base.sx;
            final dirY = endProj.sy - base.sy;
            final dirLen = math.sqrt(dirX*dirX + dirY*dirY);
            if (dirLen > 0) {
               final nx = dirX / dirLen;
               final ny = dirY / dirLen;
               final arrowLen = 6.0;
               final p1x = endProj.sx - nx * arrowLen - ny * arrowLen * 0.5;
               final p1y = endProj.sy - ny * arrowLen + nx * arrowLen * 0.5;
               final p2x = endProj.sx - nx * arrowLen + ny * arrowLen * 0.5;
               final p2y = endProj.sy - ny * arrowLen - nx * arrowLen * 0.5;
               
               canvas.drawLine(Offset(endProj.sx, endProj.sy), Offset(p1x, p1y), vecPaint);
               canvas.drawLine(Offset(endProj.sx, endProj.sy), Offset(p2x, p2y), vecPaint);
            }
         }
       }
    }
  }

  @override
  bool shouldRepaint(covariant _VibrationalPainter old) => true;
}

abstract class _ProjectedItem {
  double get z;
}

class _ProjectedAtom implements _ProjectedItem {
  final Atom atom;
  final double sx, sy;
  @override final double z;
  _ProjectedAtom(this.atom, this.sx, this.sy, this.z);
}

class _ProjectedBond implements _ProjectedItem {
  final _ProjectedAtom a1, a2;
  @override final double z;
  _ProjectedBond(this.a1, this.a2, this.z);
}
