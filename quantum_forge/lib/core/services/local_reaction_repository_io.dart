// ============================================================================
// LocalReactionRepository — JSON file-based reaction store. Fully offline, no Firebase.
//
// Storage layout (in app documents directory):
//   colabrxn/
//   └── reactions/
//       ├── index.json          ← list of all reaction IDs + metadata
//       └── <reactionId>.json        ← full reaction document
//
// Real-time streaming is simulated with a StreamController that is updated
// whenever updateReaction() is called. The compute_worker.py, when running locally,
// can also write to these files via the same JSON protocol.
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:quantum_forge/core/utils/uuid_util.dart';
import 'package:quantum_forge/features/reaction_runner/data/models/reaction_models.dart';
import 'reaction_repository.dart';

class LocalReactionRepository implements ReactionRepository {

  static const _folder = 'colabrxn/reactions';

  // Active stream controllers keyed by reactionId
  final Map<String, StreamController<ReactionStatusResponse>> _controllers = {};

  // -------------------------------------------------------------------------
  // Directory helpers
  // -------------------------------------------------------------------------
  Future<String> get _reactionsDir async {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData == null) throw UnsupportedError('Windows only');
    final dir = Directory(p.join(localAppData, _folder));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  Future<File> _reactionFile(String reactionId) async =>
      File(p.join(await _reactionsDir, '$reactionId.json'));

  Future<File> get _indexFile async =>
      File(p.join(await _reactionsDir, 'index.json'));

  // -------------------------------------------------------------------------
  // CRUD
  // -------------------------------------------------------------------------
  @override
  Future<String> createReaction(Map<String, dynamic> reactionData) async {
    final reactionId = reactionData['reaction_id'] as String? ?? UuidUtil.v4();
    final doc = {
      ...reactionData,
      'reaction_id': reactionId,
      'created_at': DateTime.now().toIso8601String(),
    };

    // Write reaction file
    final file = await _reactionFile(reactionId);
    await file.writeAsString(jsonEncode(doc));

    // Update index
    await _updateIndex(reactionId, doc);

    // Notify any active watcher
    _notifyController(reactionId, doc);

    return reactionId;
  }

  @override
  Future<ReactionStatusResponse?> getReaction(String reactionId) async {
    try {
      final file = await _reactionFile(reactionId);
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;
      final raw = jsonDecode(content) as Map<String, dynamic>;
      return _fromMap(raw);
    } catch (e) {
      print('Error reading reaction $reactionId: $e');
      return null;
    }
  }

  @override
  Future<ReactionStatusResponse?> findCachedTemplateReaction(String templateId, Map<String, dynamic> settingsMap) async {
    final idxFile = await _indexFile;
    if (!await idxFile.exists()) return null;
    final content = await idxFile.readAsString();
    if (content.trim().isEmpty) return null;
    final index = jsonDecode(content) as Map<String, dynamic>;
    
    // Sort by created_at descending if possible
    final List<Map<String, dynamic>> entries = index.values.cast<Map<String, dynamic>>().toList();
    entries.sort((a, b) {
      final aDate = a['created_at'] ?? '';
      final bDate = b['created_at'] ?? '';
      return bDate.compareTo(aDate);
    });

    for (var meta in entries) {
      if (meta['template_id'] == templateId && meta['state'] == ReactionState.completed.name) {
        // We found a match in metadata, let's load the full file to check settings
        final fullReaction = await getReaction(meta['reaction_id'] as String);
        if (fullReaction != null) {
          // Read raw file again to get settings map since ReactionStatusResponse doesn't store settings
          final file = await _reactionFile(fullReaction.reactionId);
          if (await file.exists()) {
             final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
             bool settingsMatch = true;
             for (var key in settingsMap.keys) {
               if (raw[key] != settingsMap[key]) {
                 settingsMatch = false;
                 break;
               }
             }
             if (settingsMatch) return fullReaction;
          }
        }
      }
    }
    return null;
  }

