// ============================================================================
// Avogadro Bridge — non-web fallback
// ----------------------------------------------------------------------------
// Quantum Forge ships as a web app, but the package is also compiled for
// desktop/mobile targets during `flutter test` and `flutter build`. This stub
// keeps the same API surface so those builds stay green; it never performs I/O.
// ============================================================================

import 'dart:typed_data';

import 'avogadro_interchange.dart';

class AvogadroBridge {
  const AvogadroBridge();

  static void download(
    String filename,
    String content, {
    String mimeType = 'chemical/x-xyz',
  }) {
    throw UnsupportedError(
      'Downloading $filename ($mimeType) requires the web build of Quantum Forge.',
    );
  }

  static void downloadBytes(
    String filename,
    Uint8List bytes, {
    String mimeType = 'application/octet-stream',
  }) {
    throw UnsupportedError(
      'Downloading $filename ($mimeType) requires the web build of Quantum Forge.',
    );
  }

  static void downloadStructure(
    AvogadroStructure structure, {
    required String format,
    int precision = 5,
    bool includeTitleLine = true,
    String? filenameOverride,
  }) {
    download(filenameOverride ?? safeFilename(structure.title, format), '');
  }

  static void downloadTrajectory(
    List<AvogadroStructure> frames, {
    required String filename,
    int precision = 5,
    bool includeTitleLine = true,
  }) {
    download(filename, '');
  }

  static Future<bool> copyToClipboard(
    String content, {
    String mimeType = 'text/plain',
  }) async =>
      false;

  static void openUrl(String url) {}

  static bool stripImportParams(Uri current) => false;
}

String safeFilename(String title, String extension) {
  final slug = title
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  final base = slug.isEmpty ? 'quantum_forge_structure' : slug;
  return '$base.$extension';
}
