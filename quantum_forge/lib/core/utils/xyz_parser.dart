import 'dart:convert';
import 'package:flutter/material.dart';

class Atom {
  final String symbol;
  final double x;
  final double y;
  final double z;
  final Color color;
  final double radius;
  final double covalentRadius;

  const Atom(this.symbol, this.x, this.y, this.z, this.color, this.radius, this.covalentRadius);
}

class MolecularInfo {
  final String formula;
  final double weight;
  final int numAtoms;
  final Map<String, int> elementCounts;

  MolecularInfo({
    required this.formula,
    required this.weight,
    required this.numAtoms,
    required this.elementCounts,
  });
}

import 'package:quantum_forge/core/utils/element_data.dart';

class XyzParser {
  static final RegExp _whitespaceRegExp = RegExp(r'\s+');

  static Future<List<Atom>> parseAsync(String xyz) async {
    return parse(xyz);
  }

  static List<Atom> parse(String xyz) {
    final lines = const LineSplitter().convert(xyz).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.length < 3) return [];

    final atoms = <Atom>[];
    for (int i = 2; i < lines.length; i++) {
      final parts = lines[i].split(_whitespaceRegExp);
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
          ElementData.colors[symbol] ?? Colors.pinkAccent,
          ElementData.vdwRadii[symbol] ?? 1.5,
          ElementData.covalentRadii[symbol] ?? 0.7,
        ));
      }
    }
    return atoms;
  }

  static MolecularInfo getMolecularInfo(List<Atom> atoms) {
    double weight = 0.0;
    final counts = <String, int>{};

    for (final atom in atoms) {
      counts[atom.symbol] = (counts[atom.symbol] ?? 0) + 1;
      weight += ElementData.atomicMasses[atom.symbol] ?? 0.0;
    }

    // Build Hill formula
    final formulaBuffer = StringBuffer();
    if (counts.containsKey('C')) {
      formulaBuffer.write('C${counts['C']! > 1 ? counts['C'] : ''}');
      if (counts.containsKey('H')) {
        formulaBuffer.write('H${counts['H']! > 1 ? counts['H'] : ''}');
      }
    }

    final sortedKeys = counts.keys.toList()..sort();
    for (final key in sortedKeys) {
      if (counts.containsKey('C') && (key == 'C' || key == 'H')) continue;
      formulaBuffer.write('$key${counts[key]! > 1 ? counts[key] : ''}');
    }

    return MolecularInfo(
      formula: formulaBuffer.toString(),
      weight: weight,
      numAtoms: atoms.length,
      elementCounts: counts,
    );
  }

  static List<List<Atom>> getDistinctMolecules(List<Atom> atoms) {
    if (atoms.isEmpty) return [];

    final n = atoms.length;
    final adjacency = List.generate(n, (_) => <int>[]);

    for (int i = 0; i < n; i++) {
      for (int j = i + 1; j < n; j++) {
        final a = atoms[i], b = atoms[j];
        final dx = a.x - b.x, dy = a.y - b.y, dz = a.z - b.z;
        final distSq = dx * dx + dy * dy + dz * dz;
        final idealDist = a.covalentRadius + b.covalentRadius;
        
        // 1.18 is a typical bond length tolerance factor
        if (distSq < (idealDist * 1.18) * (idealDist * 1.18)) {
          adjacency[i].add(j);
          adjacency[j].add(i);
        }
      }
    }

    final visited = List.filled(n, false);
    final molecules = <List<Atom>>[];

    for (int i = 0; i < n; i++) {
      if (!visited[i]) {
        final currentMolecule = <Atom>[];
        final queue = [i];
        visited[i] = true;

        while (queue.isNotEmpty) {
          final curr = queue.removeAt(0);
          currentMolecule.add(atoms[curr]);
          for (final neighbor in adjacency[curr]) {
            if (!visited[neighbor]) {
              visited[neighbor] = true;
              queue.add(neighbor);
            }
          }
        }
        molecules.add(currentMolecule);
      }
    }

    return molecules;
  }
}
