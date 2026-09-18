import 'dart:typed_data';
import 'dart:convert';
import 'storage_service.dart';

class LocalStorageService implements StorageService {
  final Map<String, Uint8List> _memoryStorage = {};

  @override
  Future<StoredFile> uploadBytes({
    required String userId,
    required String jobId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final locator = '$userId/$jobId/$fileName';
    _memoryStorage[locator] = bytes;
    return StoredFile(locator: locator);
  }

  @override
  Future<StoredFile> uploadFile({
    required String userId,
    required String jobId,
    required String fileName,
    required String filePath,
  }) async {
    // Unsupported on web natively without html file inputs, stub it
    final locator = '$userId/$jobId/$fileName';
    _memoryStorage[locator] = Uint8List(0);
    return StoredFile(locator: locator);
  }

  @override
  Future<String> readAsString(StoredFile file) async {
    final bytes = _memoryStorage[file.locator];
    if (bytes == null) throw Exception('File not found in memory: ${file.locator}');
    return utf8.decode(bytes);
  }

  @override
  Future<void> deleteJobFiles(String userId, String jobId) async {
    final prefix = '$userId/$jobId/';
    _memoryStorage.removeWhere((k, v) => k.startsWith(prefix));
  }

  Future<String> exportResultsToZip({
    required String userId,
    required String jobId,
    required List<String> trajectoryFrames,
    required List<double> energyProfile,
  }) async {
    // Just return a dummy path for web debugging
    return 'memory://results_$jobId.zip';
  }
}
