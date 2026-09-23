// ============================================================================
// Avogadro geometry parity tests
// ----------------------------------------------------------------------------
// These pin the numbers that let the animation claim Avogadro parity, and they
// are the reason the geometry lives in pure Dart rather than inside a
// representation borrowed from the renderer: every value below is checkable in
// milliseconds, headlessly, without a browser or a GPU.
//
// Each expectation is traceable to a specific line of upstream Avogadro:
//
//   colours / radii   avogadro/core/elementdata.h
//   bond perception   avogadro/core/molecule.cpp  (perceiveBondsSimple)
//   display geometry  avogadro/qtplugins/{ballandstick,licorice,vanderwaals,wireframe}
//
// If a future upstream release changes one of these, this file is where the
// difference should surface — not in a rendered figure.
// ============================================================================

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:quantum_forge/core/utils/avogadro_element_data.dart';
import 'package:quantum_forge/core/utils/xyz_parser.dart' show Atom, atomFor;
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/ngl/avogadro_geometry.dart';

/// Convenience: an atom of [symbol] at ([x], [y], [z]).
Atom at(String symbol, double x, [double y = 0, double z = 0]) =>
    atomFor(symbol, x, y, z);

void main() {
  // ── Element data ──────────────────────────────────────────────────────────

  group('Avogadro element data', () {
    test('carries every element upstream defines', () {
      // 119 = index 0 (dummy Xx) through oganesson at 118.
      expect(AvogadroElementData.colors, hasLength(119));
      expect(AvogadroElementData.vanDerWaalsRadii, hasLength(119));
      expect(AvogadroElementData.covalentRadii, hasLength(119));
    });

    test('uses Avogadro\'s carbon, not Jmol\'s', () {
      // The upstream header says so in a comment:
      //   "C is slightly darker (i.e. 50% gray - consistent with Avo1)"
      // 0x7F == 127 == 50% grey. This is the single most visible difference
      // between an Avogadro render and a Jmol/NGL one, because carbon is in
      // every organic molecule, so it is worth pinning explicitly.
      expect(AvogadroElementData.colorForSymbol('C'), 0x7F7F7F);
      expect(
        AvogadroElementData.colorForSymbol('C'),
        isNot(0x909090),
        reason: 'that is the Jmol grey the app-wide palette uses',
      );
      expect(
        AvogadroElementData.colorForSymbol('C'),
        isNot(0x303030),
        reason: 'that is Avogadro 1\'s carbon',
      );
    });

    test('uses Avogadro\'s other two deliberate deviations from Jmol', () {
      // "H is not completely white"; "F is bluer to add contrast with Cl".
      expect(AvogadroElementData.colorForSymbol('H'), 0xF0F0F0);
      expect(AvogadroElementData.colorForSymbol('F'), 0xB2FFFF);
      // Jmol's F is a pale green (#90E050), which is what the app-wide table
      // still holds — the two palettes really are different.
      expect(AvogadroElementData.colorForSymbol('F'), isNot(0x90E050));
    });

    test('matches upstream for the common organic elements', () {
      expect(AvogadroElementData.colorForSymbol('N'), 0x3050FF);
      expect(AvogadroElementData.colorForSymbol('O'), 0xFF0D0D);
      expect(AvogadroElementData.colorForSymbol('P'), 0xFF8000);
      expect(AvogadroElementData.colorForSymbol('S'), 0xFFFF30);
      expect(AvogadroElementData.colorForSymbol('Cl'), 0x1FF01F);
      expect(AvogadroElementData.colorForSymbol('Br'), 0xA62929);
      expect(AvogadroElementData.colorForSymbol('I'), 0x940094);
    });

    test('resolves symbols case- and case-shape-insensitively', () {
      expect(AvogadroElementData.atomicNumberForSymbol('c'), 6);
      expect(AvogadroElementData.atomicNumberForSymbol('CL'), 17);
      expect(
        AvogadroElementData.colorForSymbol('cl'),
        AvogadroElementData.colorForSymbol('Cl'),
      );
    });

    test('falls back to the dummy element for an unknown symbol', () {
      // Z = 0 is Avogadro's `Xx`, not an error: `Elements::color()` returns
      // `element_color[0]` for anything it cannot resolve, and so do we — so an
      // unexpected element never draws in an alarm colour.
      expect(AvogadroElementData.atomicNumberForSymbol('Zz'), 0);
      expect(AvogadroElementData.colorForSymbol('Zz'), 0x117FB2);
      expect(AvogadroElementData.vanDerWaalsRadius(0), 0.69);
      expect(AvogadroElementData.covalentRadius(0), 0.18);
    });

    test('van der Waals radii are Alvarez, per atomic number', () {
      expect(AvogadroElementData.vanDerWaalsRadius(1), 1.2); // H
      expect(AvogadroElementData.vanDerWaalsRadius(6), 1.77); // C
      expect(AvogadroElementData.vanDerWaalsRadius(7), 1.66); // N
      expect(AvogadroElementData.vanDerWaalsRadius(8), 1.50); // O
      expect(AvogadroElementData.vanDerWaalsRadius(9), 1.46); // F
      expect(AvogadroElementData.vanDerWaalsRadius(17), 1.82); // Cl
      expect(AvogadroElementData.vanDerWaalsRadius(35), 1.86); // Br
      expect(AvogadroElementData.vanDerWaalsRadius(53), 2.04); // I
    });

    test('covalent radii are Pyykko, per atomic number', () {
      expect(AvogadroElementData.covalentRadius(1), 0.32);
      expect(AvogadroElementData.covalentRadius(6), 0.75);
      expect(AvogadroElementData.covalentRadius(7), 0.71);
      expect(AvogadroElementData.covalentRadius(8), 0.63);
      expect(AvogadroElementData.covalentRadius(17), 0.99);
      expect(AvogadroElementData.covalentRadius(53), 1.33);
    });

    test('exposes the upstream display constants verbatim', () {
      // ballandstick.h / .cpp
      expect(AvogadroElementData.ballAndStickAtomScale, 0.3);
      expect(AvogadroElementData.ballAndStickBondRadius, 0.1);
      // licorice.cpp: float radius(0.2f);
      expect(AvogadroElementData.licoriceRadius, 0.2);
      // vanderwaals.cpp: full VDW radius, no extra scale
      expect(AvogadroElementData.vanDerWaalsScale, 1.0);
      // wireframe.cpp: lineWidth (1.0) * WideLineGeometry::lineWidthScale
      // (0.035), halved because the shader draws half-width * side.
      expect(AvogadroElementData.wireframeBondRadius, closeTo(0.0175, 1e-12));
    });
  });

  // ── Bond perception ───────────────────────────────────────────────────────

  group('AvogadroBondPerception', () {
    test('pins the upstream tolerance and minimum distance', () {
      expect(AvogadroBondPerception.tolerance, 0.45);
      expect(AvogadroBondPerception.minDistance, 0.32);
      expect(
        AvogadroBondPerception.excludedAtomicNumbers,
        containsAll(<int>[2, 10, 18, 36]),
      );
    });

    test('bonds methane\'s four hydrogens to its carbon', () {
      final methane = <Atom>[
        at('C', 0, 0, 0),
        at('H', 0.63, 0.63, 0.63),
        at('H', -0.63, -0.63, 0.63),
        at('H', -0.63, 0.63, -0.63),
        at('H', 0.63, -0.63, -0.63),
      ];
      final bonds = AvogadroBondPerception.perceive(methane);
      expect(bonds, hasLength(4));
      // Every bond starts at the carbon: four C–H, never H–H.
      expect(bonds.every((b) => b.a == 0), isTrue);
      expect(bonds.every((b) => b.order == 1), isTrue);
    });

    test('accepts a C–C bond at 1.54 A and rejects it at the cutoff', () {
      // cutoff = rcov(C) + rcov(C) + tolerance = 0.75 + 0.75 + 0.45 = 1.95
      expect(
        AvogadroBondPerception.isBonded(at('C', 0), at('C', 1.54)),
        isTrue,
      );
      expect(
        AvogadroBondPerception.isBonded(at('C', 0), at('C', 1.9499)),
        isTrue,
      );
      // Strictly less than the cutoff, so exactly at it is *not* a bond.
      expect(
        AvogadroBondPerception.isBonded(at('C', 0), at('C', 1.95)),
        isFalse,
      );
      expect(
        AvogadroBondPerception.isBonded(at('C', 0), at('C', 1.96)),
        isFalse,
      );
    });

    test('rejects a pair closer than the minimum distance as a clash', () {
      expect(
        AvogadroBondPerception.isBonded(at('C', 0), at('C', 0.32)),
        isFalse,
        reason: 'exactly minDistance is excluded (strict >)',
      );
      expect(
        AvogadroBondPerception.isBonded(at('C', 0), at('C', 0.33)),
        isTrue,
      );
    });

    test('never bonds hydrogen to hydrogen', () {
      // 0.74 A is inside the H–H cutoff (0.32 + 0.32 + 0.45 = 1.09), so the
      // exclusion — not the geometry — is what prevents the bond.
      expect(
        AvogadroBondPerception.isBonded(at('H', 0), at('H', 0.74)),
        isFalse,
      );
      expect(
        AvogadroBondPerception.perceive([at('H', 0), at('H', 0.74)]),
        isEmpty,
      );
    });

    test('never bonds helium, neon, argon or krypton to anything', () {
      for (final noble in <String>['He', 'Ne', 'Ar', 'Kr']) {
        // Distance chosen to sit inside the pair cutoff, so only the element
        // exclusion can explain the missing bond.
        expect(
          AvogadroBondPerception.isBonded(at('C', 0), at(noble, 1.9)),
          isFalse,
          reason: '$noble must never bond',
        );
      }
    });

    test('perceives every bond in benzene as order 1', () {
      // A real aromatic ring: six C–H and six C–C, and — faithfully to
      // Avogadro's player, which never calls perceiveBondOrders() — no double
      // bonds at all even though the chemistry has them.
      const r = 1.39; // C–C aromatic
      const rh = 1.09;
      final atoms = <Atom>[];
      for (var i = 0; i < 6; i++) {
        final angle = i * math.pi / 3;
        atoms.add(at('C', r * math.cos(angle), r * math.sin(angle)));
      }
      for (var i = 0; i < 6; i++) {
        final angle = i * math.pi / 3;
        atoms.add(
          at('H', (r + rh) * math.cos(angle), (r + rh) * math.sin(angle)),
        );
      }

      final bonds = AvogadroBondPerception.perceive(atoms);
      expect(bonds, hasLength(12), reason: '6 ring bonds + 6 C–H bonds');
      expect(bonds.every((b) => b.order == 1), isTrue);
    });

    test('counts connected fragments, which is the "R -> P" readout', () {
      // Two methane molecules 20 A apart.
      final twoMolecules = <Atom>[
        at('C', 0, 0, 0),
        at('H', 1.09, 0, 0),
        at('C', 20, 0, 0),
        at('H', 21.09, 0, 0),
      ];
      final bonds = AvogadroBondPerception.perceive(twoMolecules);
      expect(bonds, hasLength(2));
      expect(
        AvogadroBondPerception.fragmentCount(twoMolecules.length, bonds),
        2,
      );
    });

    test('treats an unbonded atom as its own fragment', () {
      final lonelyArgon = <Atom>[at('C', 0), at('Ar', 3.0)];
      final bonds = AvogadroBondPerception.perceive(lonelyArgon);
      expect(bonds, isEmpty);
      expect(
        AvogadroBondPerception.fragmentCount(lonelyArgon.length, bonds),
        2,
      );
      expect(AvogadroBondPerception.fragmentCount(0, const []), 0);
    });
  });

  // ── Display geometry ──────────────────────────────────────────────────────

  group('ReactionFrameGeometry', () {
    // Two bonded atoms, so every case exercises both buffers.
    final water = <Atom>[at('O', 0), at('H', 0.96, 0)];
    final waterBonds = AvogadroBondPerception.perceive(water);

    test('the perception fixture really is bonded', () {
      expect(waterBonds, hasLength(1));
    });

    // Buffer values are Float32 — the precision WebGL wants — so compare with a
    // float32-appropriate tolerance rather than exact equality.
    const eps = 1e-6;

    test('ball and stick scales the VDW radius by 0.3', () {
      final geometry = ReactionFrameGeometry.build(
        atoms: water,
        bonds: waterBonds,
        displayType: AvogadroDisplayType.ballAndStick,
      );

      expect(geometry.sphereCount, 2);
      // O: 1.50 * 0.3 = 0.45   H: 1.20 * 0.3 = 0.36
      expect(geometry.sphereRadii[0], closeTo(0.45, eps));
      expect(geometry.sphereRadii[1], closeTo(0.36, eps));
    });

    test('ball and stick keeps every bond cylinder at a flat 0.1 A', () {
      final geometry = ReactionFrameGeometry.build(
        atoms: water,
        bonds: waterBonds,
        displayType: AvogadroDisplayType.ballAndStick,
      );

      // Two half-cylinders per bond, both at m_bondRadius — NOT scaled by the
      // atom radius, which is the whole reason NGL's own ball+stick cannot be
      // used here.
      expect(geometry.cylinderCount, 2);
      expect(geometry.cylinderRadii[0], closeTo(0.1, eps));
      expect(geometry.cylinderRadii[1], closeTo(0.1, eps));
    });

    test('licorice uses one radius for spheres and cylinders alike', () {
      final geometry = ReactionFrameGeometry.build(
        atoms: water,
        bonds: waterBonds,
        displayType: AvogadroDisplayType.licorice,
      );

      expect(geometry.sphereRadii[0], closeTo(0.2, eps));
      expect(geometry.sphereRadii[1], closeTo(0.2, eps));
      expect(geometry.cylinderRadii[0], closeTo(0.2, eps));
      expect(geometry.cylinderRadii[1], closeTo(0.2, eps));
    });

    test('van der Waals draws full radii and no bonds', () {
      final geometry = ReactionFrameGeometry.build(
        atoms: water,
        bonds: waterBonds,
        displayType: AvogadroDisplayType.vanDerWaals,
      );

      expect(geometry.sphereRadii[0], closeTo(1.50, eps));
      expect(geometry.sphereRadii[1], closeTo(1.20, eps));
      expect(geometry.cylinderCount, 0);
    });

    test('wireframe draws bonds only, at the wide-line half-width', () {
      final geometry = ReactionFrameGeometry.build(
        atoms: water,
        bonds: waterBonds,
        displayType: AvogadroDisplayType.wireframe,
      );

      expect(geometry.sphereCount, 0);
      expect(geometry.cylinderCount, 2);
      expect(geometry.cylinderRadii[0], closeTo(0.0175, 1e-7));
    });

    test(
      'splits each bond into two half-cylinders meeting at the midpoint',
      () {
        final geometry = ReactionFrameGeometry.build(
          atoms: water,
          bonds: waterBonds,
          displayType: AvogadroDisplayType.ballAndStick,
        );

        // First half: O (0, 0, 0) -> midpoint (0.48, 0, 0)
        expect(geometry.cylinderPositions[0], 0.0);
        expect(geometry.cylinderPositions[3], closeTo(0.48, 1e-6));
        // Second half: midpoint -> H (0.96, 0, 0)
        expect(geometry.cylinderPositions[6], closeTo(0.48, 1e-6));
        expect(geometry.cylinderPositions[9], closeTo(0.96, 1e-6));
      },
    );

    test('tints each half with the colour of the atom it touches', () {
      final geometry = ReactionFrameGeometry.build(
        atoms: water,
        bonds: waterBonds,
        displayType: AvogadroDisplayType.ballAndStick,
      );

      // 0xFF0D0D / 255
      expect(geometry.cylinderColors[0], closeTo(0xFF / 255, 1e-6));
      expect(geometry.cylinderColors[1], closeTo(0x0D / 255, 1e-6));
      // 0xF0F0F0 / 255
      expect(geometry.cylinderColors[3], closeTo(0xF0 / 255, 1e-6));
    });

    test('sphere colours come straight from the Avogadro palette', () {
      final geometry = ReactionFrameGeometry.build(
        atoms: <Atom>[at('C', 0)],
        bonds: const <PerceivedBond>[],
        displayType: AvogadroDisplayType.ballAndStick,
      );

      // Carbon #7F7F7F, all three channels equal — this is the assertion that
      // would have caught a Jmol palette leak.
      expect(geometry.sphereColors[0], closeTo(0x7F / 255, 1e-6));
      expect(geometry.sphereColors[1], closeTo(0x7F / 255, 1e-6));
      expect(geometry.sphereColors[2], closeTo(0x7F / 255, 1e-6));
    });

    test('an empty frame produces empty buffers rather than throwing', () {
      final geometry = ReactionFrameGeometry.build(
        atoms: const <Atom>[],
        bonds: const <PerceivedBond>[],
        displayType: AvogadroDisplayType.ballAndStick,
      );

      expect(geometry.sphereCount, 0);
      expect(geometry.cylinderCount, 0);
    });

    test('an atom count mismatch cannot index out of range', () {
      // Bonds describe a two-atom frame; the atoms list has one. A trajectory
      // whose images disagree on atom count must not take the viewer down.
      final geometry = ReactionFrameGeometry.build(
        atoms: <Atom>[at('C', 0)],
        bonds: const <PerceivedBond>[PerceivedBond(0, 1)],
        displayType: AvogadroDisplayType.ballAndStick,
      );

      // The out-of-range bond is simply not drawn.
      expect(geometry.sphereCount, 1);
      expect(
        geometry.cylinderCount,
        0,
        reason:
            'a bond naming a non-existent atom must be dropped, not '
            'indexed',
      );
    });
  });
}
