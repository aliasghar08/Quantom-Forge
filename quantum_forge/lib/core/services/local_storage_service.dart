// ============================================================================
// LocalStorageService — path_provider based, fully offline.
// Files are stored in <appDocumentsDir>/colabrxn/users/<userId>/jobs/<jobId>/
// ============================================================================

import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'storage_service.dart';

class LocalStorageService implements StorageService {
  static const _appFolder = 'colabrxn';

  Future<String> _jobDir(String userId, String jobId) async {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData == null) throw UnsupportedError('Windows only');
    return p.join(localAppData, _appFolder, 'users', userId, 'jobs', jobId);
  }

  @override
  Future<StoredFile> uploadBytes({
    required String userId,
    required String jobId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final dir = await _jobDir(userId, jobId);
    await Directory(dir).create(recursive: true);
    final filePath = p.join(dir, fileName);
    await File(filePath).writeAsBytes(bytes);
    return StoredFile(locator: filePath);
  }

  @override
  Future<StoredFile> uploadFile({
    required String userId,
    required String jobId,
    required String fileName,
    required String filePath,
  }) async {
    final dir = await _jobDir(userId, jobId);
    await Directory(dir).create(recursive: true);
    final destPath = p.join(dir, fileName);
    await File(filePath).copy(destPath);
    return StoredFile(locator: destPath);
  }

  @override
  Future<String> readAsString(StoredFile file) async {
    return File(file.locator).readAsString();
  }

  @override
  Future<void> deleteJobFiles(String userId, String jobId) async {
    final dir = await _jobDir(userId, jobId);
    final d = Directory(dir);
    if (await d.exists()) await d.delete(recursive: true);
  }
}
