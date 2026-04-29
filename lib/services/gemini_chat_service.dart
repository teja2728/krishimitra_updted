import 'dart:convert';
import 'package:http/http.dart' as http;
import 'local_user_storage.dart';
import 'api_service.dart' show resolveApiBaseUrl, ApiException;

class GeminiChatMessage {
  final String role; // 'user' | 'ai'
  final String text;
  final DateTime timestamp;

  GeminiChatMessage({
    required this.role,
    required this.text,
    required this.timestamp,
  });
}

class GeminiChatService {
  GeminiChatService(this._storage);

  final LocalUserStorage _storage;
  final http.Client _client = http.Client();

  String get _base => resolveApiBaseUrl();

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.readJwtToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Send a message to the Gemini backend and return the AI reply.
  Future<String> sendMessage(String message, {String? context}) async {
    final res = await _client.post(
      Uri.parse('$_base/gemini/chat'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'message': message.trim(),
        if (context != null && context.isNotEmpty) 'context': context,
      }),
    );

    final body = jsonDecode(res.body) as Map<String, dynamic>;

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final reply = body['reply'] as String? ?? '';
      if (reply.isEmpty) throw ApiException('Empty reply from AI.');
      return reply;
    }

    final errMsg = body['error'] as String? ?? 'Request failed (${res.statusCode})';
    throw ApiException(errMsg, res.statusCode);
  }

  void dispose() => _client.close();
}
