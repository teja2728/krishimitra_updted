import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';
import '../models/auth_role.dart';

class LocalUserStorage {
  static const String _key = 'krishi_mitra_user_auth';
  static const String _roleKey = 'krishi_mitra_role';
  static const String _jwtKey = 'krishi_mitra_jwt';
  static const String _backendUserIdKey = 'krishi_mitra_backend_user_id';
  static const String _offlineSchemesKey = 'krishi_mitra_offline_schemes'; // For offline caching

  Future<void> saveUserAuth(UserAuthData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(data.toJson()));
  }

  Future<UserAuthData?> readUserAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;

    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return UserAuthData.fromJson(decoded);
    }
    return null;
  }

  /// Removes ALL stored data — only call on account deletion or full reset.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_roleKey);
    await prefs.remove(_jwtKey);
    await prefs.remove(_backendUserIdKey);
    await prefs.remove(_offlineSchemesKey);
  }

  /// Removes auth credentials ONLY (JWT, role, userId).
  /// Deliberately preserves bookmark and reminder caches so they survive
  /// logout and are available as fallback until the next backend sync.
  Future<void> clearAuthOnly() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);            // user profile/auth data
    await prefs.remove(_roleKey);        // role
    await prefs.remove(_jwtKey);         // JWT token
    await prefs.remove(_backendUserIdKey); // backend user id
    // NOTE: _offlineSchemesKey, bookmarks, reminders are intentionally kept
  }

  Future<void> saveSession({
    required String token,
    required String userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_jwtKey, token);
    await prefs.setString(_backendUserIdKey, userId);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_jwtKey);
    await prefs.remove(_backendUserIdKey);
    await prefs.remove(_roleKey); // Ensure role is cleared on logout
  }

  Future<String?> readJwtToken() async {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getString(_jwtKey);
    if (t == null || t.isEmpty) return null;
    return t;
  }

  Future<String?> readBackendUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_backendUserIdKey);
    if (id == null || id.isEmpty) return null;
    return id;
  }

  Future<void> saveRole(AuthRole role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, role.toShortString());
  }

  Future<AuthRole?> readRole() async {
    final prefs = await SharedPreferences.getInstance();
    return AuthRole.fromString(prefs.getString(_roleKey));
  }

  Future<void> updateProfile(UserProfile profile) async {
    final existing = await readUserAuth();
    if (existing == null) {
      await saveUserAuth(
        UserAuthData(
          mobile: profile.mobile,
          password: '',
          profile: profile,
        ),
      );
      return;
    }

    await saveUserAuth(
      UserAuthData(
        mobile: profile.mobile,
        password: existing.password,
        profile: profile,
      ),
    );
  }

  // Offline support caching
  Future<void> saveOfflineSchemes(String jsonStr) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_offlineSchemesKey, jsonStr);
  }

  Future<String?> getOfflineSchemes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_offlineSchemesKey);
  }

  /// Removes the offline schemes cache so the next fetch goes to the network.
  Future<void> clearOfflineSchemes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_offlineSchemesKey);
  }
}
