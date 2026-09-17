// ============================================================================
// StorageService — Abstract interface for binary/file storage
// Implementations: LocalStorageService (path_provider), FirebaseStorageService
// ============================================================================

import 'dart:typed_data';

class StoredFile {
  /// A locator that can be used to retrieve or stream the file.
  /// For local impl: absolute filesystem path.
  /// For Firebase impl: gs:// download URL.
  final String locator;
  const StoredFile({required this.locator});
}

abstract class StorageService {
  /// Upload raw bytes and return a [StoredFile] with its locator.
  Future<StoredFile> uploadBytes({
    required String userId,
    required String jobId,
    required String fileName,
    required Uint8List bytes,
  });

  /// Upload from a filesystem path and return a [StoredFile].
  Future<StoredFile> uploadFile({
    required String userId,
    required String jobId,
    required String fileName,
    required String filePath,
  });

  /// Read the content of a stored file as a UTF-8 string.
  Future<String> readAsString(StoredFile file);

  /// Delete all files for a given job.
  Future<void> deleteJobFiles(String userId, String jobId);
}
