import '../models/scheme.dart';
import '../services/api_service.dart';
import 'schemes_local_data_source.dart';
import 'schemes_admin_store.dart';

/// Loads schemes from the backend ([ApiService.fetchSchemes]) instead of JSON,
/// with [SchemesLocalDataSource] as fallback when the request fails or returns
/// an empty list (e.g. DB not seeded yet).
class SchemesRepository {
  SchemesRepository(
    this._localSource, {
    required SchemesAdminStore adminStore,
    required ApiService apiService,
  })  : _adminStore = adminStore,
        _api = apiService;

  final SchemesLocalDataSource _localSource;
  final SchemesAdminStore _adminStore;
  final ApiService _api;

  Future<List<Scheme>> fetchSchemes() async {
    try {
      final remote = await _api.fetchSchemes();
      if (remote.isEmpty) {
        return _localSource.loadSchemes();
      }
      return remote;
    } catch (_) {
      return _localSource.loadSchemes();
    }
  }

  List<Scheme> filterByType(List<Scheme> schemes, SchemeType type) {
    return schemes.where((s) => s.type == type).toList(growable: false);
  }

  Future<List<Scheme>> fetchSchemesWithAdminOverrides() async {
    final hasStored = await _adminStore.hasStoredSchemes();
    if (hasStored) return _adminStore.readStoredSchemes();
    return fetchSchemes();
  }

  Future<void> saveAllSchemes(List<Scheme> schemes) {
    return _adminStore.writeStoredSchemes(schemes);
  }
}

