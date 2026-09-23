// ============================================================================
// Bond badge tests
// ----------------------------------------------------------------------------
// The badges are only useful if their numbers refer to the bonds actually drawn,
// so these pin the two properties that decide that, headlessly:
//
//   * the bond set comes from AvogadroBondPerception — the same perception that
//     writes the SDF bond block and therefore the same bonds NGL renders;
//   * numbering is 1-based in (i, j) index order, stable for a frame.
//
// A badge on a pair that is not drawn, or a drawn bond with no badge, is the
// failure this file exists to catch: it would leave a reader counting something
// that is not on screen.
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:quantum_forge/core/utils/xyz_parser.dart' show Atom, atomFor;
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/ngl/avogadro_geometry.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/ngl/ngl_bond_label.dart';

Atom at(String symbol, double x, [double y = 0, double z = 0]) =>
    atomFor(symbol, x, y, z);

List<Atom> methane() => <Atom>[
      at('C', 0.0, 0.0, 0.0),
      at('H', 0.6291, 0.6291, 0.6291),
      at('H', -0.6291, -0.6291, 0.6291),
      at('H', -0.6291, 0.6291, -0.6291),
      at('H', 0.6291, -0.6291, -0.6291),
    ];

void main() {
  group('bondLabelsForFrame', () {
    test('produces one badge per perceived bond', () {
      final atoms = methane();
      final expected = AvogadroBondPerception.perceive(atoms).length;
      final labels = bondLabelsForFrame(atoms);

      expect(expected, 4, reason: 'methane has four C-H bonds');
      expect(labels, hasLength(expected));
    });

    test('numbers from 1 without gaps, in order', () {
      final labels = bondLabelsForFrame(methane());
      expect(labels.map((l) => l.index).toList(), <int>[1, 2, 3, 4]);
    });

    test('places every badge at its bond midpoint', () {
      final atoms = methane();
      final bonds = AvogadroBondPerception.perceive(atoms);
      final labels = bondLabelsForFrame(atoms);

      for (var i = 0; i < bonds.length; i++) {
        final first = atoms[bonds[i].a];
        final second = atoms[bonds[i].b];
        expect(labels[i].x, closeTo((first.x + second.x) / 2, 1e-12));
        expect(labels[i].y, closeTo((first.y + second.y) / 2, 1e-12));
        expect(labels[i].z, closeTo((first.z + second.z) / 2, 1e-12));
      }
    });

    test('is deterministic for the same frame', () {
      final first = bondLabelsForFrame(methane());
      final second = bondLabelsForFrame(methane());
      expect(first, equals(second));
    });

    test('numbers the same pair identically across calls', () {
      // Same geometry, rebuilt: badge N must sit on the same bond both times, or
      // a number in a figure would not refer to a number in a table.
      final a = bondLabelsForFrame(methane());
      final b = bondLabelsForFrame(methane());
      for (var i = 0; i < a.length; i++) {
        expect(a[i].index, b[i].index);
        expect(a[i].x, b[i].x);
        expect(a[i].y, b[i].y);
        expect(a[i].z, b[i].z);
      }
    });

    test('drops a badge when a bond breaks', () {
      // The C-H2 bond is inside the 1.52 A cutoff at 1.09 A and outside it at
      // 1.65 A, so the badge count must follow the drawn bonds.
      final intact = <Atom>[at('C', 0), at('H', 1.09, 0), at('H', -1.09, 0)];
      final broken = <Atom>[at('C', 0), at('H', 1.09, 0), at('H', -1.65, 0)];

      expect(bondLabelsForFrame(intact), hasLength(2));
      final after = bondLabelsForFrame(broken);
      expect(after, hasLength(1));
      expect(after.single.index, 1,
          reason: 'the surviving bond is still number 1');
    });

    test('an empty frame yields no badges', () {
      expect(bondLabelsForFrame(const <Atom>[]), isEmpty);
    });

    test('a lone atom yields no badges', () {
      expect(bondLabelsForFrame(<Atom>[at('C', 0, 0, 0)]), isEmpty);
    });

    test('a badge is never placed away from its bond', () {
      // Guards the axis mix-ups that a midpoint computed by hand invites.
      final atoms = <Atom>[at('O', 0, 0, 0), at('H', 0, 0, 0.96)];
      final labels = bondLabelsForFrame(atoms);
      expect(labels, hasLength(1));
      expect(labels.single.x, closeTo(0.0, 1e-12));
      expect(labels.single.y, closeTo(0.0, 1e-12));
      expect(labels.single.z, closeTo(0.48, 1e-12));
    });
  });

  group('BondLabel equality', () {
    test('compares by value', () {
      const a = BondLabel(index: 1, x: 0.5, y: 0.0, z: -0.5);
      const b = BondLabel(index: 1, x: 0.5, y: 0.0, z: -0.5);
      const c = BondLabel(index: 2, x: 0.5, y: 0.0, z: -0.5);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });
}
