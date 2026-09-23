// ============================================================================
// Avogadro SDF writer tests
// ----------------------------------------------------------------------------
// SDF is column-positioned: every field after a mistake is misread, and the
// failure shows up as a viewer drawing the wrong structure rather than as an
// error. These tests therefore pin the *width* of every block, not just the
// values in it.
//
// The writer exists because NGL cannot load XYZ — see the header of
// `avogadro_sdf.dart` for the evidence — so this file is also where the
// replacement format's contract is recorded.
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:quantum_forge/core/utils/xyz_parser.dart' show Atom, atomFor;
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/ngl/avogadro_geometry.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/ngl/avogadro_sdf.dart';

Atom at(String symbol, double x, [double y = 0, double z = 0]) =>
    atomFor(symbol, x, y, z);

/// Methane: one carbon with four hydrogens at 1.09 A.
List<Atom> methane() => <Atom>[
  at('C', 0.0, 0.0, 0.0),
  at('H', 0.6291, 0.6291, 0.6291),
  at('H', -0.6291, -0.6291, 0.6291),
  at('H', -0.6291, 0.6291, -0.6291),
  at('H', 0.6291, -0.6291, -0.6291),
];

void main() {
  group('SDF field widths', () {
    test('the counts line is 39 characters', () {
      final line = AvogadroSdfWriter.countsLine(5, 4);
      expect(line.length, 39);
      expect(line.substring(0, 3), '  5');
      expect(line.substring(3, 6), '  4');
      // version stamp must sit in the last six columns
      expect(line.substring(33), ' V2000');
    });

    test('an atom line is 69 characters', () {
      final line = AvogadroSdfWriter.atomLine(at('C', 0, 0, 0), 4);
      expect(line.length, 69);
      // coordinates occupy the first 30 columns as F10.4
      expect(line.substring(0, 10), '    0.0000');
      expect(line.substring(10, 20), '    0.0000');
      expect(line.substring(20, 30), '    0.0000');
      // then a space and the left-justified element symbol
      expect(line.substring(30, 34), ' C  ');
    });

    test('a bond line is 21 characters', () {
      final line = AvogadroSdfWriter.bondLine(1, 2, 1);
      expect(line.length, 21);
      expect(line.substring(0, 3), '  1');
      expect(line.substring(3, 6), '  2');
      expect(line.substring(6, 9), '  1');
    });

    test('every line of a real model has the right width', () {
      final atoms = methane();
      final bonds = AvogadroBondPerception.perceive(atoms);
      final model = AvogadroSdfWriter.writeModel(atoms, bonds);
      final lines = model.split('\n');

      // three header lines, counts, five atoms, four bonds, M  END
      expect(lines[3].length, 39, reason: 'counts line');
      for (var i = 4; i < 9; i++) {
        expect(lines[i].length, 69, reason: 'atom line $i');
      }
      for (var i = 9; i < 13; i++) {
        expect(lines[i].length, 21, reason: 'bond line $i');
      }
      expect(lines[13].trim(), 'M  END');
    });
  });

  group('SDF content', () {
    test('declares the atom and bond counts it actually writes', () {
      final atoms = methane();
      final bonds = AvogadroBondPerception.perceive(atoms);
      expect(bonds, hasLength(4), reason: 'methane perception sanity check');

      final model = AvogadroSdfWriter.writeModel(atoms, bonds);
      final lines = model.split('\n');

      expect(lines[3].substring(0, 3).trim(), '5');
      expect(lines[3].substring(3, 6).trim(), '4');

      // The declared counts must match the blocks, or NGL reads the bond block
      // as atom data.
      final atomLines = lines.sublist(4, 4 + 5);
      final bondLines = lines.sublist(9, 9 + 4);
      expect(atomLines.every((l) => l.length == 69), isTrue);
      expect(bondLines.every((l) => l.length == 21), isTrue);
    });

    test('writes 1-based atom indices', () {
      final atoms = methane();
      final bonds = AvogadroBondPerception.perceive(atoms);
      final model = AvogadroSdfWriter.writeModel(atoms, bonds);
      final bondLines = model.split('\n').sublist(9, 13);

      for (final line in bondLines) {
        final first = int.parse(line.substring(0, 3));
        final second = int.parse(line.substring(3, 6));
        // 0 would address nothing in a 1-based format; 6 would address nothing
        // in a five-atom model.
        expect(first, inInclusiveRange(1, 5));
        expect(second, inInclusiveRange(1, 5));
        expect(first, isNot(second));
      }
    });

    test('writes bond order 1, matching Avogadro playback', () {
      final atoms = methane();
      final bonds = AvogadroBondPerception.perceive(atoms);
      final model = AvogadroSdfWriter.writeModel(atoms, bonds);
      for (final line in model.split('\n').sublist(9, 13)) {
        expect(line.substring(6, 9).trim(), '1');
      }
    });

    test('round-trips coordinates to the requested precision', () {
      final atoms = <Atom>[at('O', 1.23456, -2.34567, 0.00004)];
      final model = AvogadroSdfWriter.writeModel(
        atoms,
        const [],
        coordinatePrecision: 4,
      );
      final atomLine = model.split('\n')[4];

      expect(double.parse(atomLine.substring(0, 10)), closeTo(1.2346, 1e-9));
      expect(double.parse(atomLine.substring(10, 20)), closeTo(-2.3457, 1e-9));
      expect(double.parse(atomLine.substring(20, 30)), closeTo(0.0, 1e-9));
    });

    test('drops bonds that name an atom outside the model', () {
      // A trajectory whose images disagree on atom count is a real case: the
      // UMA backend has failed with "Frame has 1 atoms, expected 2". A bond
      // pointing at the missing atom must not corrupt the file.
      final atoms = <Atom>[at('C', 0)];
      final model = AvogadroSdfWriter.writeModel(atoms, const <PerceivedBond>[
        PerceivedBond(0, 1),
        PerceivedBond(0, 5),
      ]);
      final lines = model.split('\n');

      expect(
        lines[3].substring(3, 6).trim(),
        '0',
        reason: 'both bonds are invalid, so the bond count must be zero',
      );
      expect(lines[5].trim(), 'M  END');
    });

    test('cannot be widened by an out-of-range coordinate', () {
      // A coordinate too wide for its field would shift every following column.
      final atoms = <Atom>[at('C', 123456.789, -98765.4321, 0)];
      final line = AvogadroSdfWriter.atomLine(atoms.first, 4);
      expect(line.length, 69);
    });
  });

  group('multi-model trajectory', () {
    test(r'terminates every model with the $$$$ separator', () {
      final bonds = AvogadroBondPerception.perceive(methane());
      final frames = <List<Atom>>[
        methane(),
        <Atom>[at('C', 0), at('H', 1.2)],
        <Atom>[at('C', 0), at('H', 1.4)],
      ];

      final trajectory = AvogadroSdfWriter.writeTrajectory(frames, bonds);
      final separators = trajectory
          .split('\n')
          .where((l) => l.trim() == r'$$$$')
          .length;
      expect(
        separators,
        3,
        reason: 'one separator per model, including the last',
      );

      // Three M  END markers, i.e. three complete models.
      final ends = trajectory
          .split('\n')
          .where((l) => l.trim() == 'M  END')
          .length;
      expect(ends, 3);
    });

    test('each model uses the supplied topology, not its own', () {
      // NGL's asTrajectory mode takes connectivity from the first model, so the
      // writer must emit the same bond block in every model or the trajectory
      // and the topology would disagree.
      final bonds = AvogadroBondPerception.perceive(methane());
      final frames = <List<Atom>>[methane(), methane()];
      final trajectory = AvogadroSdfWriter.writeTrajectory(frames, bonds);

      // The final model is followed by a separator too, so the split produces a
      // trailing empty chunk — filter rather than assume a count.
      final models = trajectory
          .split(r'$$$$')
          .where((model) => model.trim().isNotEmpty)
          .toList();
      expect(models, hasLength(2));
      for (final model in models) {
        final lines = model.trim().split('\n');
        expect(lines[3].substring(3, 6).trim(), '4');
      }
    });

    test('an empty frame list produces an empty document', () {
      expect(AvogadroSdfWriter.writeTrajectory(const [], const []), isEmpty);
    });
  });

  group('dynamic bonding', () {
    test('a stretching bond disappears from the bond block', () {
      // The C-H2 bond is inside the 1.52 A cutoff at 1.09 A and outside it at
      // 1.65 A. Rewriting the model per frame is what makes that visible, and
      // it is why the trajectory path and the dynamic-bonding path differ.
      final near = <Atom>[at('C', 0), at('H', 1.09, 0), at('H', -1.09, 0)];
      final far = <Atom>[at('C', 0), at('H', 1.09, 0), at('H', -1.65, 0)];

      final nearBonds = AvogadroBondPerception.perceive(near);
      final farBonds = AvogadroBondPerception.perceive(far);
      expect(nearBonds, hasLength(2));
      expect(farBonds, hasLength(1));

      final nearModel = AvogadroSdfWriter.writeModel(near, nearBonds);
      final farModel = AvogadroSdfWriter.writeModel(far, farBonds);
      expect(nearModel.split('\n')[3].substring(3, 6).trim(), '2');
      expect(farModel.split('\n')[3].substring(3, 6).trim(), '1');
    });
  });
}
