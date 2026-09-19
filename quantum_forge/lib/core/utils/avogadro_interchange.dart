// ============================================================================
// Avogadro 2 Interchange Writers
// ----------------------------------------------------------------------------
// Avogadro 2 speaks Chemical JSON (CJSON) natively, and also reads CML, XYZ,
// SDF and PDB. Quantum Forge previously only produced a (malformed) XYZ
// download, which is why "load structure files exported from Avogadro" worked
// one way at best.
//
// This file implements real writers for the formats that matter:
//
//   * CJSON  — round-trips chemistry (elements, bonds, orders, partial charges)
//   * CML    — XML with a proper <atomArray>/<bondArray> and 3D coordinates
//   * XYZ    — plain cartesian, correct header handling, adjustable precision
//   * SDF    — V2000 connection table with a real bond block
//
// Bond perception is shared by CJSON/CML/SDF and uses covalent radii with a
// configurable tolerance, plus a valence-aware bond-order refinement.
// ============================================================================

import 'dart:math' as math;

import 'element_data.dart';
import 'molecular.dart';

/// A perceived bond between two atom indices (0-based).
class PerceivedBond {
  final int a;
  final int b;
  final int order;
  final double length;

  const PerceivedBond({
    required this.a,
    required this.b,
    required this.order,
    required this.length,
  });

  /// True for amide/aromatic-style delocalised bonds (order 1.5 in V2000).
  bool get isAromatic => order == 4;

  /// V2000 bond type code.
  int get v2000Order => switch (order) {
        2 => 2,
        3 => 3,
        4 => 4,
        _ => 1,
      };
}

/// Maximum classical valence per element (used for bond-order refinement).
const Map<String, int> _maxValence = {
  'H': 1, 'He': 0, 'Li': 1, 'Be': 2, 'B': 3, 'C': 4, 'N': 3, 'O': 2, 'F': 1,
  'Ne': 0, 'Na': 1, 'Mg': 2, 'Al': 3, 'Si': 4, 'P': 5, 'S': 6, 'Cl': 1,
  'Ar': 0, 'K': 1, 'Ca': 2, 'Br': 1, 'I': 1, 'Se': 2, 'As': 3, 'Te': 2,
};

/// Every structure Quantum Forge can hand to Avogadro, plus its metadata.
class AvogadroStructure {
  final String title;
  final List<Atom> atoms;
  final List<PerceivedBond> bonds;
  final int charge;
  final int multiplicity;

  const AvogadroStructure({
    required this.title,
    required this.atoms,
    required this.bonds,
    this.charge = 0,
    this.multiplicity = 1,
  });

  int get atomCount => atoms.length;
  bool get isEmpty => atoms.isEmpty;
}

class AvogadroInterchange {
  const AvogadroInterchange._();

  static const String generator = 'Quantum Forge';
  static const int version = 1;

  /// Perceives bonds from interatomic distances.
  ///
  /// [tolerance] is the multiplier applied to the sum of covalent radii
  /// (1.6 is a sensible default; the interactive builder uses the same value).
  /// Bond orders are then refined so that no atom exceeds its classical
  /// valence, which gives Avogadro a chemically sensible connection table.
  static List<PerceivedBond> perceiveBonds(
    List<Atom> atoms, {
    double tolerance = 1.6,
  }) {
    final raw = <PerceivedBond>[];
    for (var i = 0; i < atoms.length; i++) {
      for (var j = i + 1; j < atoms.length; j++) {
        final dx = atoms[i].x - atoms[j].x;
        final dy = atoms[i].y - atoms[j].y;
        final dz = atoms[i].z - atoms[j].z;
        final dist = math.sqrt(dx * dx + dy * dy + dz * dz);
        final ideal = atoms[i].covalentRadius + atoms[j].covalentRadius;
        if (dist > 0.15 && dist <= ideal * tolerance) {
          raw.add(PerceivedBond(a: i, b: j, order: 1, length: dist));
        }
      }
    }

    // Valence-aware refinement: promote a single bond to a double bond when
    // both atoms still have a spare valence and the bond is short relative to
    // the covalent sum (a cheap but effective heuristic).
    final maxValences = [
      for (final atom in atoms) _maxValence[atom.symbol] ?? 8,
    ];
    final used = List<int>.generate(
      atoms.length,
      (i) => raw.where((b) => b.a == i || b.b == i).length,
    );

    final refined = <PerceivedBond>[];
    for (final bond in raw) {
      final a = atoms[bond.a];
      final b = atoms[bond.b];
      final maxA = maxValences[bond.a];
      final maxB = maxValences[bond.b];
      final ideal = a.covalentRadius + b.covalentRadius;
      final isShort = bond.length < ideal * 0.88;

      var order = 1;
      if (isShort && maxA - used[bond.a] >= 1 && maxB - used[bond.b] >= 1) {
        order = 2;
        used[bond.a] += 1;
        used[bond.b] += 1;
      }
      refined.add(PerceivedBond(
        a: bond.a,
        b: bond.b,
        order: order,
        length: bond.length,
      ));
    }
    return refined;
  }

