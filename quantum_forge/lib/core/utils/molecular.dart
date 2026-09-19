// ============================================================================
// Molecular model — the shared atom/analysis types
// ----------------------------------------------------------------------------
// These used to live inside `xyz_parser.dart`, which forced the Avogadro
// interchange layer to import a parser just to name an `Atom` (and created a
// cycle once the parser started reusing the interchange formula helper).
// Everything now depends on this neutral module.
// ============================================================================

import 'package:flutter/material.dart';

import 'element_data.dart';

/// A single atom with its cartesian coordinates and cached visual properties.
class Atom {
  final String symbol;
  double x;
  double y;
  double z;
  final Color color;
  final double radius;
  final double covalentRadius;

  Atom(this.symbol, this.x, this.y, this.z, this.color, this.radius,
      this.covalentRadius);

  Atom copyWith({String? symbol, double? x, double? y, double? z}) => Atom(
        symbol ?? this.symbol,
        x ?? this.x,
        y ?? this.y,
        z ?? this.z,
        ElementData.colors[symbol ?? this.symbol] ?? color,
        ElementData.vdwRadii[symbol ?? this.symbol] ?? radius,
        ElementData.covalentRadii[symbol ?? this.symbol] ?? covalentRadius,
      );

  @override
  String toString() =>
      '$symbol(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)}, ${z.toStringAsFixed(3)})';
}

/// Aggregate properties of a set of atoms.
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

  double get averageMass => numAtoms == 0 ? 0 : weight / numAtoms;
}

/// Hill-order molecular formula, e.g. `C8H10N4O2`.
///
/// Carbon first, then hydrogen, then the remaining elements alphabetically —
/// the ordering used by Avogadro and by most journals.
String hillFormula(List<Atom> atoms) {
  if (atoms.isEmpty) return '';
  final counts = <String, int>{};
  for (final atom in atoms) {
    counts[atom.symbol] = (counts[atom.symbol] ?? 0) + 1;
  }
  final parts = <String>[];
  void emit(String symbol) {
    final n = counts.remove(symbol);
    if (n == null) return;
    parts.add(n > 1 ? '$symbol$n' : symbol);
  }

  emit('C');
  emit('H');
  final rest = counts.keys.toList()..sort();
  for (final symbol in rest) {
    emit(symbol);
  }
  return parts.join();
}

/// Molar mass in g/mol for a set of atoms.
double molarMass(List<Atom> atoms) {
  var weight = 0.0;
  for (final atom in atoms) {
    weight += ElementData.atomicMasses[atom.symbol] ?? 0.0;
  }
  return weight;
}

/// Builds an atom using the element tables (colour, VDW and covalent radii).
Atom atomFor(String symbol, double x, double y, double z) {
  final canonical = ElementData.canonicalSymbol(symbol);
  return Atom(
    canonical,
    x,
    y,
    z,
    ElementData.colors[canonical] ?? Colors.pinkAccent,
    ElementData.vdwRadii[canonical] ?? 1.5,
    ElementData.covalentRadii[canonical] ?? 0.7,
  );
}
