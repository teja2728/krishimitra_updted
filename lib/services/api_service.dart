import 'dart:convert';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:http/http.dart' as http;

import '../models/auth_role.dart';
import '../models/scheme.dart';
import '../models/user_profile.dart';
import 'local_user_storage.dart';

String resolveApiBaseUrl() {
  if (kIsWeb) return 'http://localhost:5000/api';
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:5000/api';
  }
  return 'http://localhost:5000/api';
}

class ApiException implements Exception {
  ApiException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AuthResponse {
  const AuthResponse({
    required this.token,
    required this.userId,
    required this.userJson,
  });

  final String token;
  final String userId;
  final Map<String, dynamic> userJson;
}

class ApiService {
  ApiService(
    this._storage, {
    String? baseUrl,
    http.Client? httpClient,
  })  : _base = baseUrl ?? resolveApiBaseUrl(),
        _client = httpClient ?? http.Client();

  final LocalUserStorage _storage;
  final String _base;
  final http.Client _client;

  Uri _uri(String path) => Uri.parse('$_base$path');

  Future<Map<String, String>> _headers({bool auth = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (auth) {
      final token = await _storage.readJwtToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  void _throwIfError(http.Response r) {
    if (r.statusCode >= 200 && r.statusCode < 300) return;
    String msg = 'Request failed (${r.statusCode})';
    try {
      final body = jsonDecode(r.body);
      if (body is Map && body['message'] != null) {
        msg = body['message'].toString();
      }
    } catch (_) {
      if (r.body.isNotEmpty) msg = r.body;
    }
    throw ApiException(msg, r.statusCode);
  }

  Future<AuthResponse> register(UserAuthData data) async {
    final profile = data.profile;
    final res = await _client.post(
      _uri('/auth/register'),
      headers: await _headers(),
      body: jsonEncode({
        'name': profile.name,
        'mobile': profile.mobile,
        'password': data.password,
        'state': profile.state,
        'language': profile.language,
        'crops': profile.crops,
        'soilType': profile.soilType,
        'landSize': profile.landSize,
      }),
    );
    _throwIfError(res);
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final token = map['token'] as String? ?? '';
    final user = map['user'] as Map<String, dynamic>? ?? {};
    final userId = user['id']?.toString() ?? '';
    if (token.isEmpty || userId.isEmpty) {
      throw ApiException('Invalid register response');
    }
    return AuthResponse(token: token, userId: userId, userJson: user);
  }

  Future<AuthResponse> login({
    required String mobile,
    required String password,
  }) async {
    final res = await _client.post(
      _uri('/auth/login'),
      headers: await _headers(),
      body: jsonEncode({
        'mobile': mobile,
        'password': password,
      }),
    );
    _throwIfError(res);
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final token = map['token'] as String? ?? '';
    final user = map['user'] as Map<String, dynamic>? ?? {};
    final userId = user['id']?.toString() ?? '';
    if (token.isEmpty || userId.isEmpty) {
      throw ApiException('Invalid login response');
    }
    return AuthResponse(token: token, userId: userId, userJson: user);
  }

  Future<AuthResponse> adminLogin({
    required String mobile,
    required String password,
  }) async {
    final res = await _client.post(
      _uri('/auth/admin-login'),
      headers: await _headers(),
      body: jsonEncode({
        'mobile': mobile,
        'password': password,
      }),
    );
    _throwIfError(res);
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final token = map['token'] as String? ?? '';
    final user = map['user'] as Map<String, dynamic>? ?? {};
    final userId = user['id']?.toString() ?? '';
    if (token.isEmpty || userId.isEmpty) {
      throw ApiException('Invalid admin login response');
    }
    return AuthResponse(token: token, userId: userId, userJson: user);
  }

  // Fetch schemes using the /smart endpoint with optional language translation
  Future<List<Scheme>> fetchSchemes({String lang = 'en'}) async {
    // Map full language name → 2-letter code the backend expects
    final langCode = _langCode(lang);
    try {
      final uri = Uri.parse('$_base/schemes/smart')
          .replace(queryParameters: langCode != 'en' ? {'lang': langCode} : null);
      final res = await _client.get(
        uri,
        headers: await _headers(auth: true),
      );
      _throwIfError(res);
      var decoded = jsonDecode(res.body);

      // Handle fallback response format { message: '...', data: [...] }
      if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
        decoded = decoded['data'];
      }

      // Save for offline (always store English baseline for cache purposes)
      if (langCode == 'en') {
        await _storage.saveOfflineSchemes(jsonEncode(decoded));
      }

      if (decoded is! List) {
        throw ApiException('Invalid schemes payload');
      }
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(Scheme.fromJson)
          .toList(growable: false);
    } catch (e) {
      // Offline fallback
      final offlineData = await _storage.getOfflineSchemes();
      if (offlineData != null) {
        final decoded = jsonDecode(offlineData);
        if (decoded is List) {
          return decoded
              .whereType<Map<String, dynamic>>()
              .map(Scheme.fromJson)
              .toList(growable: false);
        }
      }
      rethrow;
    }
  }

  /// Maps full language name to a 2-letter backend code.
  static String _langCode(String lang) {
    switch (lang.toLowerCase()) {
      case 'telugu':  return 'te';
      case 'hindi':   return 'hi';
      case 'kannada': return 'kn';
      default:        return 'en';
    }
  }

  Future<void> bookmarkScheme(String schemeId) async {
    final res = await _client.post(
      _uri('/bookmark'),
      headers: await _headers(auth: true),
      body: jsonEncode({'schemeId': schemeId}),
    );
    _throwIfError(res);
  }

  Future<Set<String>> fetchBookmarkSchemeIds(String userId) async {
    final res = await _client.get(
      _uri('/bookmark/$userId'),
      headers: await _headers(auth: true),
    );
    _throwIfError(res);
    final list = jsonDecode(res.body) as List? ?? const [];
    // The new response returns array of UserScheme docs. Extract schemeId.id or just schemeId
    return list.map((e) {
      if (e is Map) {
        final scheme = e['schemeId'];
        if (scheme is Map) return scheme['id']?.toString() ?? '';
        return scheme?.toString() ?? '';
      }
      return e.toString();
    }).toSet();
  }

  Future<void> sendFeedback(String message) async {
    final res = await _client.post(
      _uri('/feedback'),
      headers: await _headers(auth: true),
      body: jsonEncode({'message': message}),
    );
    _throwIfError(res);
  }

  Future<List<Map<String, dynamic>>> fetchFeedbackList() async {
    final res = await _client.get(
      _uri('/feedback'),
      headers: await _headers(auth: true),
    );
    _throwIfError(res);
    final decoded = jsonDecode(res.body);
    if (decoded is! List) {
      throw ApiException('Invalid feedback payload');
    }
    return decoded.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  Future<UserProfile> updateProfile(UserProfile profile) async {
    final res = await _client.put(
      _uri('/auth/profile'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'name': profile.name,
        'state': profile.state,
        'language': profile.language,
        'crops': profile.crops,
        'soilType': profile.soilType,
        'landSize': profile.landSize,
      }),
    );
    _throwIfError(res);
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final userJson = map['user'] as Map<String, dynamic>? ?? {};
    return userProfileFromApiUser(userJson);
  }

  void close() => _client.close();
}

UserProfile userProfileFromApiUser(Map<String, dynamic> u) {
  return UserProfile(
    id: (u['id'] ?? '').toString(),
    mobile: (u['mobile'] ?? '').toString(),
    name: (u['name'] ?? '').toString(),
    state: (u['state'] ?? '').toString(),
    language: (u['language'] ?? '').toString(),
    crops: (u['crops'] as List? ?? const [])
        .map((e) => e.toString())
        .toList(),
    soilType: (u['soilType'] ?? '').toString(),
    landSize: int.tryParse((u['landSize'] ?? 0).toString()) ?? 0,
    role: (u['role'] ?? 'user').toString(),
  );
}

AuthRole authRoleFromApiUser(Map<String, dynamic> u) {
  final r = (u['role'] ?? 'user').toString().toLowerCase();
  return r == 'admin' ? AuthRole.admin : AuthRole.user;
}
