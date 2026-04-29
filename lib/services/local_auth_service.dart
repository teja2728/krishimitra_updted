import '../models/auth_role.dart';
import '../models/user_profile.dart';
import 'api_service.dart';
import 'local_user_storage.dart';

class LocalAuthService {
  LocalAuthService(this._api, this._storage);

  final ApiService _api;
  final LocalUserStorage _storage;

  static const String adminMobile = 'admin';
  static const String adminPassword = 'admin123';

  UserAuthData _normalizeAuth(UserAuthData data) {
    final mobile = data.mobile.trim();
    final password = data.password.trim();
    final p = data.profile;
    final profile = UserProfile(
      id: p.id,
      mobile: mobile,
      name: p.name.trim(),
      state: p.state,
      language: p.language,
      crops: p.crops,
      soilType: p.soilType,
      landSize: p.landSize,
      role: p.role,
    );
    return UserAuthData(
      mobile: mobile,
      password: password,
      profile: profile,
    );
  }

  Future<void> registerUser(UserAuthData data) async {
    final normalized = _normalizeAuth(data);
    try {
      final res = await _api.register(normalized);
      await _storage.saveSession(token: res.token, userId: res.userId);
      final profile = userProfileFromApiUser(res.userJson);
      final role = authRoleFromApiUser(res.userJson);
      await _storage.saveUserAuth(
        UserAuthData(
          mobile: profile.mobile.trim(),
          password: normalized.password,
          profile: profile,
        ),
      );
      await _storage.saveRole(role);
    } catch (_) {
      throw const AuthException('Registration failed on server.');
    }
  }

  Future<UserProfile> loginUser({
    required String mobile,
    required String password,
  }) async {
    final mob = mobile.trim();
    final pwd = password.trim();
    try {
      final res = await _api.login(mobile: mob, password: pwd);
      
      // Fix logout bug: Ensure a clean session start
      await _storage.clearSession();
      
      await _storage.saveSession(token: res.token, userId: res.userId);
      final profile = userProfileFromApiUser(res.userJson);
      await _storage.saveUserAuth(
        UserAuthData(
          mobile: profile.mobile.trim(),
          password: pwd,
          profile: profile,
        ),
      );
      await _storage.saveRole(authRoleFromApiUser(res.userJson));
      return profile;
    } catch (e) {
      if (e is ApiException) {
        throw AuthException(e.message);
      }
      throw const AuthException('Invalid mobile number or password.');
    }
  }

  bool isAdminLogin({
    required String mobile,
    required String password,
  }) {
    return mobile == adminMobile && password == adminPassword;
  }

  Future<void> loginAdmin() async {
    await _storage.saveRole(AuthRole.admin);
  }

  Future<void> loginAdminWithCredentials({
    required String mobile,
    required String password,
  }) async {
    final mob = mobile.trim();
    final pwd = password.trim();
    try {
      final res = await _api.adminLogin(mobile: mob, password: pwd);
      
      // Fix logout bug
      await _storage.clearSession();
      
      await _storage.saveSession(token: res.token, userId: res.userId);
      final profile = userProfileFromApiUser(res.userJson);
      await _storage.saveUserAuth(
        UserAuthData(
          mobile: profile.mobile.trim(),
          password: pwd,
          profile: profile,
        ),
      );
      await _storage.saveRole(AuthRole.admin);
    } catch (e) {
      if (e is ApiException) {
        throw AuthException(e.message);
      }
      throw const AuthException('Invalid admin credentials.');
    }
  }

  Future<void> logout() async {
    await _storage.clearSession();
  }
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}
