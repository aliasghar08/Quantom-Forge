import 'package:flutter/material.dart';

class Atom {
  final String symbol;
  final double x;
  final double y;
  final double z;
  final Color color;
  final double radius;

  const Atom(this.symbol, this.x, this.y, this.z, this.color, this.radius);
}

class XyzParser {
  static const Map<String, Color> _atomColors = {
    'H': Colors.white,
    'C': Colors.grey,
    'O': Colors.red,
    'N': Colors.blue,
    'F': Colors.lightGreen,
    'Cl': Colors.green,
    'S': Colors.yellow,
    'P': Colors.orange,
  };

  static const Map<String, double> _atomRadii = {
    'H': 1.2,
    'C': 1.7,
    'O': 1.52,
    'N': 1.55,
    'F': 1.47,
    'Cl': 1.75,
    'S': 1.8,
    'P': 1.8,
  };

  static List<Atom> parse(String xyz) {
    final lines = xyz.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.length < 3) return [];

    final atoms = <Atom>[];
    for (int i = 2; i < lines.length; i++) {
      final parts = lines[i].split(RegExp(r'\s+'));
      if (parts.length >= 4) {
        final symbol = parts[0];
        final x = double.tryParse(parts[1]) ?? 0.0;
        final y = double.tryParse(parts[2]) ?? 0.0;
        final z = double.tryParse(parts[3]) ?? 0.0;
        
        atoms.add(Atom(
          symbol,
          x,
          y,
          z,
          _atomColors[symbol] ?? Colors.pinkAccent,
          _atomRadii[symbol] ?? 1.5,
        ));
      }
    }
    return atoms;
  }
}
