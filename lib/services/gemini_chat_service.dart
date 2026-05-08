import 'dart:convert';
import 'package:http/http.dart' as http;
import 'local_user_storage.dart';
import 'api_service.dart' show resolveApiBaseUrl, ApiException;

// ─── Message model ────────────────────────────────────────────────────────────

class GeminiChatMessage {
  final String role; // 'user' | 'ai'
  final String text;
  final DateTime timestamp;

  GeminiChatMessage({
    required this.role,
    required this.text,
    DateTime? ts,
  }) : timestamp = ts ?? DateTime.now();
}

// ─── Response models ──────────────────────────────────────────────────────────

class ChatResponse {
  final String reply;
  final String detectedLanguage;
  const ChatResponse({required this.reply, required this.detectedLanguage});
}

// ─── Service ──────────────────────────────────────────────────────────────────

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

  Future<String?> _bearerToken() async {
    final token = await _storage.readJwtToken();
    return (token != null && token.isNotEmpty) ? token : null;
  }

  // ── Text message ──────────────────────────────────────────────────────────
  /// Sends [message] to the backend with an optional [language] hint
  /// (the app's currently selected language, e.g. "Telugu").
  /// The backend will respond in that language.
  Future<ChatResponse> sendMessage(String message, {String? language, String? context}) async {
    final res = await _client.post(
      Uri.parse('$_base/gemini/chat'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'message': message.trim(),
        if (language != null && language.isNotEmpty) 'language': language,
        if (context  != null && context.isNotEmpty)  'context':  context,
      }),
    );

    final body = jsonDecode(res.body) as Map<String, dynamic>;

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final reply = body['reply'] as String? ?? '';
      if (reply.isEmpty) throw ApiException('Empty reply from AI.');
      return ChatResponse(
        reply: reply,
        detectedLanguage: body['detectedLanguage'] as String? ?? (language ?? 'English'),
      );
    }

    final errMsg = body['error'] as String? ?? 'Request failed (${res.statusCode})';
    throw ApiException(errMsg, res.statusCode);
  }

  void dispose() => _client.close();
}