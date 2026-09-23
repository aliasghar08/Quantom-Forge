// ============================================================================
// BondLabel — a numbered badge positioned in molecule space
// ----------------------------------------------------------------------------
// Lives in its own file because both sides of the engine boundary need it: the
// widget builds labels, the engine (and its non-web stub) consumes them.
// Declaring it in `ngl_viewer.dart` instead would make the stub import the file
// that imports the stub.
// ============================================================================

import 'package:quantum_forge/core/utils/xyz_parser.dart' show Atom;

import 'avogadro_geometry.dart';

/// Builds the numbered badges for one frame.
///
/// The bonds come from [AvogadroBondPerception] — the *same* perception that
/// writes the SDF bond block, and therefore the same bonds the viewer draws.
/// That is the only referent that makes a number meaningful: a badge on a pair
/// that is not drawn, or a drawn bond with no badge, leaves the reader counting
/// something that is not on screen.
///
/// Numbering is 1-based in `(i, j)` index order over the atom list, so it is
/// stable for a given frame and reproducible across runs. Extracted from the
/// widget so the scheme can be tested directly rather than only through a
/// rendered frame.
///
/// A frame whose atoms are empty yields no labels.
List<BondLabel> bondLabelsForFrame(List<Atom> atoms) {
  if (atoms.isEmpty) return const <BondLabel>[];

  final bonds = AvogadroBondPerception.perceive(atoms);
  final labels = <BondLabel>[];
  for (var b = 0; b < bonds.length; b++) {
    final first = atoms[bonds[b].a];
    final second = atoms[bonds[b].b];
    labels.add(BondLabel(
      index: b + 1,
      x: (first.x + second.x) / 2,
      y: (first.y + second.y) / 2,
      z: (first.z + second.z) / 2,
    ));
  }
  return labels;
}

/// A numbered badge to draw at a bond's midpoint, in molecule space.
///
/// Positioned in 3D rather than in screen space so it rotates, zooms and
/// depth-sorts with the structure it labels — a number that stayed put while the
/// molecule turned underneath it would be worse than no number at all.
///
/// [index] is the number printed. It is supplied rather than derived so the
/// caller owns the numbering scheme, which has to be the same one any companion
/// bond table uses, or the numbers mean nothing.
class BondLabel {
  const BondLabel({
    required this.index,
    required this.x,
    required this.y,
    required this.z,
  });

  /// 1-based bond number.
  final int index;

  /// Badge position in angstrom, normally the bond midpoint.
  final double x;
  final double y;
  final double z;

  @override
  bool operator ==(Object other) =>
      other is BondLabel &&
      other.index == index &&
      other.x == x &&
      other.y == y &&
      other.z == z;

  @override
  int get hashCode => Object.hash(index, x, y, z);

  @override
  String toString() => 'BondLabel($index @ ${x.toStringAsFixed(2)}, '
      '${y.toStringAsFixed(2)}, ${z.toStringAsFixed(2)})';
}
