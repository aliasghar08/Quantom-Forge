// ============================================================================
// Avogadro Deep Links
// ----------------------------------------------------------------------------
// The Avogadro 2 plugin hands a structure to the web app through a deep link:
//
//   https://quantom-forge.web.app/?import_struct=<base64url cjson>&fmt=cjson&name=…
//
// The legacy `?import_xyz=<base64url xyz>` form (pre-2.0 plugin) is still
// accepted so older installs keep working.
// ============================================================================

import 'avogadro_codec.dart';
import 'avogadro_interchange.dart';

/// Parameters understood on the receiving side.
class AvogadroLinkParams {
  const AvogadroLinkParams._();

  /// Base64url Chemical JSON payload — current transport.
  static const String structure = 'import_struct';

  /// Base64url XYZ payload — pre-2.0 transport, still supported.
  static const String legacyXyz = 'import_xyz';

  /// Format hint (`cjson`, `xyz`, `cml`, `sdf`).
  static const String format = 'fmt';

  /// Human readable structure name.
  static const String name = 'name';

  /// Origin marker, e.g. `avogadro-2.0`.
  static const String source = 'source';
}

/// Outcome of inspecting the current URL.
enum DeepLinkStatus {
  /// No import parameters were present.
  absent,

  /// A payload was found but could not be used.
  invalid,

  /// The payload decoded into atoms and is ready to load.
  ready,
}

/// A parsed Avogadro deep link.
class AvogadroDeepLink {
  final DeepLinkStatus status;
  final DecodedStructure? structure;
  final String? error;
  final String? rawPayload;
  final String? format;
  final String? source;

  const AvogadroDeepLink._({
    required this.status,
    this.structure,
    this.error,
    this.rawPayload,
    this.format,
    this.source,
  });

  static const AvogadroDeepLink absent = AvogadroDeepLink._(
    status: DeepLinkStatus.absent,
  );

  factory AvogadroDeepLink.ready({
    required DecodedStructure structure,
    String? format,
    String? source,
  }) =>
      AvogadroDeepLink._(
        status: DeepLinkStatus.ready,
        structure: structure,
        format: format,
        source: source,
      );

  factory AvogadroDeepLink.invalid(String error, {String? rawPayload}) =>
      AvogadroDeepLink._(
        status: DeepLinkStatus.invalid,
        error: error,
        rawPayload: rawPayload,
      );

  bool get isReady => status == DeepLinkStatus.ready;
  bool get isAbsent => status == DeepLinkStatus.absent;
  bool get isInvalid => status == DeepLinkStatus.invalid;

  /// A short, user-facing description of what arrived.
  String? get summary {
    final s = structure;
    if (s == null) return null;
    return '${s.title} — ${s.atomCount} atoms, ${s.bondCount} bonds';
  }
}

class AvogadroDeepLinkCodec {
  const AvogadroDeepLinkCodec._();

  /// Builds the URL that opens Quantum Forge with [structure] pre-loaded.
  ///
  /// The structure is transported as CJSON because it round-trips bonds and
  /// per-atom charges; the plain-XYZ link is only kept for old plugins.
  static Uri buildImportUri({
    required AvogadroStructure structure,
    required String baseUrl,
  }) {
    final cjson = AvogadroInterchange.toCjson(structure);
    final encoded = AvogadroCodec.encodePayload(cjson);
    final separator = baseUrl.contains('?') ? '&' : '?';
    return Uri.parse(
      '$baseUrl$separator'
      '${AvogadroLinkParams.structure}=$encoded'
      '&${AvogadroLinkParams.format}=cjson'
      '&${AvogadroLinkParams.source}=quantum-forge'
      '&${AvogadroLinkParams.name}=${Uri.encodeQueryComponent(structure.title)}',
    );
  }

  /// Parses the query parameters of the current page.
  ///
  /// Supports the modern `import_struct` transport plus the legacy
  /// `import_xyz` one, decoding either into atoms.
  static AvogadroDeepLink parseQuery(Map<String, String> query) {
    final modern = query[AvogadroLinkParams.structure];
    final legacy = query[AvogadroLinkParams.legacyXyz];
    final payload = (modern != null && modern.isNotEmpty) ? modern : legacy;
    if (payload == null || payload.isEmpty) return AvogadroDeepLink.absent;

    final formatHint = query[AvogadroLinkParams.format] ??
        (modern != null ? 'cjson' : 'xyz');
    final name = query[AvogadroLinkParams.name];
    final source = query[AvogadroLinkParams.source];

    try {
      final text = AvogadroCodec.decodePayload(payload);
      final decoded = AvogadroCodec.decode(
        text,
        formatHint: formatHint,
        title: (name == null || name.trim().isEmpty)
            ? 'Avogadro import'
            : name.trim(),
      );
      if (decoded.isEmpty) {
        return AvogadroDeepLink.invalid(
          'The payload decoded but contains no atoms.',
          rawPayload: payload,
        );
      }
      return AvogadroDeepLink.ready(
        structure: decoded,
        format: formatHint,
        source: source,
      );
    } on AvogadroCodecException catch (e) {
      return AvogadroDeepLink.invalid(e.message, rawPayload: payload);
    } catch (e) {
      return AvogadroDeepLink.invalid('Unexpected payload error: $e');
    }
  }

  /// Parses a full [Uri] (query parameters only).
  static AvogadroDeepLink parseUri(Uri uri) => parseQuery(uri.queryParameters);

  /// Reads the current page URL.
  static AvogadroDeepLink fromCurrentUrl() => parseUri(Uri.base);
}
