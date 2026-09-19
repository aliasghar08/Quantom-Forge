// ============================================================================
// Deep-link + codec tests
// ----------------------------------------------------------------------------
// The Avogadro plugin hands structures over as `?import_struct=<base64url cjson>`.
// These tests pin the exact payload the Python plugin produces (including the
// `=` padding the old plugin stripped) and prove the reader is robust against
// the malformed input the old implementation crashed on silently.
// ============================================================================

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quantum_forge/core/utils/avogadro_codec.dart';
import 'package:quantum_forge/core/utils/avogadro_deep_link.dart';
import 'package:quantum_forge/core/utils/avogadro_interchange.dart';
import 'package:quantum_forge/core/utils/molecular.dart';

/// The exact CJSON body `avogadro_plugin/quantom_forge_export.py` serialises
/// for water, so a change on either side of the bridge is caught here.
const String waterCjson =
    '{"chemicalJson":1,"name":"Water","atoms":{"coords":{"3d":[0.0,0.0,0.11779,'
    '0.0,0.75545,-0.47116,0.0,-0.75545,-0.47116]},"elements":{"number":[8,1,1]}},'
    '"bonds":{"connections":{"index":[0,1,0,2]},"order":[1,1]}}';

void main() {
  group('payload transport', () {
    test('encode/decode round-trips arbitrary text', () {
      final encoded = AvogadroCodec.encodePayload(waterCjson);
      expect(encoded.contains('='), isFalse, reason: 'padding is stripped');
      expect(AvogadroCodec.decodePayload(encoded), waterCjson);
    });

    test('decodes padding-stripped payloads of every length residue', () {
      for (final text in ['a', 'ab', 'abc', 'abcd', 'abcdefgh', waterCjson]) {
        final padded = base64Url.encode(utf8.encode(text));
        final stripped = padded.replaceAll('=', '');
        expect(
          AvogadroCodec.decodePayload(stripped),
          text,
          reason: 'failed for "$text" (residue ${stripped.length % 4})',
        );
      }
    });

    test('a "+" corrupted into a space is recovered (URL round trip)', () {
      // `+` is a valid base64 char that a query-string round trip can turn into
      // a space; the decoder normalises it back.
      final payload = AvogadroCodec.encodePayload(waterCjson);
      expect(AvogadroCodec.decodePayload(payload.replaceAll('-', '+')
          .replaceAll('_', '/')
          .replaceAll('+', ' ')), waterCjson);
    });

    test('rejects truncated base64 with a readable message', () {
      expect(
        () => AvogadroCodec.decodePayload('AAAAA'),
        throwsA(isA<AvogadroCodecException>()),
      );
    });

    test('rejects a payload above the size cap', () {
      // base64 expands by 4/3, so the encoded string must be larger than the
      // byte cap by that factor for the decoded size to trip it.
      final huge = 'A' * ((AvogadroCodec.maxPayloadBytes * 4) ~/ 3 + 16);
      expect(
        () => AvogadroCodec.decodePayload(huge),
        throwsA(isA<AvogadroCodecException>()),
      );
    });
  });

  group('query parsing', () {
    test('absent when there is no import parameter', () {
      final link = AvogadroDeepLinkCodec.parseQuery(const {'foo': 'bar'});
      expect(link.isAbsent, isTrue);
      expect(link.structure, isNull);
    });

    test('reads a modern CJSON payload', () {
      final link = AvogadroDeepLinkCodec.parseQuery({
        'import_struct': AvogadroCodec.encodePayload(waterCjson),
        'fmt': 'cjson',
        'source': 'avogadro',
        'name': 'Water',
      });
      expect(link.isReady, isTrue);
      expect(link.source, 'avogadro');
      expect(link.structure!.atomCount, 3);
      expect(link.structure!.bondCount, 2);
      expect(link.structure!.title, 'Water');
      expect(link.summary, contains('3 atoms'));
    });

    test('still reads a legacy import_xyz payload (pre-2.0 plugin)', () {
      const xyz = '3\nWater\nO 0 0 0.118\nH 0 0.755 -0.471\nH 0 -0.755 -0.471\n';
      final link = AvogadroDeepLinkCodec.parseQuery({
        'import_xyz': AvogadroCodec.encodePayload(xyz),
      });
      expect(link.isReady, isTrue);
      expect(link.structure!.atomCount, 3);
      // XYZ carries no bonds, so they are perceived.
      expect(link.structure!.bondsFromSource, isFalse);
    });

    test('reports invalid payloads instead of throwing', () {
      final link = AvogadroDeepLinkCodec.parseQuery({'import_struct': '!!!!'});
      expect(link.isInvalid, isTrue);
      expect(link.error, isNotNull);
    });

    test('reports a payload that decodes but holds no atoms', () {
      final link = AvogadroDeepLinkCodec.parseQuery({
        'import_struct': AvogadroCodec.encodePayload('{"chemicalJson":1}'),
      });
      expect(link.isInvalid, isTrue);
    });

    test('prefers the modern parameter when both are present', () {
      final link = AvogadroDeepLinkCodec.parseQuery({
        'import_struct': AvogadroCodec.encodePayload(waterCjson),
        'import_xyz': AvogadroCodec.encodePayload('1\nH\nH 0 0 0\n'),
      });
      expect(link.structure!.atomCount, 3);
    });
  });

  group('URL building', () {
    test('produces a URL the reader can consume unchanged', () {
      final structure = AvogadroInterchange.structure(
        [atomFor('O', 0, 0, 0.11779), atomFor('H', 0, 0.75545, -0.47116)],
        title: 'Water & friends',
      );
      final uri = AvogadroDeepLinkCodec.buildImportUri(
        structure: structure,
        baseUrl: 'https://quantom-forge.web.app',
      );

      expect(uri.host, 'quantom-forge.web.app');
      final link = AvogadroDeepLinkCodec.parseUri(uri);
      expect(link.isReady, isTrue);
      expect(link.structure!.atomCount, 2);
      // The title survives percent-encoding.
      expect(link.structure!.title, 'Water & friends');
    });

    test('appends to a base URL that already has a query string', () {
      final uri = AvogadroDeepLinkCodec.buildImportUri(
        structure: AvogadroInterchange.structure([atomFor('O', 0, 0, 0)]),
        baseUrl: 'http://localhost:8080/?debug=1',
      );
      expect(uri.queryParameters.containsKey('debug'), isTrue);
      expect(uri.queryParameters.containsKey('import_struct'), isTrue);
    });
  });

  group('codec robustness', () {
    test('sniffs the format when no hint is given', () {
      expect(AvogadroCodec.resolveFormat(waterCjson, null), 'cjson');
      expect(AvogadroCodec.resolveFormat('<?xml version="1.0"?>', null), 'cml');
      expect(AvogadroCodec.resolveFormat('3\nwater\nO 0 0 0\n', null), 'xyz');
      expect(
        AvogadroCodec.resolveFormat('x\n  RDKit\n\n  3  2  0  0  0  0  0  0  0  0999 V2000\n', null),
        'sdf',
      );
    });

    test('rejects an empty payload', () {
      expect(
        () => AvogadroCodec.decode('   '),
        throwsA(isA<AvogadroCodecException>()),
      );
    });

    test('rejects malformed JSON with a readable message', () {
      expect(
        () => AvogadroCodec.decode('{"atoms": '),
        throwsA(isA<AvogadroCodecException>()),
      );
    });

    test('rejects CJSON with no coordinates', () {
      expect(
        () => AvogadroCodec.decode('{"chemicalJson":1,"atoms":{}}'),
        throwsA(isA<AvogadroCodecException>()),
      );
    });

    test('accepts 2D coordinates as a fallback', () {
      // 2D coordinates use a stride of 2 (x, y); z is implied to be zero.
      final decoded = AvogadroCodec.decode(
        '{"chemicalJson":1,"atoms":{"coords":{"2d":[0,0,1,1]},'
        '"elements":{"number":[6,6]}}}',
      );
      expect(decoded.atomCount, 2);
      expect(decoded.atoms[0].z, 0);
      expect(decoded.atoms[0].x, 0);
      expect(decoded.atoms[1].x, 1);
      expect(decoded.atoms[1].y, 1);
    });

    test('rejects an atom count above the cap', () {
      final numbers = List.filled(AvogadroCodec.maxAtoms + 1, 6).join(',');
      final coords = List.filled((AvogadroCodec.maxAtoms + 1) * 3, 0).join(',');
      expect(
        () => AvogadroCodec.decode(
          '{"chemicalJson":1,"atoms":{"coords":{"3d":[$coords]},'
          '"elements":{"number":[$numbers]}}}',
        ),
        throwsA(isA<AvogadroCodecException>()),
      );
    });

    test('reads only the first frame of a multi-XYZ trajectory', () {
      const multi = '3\nImage 1\nO 0 0 0\nH 0 1 0\nH 0 -1 0\n'
          '3\nImage 2\nO 0 0 9\nH 0 1 9\nH 0 -1 9\n';
      final decoded = AvogadroCodec.decode(multi, formatHint: 'xyz');
      expect(decoded.atomCount, 3);
      expect(decoded.atoms[0].z, 0);
    });

    test('tolerates a header that disagrees with the atom block', () {
      const bad = '5\nLiar\nO 0 0 0\nH 0 1 0\n';
      final decoded = AvogadroCodec.decode(bad, formatHint: 'xyz');
      expect(decoded.atomCount, 2);
      expect(decoded.title, contains('header said 5'));
    });

    test('parses CML written by our own writer', () {
      final structure = AvogadroInterchange.structure(
        [atomFor('O', 0, 0, 0), atomFor('H', 0, 0.98, 0)],
        title: 'Water',
      );
      final decoded = AvogadroCodec.decode(AvogadroInterchange.toCml(structure));
      expect(decoded.atomCount, 2);
      expect(decoded.atoms[0].symbol, 'O');
      expect(decoded.title, 'Water');
    });
  });
}
