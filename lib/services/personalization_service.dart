import 'dart:convert';
import 'package:http/http.dart' as http;
import 'local_user_storage.dart';
import 'api_service.dart' show resolveApiBaseUrl, ApiException;

/// Holds Groq personalization result for a single scheme
class PersonalizationResult {
  final int    relevanceScore; // 0–100
  final String whyRelevant;
  final String highlight;
  final List<String> steps;

  const PersonalizationResult({
    required this.relevanceScore,
    required this.whyRelevant,
    required this.highlight,
    required this.steps,
  });

  factory PersonalizationResult.empty() => const PersonalizationResult(
        relevanceScore: 0,
        whyRelevant: '',
        highlight: '',
        steps: [],
      );

  factory PersonalizationResult.fromJson(Map<String, dynamic> j) =>
      PersonalizationResult(
        relevanceScore: (j['relevanceScore'] as num?)?.toInt() ?? 0,
        whyRelevant:    (j['whyRelevant']    as String?) ?? '',
        highlight:      (j['highlight']      as String?) ?? '',
        steps: (j['steps'] as List<dynamic>? ?? [])
            .map((s) => s.toString())
            .toList(),
      );
}

class PersonalizationService {
  PersonalizationService(this._storage);

  final LocalUserStorage _storage;
  final http.Client _client = http.Client();
  String get _base => resolveApiBaseUrl();

  // Simple in-memory cache: schemeId → result
  final _cache = <String, PersonalizationResult>{};

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.readJwtToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Fetch personalization for a scheme. Uses in-memory cache.
  Future<PersonalizationResult> personalize({
    required String schemeId,
    required String schemeName,
    required String description,
    required List<String> benefits,
    required List<String> eligibility,
    required String deadline,
    required String userState,
    required List<String> userCrops,
    required String userSoilType,
    required int userLandSize,
  }) async {
    if (_cache.containsKey(schemeId)) return _cache[schemeId]!;

    try {
      final res = await _client.post(
        Uri.parse('$_base/personalize'),
        headers: await _authHeaders(),
        body: jsonEncode({
          'schemeId':    schemeId,
          'schemeName':  schemeName,
          'description': description,
          'benefits':    benefits,
          'eligibility': eligibility,
          'deadline':    deadline,
          'userState':   userState,
          'userCrops':   userCrops,
          'userSoilType':userSoilType,
          'userLandSize':userLandSize,
        }),
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final result = PersonalizationResult.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>,
        );
        _cache[schemeId] = result;
        return result;
      }
    } catch (_) {}

    return PersonalizationResult.empty();
  }

  /// Translate any text via the backend Groq translate endpoint.
  Future<String> translate(String text, String targetLanguage) async {
    if (targetLanguage == 'English' || text.trim().isEmpty) return text;
    try {
      final res = await _client.post(
        Uri.parse('$_base/translate'),
        headers: await _authHeaders(),
        body: jsonEncode({'text': text, 'targetLanguage': targetLanguage}),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return (body['translatedText'] as String?) ?? text;
      }
    } catch (_) {}
    return text; // graceful fallback
  }

  void dispose() => _client.close();
}
