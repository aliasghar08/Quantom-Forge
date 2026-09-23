// ============================================================================
// LocalAuthService — UUID-based identity, no Firebase required.
// Stores a v4 UUID in AppStorage on first run and reuses it forever.
// Fully offline; behaves identically to anonymous Firebase auth from the
// app's perspective.
// ============================================================================

import 'package:quantum_forge/core/services/app_storage.dart';
import 'package:quantum_forge/core/utils/uuid_util.dart';
import 'auth_service.dart';

class LocalAuthService implements AuthService {
  static const _keyUserId = 'local_user_id';

  @override
  Future<String> getUserId() async {
    final existing = AppStorage.getString(_keyUserId);
    if (existing != null && existing.isNotEmpty) return existing;
    final newId = UuidUtil.v4();
    AppStorage.setString(_keyUserId, newId);
    return newId;
  }

  @override
  Future<bool> isAuthenticated() async =>
      AppStorage.containsKey(_keyUserId);

  @override
  Future<void> signOut() async => AppStorage.remove(_keyUserId);

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signUp(String email, String password) async {}

  @override
  Future<void> signInWithGoogle() async {}
}
