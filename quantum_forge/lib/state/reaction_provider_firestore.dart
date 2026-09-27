// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
part of 'reaction_provider.dart';

extension ReactionProviderFirestoreExt on ReactionNotifier {
  // --- Snapshot listener ---
  void _listenToReactionUpdates(String reactionId) {
    _repo.watchReaction(reactionId).listen(
      (reactionStatus) {
        value = reactionStatus;
        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        _setError('Error listening to reaction: $e');
      },
    );
  }
}
