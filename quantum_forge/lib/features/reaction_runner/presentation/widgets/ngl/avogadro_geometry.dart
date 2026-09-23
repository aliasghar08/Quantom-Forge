// ============================================================================
// Avogadro geometry — bond perception and display-type geometry
// ----------------------------------------------------------------------------
// This file is the reason the animation can claim Avogadro parity rather than
// merely "looks similar". It reimplements, in pure Dart, the two pieces of
// Avogadro that decide what a frame actually looks like:
//
//   * `Molecule::perceiveBondsSimple` — which pairs of atoms are bonded, using
//     Avogadro's own covalent radii and its 0.45 Å tolerance.
//   * The Ball-and-Stick / Licorice / Van der Waals / Wireframe scene plugins —
//     sphere radii, cylinder radii and colours.
//
// Reimplementing them here, instead of borrowing a viewer's built-in
// representation, is not gold-plating. NGL's own `ball+stick` derives the bond
// cylinder radius from the atom sphere radius through a single `aspectRatio`,
// so it cannot express Avogadro's arrangement at all: Avogadro scales spheres
// by 0.3 x VDW(Z) — element dependent — while every bond cylinder is a fixed
// 0.1 Å regardless of element. One `aspectRatio` cannot produce both. Avogadro
// also re-perceives bonds from scratch on every frame when "Dynamic bonding?"
// is ticked, which NGL offers no public API for. Owning the geometry solves
// both problems at once, and makes the result unit-testable without a browser.
//
// Everything here is deliberately free of Flutter and JavaScript so it can be
// tested headlessly — a rendered frame is then a pure function of the atoms.
// ============================================================================

import 'dart:typed_data';

import 'package:quantum_forge/core/utils/avogadro_element_data.dart';
import 'package:quantum_forge/core/utils/xyz_parser.dart' show Atom;

/// Avogadro 2 display types that mean something for a small molecule.
///
/// Cartoon/ribbon/rope are omitted on purpose: they describe secondary
/// structure, which a reaction path does not have.
///
/// [label] is the exact string Avogadro shows in its Display Types menu, so the
/// picker in the UI matches the desktop application word for word.
enum AvogadroDisplayType {
  /// Avogadro's default display type (`ballandstick.h` returns
  /// `DefaultBehavior::True`; licorice and van der Waals both return `False`).
  ballAndStick('Ball and Stick'),

  licorice('Licorice'),

  vanDerWaals('Van der Waals'),

  wireframe('Wireframe');

  const AvogadroDisplayType(this.label);

  /// Avogadro's own menu label, verbatim.
  final String label;

  /// Whether this display type draws bond cylinders at all. Van der Waals is
  /// spheres only; wireframe is bonds only.
  bool get drawsBonds => this != AvogadroDisplayType.vanDerWaals;

  /// Whether this display type draws atom spheres.
  bool get drawsAtoms => this != AvogadroDisplayType.wireframe;
}

/// A perceived bond between two 0-based atom indices.
///
/// [order] is always 1, and that is faithful rather than lazy: `PlayerTool`
/// calls `clearBonds()` + `perceiveBondsSimple()` on every frame when dynamic
/// bonding is on, and `perceiveBondsSimple` can only ever add order-1 bonds.
/// `perceiveBondOrders()` is never called during playback, so Avogadro's own
/// animation renders every bond as a single cylinder too.
class PerceivedBond {
  const PerceivedBond(this.a, this.b, {this.order = 1});

  /// Index into the frame's atom list of the first atom. Always `< b`.
  final int a;

  /// Index of the second atom.
  final int b;

  /// Bond order. Always 1 for perceived bonds.
  final int order;

  @override
  String toString() => 'PerceivedBond($a-$b, order $order)';

  @override
  bool operator ==(Object other) =>
      other is PerceivedBond &&
      other.a == a &&
      other.b == b &&
      other.order == order;

  @override
  int get hashCode => Object.hash(a, b, order);
}

/// Avogadro's simple distance-based bond perception.
///
/// Mirrors `Molecule::perceiveBondsSimple(double tolerance = 0.45,
/// double minDistance = 0.32)` from `avogadro/core/molecule.cpp`, including the
/// exclusions that make it chemistry-aware rather than a naive distance graph:
///
///   * hydrogen–hydrogen pairs never bond,
///   * the noble gases He, Ne, Ar and Kr never bond to anything,
///   * a pair closer than [minDistance] is treated as a clash, not a bond.
///
/// Bond order is never perceived — see [PerceivedBond.order].
class AvogadroBondPerception {
  AvogadroBondPerception._();

  /// Distance slack added to the summed covalent radii, in angstrom.
  static const double tolerance = 0.45;

  /// Pairs closer than this are not bonded, in angstrom.
  static const double minDistance = 0.32;

