import 'dart:typed_data';
import 'storage_service.dart';

class LocalStorageService implements StorageService {
  @override
  Future<StoredFile> uploadBytes({
    required String userId,
    required String reactionId,
    required String fileName,
    required Uint8List bytes,
  }) => throw UnsupportedError('Stub');

  @override
  Future<StoredFile> uploadFile({
    required String userId,
    required String reactionId,
    required String fileName,
    required String filePath,
  }) => throw UnsupportedError('Stub');

  @override
  Future<String> readAsString(StoredFile file) => throw UnsupportedError('Stub');

  @override
  Future<void> deleteReactionFiles(String userId, String reactionId) => throw UnsupportedError('Stub');

  Future<String> exportResultsToZip({
    required String userId,
    required String reactionId,
    required List<String> trajectoryFrames,
    required List<double> energyProfile,
  }) => throw UnsupportedError('Stub');
}
