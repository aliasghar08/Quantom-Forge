// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
part of 'reaction_provider.dart';

extension ReactionProviderBackendExt on ReactionNotifier {
  // --- ColabReaction (DMF) backend -------------------------------------
  /// Runs the reaction on the configured compute backend (the Direct MaxFlux +
  /// MLIP pipeline ported from ColabReaction v1.0.3).
  ///
  /// Returns `true` when a backend is configured and handled the request, and
  /// `false` when none is set so the caller can fall back to local execution.
  Future<bool> _dispatchToBackend(
    String reactantXyz,
    String productXyz,
    QuantumSettings settings,
  ) async {
    var url = (backendUrlProvider?.call() ?? '').trim();
    if (settings.mlipModel == 'tx1-fastapi') {
      url = (gnnBackendUrlProvider?.call() ?? '').trim();
    } else if (settings.mlipModel == 'MACE-MP-0') {
      url = 'http://127.0.0.1:8001';
    }
    if (url.isEmpty) return false;
    if (reactantXyz.isEmpty || productXyz.isEmpty) {
      _setError('The backend needs both a reactant and a product structure.');
      return true;
    }

    _setLoading(true);
    try {
      value = ReactionStatusResponse(
        reactionId: '',
        state: ReactionState.pending,
        progress: 0.0,
        message: 'Submitting to ${settings.mlipModel == 'tx1-fastapi' ? 'GNN (tx1)' : 'DMF'} compute node…',
      );
      notifyListeners();

      // Fake progress during potentially long cold-start submit request
      bool isSubmitting = true;
      double simulatedProgress = 0.0;
      int elapsedSeconds = 0;
      
      void simulateProgress() async {
        while (isSubmitting && simulatedProgress < 0.04) {
          await Future.delayed(const Duration(seconds: 1));
          if (!isSubmitting) break;
          elapsedSeconds++;
          simulatedProgress += 0.005;
          if (simulatedProgress > 0.04) simulatedProgress = 0.04;
          
          String message = value?.message ?? 'Submitting...';
          if (elapsedSeconds > 10) {
            message = 'Waking up compute node (this may take up to 2 minutes)…';
          }
          
          value = ReactionStatusResponse(
            reactionId: '',
            state: ReactionState.pending,
            progress: simulatedProgress,
            message: message,
          );
          notifyListeners();
        }
      }
      simulateProgress();

      final reactionId =
          await _backend.submit(url, reactantXyz, productXyz, settings);
      
      isSubmitting = false;

      value = ReactionStatusResponse(
        reactionId: reactionId,
        state: ReactionState.optimizing,
        progress: 0.05,
        message: '${settings.mlipModel == 'tx1-fastapi' ? 'GNN (tx1)' : 'Direct MaxFlux'} running (${settings.mlipModel})…',
      );
      notifyListeners();

      await for (final result in _backend.poll(url, reactionId)) {
        if (result.state == ReactionState.error) {
          // The backend's own reason is the useful one; `message` is the generic
          // "DMF optimisation failed." line.
          _error = result.error ?? result.message ?? 'Backend optimisation failed.';
        }
        value = result;
        notifyListeners();
      }
      _isLoading = false;
    } catch (e) {
      _setError('DMF backend error: $e');
    }
    return true;
  }

}