  /// Atomic numbers excluded from bonding entirely:
  /// `case 2: case 10: case 18: case 36: continue;`
  static const Set<int> excludedAtomicNumbers = <int>{2, 10, 18, 36};

  /// Fallback covalent radius when an element's radius is not positive:
  /// `if (r_i <= 0) r_i = 2.0;`
  static const double _radiusFallback = 2.0;

  /// Perceives order-1 bonds from cartesian coordinates alone.
  ///
  /// The C++ implementation narrows the pair search with a `NeighborPerceiver`
  /// of radius `2 * max(radius) + tolerance`. Testing every pair gives the
  /// identical answer, because `cutoff(i, j) == r_i + r_j + tolerance` can
  /// never exceed that search radius — so the spatial index is skipped here and
  /// the result is exact rather than approximate.
  static List<PerceivedBond> perceive(List<Atom> atoms) {
    final n = atoms.length;
    if (n < 2) return const <PerceivedBond>[];

    final atomicNumbers = Int32List(n);
    final radii = Float64List(n);
    for (var i = 0; i < n; i++) {
      final z = AvogadroElementData.atomicNumberForSymbol(atoms[i].symbol);
      atomicNumbers[i] = z;
      final r = AvogadroElementData.covalentRadius(z) ?? 0.0;
      radii[i] = r > 0 ? r : _radiusFallback;
    }

    const minDistSq = minDistance * minDistance;
    final bonds = <PerceivedBond>[];

    for (var i = 0; i < n; i++) {
      final zi = atomicNumbers[i];
      if (excludedAtomicNumbers.contains(zi)) continue;

      for (var j = i + 1; j < n; j++) {
        final zj = atomicNumbers[j];
        if (excludedAtomicNumbers.contains(zj)) continue;

        // Hydrogen–hydrogen is always excluded.
        if (zi == 1 && zj == 1) continue;

        final cutoff = radii[i] + radii[j] + tolerance;
        final dx = atoms[i].x - atoms[j].x;
        if (dx > cutoff || dx < -cutoff) continue;
        final dy = atoms[i].y - atoms[j].y;
        if (dy > cutoff || dy < -cutoff) continue;
        final dz = atoms[i].z - atoms[j].z;
        if (dz > cutoff || dz < -cutoff) continue;

        final distSq = dx * dx + dy * dy + dz * dz;
        if (distSq > minDistSq && distSq < cutoff * cutoff) {
          bonds.add(PerceivedBond(i, j));
        }
      }
    }

    return bonds;
  }

  /// Pure predicate form of [perceive], used by the tests to pin the boundaries
  /// (exactly at the cutoff, exactly at [minDistance]).
  static bool isBonded(Atom first, Atom second) {
    final zi = AvogadroElementData.atomicNumberForSymbol(first.symbol);
    final zj = AvogadroElementData.atomicNumberForSymbol(second.symbol);
    if (excludedAtomicNumbers.contains(zi)) return false;
    if (excludedAtomicNumbers.contains(zj)) return false;
    if (zi == 1 && zj == 1) return false;

    final ri = AvogadroElementData.covalentRadius(zi) ?? 0.0;
    final rj = AvogadroElementData.covalentRadius(zj) ?? 0.0;
    final cutoff =
        (ri > 0 ? ri : _radiusFallback) +
        (rj > 0 ? rj : _radiusFallback) +
        tolerance;
    final dx = first.x - second.x;
    final dy = first.y - second.y;
    final dz = first.z - second.z;
    final distSq = dx * dx + dy * dy + dz * dz;
    return distSq > minDistance * minDistance && distSq < cutoff * cutoff;
  }

  /// Number of connected fragments [bonds] split [atomCount] atoms into.
  ///
  /// This is the "how many molecules are on screen" count the reaction header
  /// reports as `2R → 1P`, and it is computed from the *same* perceived bonds
  /// that are drawn — so the count can never disagree with the picture. (The
  /// previous implementation used a different radius table and a 1.18 tolerance
  /// factor for the count and Avogadro's rule for nothing, which is how a header
  /// can claim two molecules while the viewer draws one.)
  ///
  /// Isolated atoms each count as a fragment, which is what an ion or a
  /// lone atom in a trajectory should do.
  static int fragmentCount(int atomCount, List<PerceivedBond> bonds) {
    if (atomCount <= 0) return 0;
    if (bonds.isEmpty) return atomCount;

    final parent = List<int>.generate(atomCount, (i) => i);
    int find(int x) {
      var root = x;
      while (parent[root] != root) {
        root = parent[root];
      }
      // Path compression, so a long chain does not degenerate to O(n) lookups.
      var walk = x;
      while (parent[walk] != root) {
        final next = parent[walk];
        parent[walk] = root;
        walk = next;
      }
      return root;
    }

    for (final bond in bonds) {
      final a = find(bond.a);
      final b = find(bond.b);
      if (a != b) parent[a] = b;
    }

    final roots = <int>{};
    for (var i = 0; i < atomCount; i++) {
      roots.add(find(i));
    }
    return roots.length;
  }
}

