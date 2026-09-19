// ============================================================================
// XYZ parser / writer
// ----------------------------------------------------------------------------
// `Atom` and `MolecularInfo` now live in `molecular.dart`; they are re-exported
// here so the many existing `import '.../xyz_parser.dart'` call sites keep
// working unchanged.
// ============================================================================

import 'dart:convert';

import 'molecular.dart';

export 'molecular.dart' show Atom, MolecularInfo, hillFormula, molarMass, atomFor;

class XyzParser {
  static final RegExp _whitespaceRegExp = RegExp(r'\s+');

  static Future<List<Atom>> parseAsync(String xyz) async {
    return parse(xyz);
  }

  /// Parses an XYZ document.
  ///
  /// The declared atom count on the first line is honoured when present, so a
  /// multi-frame XYZ (an NEB trajectory, for example) yields its first frame
  /// instead of silently concatenating every frame into one "molecule".
  static List<Atom> parse(String xyz) {
    final lines = const LineSplitter().convert(xyz).map((l) => l.trim()).toList();

    var cursor = 0;
    while (cursor < lines.length && lines[cursor].isEmpty) {
      cursor++;
    }
    if (cursor >= lines.length) return const [];

    final declared = int.tryParse(lines[cursor].split(_whitespaceRegExp).first);
    cursor++; // count line
    if (cursor < lines.length) cursor++; // comment line (may be empty)

    final atoms = <Atom>[];
    final limit = declared != null && declared > 0 ? declared : -1;
    for (var i = cursor; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) continue;
      if (limit > 0 && atoms.length >= limit) break;
      final parts = line.split(_whitespaceRegExp);
      if (parts.length < 4) continue;
      final x = double.tryParse(parts[1]) ?? 0.0;
      final y = double.tryParse(parts[2]) ?? 0.0;
      final z = double.tryParse(parts[3]) ?? 0.0;
      atoms.add(atomFor(parts[0], x, y, z));
    }
    return atoms;
  }

  /// Serialises atoms back to a single-frame XYZ document.
  ///
  /// The count line is generated from [atoms], so it can never disagree with
  /// the atom block (the interactive builder previously hand-wrote this and
  /// could emit a mismatched header).
  static String serialize(
    List<Atom> atoms, {
    String title = 'Quantum Forge structure',
    int precision = 5,
  }) {
    final buffer = StringBuffer()
      ..writeln(atoms.length)
      ..writeln(title);
    for (final atom in atoms) {
      buffer
        ..write(atom.symbol.padRight(2))
        ..write(' ')
        ..write(atom.x.toStringAsFixed(precision).padLeft(precision + 5))
        ..write(' ')
        ..write(atom.y.toStringAsFixed(precision).padLeft(precision + 5))
        ..write(' ')
        ..write(atom.z.toStringAsFixed(precision).padLeft(precision + 5))
        ..writeln();
    }
    return buffer.toString();
  }

  static MolecularInfo getMolecularInfo(List<Atom> atoms) {
    final counts = <String, int>{};
    for (final atom in atoms) {
      counts[atom.symbol] = (counts[atom.symbol] ?? 0) + 1;
    }

    return MolecularInfo(
      formula: hillFormula(atoms),
      weight: molarMass(atoms),
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
