// ============================================================================
// Avogadro SDF writer — the format NGL can actually load
// ----------------------------------------------------------------------------
// The reaction animation used to hand its trajectory to NGL as multi-frame XYZ.
// That cannot work, and never could: NGL has no XYZ parser. Asking for it fails
// at the loader with
//
//     Error: autoLoad: ext 'xyz' unknown
//
// and the extension is absent from the shipped bundle in every version checked —
// `ngl@2.5.0` and the `ngl@2.0.0-dev.39` prerelease the old CDN link pinned both
// contain zero quoted occurrences of `"xyz"`, while every format NGL does support
// (`pdb`, `cif`, `sdf`, `mol2`, `gro`, `mmtf`, ...) is present. Upstream has no
// `xyz-parser` source file either. XYZ is only ever a *coordinate* format in NGL,
// to be attached to an existing topology, and not a structure file.
//
// SDF is the closest supported format that carries both coordinates and
// connectivity, which is exactly what a reaction path needs: the bond block is
// what lets a viewer draw bonds at all, and rewriting it per frame is what makes
// dynamic bonding possible.
//
// Writing SDF from Dart rather than asking a viewer to perceive bonds also keeps
// the chemistry in one place. Every bond written here comes from
// [AvogadroBondPerception] — Avogadro's own `perceiveBondsSimple` rule — so the
// drawn connectivity is the same connectivity the rest of the app reasons about.
//
// The format is strictly column-positioned, which is why this is a writer with
// tests rather than string interpolation at the call site: a misplaced space
// shifts every field and the file silently parses as something else.
// ============================================================================

import 'package:quantum_forge/core/utils/xyz_parser.dart' show Atom;

import 'avogadro_geometry.dart';

/// Writes MDL molfile V2000 records (`SDF`) for NGL to load.
///
/// Only the subset NGL reads is emitted: the three header lines, the counts
/// line, the atom block, the bond block and `M  END`. Property blocks (`> <...>`)
/// are omitted because NGL does not need them and they would be per-frame noise.
class AvogadroSdfWriter {
  AvogadroSdfWriter._();

  /// Characters in the counts line, per the CTfile specification.
  static const int countsLineWidth = 39;

  /// Characters in one atom-block line.
  static const int atomLineWidth = 69;

  /// Characters in one bond-block line.
  ///
  /// `111222tttsssxxxrrrccc`: two atom indices, the bond type, then four
  /// unused/status fields. NGL tolerates a truncated bond line — a 12-column
  /// line parses — but a short line is only accidentally valid, so the full
  /// 21-column form is written.
  static const int bondLineWidth = 21;

  /// Separator between models in a multi-model SDF.
  static const String modelSeparator = r'$$$$';

  /// Writes one V2000 model.
  ///
  /// [bonds] is expected to index into [atoms]; any bond naming an atom outside
  /// the list is skipped, because a trajectory whose images disagree on atom
  /// count is a real case (the UMA backend has failed with "Frame has 1 atoms,
  /// expected 2") and must not produce a corrupt file.
  static String writeModel(
    List<Atom> atoms,
    List<PerceivedBond> bonds, {
    String title = 'Quantum Forge image',
    int coordinatePrecision = 4,
  }) {
    final valid = <PerceivedBond>[];
    for (final bond in bonds) {
      if (bond.a < 0 || bond.a >= atoms.length) continue;
      if (bond.b < 0 || bond.b >= atoms.length) continue;
      valid.add(bond);
    }

    final buffer = StringBuffer()
      ..writeln(_clip(title, 80))
      // Program line. NGL ignores it, but a molfile without three header lines
      // is not a molfile, and some parsers count lines rather than columns.
      ..writeln('  Quantum Forge')
      ..writeln()
      ..writeln(countsLine(atoms.length, valid.length));

    final precision = coordinatePrecision.clamp(0, 4);
    for (final atom in atoms) {
      buffer.writeln(atomLine(atom, precision));
    }

    for (final bond in valid) {
      // 1-based atom indices, and bond order 1 — see PerceivedBond.order.
      buffer.writeln(bondLine(bond.a + 1, bond.b + 1, bond.order));
    }

    buffer.writeln('M  END');
    return buffer.toString();
  }

