import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A service to save and restore the state of the dashboard session.
/// This prevents data loss when the user refreshes the page.
class SessionStateService {
  static const String _kSessionKey = 'quantum_forge_session_state';

  /// Saves the serialized session state into SharedPreferences.
  Future<void> saveDashboardState(Map<String, dynamic> state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(state);
      await prefs.setString(_kSessionKey, jsonStr);
    } catch (e) {
      // Fail silently for session state saves
      debugPrint('Failed to save session state: $e');
    }
  }

  /// Loads the serialized session state from SharedPreferences.
  Future<Map<String, dynamic>?> loadDashboardState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_kSessionKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        return jsonDecode(jsonStr) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Failed to load session state: $e');
    }
    return null;
  }
}
