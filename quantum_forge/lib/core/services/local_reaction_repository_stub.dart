import 'dart:async';
import 'package:quantum_forge/features/reaction_runner/data/models/reaction_models.dart';
import 'reaction_repository.dart';

class LocalReactionRepository implements ReactionRepository {
  @override
  Future<String> createReaction(Map<String, dynamic> reactionData) => throw UnsupportedError('Stub');

  @override
  Future<ReactionStatusResponse?> getReaction(String reactionId) => throw UnsupportedError('Stub');

  @override
  Future<ReactionStatusResponse?> findCachedTemplateReaction(String templateId, Map<String, dynamic> settingsMap) => throw UnsupportedError('Stub');

  @override
  Future<void> updateReaction(String reactionId, Map<String, dynamic> fields) => throw UnsupportedError('Stub');

  @override
  Stream<ReactionStatusResponse> watchReaction(String reactionId) => throw UnsupportedError('Stub');

  @override
  Future<List<ReactionStatusResponse>> listReactions(String userId) => throw UnsupportedError('Stub');

  @override
  Future<void> deleteReaction(String reactionId) => throw UnsupportedError('Stub');
  
  Future<void> dispose() => throw UnsupportedError('Stub');
}
