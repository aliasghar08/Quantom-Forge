import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:quantum_forge/core/utils/xyz_parser.dart';
import 'package:quantum_forge/core/utils/element_data.dart';

class MoleculeParser {
  static final RegExp _whitespaceRegExp = RegExp(r'\s+');

  /// Determines the file format and parses it into a list of atoms.
  static List<Atom> parse(String data, String format) {
    if (format.toLowerCase() == 'xyz') {
      return XyzParser.parse(data);
    } else if (format.toLowerCase() == 'mol' || format.toLowerCase() == 'sdf') {
      return _parseMol(data);
    } else if (format.toLowerCase() == 'cml') {
      return _parseCml(data);
    }
    // Fallback to trying to parse as XYZ
    return XyzParser.parse(data);
  }

  /// Extremely basic .mol / .sdf parser
  /// Extracts the atom block from a V2000 molfile.
  static List<Atom> _parseMol(String data) {
    final lines = const LineSplitter().convert(data).map((l) => l.trimRight()).toList();
    if (lines.length < 4) return [];

    // Line 4 is the counts line
    final countsLine = lines[3];
    if (countsLine.length < 6) return [];
    
    final numAtomsStr = countsLine.substring(0, 3).trim();
    final numAtoms = int.tryParse(numAtomsStr) ?? 0;

    final atoms = <Atom>[];
    for (int i = 4; i < 4 + numAtoms && i < lines.length; i++) {
      final line = lines[i];
      if (line.length < 32) continue;
      
      final xStr = line.substring(0, 10).trim();
      final yStr = line.substring(10, 20).trim();
      final zStr = line.substring(20, 30).trim();
      final symbol = line.substring(31, 34).trim();

      final x = double.tryParse(xStr) ?? 0.0;
      final y = double.tryParse(yStr) ?? 0.0;
      final z = double.tryParse(zStr) ?? 0.0;

      // Leverage existing maps from XyzParser (via public access or redefine them here)
      // Since XyzParser fields are private, we will just use a fallback or expose them.
      // For now, we will construct the Atom manually with defaults if needed.
      final color = _getAtomColor(symbol);
      final radius = _getAtomRadius(symbol);
      final covRadius = _getAtomCovalentRadius(symbol);

      atoms.add(Atom(symbol, x, y, z, color, radius, covRadius));
    }
    return atoms;
  }

  /// Extremely basic CML parser using regex to find <atom> tags
  static List<Atom> _parseCml(String data) {
    final atoms = <Atom>[];
    // Match <atom id="a1" elementType="C" x3="1.2" y3="3.4" z3="5.6"/>
    final RegExp atomRegex = RegExp(r'<atom[^>]+>');
    final RegExp elementRegex = RegExp(r'elementType="([^"]+)"');
    final RegExp x3Regex = RegExp(r'x3="([^"]+)"');
    final RegExp y3Regex = RegExp(r'y3="([^"]+)"');
    final RegExp z3Regex = RegExp(r'z3="([^"]+)"');

    final matches = atomRegex.allMatches(data);
    for (final match in matches) {
      final atomStr = match.group(0)!;
      final elementMatch = elementRegex.firstMatch(atomStr);
      final x3Match = x3Regex.firstMatch(atomStr);
      final y3Match = y3Regex.firstMatch(atomStr);
      final z3Match = z3Regex.firstMatch(atomStr);

      if (elementMatch != null && x3Match != null && y3Match != null && z3Match != null) {
        final symbol = elementMatch.group(1)!;
        final x = double.tryParse(x3Match.group(1)!) ?? 0.0;
        final y = double.tryParse(y3Match.group(1)!) ?? 0.0;
        final z = double.tryParse(z3Match.group(1)!) ?? 0.0;

        atoms.add(Atom(symbol, x, y, z, _getAtomColor(symbol), _getAtomRadius(symbol), _getAtomCovalentRadius(symbol)));
      }
    }
    return atoms;
  }

  static Color _getAtomColor(String symbol) {
    return ElementData.colors[symbol] ?? Colors.pinkAccent;
  }

  static double _getAtomRadius(String symbol) {
    return ElementData.vdwRadii[symbol] ?? 1.5;
  }

  static double _getAtomCovalentRadius(String symbol) {
    return ElementData.covalentRadii[symbol] ?? 0.7;
  }
}
