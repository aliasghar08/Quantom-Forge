// ============================================================================
// XYZ parser + ZIP writer tests
// ----------------------------------------------------------------------------
// The XYZ parser used to skip two lines unconditionally and ignore the declared
// atom count, so a multi-frame trajectory was silently concatenated into one
// nonsense molecule. The ZIP writer is new (the old export button produced no
// file at all), so its structure and CRCs are pinned here.
// ============================================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quantum_forge/core/utils/xyz_parser.dart';
import 'package:quantum_forge/core/utils/zip_writer.dart';

void main() {
  group('XyzParser.parse', () {
    test('reads a well-formed water file', () {
      const xyz = '3\nWater molecule\n'
          'O  0.00000  0.00000  0.11779\n'
          'H  0.00000  0.75545 -0.47116\n'
          'H  0.00000 -0.75545 -0.47116\n';
      final atoms = XyzParser.parse(xyz);
      expect(atoms, hasLength(3));
      expect(atoms.first.symbol, 'O');
      expect(atoms.first.z, closeTo(0.11779, 1e-6));
      expect(atoms[1].y, closeTo(0.75545, 1e-6));
    });

    test('reads only the declared number of atoms', () {
      const xyz = '2\ntwo of three\nC 0 0 0\nH 0 1 0\nO 0 0 5\n';
      expect(XyzParser.parse(xyz), hasLength(2));
    });

    test('a two-atom molecule with a blank comment line still parses', () {
      // The old implementation required three non-empty lines, so a two-atom
      // molecule with an empty title produced nothing.
      const xyz = '2\n\nH 0 0 0\nH 0 0 0.74\n';
      expect(XyzParser.parse(xyz), hasLength(2));
    });

    test('independent frames do not bleed into one molecule', () {
      const trajectory = '3\nImage 1\nO 0 0 0\nH 0 1 0\nH 0 -1 0\n'
          '3\nImage 2\nO 0 0 9\nH 0 1 9\nH 0 -1 9\n';
      final atoms = XyzParser.parse(trajectory);
      expect(atoms, hasLength(3));
      expect(atoms[0].z, 0, reason: 'must be frame 1, not frame 2 or both');
    });

    test('handles leading blank lines and extra whitespace', () {
      const xyz = '\n\n  1\n  Only hydrogen\n  H   1.0   2.0   3.0   \n';
      final atoms = XyzParser.parse(xyz);
      expect(atoms, hasLength(1));
      expect(atoms.first.x, 1.0);
      expect(atoms.first.z, 3.0);
    });

    test('returns nothing for empty or garbage input', () {
      expect(XyzParser.parse(''), isEmpty);
      expect(XyzParser.parse('this is not an xyz file'), isEmpty);
      expect(XyzParser.parse('3\nTitle\n'), isEmpty);
    });

    test('normalises element symbols and unknown symbols keep fallbacks', () {
      const xyz = '2\nodd\nc 0 0 0\nXX 1 0 0\n';
      final atoms = XyzParser.parse(xyz);
      expect(atoms[0].symbol, 'C');
      expect(atoms[1].symbol, 'Xx'); // canonicalised, unknown element
      expect(atoms[1].radius, greaterThan(0));
      expect(atoms[1].covalentRadius, greaterThan(0));
    });
  });

  group('XyzParser.serialize', () {
    test('writes a header that matches the atom block', () {
      final atoms = [
        atomFor('O', 0, 0, 0.11779),
        atomFor('H', 0, 0.75545, -0.47116),
      ];
      final xyz = XyzParser.serialize(atoms, title: 'Water');
      final lines = xyz.trim().split('\n');
      expect(lines.first, '2');
      expect(lines[1], 'Water');
      expect(lines.length, 4);
    });

    test('round-trips through parse without loss', () {
      final atoms = [
        atomFor('C', -1.2, 0, 0),
        atomFor('N', 0.3, 0.1, 0.2),
        atomFor('O', 0.9, 1.2, -0.4),
      ];
      final restored = XyzParser.parse(XyzParser.serialize(atoms, title: 'x'));
      expect(restored, hasLength(3));
      for (var i = 0; i < atoms.length; i++) {
        expect(restored[i].symbol, atoms[i].symbol);
        expect(restored[i].x, closeTo(atoms[i].x, 1e-5));
        expect(restored[i].y, closeTo(atoms[i].y, 1e-5));
        expect(restored[i].z, closeTo(atoms[i].z, 1e-5));
      }
    });

    test('respects the requested precision', () {
      final xyz = XyzParser.serialize([atomFor('H', 1.23456789, 0, 0)],
          precision: 2);
      expect(xyz, contains('1.23'));
      expect(xyz.contains('1.2345'), isFalse);
    });
  });

  group('XyzParser analysis helpers', () {
    test('getMolecularInfo reports a Hill formula and mass', () {
      final atoms = [
        atomFor('C', 0, 0, 0),
        atomFor('C', 1.5, 0, 0),
        atomFor('O', 3.0, 0, 0),
        atomFor('H', 0, 1, 0),
      ];
      final info = XyzParser.getMolecularInfo(atoms);
      // Hill notation omits the subscript when the count is one.
      expect(info.formula, 'C2HO');
      expect(info.numAtoms, 4);
      expect(info.weight, closeTo(12.011 * 2 + 1.008 + 15.999, 0.01));
      expect(info.elementCounts['C'], 2);
    });

    test('getDistinctMolecules splits non-bonded fragments', () {
      final atoms = [
        atomFor('O', 0, 0, 0),
        atomFor('H', 0, 1, 0),
        atomFor('H', 0, -1, 0),
        // A separate neon atom, far away.
        atomFor('Ne', 20, 0, 0),
      ];
      final molecules = XyzParser.getDistinctMolecules(atoms);
      expect(molecules, hasLength(2));
      expect(molecules.first, hasLength(3));
      expect(molecules.last.first.symbol, 'Ne');
    });

    test('getDistinctMolecules on an empty list returns empty', () {
      expect(XyzParser.getDistinctMolecules(const []), isEmpty);
    });
  });

  group('ZipWriter', () {
    test('emits a structurally valid archive', () {
      final bytes = ZipWriter.build(const [
        ZipEntry('README.txt', 'hello'),
        ZipEntry('data/water.xyz', '3\nWater\nO 0 0 0\nH 0 1 0\nH 0 -1 0\n'),
      ]);

      // Local file header signature at the start.
      expect(_u32(bytes, 0), 0x04034b50);
      // End of central directory is the last 22 bytes (no comment).
      expect(_u32(bytes, bytes.length - 22), 0x06054b50);
      // Entry count, little endian, in both directory records.
      expect(_u16(bytes, bytes.length - 14), 2);
      expect(_u16(bytes, bytes.length - 12), 2);
      // Central directory offset must point at a central directory header.
      final centralOffset = _u32(bytes, bytes.length - 6);
      expect(_u32(bytes, centralOffset), 0x02014b50);
    });

    test('stores names and content verbatim', () {
      final bytes = ZipWriter.build(const [
        ZipEntry('manifest.csv', 'image,energy\n1,-0.5\n'),
      ]);
      final asLatin = latin1.decode(bytes);
      expect(asLatin, contains('manifest.csv'));
      expect(asLatin, contains('image,energy'));
    });

    test('CRC-32 matches the known value for "123456789"', () {
      // The IEEE 802.3 check value: 0xCBF43926.
      expect(ZipWriter.crc32(utf8.encode('123456789')), 0xCBF43926);
    });

    test('CRC-32 of an empty input is zero', () {
      expect(ZipWriter.crc32(const []), 0);
    });

    test('sizes written in the entry header match the data length', () {
      const content = 'abcdefghij';
      final bytes = ZipWriter.build(const [ZipEntry('a.txt', content)]);
      final nameLength = _u16(bytes, 26);
      expect(nameLength, 'a.txt'.length);
      expect(_u32(bytes, 18), content.length); // compressed size
      expect(_u32(bytes, 22), content.length); // uncompressed size
    });

    test('builds an archive for zero entries without crashing', () {
      final bytes = ZipWriter.build(const []);
      expect(bytes.length, 22);
      expect(_u32(bytes, 0), 0x06054b50);
    });

    test('two archives with the same content have the same payload bytes', () {
      final a = ZipWriter.build(const [ZipEntry('x.txt', 'same')]);
      final b = ZipWriter.build(const [ZipEntry('x.txt', 'same')]);
      // The data bytes themselves must be identical.
      expect(a.sublist(30, 30 + 4), b.sublist(30, 30 + 4));
    });
  });
}

int _u32(Uint8List bytes, int offset) =>
    ByteData.view(bytes.buffer).getUint32(offset, Endian.little);

int _u16(Uint8List bytes, int offset) =>
    ByteData.view(bytes.buffer).getUint16(offset, Endian.little);
