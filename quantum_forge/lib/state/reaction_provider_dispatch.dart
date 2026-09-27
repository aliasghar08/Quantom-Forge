// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
part of 'reaction_provider.dart';

extension ReactionProviderDispatchExt on ReactionNotifier {
  // --- Dispatch from custom files ---
  Future<void> dispatchReaction(
    PickedFile reactantFile,
    PickedFile productFile,
    QuantumSettings settings,
  ) async {
    _setLoading(true);
    try {
      final reactantXyz = reactantFile.bytes != null
          ? utf8.decode(reactantFile.bytes!, allowMalformed: true)
          : '';
      final productXyz = productFile.bytes != null
          ? utf8.decode(productFile.bytes!, allowMalformed: true)
          : '';

      // 1. A configured ColabReaction (DMF) backend takes precedence — it
      //    runs the real Direct MaxFlux + MLIP optimisation.
      if (await _dispatchToBackend(reactantXyz, productXyz, settings)) return;

      // Guests run in a local, in-memory session — no Firestore, no history.
      // Signing in turns history on (cross-device sync).
      if (!await _auth.isAuthenticated()) {
        await _simulateGuestReaction(reactantXyz, productXyz);
        return;
      }

      final userId = await _auth.getUserId();
      
      final reactionId = await _repo.createReaction({
        'user_id': userId,
        'state': ReactionState.pending.name,
        'progress': 0.0,
        'message': 'Uploading structures...',
      });

      // Upload Reactant
      final reactantStored = reactantFile.bytes != null 
          ? await _storage.uploadBytes(
              userId: userId, 
              reactionId: reactionId, 
              fileName: 'reactant.xyz', 
              bytes: reactantFile.bytes!)
          : await _storage.uploadFile(
              userId: userId, 
              reactionId: reactionId, 
              fileName: 'reactant.xyz', 
              filePath: reactantFile.path!);

      // Upload Product
      final productStored = productFile.bytes != null 
          ? await _storage.uploadBytes(
              userId: userId, 
              reactionId: reactionId, 
              fileName: 'product.xyz', 
              bytes: productFile.bytes!)
          : await _storage.uploadFile(
              userId: userId, 
              reactionId: reactionId, 
              fileName: 'product.xyz', 
              filePath: productFile.path!);

      // Update reaction with locators and settings
      await _repo.updateReaction(reactionId, {
        'message': 'Reaction submitted to compute node...',
        'reactant_xyz': reactantStored.locator,
        'product_xyz': productStored.locator,
        ...settings.toFirestoreMap(),
      });

      _listenToReactionUpdates(reactionId);
      
      // Simulate backend processing
      _simulateReactionProcessing(reactionId, reactantXyz, productXyz);
    } catch (e) {
      _setError('Failed to dispatch reaction: $e');
    }
  }

  // --- Dispatch from embedded template (no file upload) ---
  Future<void> dispatchFromTemplate(
    ReactionTemplate template,
    QuantumSettings settings,
  ) async {
    _setLoading(true);
    try {
      // A configured compute backend takes precedence (real DMF run).
      if (await _dispatchToBackend(
          template.reactantXyz, template.productXyz, settings)) {
        return;
      }

      // Guests run locally; the template cache and Firestore persistence only
      // apply to signed-in users.
      if (!await _auth.isAuthenticated()) {
        await _simulateGuestReaction(template.reactantXyz, template.productXyz);
        return;
      }

      final userId = await _auth.getUserId();

      // --- Caching check ---
      final cachedReaction = await _repo.findCachedTemplateReaction(template.id, settings.toFirestoreMap());
      if (cachedReaction != null) {
        // Found an existing completed reaction matching this template and settings!
        _setLoading(false);
        value = ReactionStatusResponse(
          reactionId: cachedReaction.reactionId,
          state: ReactionState.optimizing,
          progress: 0.0,
          message: 'Cache hit! Restoring quantum state...',
        );
        notifyListeners();

        // Simulate fast restoration progress
        for (int i = 1; i <= 10; i++) {
          await Future.delayed(const Duration(milliseconds: 100));
          value = ReactionStatusResponse(
            reactionId: cachedReaction.reactionId,
            state: ReactionState.optimizing,
            progress: i / 10.0,
            message: 'Restoring trajectory frames...',
          );
          notifyListeners();
        }

        value = cachedReaction;
        _listenToReactionUpdates(cachedReaction.reactionId);
        notifyListeners();
        return;
      }
      // ---------------------

      final reactionId = await _repo.createReaction({
        'user_id': userId,
        'template_id': template.id,
        'template_name': template.name,
        'reference_ea': template.referenceEa,
        'state': ReactionState.pending.name,
        'progress': 0.0,
        'message': 'Template reaction submitted — ${template.name}...',
        'reactant_xyz_inline': template.reactantXyz,
        'product_xyz_inline': template.productXyz,
        ...settings.toFirestoreMap(),
      });

      _listenToReactionUpdates(reactionId);
      
      // Simulate backend processing
      _simulateReactionProcessing(reactionId, template.reactantXyz, template.productXyz);
    } catch (e) {
      _setError('Failed to dispatch template reaction: $e');
    }
  }

}
