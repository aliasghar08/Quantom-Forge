// ============================================================================
// Avogadro interchange tests
// ----------------------------------------------------------------------------
// These cover the format writers that replaced the single broken XYZ download:
// the count line must always match the atom block, CJSON must round-trip bonds,
// and every writer must produce output the Avogadro side can actually read.
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:quantum_forge/core/utils/avogadro_codec.dart';
import 'package:quantum_forge/core/utils/avogadro_interchange.dart';
import 'package:quantum_forge/core/utils/element_data.dart';
import 'package:quantum_forge/core/utils/molecular.dart';

/// Water, as any Avogadro install would hand it over.
List<Atom> water() => [
      atomFor('O', 0.00000, 0.00000, 0.11779),
      atomFor('H', 0.00000, 0.75545, -0.47116),
      atomFor('H', 0.00000, -0.75545, -0.47116),
    ];

/// Ethanol — has C, H and O, so the Hill formula ordering is exercised.
List<Atom> ethanol() => [
      atomFor('C', -1.2000, 0.0000, 0.0000),
      atomFor('C', 0.3000, 0.0000, 0.0000),
      atomFor('O', 0.9000, 1.2000, 0.0000),
      atomFor('H', -1.6000, 1.0000, 0.0000),
      atomFor('H', -1.6000, -0.5000, 0.8800),
      atomFor('H', -1.6000, -0.5000, -0.8800),
      atomFor('H', 0.7000, -0.5000, 0.8800),
      atomFor('H', 0.7000, -0.5000, -0.8800),
      atomFor('H', 1.8500, 1.2000, 0.0000),
    ];

