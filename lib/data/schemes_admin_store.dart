import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/scheme.dart';

class SchemesAdminStore {
  static const String _key = 'krishi_mitra_admin_schemes';

  Future<bool> hasStoredSchemes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_key);
  }

  Future<List<Scheme>> readStoredSchemes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];

    return decoded
        .whereType<Map<String, dynamic>>()
        .map((e) => Scheme.fromJson(e))
        .toList(growable: false);
  }

  Future<void> writeStoredSchemes(List<Scheme> schemes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(schemes.map((e) => e.toJson()).toList(growable: false)),
    );
  }

  /// Clears the locally cached admin schemes.
  ///
  /// Call this whenever the user's state changes so the next
  /// [SchemesRepository.fetchSchemesWithAdminOverrides] call will bypass
  /// the stale cache and fetch fresh state-specific data from the backend.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}