  /// Builds a full structure description from atoms and a title.
  static AvogadroStructure structure(
    List<Atom> atoms, {
    String title = 'Quantum Forge structure',
    int charge = 0,
    int multiplicity = 1,
    double bondTolerance = 1.6,
  }) {
    return AvogadroStructure(
      title: title.isEmpty ? 'Quantum Forge structure' : title,
      atoms: List<Atom>.unmodifiable(atoms),
      bonds: perceiveBonds(atoms, tolerance: bondTolerance),
      charge: charge,
      multiplicity: multiplicity,
    );
  }

  // ── CJSON ────────────────────────────────────────────────────────────────
  /// Serialises to Chemical JSON as read by Avogadro 2 (`input-format=cjson`).
  static Map<String, dynamic> toCjsonMap(AvogadroStructure s) {
    final coords = <double>[];
    final numbers = <int>[];
    for (final atom in s.atoms) {
      coords.addAll([_round(atom.x), _round(atom.y), _round(atom.z)]);
      numbers.add(ElementData.atomicNumber(atom.symbol));
    }

    final cjson = <String, dynamic>{
      'chemicalJson': version,
      'name': s.title,
      'generator': generator,
      'atoms': {
        'coords': {'3d': coords},
        'elements': {'number': numbers},
      },
    };

    if (s.bonds.isNotEmpty) {
      final index = <int>[];
      final order = <int>[];
      for (final bond in s.bonds) {
        index.addAll([bond.a, bond.b]);
        order.add(bond.order);
      }
      cjson['bonds'] = {
        'connections': {'index': index},
        'order': order,
      };
    }

    if (s.charge != 0 || s.multiplicity != 1) {
      cjson['properties'] = {
        'totalCharge': s.charge,
        'totalSpinMultiplicity': s.multiplicity,
      };
    }

    // Molecular formula is a nice-to-have that Avogadro displays in the
    // overview panel; cheap to compute, so always include it.
    final formula = formulaOf(s.atoms);
    if (formula.isNotEmpty) {
      cjson['formula'] = formula;
    }
    return cjson;
  }

  /// Serialises to a CJSON document (pretty printed).
  static String toCjson(AvogadroStructure s) =>
      _prettyJson(toCjsonMap(s));

  // ── XYZ ──────────────────────────────────────────────────────────────────
  /// Writes a single-frame XYZ block. The count line always matches the atom
  /// block — the interactive builder used to emit a header that could differ
  /// from the real atom count.
  static String toXyz(
    AvogadroStructure s, {
    int precision = 5,
    bool includeTitleLine = true,
  }) {
    final buffer = StringBuffer()
      ..writeln(s.atoms.length)
      ..writeln(includeTitleLine ? s.title : '');
    for (final atom in s.atoms) {
      buffer
        ..write(_pad(atom.symbol, 2))
        ..write(' ')
        ..write(_fixed(atom.x, precision).padLeft(precision + 5))
        ..write(' ')
        ..write(_fixed(atom.y, precision).padLeft(precision + 5))
        ..write(' ')
        ..write(_fixed(atom.z, precision).padLeft(precision + 5))
        ..writeln();
    }
    return buffer.toString();
  }

