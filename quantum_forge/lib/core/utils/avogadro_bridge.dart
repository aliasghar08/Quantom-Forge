// ============================================================================
// Avogadro Bridge — platform selector
// ----------------------------------------------------------------------------
// Replaces the old `avogadro_export.dart` shim, which unconditionally exported
// the web-only `dart:js_interop` implementation and therefore could not be
// compiled (or unit-tested) off the web.
//
// `AvogadroExporter.exportForAvogadro` is kept as a thin deprecated shim so
// older call sites keep compiling.
// ============================================================================

export 'avogadro_bridge_stub.dart'
    if (dart.library.js_interop) 'avogadro_bridge_web.dart';

import 'avogadro_bridge_stub.dart'
    if (dart.library.js_interop) 'avogadro_bridge_web.dart';
import 'avogadro_interchange.dart';
import 'xyz_parser.dart';

/// Backwards-compatible facade over [AvogadroBridge].
@Deprecated('Use AvogadroBridge.downloadStructure / AvogadroInterchange instead.')
class AvogadroExporter {
  /// Downloads a raw XYZ payload. Prefer
  /// `AvogadroBridge.downloadStructure(structure, format: 'cjson')`.
  static Future<void> exportForAvogadro(String filename, String xyzData) async {
    AvogadroBridge.download(filename, xyzData, mimeType: 'chemical/x-xyz');
  }
}

/// Convenience: export a plain atom list without building a structure first.
void downloadAtoms({
  required List<Atom> atoms,
  required String title,
  required String format,
  int precision = 5,
  bool includeTitleLine = true,
  double bondTolerance = 1.6,
}) {
  final structure = AvogadroInterchange.structure(
    atoms,
    title: title,
    bondTolerance: bondTolerance,
  );
  AvogadroBridge.downloadStructure(
    structure,
    format: format,
    precision: precision,
    includeTitleLine: includeTitleLine,
  );
}