/// Renderer-ready geometry for a single trajectory frame.
///
/// The layout is structure-of-arrays rather than a list of objects because the
/// only consumer is the NGL bridge, which has to hand every value to
/// JavaScript individually. Building the buffers once per frame keeps that
/// bridge a straight copy with no per-atom allocation.
///
/// Spheres and cylinders are separate buffers because Avogadro draws each bond
/// as two half-cylinders tinted with the colour of the atom they touch. A
/// viewer's "two-tone cylinder" is not universally available (`NGL.Shape`
/// cylinders take a single colour), and splitting at the midpoint is
/// pixel-identical to Avogadro's own two-tone cylinders, so every bond becomes
/// two cylinders here.
class ReactionFrameGeometry {
  const ReactionFrameGeometry({
    required this.spherePositions,
    required this.sphereColors,
    required this.sphereRadii,
    required this.cylinderPositions,
    required this.cylinderColors,
    required this.cylinderRadii,
  });

  /// `xyz` triples, 3 floats per sphere.
  final Float32List spherePositions;

  /// `rgb` triples in the 0..1 range, 3 floats per sphere.
  final Float32List sphereColors;

  /// One radius in angstrom per sphere.
  final Float32List sphereRadii;

  /// `x1 y1 z1 x2 y2 z2` per cylinder, 6 floats per cylinder.
  final Float32List cylinderPositions;

  /// `rgb` triples in the 0..1 range, 3 floats per cylinder.
  final Float32List cylinderColors;

  /// One radius in angstrom per cylinder.
  final Float32List cylinderRadii;

  int get sphereCount => sphereRadii.length;

  int get cylinderCount => cylinderRadii.length;

  /// An empty frame — what a viewer shows before a trajectory is loaded.
  static final ReactionFrameGeometry empty = ReactionFrameGeometry(
    spherePositions: Float32List(0),
    sphereColors: Float32List(0),
    sphereRadii: Float32List(0),
    cylinderPositions: Float32List(0),
    cylinderColors: Float32List(0),
    cylinderRadii: Float32List(0),
  );

  /// Builds the geometry Avogadro would draw for [atoms] under [displayType].
  ///
  /// [bonds] is passed in rather than perceived here so the caller can decide
  /// whether bonds are re-perceived per frame (dynamic bonding on, which is
  /// Avogadro's checkbox) or carried over from the first frame (dynamic bonding
  /// off, which is Avogadro's default and the default here too).
  static ReactionFrameGeometry build({
    required List<Atom> atoms,
    required List<PerceivedBond> bonds,
    required AvogadroDisplayType displayType,
  }) {
    if (atoms.isEmpty) return empty;

    final n = atoms.length;
    final atomicNumbers = Int32List(n);
    for (var i = 0; i < n; i++) {
      atomicNumbers[i] = AvogadroElementData.atomicNumberForSymbol(
        atoms[i].symbol,
      );
    }

    final sphereCount = displayType.drawsAtoms ? n : 0;
    final spherePositions = Float32List(sphereCount * 3);
    final sphereColors = Float32List(sphereCount * 3);
    final sphereRadii = Float32List(sphereCount);

    for (var i = 0; i < sphereCount; i++) {
      final atom = atoms[i];
      spherePositions[i * 3] = atom.x;
      spherePositions[i * 3 + 1] = atom.y;
      spherePositions[i * 3 + 2] = atom.z;

      final hex = AvogadroElementData.colorForAtomicNumber(atomicNumbers[i]);
      sphereColors[i * 3] = ((hex >> 16) & 0xFF) / 255.0;
      sphereColors[i * 3 + 1] = ((hex >> 8) & 0xFF) / 255.0;
      sphereColors[i * 3 + 2] = (hex & 0xFF) / 255.0;

      sphereRadii[i] = _sphereRadius(atomicNumbers[i], displayType);
    }

    // Two half-cylinders per bond; nothing at all for van der Waals.
    //
    // Bonds are filtered against the atom count first. A trajectory whose images
    // disagree on atom count is not hypothetical — the UMA backend has failed
    // with "ase.io.extxyz: Frame has 1 atoms, expected 2" — and an index that
    // only exists in another frame must not take the viewer down mid-animation.
    final drawBonds = displayType.drawsBonds;
    final usableBonds = <PerceivedBond>[];
    if (drawBonds) {
      for (final bond in bonds) {
        if (bond.a < 0 || bond.a >= n) continue;
        if (bond.b < 0 || bond.b >= n) continue;
        usableBonds.add(bond);
      }
    }
    final cylinderCount = usableBonds.length * 2;
    final cylinderPositions = Float32List(cylinderCount * 6);
    final cylinderColors = Float32List(cylinderCount * 3);
    final cylinderRadii = Float32List(cylinderCount);

    if (usableBonds.isNotEmpty) {
      final radius = _cylinderRadius(displayType);
      for (var b = 0; b < usableBonds.length; b++) {
        final bond = usableBonds[b];
        final first = atoms[bond.a];
        final second = atoms[bond.b];

        // Avogadro splits a bond at the geometric midpoint.
        final mx = (first.x + second.x) / 2;
        final my = (first.y + second.y) / 2;
        final mz = (first.z + second.z) / 2;

        _writeCylinder(
          positions: cylinderPositions,
          colors: cylinderColors,
          radii: cylinderRadii,
          slot: b * 2,
          x1: first.x,
          y1: first.y,
          z1: first.z,
          x2: mx,
          y2: my,
          z2: mz,
          hex: AvogadroElementData.colorForAtomicNumber(atomicNumbers[bond.a]),
          radius: radius,
        );
        _writeCylinder(
          positions: cylinderPositions,
          colors: cylinderColors,
          radii: cylinderRadii,
          slot: b * 2 + 1,
          x1: mx,
          y1: my,
          z1: mz,
          x2: second.x,
          y2: second.y,
          z2: second.z,
          hex: AvogadroElementData.colorForAtomicNumber(atomicNumbers[bond.b]),
          radius: radius,
        );
      }
    }

    return ReactionFrameGeometry(
      spherePositions: spherePositions,
      sphereColors: sphereColors,
      sphereRadii: sphereRadii,
      cylinderPositions: cylinderPositions,
      cylinderColors: cylinderColors,
      cylinderRadii: cylinderRadii,
    );
  }