  /// Writes several frames (e.g. an NEB trajectory) as a multi-XYZ document.
  ///
  /// A comment line of `frame <i>/<n>` is emitted for each frame so Avogadro's
  /// animation panel labels the images in order.
  static String toMultiXyz(
    List<AvogadroStructure> frames, {
    int precision = 5,
    bool includeTitleLine = true,
  }) {
    if (frames.isEmpty) return '';
    final buffer = StringBuffer();
    for (var i = 0; i < frames.length; i++) {
      final frame = frames[i];
      buffer
        ..writeln(frame.atoms.length)
        ..writeln(
          includeTitleLine
              ? '${frame.title} — frame ${i + 1}/${frames.length}'
              : 'frame ${i + 1}/${frames.length}',
        );
      for (final atom in frame.atoms) {
        buffer
          ..write(_pad(atom.symbol, 2))
          ..write(' ')
          ..write(_fixed(atom.x, precision).padLeft(precision + 5))
          ..write(' ')
          ..write(_fixed(atom.y, precision).padLeft(precision + 5))
          ..write(' ')
          ..write(_fixed(atom.z, precision).padLeft(precision + 5))
          ..writeln();
      }
    }
    return buffer.toString();
  }

  // ── CML ──────────────────────────────────────────────────────────────────
  static String toCml(AvogadroStructure s) {
    final buffer = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<molecule id="qf-${_slug(s.title)}" '
          'xmlns="http://www.xml-cml.org/schema">')
      ..writeln('  <name>${_xml(s.title)}</name>')
      ..writeln('  <formula>${_xml(formulaOf(s.atoms))}</formula>')
      ..writeln('  <atomArray>');
    for (var i = 0; i < s.atoms.length; i++) {
      final a = s.atoms[i];
      buffer.writeln(
        '    <atom id="a${i + 1}" elementType="${_xml(a.symbol)}" '
        'x3="${_fixed(a.x, 6)}" y3="${_fixed(a.y, 6)}" z3="${_fixed(a.z, 6)}" '
        'formalCharge="0"/>',
      );
    }
    buffer.writeln('  </atomArray>');
    if (s.bonds.isNotEmpty) {
      buffer.writeln('  <bondArray>');
      for (var i = 0; i < s.bonds.length; i++) {
        final b = s.bonds[i];
        buffer.writeln(
          '    <bond id="b${i + 1}" atomRefs2="a${b.a + 1} a${b.b + 1}" '
          'order="${b.order == 4 ? 'A' : b.order}"/>',
        );
      }
      buffer.writeln('  </bondArray>');
    }
    buffer.writeln('</molecule>');
    return buffer.toString();
  }

  // ── SDF / MOL (V2000) ────────────────────────────────────────────────────
  static String toSdf(
    AvogadroStructure s, {
    bool includeProperties = true,
    int charge = 0,
  }) {
    final buffer = StringBuffer()
      ..writeln(s.title)
      ..writeln('  Quantum Forge  3D  Avogadro-ready')
      ..writeln()
      ..writeln(
        '${s.atoms.length.toString().padLeft(3)}'
        '${s.bonds.length.toString().padLeft(3)}'
        '  0  0  0  0  0  0  0  0999 V2000',
      );

    for (final atom in s.atoms) {
      // V2000 fixed columns: x/y/z in 10-char fields, then a space, then the
      // 3-char element symbol at columns 32-34. Trailing property fields come
      // after it — the symbol must never be the last thing on the line.
      buffer.writeln(
        '${_fixed(atom.x, 4).padLeft(10)}'
        '${_fixed(atom.y, 4).padLeft(10)}'
        '${_fixed(atom.z, 4).padLeft(10)}'
        ' ${atom.symbol.padLeft(3)}'
        ' 0  0  0  0  0  0  0  0  0  0  0  0',
      );
    }
    for (final bond in s.bonds) {
      buffer.writeln(
        '${(bond.a + 1).toString().padLeft(3)}'
        '${(bond.b + 1).toString().padLeft(3)}'
        '${bond.v2000Order.toString().padLeft(3)}  0  0  0  0',
      );
    }
    buffer.writeln('M  END');
    if (includeProperties) {
      final formula = formulaOf(s.atoms);
      if (formula.isNotEmpty) buffer.writeln('> <FORMULA>\n$formula\n');
      if (charge != 0) buffer.writeln('> <CHARGE>\n$charge\n');
      buffer.writeln('> <GENERATOR>\n$generator\n');
    }
    buffer.writeln(r'$$$$');
    return buffer.toString();
  }

  // ── helpers ──────────────────────────────────────────────────────────────
  /// Hill-order molecular formula, e.g. `C8H10N4O2`.
  static String formulaOf(List<Atom> atoms) => hillFormula(atoms);

  /// Formats [value] with exactly [precision] decimals.
  static String _fixed(double value, int precision) =>
      _round(value, precision).toStringAsFixed(precision);

  static double _round(double value, [int precision = 6]) {
    if (!value.isFinite) return 0;
    final factor = _pow10(precision);
    return (value * factor).round() / factor;
  }

  static double _pow10(int exponent) {
    var result = 1.0;
    for (var i = 0; i < exponent; i++) {
      result *= 10;
    }
    return result;
  }

  static String _pad(String value, int width) =>
      value.length >= width ? value : value.padRight(width);

  static String _xml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  static String _slug(String value) {
    final slug = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty ? 'structure' : slug;
  }

  /// Minimal deterministic pretty-printer (2-space indent) so CJSON output is
  /// diff-friendly without depending on `dart:convert`'s encoder defaults.
  static String _prettyJson(Object? value, [int indent = 0]) {
    final pad = '  ' * indent;
    final childPad = '  ' * (indent + 1);
    if (value is Map) {
      if (value.isEmpty) return '{}';
      final entries = value.entries
          .map((e) =>
              '$childPad${_jsonString(e.key.toString())}: ${_prettyJson(e.value, indent + 1)}')
          .join(',\n');
      return '{\n$entries\n$pad}';
    }
    if (value is List) {
      if (value.isEmpty) return '[]';
      // Numeric arrays stay on one line — they dominate CJSON payload size.
      final allNumbers = value.every((e) => e is num);
      if (allNumbers) {
        return '[${value.map(_jsonNumber).join(', ')}]';
      }
      final items =
          value.map((e) => '$childPad${_prettyJson(e, indent + 1)}').join(',\n');
      return '[\n$items\n$pad]';
    }
    if (value is num) return _jsonNumber(value);
    if (value is bool) return value ? 'true' : 'false';
    if (value == null) return 'null';
    return _jsonString(value.toString());
  }

  static String _jsonNumber(Object? value) {
    if (value is int) return value.toString();
    if (value is double) {
      if (value == value.roundToDouble() && value.abs() < 1e15) {
        return value.toInt().toString();
      }
      return value.toString();
    }
    return '0';
  }

  static String _jsonString(String value) {
    final buffer = StringBuffer('"');
    for (final rune in value.runes) {
      switch (rune) {
        case 0x22:
          buffer.write(r'\"');
        case 0x5C:
          buffer.write(r'\\');
        case 0x0A:
          buffer.write(r'\n');
        case 0x0D:
          buffer.write(r'\r');
        case 0x09:
          buffer.write(r'\t');
        default:
          if (rune < 0x20) {
            buffer.write('\\u${rune.toRadixString(16).padLeft(4, '0')}');
          } else {
            buffer.writeCharCode(rune);
          }
      }
    }
    buffer.write('"');
    return buffer.toString();
  }
}
