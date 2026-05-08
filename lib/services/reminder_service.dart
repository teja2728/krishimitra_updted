import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'local_user_storage.dart';

class ReminderService {
  ReminderService({
    ApiService? api,
    LocalUserStorage? storage,
  })  : _api = api,
        _storage = storage;

  static const String _key = 'krishi_mitra_reminders';

  final ApiService? _api;
  final LocalUserStorage? _storage;

  /// Loads reminder scheme IDs.
  ///
  /// Prefers the backend as source of truth. Falls back to the local
  /// SharedPreferences cache when offline or when no session exists.
  Future<Set<String>> loadReminderIds() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? const <String>[];
    final local = list.toSet();

    try {
      final api = _api;
      final storage = _storage;
      if (api != null && storage != null) {
        final token = await storage.readJwtToken();
        final userId = await storage.readBackendUserId();
        if (token != null && userId != null) {
          final remote = await api.fetchReminderSchemeIds(userId);
          await saveReminderIds(remote);
          return remote;
        }
      }
    } catch (_) {}

    return local;
  }

  Future<void> saveReminderIds(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, ids.toList());
  }
}
