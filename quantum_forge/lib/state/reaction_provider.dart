// ============================================================================
// Reaction Provider — Riverpod AsyncNotifier decoupled from Firebase
// 
// Delegates all operations (Auth, Storage, DB) to the injected service layer.
// Supports both custom file dispatch and template dispatch.
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:quantum_forge/core/services/auth_service.dart';
import 'package:quantum_forge/core/services/backend_compute_service.dart';
import 'package:quantum_forge/core/services/storage_service.dart';
import 'package:quantum_forge/core/services/reaction_repository.dart';
import 'package:quantum_forge/core/services/file_picker_service.dart';
import 'package:quantum_forge/features/reaction_runner/data/models/reaction_models.dart';
import 'package:quantum_forge/state/settings_provider.dart';
import 'package:quantum_forge/features/reaction_library/data/reaction_templates.dart';
import 'package:quantum_forge/core/utils/molecule_parser.dart';
import 'package:quantum_forge/core/utils/uuid_util.dart';
import 'dart:convert';
import 'dart:math' as math;

part 'reaction_provider_dispatch.dart';
part 'reaction_provider_simulation.dart';
part 'reaction_provider_backend.dart';
part 'reaction_provider_guest.dart';
part 'reaction_provider_firestore.dart';


class ReactionNotifier extends ValueNotifier<ReactionStatusResponse?> {
  final AuthService _auth;
  final StorageService _storage;
  final ReactionRepository _repo;

  /// Returns the configured ColabReaction (DMF) backend URL, or an empty
  /// string to use the local illustrative simulation.
  final String Function()? backendUrlProvider;

  /// Returns the configured Transition1x GNN compute backend URL.
  final String Function()? gnnBackendUrlProvider;

  final BackendComputeService _backend = const BackendComputeService();
  bool _isLoading = false;
  String? _error;

  ReactionNotifier(
    this._auth,
    this._storage,
    this._repo, {
    this.backendUrlProvider,
    this.gnnBackendUrlProvider,
  }) : super(null);

  bool get isLoading => _isLoading;
  String? get error => _error;

  void _setLoading(bool loading) {
    _isLoading = loading;
    if (loading) _error = null;
    notifyListeners();
  }

  void _setError(String error) {
    _isLoading = false;
    _error = error;
    if (value != null) {
      value = ReactionStatusResponse(
        reactionId: value!.reactionId,
        state: ReactionState.error,
        progress: value!.progress,
        message: value!.message,
        error: error,
      );
    }
    notifyListeners();
  }

}
