import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:quantum_forge/core/utils/xyz_parser.dart';

enum BuilderTool { navigate, draw, delete }

class InteractiveBuilderWidget extends StatefulWidget {
  final List<Atom> initialAtoms;
  final BuilderTool currentTool;
  final String currentElement;
  final ValueChanged<List<Atom>> onAtomsChanged;

  const InteractiveBuilderWidget({
    super.key,
    required this.initialAtoms,
    required this.currentTool,
    required this.currentElement,
    required this.onAtomsChanged,
  });

  @override
  State<InteractiveBuilderWidget> createState() => _InteractiveBuilderWidgetState();
}

class _InteractiveBuilderWidgetState extends State<InteractiveBuilderWidget> {
  double _rotationX = 0;
  double _rotationY = 0;
  double _scale = 60.0;
  List<Atom> _atoms = [];
  
  Atom? _dragStartAtom;
  Offset? _currentDragPos;

  // Variables to hold the dynamic scale and center from the last paint, 
  // so we can project/unproject clicks accurately.
  double _lastDynamicScale = 60.0;
  double _lastAvgX = 0;
  double _lastAvgY = 0;
  double _lastAvgZ = 0;

  @override
  void initState() {
    super.initState();
    _atoms = List.from(widget.initialAtoms);
  }

