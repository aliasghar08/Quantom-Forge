// ============================================================================
// LocalAuthService — UUID-based identity, no Firebase required.
// Stores a v4 UUID in SharedPreferences on first run and reuses it forever.
// Fully offline; behaves identically to anonymous Firebase auth from the
// app's perspective.
// ============================================================================

import 'package:quantum_forge/core/utils/local_prefs.dart';
import 'package:quantum_forge/core/utils/uuid_util.dart';
import 'auth_service.dart';

class LocalAuthService implements AuthService {
  static const _keyUserId = 'local_user_id';


  @override
  Future<String> getUserId() async {
    final prefs = await LocalPrefs.getInstance();
    final existing = prefs.getString(_keyUserId);
    if (existing != null && existing.isNotEmpty) return existing;
    final newId = UuidUtil.v4();
    await prefs.setString(_keyUserId, newId);
    return newId;
  }

  @override
  Future<bool> isAuthenticated() async {
    final prefs = await LocalPrefs.getInstance();
    return prefs.containsKey(_keyUserId);
  }

  @override
  Future<void> signOut() async {
    final prefs = await LocalPrefs.getInstance();
    await prefs.remove(_keyUserId);
  }
}