  /// Writes a multi-model SDF: one `$$$$`-terminated model per frame.
  ///
  /// This is what NGL loads with `{ asTrajectory: true }` to obtain a scrubbable
  /// trajectory, which is the capability the XYZ path was reaching for. All
  /// models share [topology] — NGL takes connectivity from the first model and
  /// treats the rest as coordinates, which is also why dynamic bonding needs a
  /// separate code path rather than a flag here.
  static String writeTrajectory(
    List<List<Atom>> frames,
    List<PerceivedBond> topology, {
    String title = 'Quantum Forge trajectory',
    int coordinatePrecision = 4,
  }) {
    final buffer = StringBuffer();
    for (var i = 0; i < frames.length; i++) {
      buffer.write(
        writeModel(
          frames[i],
          topology,
          title: '$title — image ${i + 1}',
          coordinatePrecision: coordinatePrecision,
        ),
      );
      buffer.writeln(modelSeparator);
    }
    return buffer.toString();
  }

  /// The counts line: `aaabbblllfffcccsssxxxrrrpppiiimmmvvvvvv`.
  ///
  /// Field 11 is the count of additional property lines. `999` conventionally
  /// means "unknown", which is what every writer emits and what NGL tolerates.
  static String countsLine(int atomCount, int bondCount) {
    final line = StringBuffer()
      ..write(_int(atomCount, 3))
      ..write(_int(bondCount, 3));
    // Eight obsolete/zero fields between the bond count and the property count.
    for (var i = 0; i < 8; i++) {
      line.write(_int(0, 3));
    }
    line
      ..write(_int(999, 3))
      ..write(' V2000');
    return _checked(line.toString(), countsLineWidth, 'counts line');
  }

  /// One atom-block line, 69 characters:
  ///
  ///     xxxxx.xxxxyyyyy.yyyyzzzzz.zzzz aaaddcccssshhhbbbvvvHHHrrriiimmmnnneee
  ///
  /// Every field after the coordinates is a zero: this writer has no isotope,
  /// charge or valence information to record, and NGL reads none of them.
  /// They are emitted anyway because the columns are positional — omitting them
  /// would not shorten the line, it would shift it.
  static String atomLine(Atom atom, int precision) {
    final line = StringBuffer()
      ..write(_coordinate(atom.x, precision))
      ..write(_coordinate(atom.y, precision))
      ..write(_coordinate(atom.z, precision))
      ..write(' ')
      ..write(_pad(atom.symbol, 3))
      // mass difference (2 wide, `%2d`)
      ..write(_int(0, 2))
    // charge, stereo parity, hydrogen count, stereo care, valence, H0
    // designator, then the four obsolete fields — eleven 3-wide fields.
    ;
    for (var field = 0; field < 11; field++) {
      line.write(_int(0, 3));
    }
    return _checked(line.toString(), atomLineWidth, 'atom line');
  }

  /// One bond-block line: two 1-based atom indices then the bond order.
  static String bondLine(int atom1, int atom2, int order) {
    final line = StringBuffer()
      ..write(_int(atom1, 3))
      ..write(_int(atom2, 3))
      ..write(_int(order, 3));
    // bond stereo, then three unused / topology / reacting-centre fields
    for (var field = 0; field < 4; field++) {
      line.write(_int(0, 3));
    }
    return _checked(line.toString(), bondLineWidth, 'bond line');
  }

  /// `F10.4`-style fixed-width coordinate, clamped to the field's width.
  ///
  /// A coordinate that does not fit would widen the line and shift every
  /// following field, so it is clamped rather than allowed to overflow: a
  /// reaction path lives inside a few angstrom of the origin, and a value beyond
  /// 9999 Å is corrupt input, not a structure.
  static String _coordinate(double value, int precision) {
    final safe = value.isFinite ? value : 0.0;
    final clamped = safe.clamp(-999.9999, 9999.9999);
    return clamped.toStringAsFixed(precision).padLeft(10);
  }

  /// Right-aligned integer in an exactly [width]-wide field.
  static String _int(int value, int width) =>
      value.toString().padLeft(width).substring(0, width).padRight(width);

  /// Left-aligned text in an exactly [width]-wide field.
  static String _pad(String value, int width) =>
      value.length >= width ? value.substring(0, width) : value.padRight(width);

  static String _clip(String value, int max) =>
      value.length <= max ? value : value.substring(0, max);

  /// Guards the one invariant the format actually has: field widths.
  ///
  /// An `assert` rather than a thrown `StateError`, deliberately. This runs once
  /// per atom per frame, and a malformed line must not take down a render loop —
  /// the tests assert the widths directly, so a regression fails there rather
  /// than here, and release builds stay byte-identical to debug builds.
  static String _checked(String line, int expected, String what) {
    assert(
      line.length == expected,
      'SDF $what must be $expected characters, produced ${line.length}: '
      '"$line". Every field after the mistake would be misread.',
    );
    return line;
  }
}