  @override
  void didUpdateWidget(covariant InteractiveBuilderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialAtoms != widget.initialAtoms) {
      _atoms = List.from(widget.initialAtoms);
    }
  }

  void _notifyChanges() {
    widget.onAtomsChanged(List.from(_atoms));
  }

  // Gets color, radius, covRadius for element
  Atom _createNewAtom(String symbol, double x, double y, double z) {
    // Generate a temporary XYZ to parse for defaults
    final xyz = "1\n\n$symbol $x $y $z";
    final parsed = XyzParser.parse(xyz);
    if (parsed.isNotEmpty) return parsed.first;
    return Atom(symbol, x, y, z, Colors.pinkAccent, 1.5, 0.7);
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (widget.currentTool == BuilderTool.navigate) {
      setState(() {
        _rotationY += details.delta.dx * 0.01;
        _rotationX += details.delta.dy * 0.01;
      });
    } else if (widget.currentTool == BuilderTool.draw && _dragStartAtom != null) {
      setState(() {
        _currentDragPos = details.localPosition;
      });
    }
  }

  void _handlePanStart(DragStartDetails details) {
    if (widget.currentTool == BuilderTool.draw) {
      // Check if we clicked on an atom to start drawing a bond
      final clickedAtom = _getAtomAtScreenPosition(details.localPosition);
      if (clickedAtom != null) {
        setState(() {
          _dragStartAtom = clickedAtom;
          _currentDragPos = details.localPosition;
        });
      }
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    if (widget.currentTool == BuilderTool.draw && _dragStartAtom != null && _currentDragPos != null) {
      // Finish drawing bond
      final worldPos = _unproject(_currentDragPos!);
      
      // Calculate distance vector
      final dx = worldPos.dx - _dragStartAtom!.x;
      final dy = worldPos.dy - _dragStartAtom!.y;
      final dz = worldPos.dz - _dragStartAtom!.z;
      
      // Normalize and multiply by standard bond length (e.g., sum of covalent radii)
      final length = math.sqrt(dx*dx + dy*dy + dz*dz);
      if (length > 0.1) {
        final tempNewAtom = _createNewAtom(widget.currentElement, 0, 0, 0);
        final idealDist = _dragStartAtom!.covalentRadius + tempNewAtom.covalentRadius;
        
        final nx = (dx / length) * idealDist;
        final ny = (dy / length) * idealDist;
        final nz = (dz / length) * idealDist;
        
        final newAtom = _createNewAtom(
          widget.currentElement, 
          _dragStartAtom!.x + nx, 
          _dragStartAtom!.y + ny, 
          _dragStartAtom!.z + nz
        );
        
        setState(() {
          _atoms.add(newAtom);
          _dragStartAtom = null;
          _currentDragPos = null;
        });
        _notifyChanges();
      } else {
        setState(() {
          _dragStartAtom = null;
          _currentDragPos = null;
        });
      }
    }
  }

  void _handleTapDown(TapDownDetails details) {
    final clickedAtom = _getAtomAtScreenPosition(details.localPosition);

    if (widget.currentTool == BuilderTool.delete) {
      if (clickedAtom != null) {
        setState(() {
          _atoms.remove(clickedAtom);
        });
        _notifyChanges();
      }
    } else if (widget.currentTool == BuilderTool.draw) {
      if (clickedAtom == null) {
        // Place atom in empty space
        final worldPos = _unproject(details.localPosition);
        final newAtom = _createNewAtom(widget.currentElement, worldPos.dx, worldPos.dy, worldPos.dz);
        setState(() {
          _atoms.add(newAtom);
        });
        _notifyChanges();
      }
    }
  }

  Atom? _getAtomAtScreenPosition(Offset screenPos) {
    // We iterate backwards to select the atom that is visually "on top" (highest Z)
    // Actually, we must project all atoms, sort by Z, then check hits.
    final projected = _projectAllAtoms();
    projected.sort((a, b) => b.zDepth.compareTo(a.zDepth)); // Highest Z first (closest to camera)

    for (final p in projected) {
      final dx = p.screenX - screenPos.dx;
      final dy = p.screenY - screenPos.dy;
      final distSq = dx*dx + dy*dy;
      final radius = p.atom.radius * _lastDynamicScale * 0.25;
      if (distSq <= radius * radius) {
        return p.atom;
      }
    }
    return null;
  }

  List<_ProjectedAtom> _projectAllAtoms() {
    final cx = context.size!.width / 2;
    final cy = context.size!.height / 2;
    final cosX = math.cos(_rotationX);
    final sinX = math.sin(_rotationX);
    final cosY = math.cos(_rotationY);
    final sinY = math.sin(_rotationY);

    final projected = <_ProjectedAtom>[];
    for (final atom in _atoms) {
      final dx = atom.x - _lastAvgX;
      final dy = atom.y - _lastAvgY;
      final dz = atom.z - _lastAvgZ;

      final rx = dx * cosY - dz * sinY;
      final rz1 = dx * sinY + dz * cosY;
      final ry = dy * cosX - rz1 * sinX;
      final rz2 = dy * sinX + rz1 * cosX;

      projected.add(_ProjectedAtom(
        atom: atom,
        screenX: cx + rx * _lastDynamicScale,
        screenY: cy + ry * _lastDynamicScale,
        zDepth: rz2,
      ));
    }
    return projected;
  }

  _WorldPos _unproject(Offset screenPos) {
    final cx = context.size!.width / 2;
    final cy = context.size!.height / 2;

    double sx = (screenPos.dx - cx) / _lastDynamicScale;
    double sy = (screenPos.dy - cy) / _lastDynamicScale;
    double sz = 0.0; // Place on the screen plane

    // Inverse X rotation (angle = -rotationX)
    double ry = sy * math.cos(-_rotationX) - sz * math.sin(-_rotationX);
    double rz1 = sy * math.sin(-_rotationX) + sz * math.cos(-_rotationX);

    // Inverse Y rotation (angle = -rotationY)
    double rx = sx * math.cos(-_rotationY) - rz1 * math.sin(-_rotationY);
    double rz2 = sx * math.sin(-_rotationY) + rz1 * math.cos(-_rotationY);

    return _WorldPos(rx + _lastAvgX, ry + _lastAvgY, rz2 + _lastAvgZ);
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (widget.currentTool == BuilderTool.navigate) {
      setState(() {
        _scale = (_scale * details.scale).clamp(10.0, 300.0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _handlePanStart,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      onTapDown: _handleTapDown,
      // onScaleUpdate: _onScaleUpdate, // Scale causes gesture conflicts with pan, using slider instead usually
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate Center of Mass
          double avgX = 0, avgY = 0, avgZ = 0;
          if (_atoms.isNotEmpty) {
            for (final a in _atoms) {
              avgX += a.x; avgY += a.y; avgZ += a.z;
            }
            avgX /= _atoms.length; avgY /= _atoms.length; avgZ /= _atoms.length;
          }
          _lastAvgX = avgX;
          _lastAvgY = avgY;
          _lastAvgZ = avgZ;

          // Auto-scale logic if user hasn't explicitly scrolled/zoomed, 
          // or we just use _scale. We will blend them.
          double maxDistSq = 0.0;
          for (final a in _atoms) {
            final dx = a.x - avgX;
            final dy = a.y - avgY;
            final dz = a.z - avgZ;
            final distSq = dx*dx + dy*dy + dz*dz;
            if (distSq > maxDistSq) maxDistSq = distSq;
          }

          _lastDynamicScale = _scale;
          if (maxDistSq > 0.01 && _atoms.length > 1) {
            final maxDist = math.sqrt(maxDistSq);
            final targetSize = math.min(constraints.maxWidth, constraints.maxHeight) * 0.85;
            _lastDynamicScale = (targetSize / (2 * maxDist)).clamp(25.0, 200.0);
            // Blend manual scale and auto scale
            _lastDynamicScale = _lastDynamicScale * (_scale / 60.0);
          }

          return CustomPaint(
            size: Size.infinite,
            painter: _BuilderPainter(
              atoms: _atoms,
              rotationX: _rotationX,
              rotationY: _rotationY,
              dynamicScale: _lastDynamicScale,
              avgX: avgX,
              avgY: avgY,
              avgZ: avgZ,
              dragStartAtom: _dragStartAtom,
              currentDragPos: _currentDragPos,
            ),
          );
        },
      ),
    );
  }
}

class _WorldPos {
  final double dx, dy, dz;
  _WorldPos(this.dx, this.dy, this.dz);
}

class _ProjectedAtom {
  final Atom atom;
  final double screenX, screenY, zDepth;
  _ProjectedAtom({required this.atom, required this.screenX, required this.screenY, required this.zDepth});
}

class _ProjectedBond {
  final _ProjectedAtom p1, p2;
  final double zDepth;
  final double distance;
  final double idealDist;
  _ProjectedBond({required this.p1, required this.p2, required this.zDepth, required this.distance, required this.idealDist});
}

class _BuilderPainter extends CustomPainter {
  final List<Atom> atoms;
  final double rotationX, rotationY, dynamicScale;
  final double avgX, avgY, avgZ;
  
  final Atom? dragStartAtom;
  final Offset? currentDragPos;

  static final Map<Color, Paint> _basePaints = {};
  static final Paint _borderPaint = Paint()..color = Colors.black87..style = PaintingStyle.stroke..strokeWidth = 1.0;
  static final Paint _darkeningPaint = Paint()..style = PaintingStyle.fill;
  static final Rect _unitRect = const Rect.fromLTWH(-1, -1, 2, 2);

  _BuilderPainter({
    required this.atoms,
    required this.rotationX,
    required this.rotationY,
    required this.dynamicScale,
    required this.avgX,
    required this.avgY,
    required this.avgZ,
    this.dragStartAtom,
    this.currentDragPos,
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

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final cosX = math.cos(rotationX);
    final sinX = math.sin(rotationX);
    final cosY = math.cos(rotationY);
    final sinY = math.sin(rotationY);

    final projected = <_ProjectedAtom>[];
    for (final atom in atoms) {
      final dx = atom.x - avgX;
      final dy = atom.y - avgY;
      final dz = atom.z - avgZ;

      final rx = dx * cosY - dz * sinY;
      final rz1 = dx * sinY + dz * cosY;
      final ry = dy * cosX - rz1 * sinX;
      final rz2 = dy * sinX + rz1 * cosX;

      projected.add(_ProjectedAtom(
        atom: atom,
        screenX: cx + rx * dynamicScale,
        screenY: cy + ry * dynamicScale,
        zDepth: rz2,
      ));
    }

    // Bonds
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
        final threshold = idealDist * 1.6;
        
        if (dist < threshold) {
          final p1 = projected[i];
          final p2 = projected[j];
          final avgZ = (p1.zDepth + p2.zDepth) / 2;
          projectedBonds.add(_ProjectedBond(p1: p1, p2: p2, zDepth: avgZ, distance: dist, idealDist: idealDist));
        }
      }
    }

    final items = <dynamic>[...projected, ...projectedBonds];
    items.sort((a, b) => a.zDepth.compareTo(b.zDepth));

    for (final item in items) {
      if (item is _ProjectedBond) {
        final paint = Paint()
          ..color = Colors.grey.withValues(alpha: 0.8)
          ..strokeWidth = 6.0
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(item.p1.screenX, item.p1.screenY), Offset(item.p2.screenX, item.p2.screenY), paint);
      } else if (item is _ProjectedAtom) {
        final radius = item.atom.radius * dynamicScale * 0.25;
        final center = Offset(item.screenX, item.screenY);

        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.scale(radius);

        canvas.drawCircle(Offset.zero, 1.0, _getBasePaint(item.atom.color));

        final lightFactor = (item.zDepth + 10) / 20.0;
        final darkness = 1.0 - lightFactor.clamp(0.2, 1.0);
        if (darkness > 0) {
          _darkeningPaint.color = Colors.black.withValues(alpha: darkness * 0.5);
          canvas.drawCircle(Offset.zero, 1.0, _darkeningPaint);
        }
        canvas.restore();
        canvas.drawCircle(center, radius, _borderPaint);
      }
    }

    // Draw active drag bond
    if (dragStartAtom != null && currentDragPos != null) {
      final pStart = projected.firstWhere((p) => p.atom == dragStartAtom, orElse: () => projected.first);
      final paint = Paint()
          ..color = const Color(0xFF4FC3F7).withValues(alpha: 0.8)
          ..strokeWidth = 4.0
          ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(pStart.screenX, pStart.screenY), currentDragPos!, paint);
      
      // Draw ghost atom at pointer
      final ghostRadius = dragStartAtom!.radius * dynamicScale * 0.25;
      canvas.drawCircle(currentDragPos!, ghostRadius, Paint()..color = Colors.white.withValues(alpha: 0.3));
    }
  }

  @override
  bool shouldRepaint(covariant _BuilderPainter oldDelegate) => true;
}
