// Blob storage for reaction artefacts (uploaded trajectories, exported files).
//
// NOT to be confused with `AppStorage`, which is the synchronous key/value store
// for settings and theme state. This one holds *file bytes* behind the
// `StorageService` interface and is asynchronous by nature.
//
// The conditional export previously carried a `dart.library.io` branch pointing
// at `local_storage_service_io.dart`, which does not exist. The analyzer does not
// check that a conditional target exists, so it read as fine — but every
// non-web compile failed outright with:
//
//   Error when reading 'lib/core/services/local_storage_service_io.dart':
//   The system cannot find the file specified
//
// That silently made this module (and anything importing it, such as
// `main.dart` and `ReactionNotifier`) impossible to unit-test on the Dart VM,
// and would have broken a Windows/Linux/macOS build. Until there is a real
// file-backed implementation, off-web targets get the stub, which throws
// `UnsupportedError` on use rather than failing to compile.
export 'local_storage_service_stub.dart'
    if (dart.library.js_interop) 'local_storage_service_web.dart';
