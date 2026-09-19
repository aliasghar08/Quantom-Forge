// ============================================================================
// Molecule parser façade
// ----------------------------------------------------------------------------
// Format detection and parsing now live in `avogadro_codec.dart`, which
// understands Chemical JSON (Avogadro 2's native format) as well as XYZ, CML
// and SDF/MOL — including the bond blocks those formats carry. This class is
// kept as a thin façade so existing call sites keep working, and so callers get
// a readable error instead of a silently empty atom list.
// ============================================================================

import 'avogadro_codec.dart';
import 'molecular.dart';

export 'molecular.dart' show Atom, MolecularInfo, hillFormula, molarMass, atomFor;

class MoleculeParser {
  const MoleculeParser._();

  /// Parses [data] into atoms.
  ///
  /// [format] is a hint (`xyz`, `cjson`, `cml`, `sdf`, `mol`); when it is null
  /// or unrecognised the format is sniffed from the content.
  ///
  /// Throws [AvogadroCodecException] with a human-readable reason when the
  /// document cannot be read. Use [tryParse] when a silent fallback is wanted.
  static List<Atom> parse(String data, [String? format]) {
    return AvogadroCodec.decode(
      data,
      formatHint: format,
      title: 'Imported structure',
    ).atoms;
  }

  /// Like [parse] but returns an empty list instead of throwing.
  static List<Atom> tryParse(String data, [String? format]) {
    try {
      return parse(data, format);
    } on AvogadroCodecException {
      return const [];
    }
  }

  /// Parses and keeps the metadata (title, perceived bonds).
  static DecodedStructure parseDetailed(String data, [String? format]) {
    return AvogadroCodec.decode(
      data,
      formatHint: format,
      title: 'Imported structure',
    );
  }

  /// Extensions accepted by the file picker and the import actions.
  static const List<String> supportedExtensions = [
    'xyz',
    'cjson',
    'cml',
    'mol',
    'sdf',
  ];
}
