import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quantum_forge/core/services/local_storage_service.dart';
import 'package:quantum_forge/core/services/storage_service.dart';

// ============================================================================
// LocalStorageService — compile and contract tests
// ----------------------------------------------------------------------------
// This file exists mainly as a regression guard. The conditional export in
// `local_storage_service.dart` used to point at a `local_storage_service_io.dart`
// that was never written, which made the library fail to compile on any non-web
// target:
//
//   Error when reading 'lib/core/services/local_storage_service_io.dart':
//   The system cannot find the file specified
//
// Nothing caught it, because no test imported the module — so the break only
// showed up for a desktop build, and it made `ReactionNotifier` (which takes a
// `StorageService`) untestable on the VM. Importing it here means the VM now
// compiles the conditional export, so the same mistake fails loudly in CI.
//
// Note this is blob storage for reaction artefacts. Settings and theme state go
// through `AppStorage`, which is covered by `app_storage_test.dart`.
// ============================================================================

void main() {
  test('the conditional export resolves off the web', () {
    // Reaching this line at all is the point: it means the module compiled for
    // the VM. Before the fix, the test file would not even load.
    expect(LocalStorageService.new, returnsNormally);
  });

  test('the VM stub fails loudly rather than pretending to store anything', () {
    final service = LocalStorageService();
    expect(service, isA<StorageService>());
    expect(
      () => service.uploadBytes(
        userId: 'u',
        reactionId: 'r',
        fileName: 'traj.sdf',
        bytes: Uint8List(0),
      ),
      throwsUnsupportedError,
    );
    expect(
      () => service.readAsString(const StoredFile(locator: 'u/r/traj.sdf')),
      throwsUnsupportedError,
    );
    expect(() => service.deleteReactionFiles('u', 'r'), throwsUnsupportedError);
  });
}