  /// Atom sphere radius in angstrom for one element under [displayType].
  ///
  /// * Ball and Stick — `Elements::radiusVDW(Z) * 0.3`
  /// * Licorice — a flat 0.2 Å for every element
  /// * Van der Waals — the full `Elements::radiusVDW(Z)`
  /// * Wireframe — no spheres (Avogadro adds 0.001 Å stubs purely so the
  ///   selection tool has something to hit; drawing them is not intended)
  static double _sphereRadius(int atomicNumber, AvogadroDisplayType type) {
    switch (type) {
      case AvogadroDisplayType.ballAndStick:
        return (AvogadroElementData.vanDerWaalsRadius(atomicNumber) ?? 0.0) *
            AvogadroElementData.ballAndStickAtomScale;
      case AvogadroDisplayType.licorice:
        return AvogadroElementData.licoriceRadius;
      case AvogadroDisplayType.vanDerWaals:
        return (AvogadroElementData.vanDerWaalsRadius(atomicNumber) ?? 0.0) *
            AvogadroElementData.vanDerWaalsScale;
      case AvogadroDisplayType.wireframe:
        return 0.0;
    }
  }

  /// Bond cylinder radius in angstrom for [displayType].
  ///
  /// Wireframe is the one approximation in this file. Avogadro draws wireframe
  /// bonds as camera-facing quads of world-space width
  /// `lineWidth * lineWidthScale` (0.035 Å), i.e. a half-width of 0.0175 Å,
  /// with a colour gradient along the line. NGL has no wide-line primitive, so
  /// the equivalent hairline is drawn as a very thin cylinder split into two
  /// half-cylinders. That is visually indistinguishable at any zoom where the
  /// molecule is legible, but it is not the same primitive.
  static double _cylinderRadius(AvogadroDisplayType type) {
    switch (type) {
      case AvogadroDisplayType.ballAndStick:
        return AvogadroElementData.ballAndStickBondRadius;
      case AvogadroDisplayType.licorice:
        return AvogadroElementData.licoriceRadius;
      case AvogadroDisplayType.vanDerWaals:
        return 0.0;
      case AvogadroDisplayType.wireframe:
        return AvogadroElementData.wireframeBondRadius;
    }
  }

  static void _writeCylinder({
    required Float32List positions,
    required Float32List colors,
    required Float32List radii,
    required int slot,
    required double x1,
    required double y1,
    required double z1,
    required double x2,
    required double y2,
    required double z2,
    required int hex,
    required double radius,
  }) {
    positions[slot * 6] = x1;
    positions[slot * 6 + 1] = y1;
    positions[slot * 6 + 2] = z1;
    positions[slot * 6 + 3] = x2;
    positions[slot * 6 + 4] = y2;
    positions[slot * 6 + 5] = z2;

    colors[slot * 3] = ((hex >> 16) & 0xFF) / 255.0;
    colors[slot * 3 + 1] = ((hex >> 8) & 0xFF) / 255.0;
    colors[slot * 3 + 2] = (hex & 0xFF) / 255.0;

    radii[slot] = radius;
  }
}
