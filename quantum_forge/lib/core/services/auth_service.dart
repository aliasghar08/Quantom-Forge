// ============================================================================
// AuthService — Abstract interface for identity management
// Implementations: LocalAuthService (UUID), FirebaseAuthService
// ============================================================================

abstract class AuthService {
  /// Returns a stable user identifier. Creates one on first call.
  Future<String> getUserId();

  /// True if the user has an active session.
  Future<bool> isAuthenticated();

  /// Sign out / clear session.
  Future<void> signOut();
}
