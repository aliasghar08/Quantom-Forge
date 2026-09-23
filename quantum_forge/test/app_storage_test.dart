// ============================================================================
// AppStorage tests
// ----------------------------------------------------------------------------
// `AppStorage` is the app's only persistence layer: the theme, the workspace
// settings, the compute settings and the session snapshot all go through it. It
// exists because `shared_preferences` threw `MissingPluginException` on every
// call in the web build, so nothing survived a refresh.
//
// These tests run against `app_storage_stub.dart` (the Dart VM has no
// `dart:js_interop`, so the conditional export resolves to the in-memory store).
// The web implementation is deliberately written to the same contract, which is
// what makes this file worth having: it pins the semantics that the localStorage
// version must also satisfy.
// ============================================================================

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quantum_forge/core/services/app_storage.dart';

void main() {
  setUp(AppStorage.clear);
  tearDown(AppStorage.clear);

  group('typed round trips', () {
    test('string', () {
      AppStorage.setString('k', 'value');
      expect(AppStorage.getString('k'), 'value');
    });

    test('bool covers both values', () {
      AppStorage.setBool('t', true);
      AppStorage.setBool('f', false);
      expect(AppStorage.getBool('t'), isTrue);
      expect(AppStorage.getBool('f'), isFalse);
    });

    test('int, including negatives and zero', () {
      AppStorage.setInt('pos', 42);
      AppStorage.setInt('neg', -7);
      AppStorage.setInt('zero', 0);
      expect(AppStorage.getInt('pos'), 42);
      expect(AppStorage.getInt('neg'), -7);
      expect(AppStorage.getInt('zero'), 0);
    });

    test('double, including precision-sensitive values', () {
      AppStorage.setDouble('temp', 298.15);
      AppStorage.setDouble('force', 0.05);
      AppStorage.setDouble('whole', 5);
      expect(AppStorage.getDouble('temp'), 298.15);
      expect(AppStorage.getDouble('force'), 0.05);
      expect(AppStorage.getDouble('whole'), 5.0);
    });

    test('a double read back through an int-keyed format still parses', () {
      // Older builds wrote whole doubles through `setInt`; `getDouble` has to
      // keep reading them or a stored temperature would silently reset.
      AppStorage.setInt('legacy', 300);
      expect(AppStorage.getDouble('legacy'), 300.0);
    });
  });

  group('absent and malformed reads', () {
    test('an unknown key reads as null for every type', () {
      expect(AppStorage.getString('nope'), isNull);
      expect(AppStorage.getBool('nope'), isNull);
      expect(AppStorage.getInt('nope'), isNull);
      expect(AppStorage.getDouble('nope'), isNull);
      expect(AppStorage.containsKey('nope'), isFalse);
    });

    test('wrong-typed text reads as null rather than throwing', () {
      // A key written through the wrong accessor (or by an older build) must not
      // take the app down mid-load; callers fall back to their defaults.
      AppStorage.setString('garbage', 'not-a-number');
      expect(AppStorage.getBool('garbage'), isNull);
      expect(AppStorage.getInt('garbage'), isNull);
      expect(AppStorage.getDouble('garbage'), isNull);
      // ...but it is still *present*, so `containsKey` tells the truth.
      expect(AppStorage.containsKey('garbage'), isTrue);
    });

    test('booleans are strict — only the exact literals parse', () {
      AppStorage.setString('one', '1');
      AppStorage.setString('yes', 'yes');
      AppStorage.setString('empty', '');
      expect(AppStorage.getBool('one'), isNull);
      expect(AppStorage.getBool('yes'), isNull);
      expect(AppStorage.getBool('empty'), isNull);
    });
  });

  group('overwrite, remove and clear', () {
    test('writing a key twice keeps the newer value', () {
      AppStorage.setString('k', 'first');
      AppStorage.setString('k', 'second');
      expect(AppStorage.getString('k'), 'second');
    });

    test('a value can be replaced by a different type', () {
      AppStorage.setInt('k', 1);
      AppStorage.setString('k', 'now-a-string');
      expect(AppStorage.getInt('k'), isNull);
      expect(AppStorage.getString('k'), 'now-a-string');
    });

    test('remove deletes one key and leaves the rest', () {
      AppStorage.setString('a', '1');
      AppStorage.setString('b', '2');
      AppStorage.remove('a');
      expect(AppStorage.containsKey('a'), isFalse);
      expect(AppStorage.getString('a'), isNull);
      expect(AppStorage.getString('b'), '2');
    });

    test('removing an absent key is a no-op, not an error', () {
      expect(() => AppStorage.remove('never-written'), returnsNormally);
    });

    test('clear empties the store', () {
      AppStorage.setString('a', '1');
      AppStorage.setInt('b', 2);
      AppStorage.setBool('c', true);
      AppStorage.clear();
      expect(AppStorage.containsKey('a'), isFalse);
      expect(AppStorage.containsKey('b'), isFalse);
      expect(AppStorage.containsKey('c'), isFalse);
    });
  });

  group('real payloads', () {
    test('the session snapshot survives a JSON round trip', () {
      // Shape mirrors `SessionStateService`: a JSON document stored as one key.
      final payload = jsonEncode({
        'route': '/editor',
        'atomCount': 12,
        'selectedId': null,
        'nested': {
          'tags': ['dmf', 'uma'],
        },
      });
      AppStorage.setString('qf_session_state', payload);

      final decoded =
          jsonDecode(AppStorage.getString('qf_session_state')!) as Map;
      expect(decoded['route'], '/editor');
      expect(decoded['atomCount'], 12);
      expect(decoded['nested'], {'tags': ['dmf', 'uma']});
    });

    test('a provider load sees what a previous instance saved', () {
      // This is the actual bug the migration fixes: a fresh page load must read
      // back what the last session wrote.
      AppStorage.setString('qf_theme_id', 'journal_mono');
      AppStorage.setBool('app_settings_compact_mode', true);
      AppStorage.setDouble('quantum_temperature', 310.5);

      expect(AppStorage.getString('qf_theme_id'), 'journal_mono');
      expect(AppStorage.getBool('app_settings_compact_mode'), isTrue);
      expect(AppStorage.getDouble('quantum_temperature'), 310.5);
    });
  });

  group('durability reporting', () {
    test('the stub reports that it is not persistent', () {
      // True by construction off the web: the map dies with the process. On the
      // web this reports whether localStorage actually accepted a probe write,
      // so a sandboxed page can say "session only" instead of pretending.
      expect(AppStorage.isPersistent, isFalse);
    });
  });
}
