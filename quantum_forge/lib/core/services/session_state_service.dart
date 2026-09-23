import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'app_storage.dart';

/// Saves and restores the dashboard session so a page refresh does not lose the
/// work in progress.
///
/// This is the one place where "survives a refresh" is the entire feature rather
/// than a convenience, and it is also the reason `AppStorage` is synchronous:
/// the dashboard can restore its state during construction instead of behind an
/// `await`, so there is no frame where the UI shows a default and then snaps.
class SessionStateService {
  static const String _kSessionKey = 'quantum_forge_session_state';

  /// Persists [state] as JSON.
  Future<void> saveDashboardState(Map<String, dynamic> state) async {
    try {
      AppStorage.setString(_kSessionKey, jsonEncode(state));
    } catch (e) {
      // Encoding failure, not a storage failure — a value that cannot be
      // serialised. Losing session state is survivable, so this stays quiet.
      debugPrint('Failed to save session state: $e');
    }
  }

  /// The last persisted session, or null when there is none.
  Future<Map<String, dynamic>?> loadDashboardState() async {
    try {
      final jsonStr = AppStorage.getString(_kSessionKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr);
        if (decoded is Map<String, dynamic>) return decoded;
        // A stored payload of the wrong shape is stale or corrupt; treat it as
        // absent rather than throwing into every caller.
        debugPrint('Session state had an unexpected shape; ignoring it.');
      }
    } catch (e) {
      debugPrint('Failed to load session state: $e');
    }
    return null;
  }
}
