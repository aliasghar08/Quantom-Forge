import 'dart:async';
import 'package:quantum_forge/core/utils/uuid_util.dart';
import 'package:quantum_forge/features/reaction_runner/data/models/reaction_models.dart';
import 'reaction_repository.dart';

class LocalReactionRepository implements ReactionRepository {
  final Map<String, StreamController<ReactionStatusResponse>> _controllers = {};
  final Map<String, Map<String, dynamic>> _mockReactions = {};

  @override
  Future<String> createReaction(Map<String, dynamic> reactionData) async {
    final reactionId = reactionData['reaction_id'] as String? ?? UuidUtil.v4();
    final doc = {
      ...reactionData,
      'reaction_id': reactionId,
      'created_at': DateTime.now().toIso8601String(),
      'state': ReactionState.pending.name,
    };
    _mockReactions[reactionId] = doc;
    _notifyController(reactionId, doc);
    return reactionId;
  }

  @override
  Future<ReactionStatusResponse?> getReaction(String reactionId) async {
    final doc = _mockReactions[reactionId];
    if (doc == null) return null;
    return _fromMap(doc);
  }

  @override
  Future<ReactionStatusResponse?> findCachedTemplateReaction(String templateId, Map<String, dynamic> settingsMap) => throw UnimplementedError();

  @override
  Future<void> updateReaction(String reactionId, Map<String, dynamic> fields) async {
    final existing = _mockReactions[reactionId] ?? {};
    final merged = {...existing, ...fields, 'updated_at': DateTime.now().toIso8601String()};
    _mockReactions[reactionId] = merged;
    _notifyController(reactionId, merged);
  }

  @override
  Stream<ReactionStatusResponse> watchReaction(String reactionId) {
    final ctrl = _controllers.putIfAbsent(
      reactionId,
      () => StreamController<ReactionStatusResponse>.broadcast(),
    );

    final doc = _mockReactions[reactionId];
    if (doc != null && !ctrl.isClosed) {
      ctrl.add(_fromMap(doc));
    }

    return ctrl.stream;
  }

  @override
  Future<List<ReactionStatusResponse>> listReactions(String userId) async {
    final reactions = <ReactionStatusResponse>[];
    for (final doc in _mockReactions.values) {
      if (doc['user_id'] == userId || doc['user_id'] == null) {
        reactions.add(_fromMap(doc));
      }
    }
    // Reverse to simulate newest-first
    return reactions.reversed.toList();
  }

  @override
  Future<void> deleteReaction(String reactionId) async {
    _mockReactions.remove(reactionId);
    final ctrl = _controllers.remove(reactionId);
    await ctrl?.close();
  }

  void _notifyController(String reactionId, Map<String, dynamic> doc) {
    final ctrl = _controllers[reactionId];
    if (ctrl != null && !ctrl.isClosed) {
      ctrl.add(_fromMap(doc));
    }
  }

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

  Future<void> dispose() async {
    for (final ctrl in _controllers.values) {
      await ctrl.close();
    }
    _controllers.clear();
  }
}
