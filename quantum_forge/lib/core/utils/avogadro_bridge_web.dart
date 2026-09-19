// ============================================================================
// Avogadro Bridge — browser transport
// ----------------------------------------------------------------------------
// Downloads structures as files the desktop Avogadro 2 can open directly, and
// keeps the address bar clean after a deep-link import.
// ============================================================================

import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'avogadro_interchange.dart';

@JS('Blob')
external JSFunction get _blobConstructor;

@JS('URL.createObjectURL')
external JSString _createObjectURL(JSAny blob);

@JS('URL.revokeObjectURL')
external void _revokeObjectURL(JSString url);

@JS('document')
external JSObject get _document;

@JS('window')
external JSObject get _window;

@JS('navigator.clipboard')
external JSObject? get _clipboard;

/// Web implementation of the Avogadro bridge.
class AvogadroBridge {
  const AvogadroBridge();

  /// Triggers a browser download of [content] under [filename].
  ///
  /// Uses a Blob URL plus a synthetic anchor click, then revokes the URL. The
  /// previous exporter reused the URL immediately after `click()`, which could
  /// race the download in some browsers; the revoke is deferred instead.
  static void download(
    String filename,
    String content, {
    String mimeType = 'chemical/x-xyz',
  }) {
    downloadBytes(
      filename,
      Uint8List.fromList(utf8.encode(content)),
      mimeType: mimeType,
    );
  }

  /// Triggers a browser download of a binary payload (e.g. a ZIP archive).
  static void downloadBytes(
    String filename,
    Uint8List bytes, {
    String mimeType = 'application/octet-stream',
  }) {
    final array = [bytes.buffer.toJS].toJS;
    final options = JSObject()
      ..setProperty('type'.toJS, mimeType.toJS);
    final blob = _blobConstructor.callAsConstructor<JSAny>(array, options);
    final url = _createObjectURL(blob);

    final anchor = _document.callMethod('createElement'.toJS, 'a'.toJS) as JSObject;
    anchor.setProperty('href'.toJS, url);
    anchor.setProperty('download'.toJS, filename.toJS);
    anchor.setProperty('rel'.toJS, 'noopener'.toJS);
    final body = _document.getProperty('body'.toJS);
    if (body != null) {
      (body as JSObject).callMethod('appendChild'.toJS, anchor);
    }
    anchor.callMethod('click'.toJS);
    anchor.callMethod('remove'.toJS);

    _scheduleRevoke(url);
  }

  /// Downloads a structure in the requested interchange format.
  static void downloadStructure(
    AvogadroStructure structure, {
    required String format,
    int precision = 5,
    bool includeTitleLine = true,
    String? filenameOverride,
  }) {
    final (content, mime) = switch (format.toLowerCase()) {
      'cjson' => (AvogadroInterchange.toCjson(structure), 'chemical/x-cjson'),
      'cml' => (AvogadroInterchange.toCml(structure), 'chemical/x-cml'),
      'sdf' || 'mol' => (AvogadroInterchange.toSdf(structure), 'chemical/x-mdl-molfile'),
      _ => (
          AvogadroInterchange.toXyz(
            structure,
            precision: precision,
            includeTitleLine: includeTitleLine,
          ),
          'chemical/x-xyz',
        ),
    };
    final name = filenameOverride ?? safeFilename(structure.title, format);
    download(name, content, mimeType: mime);
  }

  /// Downloads several frames as a multi-XYZ trajectory.
  static void downloadTrajectory(
    List<AvogadroStructure> frames, {
    required String filename,
    int precision = 5,
    bool includeTitleLine = true,
  }) {
    final content = AvogadroInterchange.toMultiXyz(
      frames,
      precision: precision,
      includeTitleLine: includeTitleLine,
    );
    download(filename, content, mimeType: 'chemical/x-xyz');
  }

  /// Copies [content] to the system clipboard. Returns false when the browser
  /// denies clipboard access (non-secure context, missing permission).
  static Future<bool> copyToClipboard(String content, {String mimeType = 'text/plain'}) async {
    final clipboard = _clipboard;
    if (clipboard == null) return false;
    try {
      final blobOptions = JSObject()
        ..setProperty('type'.toJS, mimeType.toJS);
      final blob = _blobConstructor.callAsConstructor<JSAny>(
        [Uint8List.fromList(utf8.encode(content)).buffer.toJS].toJS,
        blobOptions,
      );
      // ClipboardItem({mimeType: blob}) — constructed by name because the
      // global is not always present (Firefox without the async API).
      final global = _window.getProperty('ClipboardItem'.toJS) as JSFunction?;
      if (global != null) {
        final entry = JSObject()
          ..setProperty(mimeType.toJS, blob);
        final clipboardItem = global.callAsConstructor<JSAny>(entry);
        final write = clipboard.callMethod('write'.toJS, [clipboardItem].toJS);
        await (write as JSPromise).toDart;
        return true;
      }
      final textWrite = clipboard.callMethod('writeText'.toJS, content.toJS);
      await (textWrite as JSPromise).toDart;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Opens [url] in a new tab.
  static void openUrl(String url) {
    _window.callMethod('open'.toJS, url.toJS, '_blank'.toJS);
  }

  /// Removes the Avogadro import parameters from the address bar without
  /// reloading, so a browser refresh does not re-import the same structure.
  static bool stripImportParams(Uri current) {
    try {
      final history = _window.getProperty('history'.toJS) as JSObject?;
      final location = _window.getProperty('location'.toJS) as JSObject?;
      if (history == null || location == null) return false;
      const consumed = {
        'import_struct',
        'import_xyz',
        'fmt',
        'name',
        'source',
      };
      final remaining = Map<String, String>.from(current.queryParameters)
        ..removeWhere((key, _) => consumed.contains(key));
      final query = remaining.entries
          .map((e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
          .join('&');
      final cleaned = current.replace(query: query.isEmpty ? null : query).toString();
      history.callMethod(
        'replaceState'.toJS,
        null,
        ''.toJS,
        cleaned.toJS,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static void _scheduleRevoke(JSString url) {
    // Revoke on the next macrotask so the navigation has definitely started.
    final timer = _window.getProperty('setTimeout'.toJS) as JSFunction?;
    if (timer == null) {
      _revokeObjectURL(url);
      return;
    }
    timer.callAsFunction(null, (() => _revokeObjectURL(url)).toJS, 4000.toJS);
  }
}

/// Builds a filesystem-safe download name for a structure.
String safeFilename(String title, String extension) {
  final slug = title
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  final base = slug.isEmpty ? 'quantum_forge_structure' : slug;
  return '$base.$extension';
}