void main() {
  group('formula / element tables', () {
    test('Hill ordering puts carbon first and hydrogen second', () {
      expect(hillFormula(ethanol()), 'C2H6O');
      expect(hillFormula(water()), 'H2O');
      expect(hillFormula(const []), '');
    });

    test('symbol ⇄ atomic number is consistent and reversed correctly', () {
      expect(ElementData.atomicNumber('C'), 6);
      expect(ElementData.atomicNumber('Og'), 118);
      expect(ElementData.symbolForAtomicNumber(8), 'O');
      expect(ElementData.symbolForAtomicNumber(0), 'X');
      expect(ElementData.symbolForAtomicNumber(999), 'X');
    });

    test('molar mass of water is close to 18.015 g/mol', () {
      expect(molarMass(water()), closeTo(18.015, 0.01));
    });
  });

  group('bond perception', () {
    test('finds both O-H bonds in water at order 1', () {
      final bonds = AvogadroInterchange.perceiveBonds(water());
      expect(bonds, hasLength(2));
      expect(bonds.every((b) => b.order == 1), isTrue);
      expect(bonds.every((b) => b.a == 0 || b.b == 0), isTrue);
    });

    test('finds all eight bonds of ethanol and no spurious ones', () {
      final bonds = AvogadroInterchange.perceiveBonds(ethanol());
      expect(bonds, hasLength(8));
    });

    test('a tighter tolerance drops borderline contacts', () {
      final loose = AvogadroInterchange.perceiveBonds(ethanol(), tolerance: 1.9);
      final tight = AvogadroInterchange.perceiveBonds(ethanol(), tolerance: 1.05);
      expect(tight.length, lessThanOrEqualTo(loose.length));
    });

    test('identical atoms have no zero-length bond', () {
      final overlapping = [atomFor('C', 0, 0, 0), atomFor('C', 0, 0, 0)];
      expect(AvogadroInterchange.perceiveBonds(overlapping), isEmpty);
    });
  });

  group('CJSON writer', () {
    test('produces the structure Avogadro expects', () {
      final structure = AvogadroInterchange.structure(water(), title: 'Water');
      final map = AvogadroInterchange.toCjsonMap(structure);

      expect(map['chemicalJson'], 1);
      expect(map['name'], 'Water');
      expect(map['formula'], 'H2O');

      final atoms = map['atoms'] as Map<String, dynamic>;
      expect((atoms['coords'] as Map)['3d'], hasLength(9));
      expect((atoms['elements'] as Map)['number'], [8, 1, 1]);

      final bonds = map['bonds'] as Map<String, dynamic>;
      expect((bonds['connections'] as Map)['index'], hasLength(4));
      expect(bonds['order'], [1, 1]);
    });

    test('round-trips through the codec with bonds intact', () {
      final original = AvogadroInterchange.structure(ethanol(), title: 'Ethanol');
      final encoded = AvogadroInterchange.toCjson(original);

      final decoded = AvogadroCodec.decode(encoded);
      expect(decoded.title, 'Ethanol');
      expect(decoded.atomCount, 9);
      expect(decoded.bondsFromSource, isTrue);
      expect(decoded.bondCount, original.bonds.length);

      // Coordinates must survive the round trip.
      for (var i = 0; i < original.atoms.length; i++) {
        expect(decoded.atoms[i].symbol, original.atoms[i].symbol);
        expect(decoded.atoms[i].x, closeTo(original.atoms[i].x, 1e-6));
        expect(decoded.atoms[i].y, closeTo(original.atoms[i].y, 1e-6));
        expect(decoded.atoms[i].z, closeTo(original.atoms[i].z, 1e-6));
      }
    });

    test('omits the bond block for a single atom', () {
      final structure = AvogadroInterchange.structure([atomFor('He', 0, 0, 0)]);
      expect(AvogadroInterchange.toCjsonMap(structure).containsKey('bonds'), isFalse);
    });
  });

  group('XYZ writer', () {
    test('count line matches the atom block exactly', () {
      final structure = AvogadroInterchange.structure(ethanol(), title: 'Ethanol');
      final xyz = AvogadroInterchange.toXyz(structure);
      final lines = xyz.trim().split('\n');

      expect(lines.first, '9');
      expect(lines[1], 'Ethanol');
      expect(lines.length, 2 + 9);
      expect(XyzParserShim.parse(xyz), hasLength(9));
    });

    test('honours the precision setting', () {
      final structure = AvogadroInterchange.structure(water(), title: 'Water');
      final xyz = AvogadroInterchange.toXyz(structure, precision: 3);
      expect(xyz, contains('0.118'));
      expect(xyz.contains('0.11779'), isFalse);
    });

    test('can suppress the title line', () {
      final structure = AvogadroInterchange.structure(water(), title: 'Water');
      final lines =
          AvogadroInterchange.toXyz(structure, includeTitleLine: false).split('\n');
      expect(lines[1], '');
    });

    test('multi-frame export labels every image', () {
      final frames = [
        AvogadroInterchange.structure(water(), title: 'Image 1/3'),
        AvogadroInterchange.structure(water(), title: 'Image 2/3'),
        AvogadroInterchange.structure(water(), title: 'Image 3/3'),
      ];
      final multi = AvogadroInterchange.toMultiXyz(frames);
      expect('Image 1/3'.allMatches(multi), hasLength(1));
      expect('Image 3/3'.allMatches(multi), hasLength(1));
      expect(AvogadroInterchange.toMultiXyz(const []), '');
    });
  });

  group('CML writer', () {
    test('emits a well-formed molecule with atoms and bonds', () {
      final structure = AvogadroInterchange.structure(water(), title: 'Water');
      final cml = AvogadroInterchange.toCml(structure);

      expect(cml, startsWith('<?xml version="1.0" encoding="UTF-8"?>'));
      expect(cml, contains('<name>Water</name>'));
      expect(cml, contains('<formula>H2O</formula>'));
      expect('<atom '.allMatches(cml), hasLength(3));
      expect('<bond '.allMatches(cml), hasLength(2));
      expect(cml, endsWith('</molecule>\n'));
    });

    test('escapes XML-hostile titles', () {
      final structure = AvogadroInterchange.structure(
        water(),
        title: 'A & B <script>alert(1)</script>',
      );
      final cml = AvogadroInterchange.toCml(structure);
      expect(cml.contains('<script>'), isFalse);
      expect(cml, contains('&amp;'));
      expect(cml, contains('&lt;script&gt;'));
    });
  });

  group('SDF writer', () {
    test('writes a V2000 connection table Avogadro can open', () {
      final structure = AvogadroInterchange.structure(water(), title: 'Water');
      final sdf = AvogadroInterchange.toSdf(structure);
      final lines = sdf.split('\n');

      expect(lines[0], 'Water');
      expect(lines[3].trim(), startsWith('3  2'));
      expect(lines[3], endsWith('V2000'));
      expect(sdf, contains('M  END'));
      expect(sdf, contains(r'$$$$'));

      // Atom block occupies lines 4..6; the element symbol must sit at the
      // V2000 columns (32-34), not at the end of the line.
      final atomLine = lines[4];
      expect(atomLine.substring(31, 34).trim(), 'O');
      expect(lines[5].substring(31, 34).trim(), 'H');
      // Bond block follows, one line per bond, 1-based indices.
      expect(lines[7].trim(), '1  2  1  0  0  0  0');
      expect(lines[8].trim(), '1  3  1  0  0  0  0');
      expect(lines[9].trim(), 'M  END');
    });

    test('parses back through the codec', () {
      final structure = AvogadroInterchange.structure(ethanol(), title: 'Ethanol');
      final sdf = AvogadroInterchange.toSdf(structure);
      final decoded = AvogadroCodec.decode(sdf);
      expect(decoded.atomCount, 9);
      expect(decoded.title, 'Ethanol');
    });
  });
}

/// Thin wrapper so this test file does not need a second import name clash.
class XyzParserShim {
  static List<Atom> parse(String data) =>
      AvogadroCodec.decode(data, formatHint: 'xyz').atoms;
}