  @override
  Future<void> updateReaction(String reactionId, Map<String, dynamic> fields) async {
    final file = await _reactionFile(reactionId);
    Map<String, dynamic> existing = {};
    if (await file.exists()) {
      existing = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    }
    final merged = {...existing, ...fields, 'updated_at': DateTime.now().toIso8601String()};
    await file.writeAsString(jsonEncode(merged));
    await _updateIndex(reactionId, merged);
    _notifyController(reactionId, merged);
  }



  @override
  Stream<ReactionStatusResponse> watchReaction(String reactionId) {
    final ctrl = _controllers.putIfAbsent(
      reactionId,
      () => StreamController<ReactionStatusResponse>.broadcast(),
    );

    // Emit the current state immediately if available
    _reactionFile(reactionId).then((f) async {
      if (await f.exists()) {
        final raw = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        if (!ctrl.isClosed) ctrl.add(_fromMap(raw));
      }
    });

    return ctrl.stream;
  }

  @override
  Future<List<ReactionStatusResponse>> listReactions(String userId) async {
    final index = await _readIndex();
    final reactions = <ReactionStatusResponse>[];
    for (final entry in index.reversed) {
      if (entry['user_id'] == userId || entry['user_id'] == null) {
        final reaction = await getReaction(entry['reaction_id'] as String);
        if (reaction != null) reactions.add(reaction);
      }
    }
    return reactions;
  }

  @override
  Future<void> deleteReaction(String reactionId) async {
    final file = await _reactionFile(reactionId);
    if (await file.exists()) await file.delete();
    await _removeFromIndex(reactionId);
    final ctrl = _controllers.remove(reactionId);
    await ctrl?.close();
  }

  // -------------------------------------------------------------------------
  // Index management
  // -------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> _readIndex() async {
    try {
      final file = await _indexFile;
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];
      final raw = jsonDecode(content);
      return (raw as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error reading index: $e');
      return [];
    }
  }

  Future<void> _updateIndex(String reactionId, Map<String, dynamic> doc) async {
    final index = await _readIndex();
    index.removeWhere((e) => e['reaction_id'] == reactionId);
    index.add({
      'reaction_id': reactionId,
      'user_id': doc['user_id'],
      'state': doc['state'],
      'template_name': doc['template_name'],
      'created_at': doc['created_at'],
    });
    final file = await _indexFile;
    await file.writeAsString(jsonEncode(index));
  }

  Future<void> _removeFromIndex(String reactionId) async {
    final index = await _readIndex();
    index.removeWhere((e) => e['reaction_id'] == reactionId);
    final file = await _indexFile;
    await file.writeAsString(jsonEncode(index));
  }

  // -------------------------------------------------------------------------
  // Stream helpers
  // -------------------------------------------------------------------------
  void _notifyController(String reactionId, Map<String, dynamic> doc) {
    final ctrl = _controllers[reactionId];
    if (ctrl != null && !ctrl.isClosed) {
      ctrl.add(_fromMap(doc));
    }
  }

  // -------------------------------------------------------------------------
  // Mapping
  // -------------------------------------------------------------------------
  static ReactionStatusResponse _fromMap(Map<String, dynamic> data) {
    final reactionStateStr = data['state'] as String? ?? ReactionState.pending.name;
    final stateEnum = ReactionState.values.firstWhere(
      (e) => e.name == reactionStateStr,
      orElse: () => ReactionState.error,
    );
    final energyRaw = data['energy_profile'] as List<dynamic>?;
    final framesRaw = data['trajectory_frames'] as List<dynamic>?;

    return ReactionStatusResponse(
      reactionId: data['reaction_id'] as String,
      state: stateEnum,
      progress: (data['progress'] as num?)?.toDouble() ?? 0.0,
      message: data['message'] as String?,
      energyProfile: energyRaw?.map((e) => (e as num).toDouble()).toList(),
      trajectoryFrames: framesRaw?.map((e) => e.toString()).toList(),
      createdAt: data['created_at'] != null ? DateTime.tryParse(data['created_at']) : null,
    );
  }

  /// Call this to release all open stream controllers (e.g., on app shutdown).
  Future<void> dispose() async {
    for (final ctrl in _controllers.values) {
      await ctrl.close();
    }
    _controllers.clear();
  }
}
