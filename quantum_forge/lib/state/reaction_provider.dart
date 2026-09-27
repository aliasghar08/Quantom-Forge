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
  /// High-frequency: frame index during a running simulation.
  final ValueNotifier<int> playbackFrameNotifier = ValueNotifier<int>(0);

  /// High-frequency: fractional progress 0..1 during a running simulation.
  final ValueNotifier<double> playbackProgressNotifier = ValueNotifier<double>(0.0);

  /// Loading is a *phase*, not a payload.
  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier<bool>(false);

  final ValueNotifier<String?> errorNotifier = ValueNotifier<String?>(null);

  ReactionNotifier(
    this._auth,
    this._storage,
    this._repo, {
    this.backendUrlProvider,
    this.gnnBackendUrlProvider,
  }) : super(null);

  int _notifyCount = 0;

  @override
  void notifyListeners() {
    _notifyCount++;
    if (kDebugMode) {
      debugPrint('[QA] ReactionNotifier.notifyListeners #$_notifyCount '
          '(value=${value?.state}, progress=${value?.progress}, '
          'hasListeners=${hasListeners ? "yes" : "no"})');
    }
    super.notifyListeners();
  }

  bool get isLoading => isLoadingNotifier.value;
  String? get error => errorNotifier.value;

  void _setLoading(bool loading) {
    isLoadingNotifier.value = loading;
    if (loading) errorNotifier.value = null;
  }

  void _setError(String errorStr) {
    isLoadingNotifier.value = false;
    errorNotifier.value = errorStr;
    if (value != null) {
      value = ReactionStatusResponse(
        reactionId: value!.reactionId,
        state: ReactionState.error,
        progress: value!.progress,
        message: value!.message,
        error: errorStr,
      );
    }
  }

}
