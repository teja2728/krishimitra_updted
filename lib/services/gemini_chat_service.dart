import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'local_user_storage.dart';
import 'api_service.dart' show resolveApiBaseUrl, ApiException;

// ─── Message model ────────────────────────────────────────────────────────────

class GeminiChatMessage {
  final String role; // 'user' | 'ai'
  final String text;
  final DateTime timestamp;
  /// If this message came from voice input, stores the transcribed text
  final String? voiceTranscript;
  /// Language the AI responded in (from backend)
  final String? detectedLanguage;

  GeminiChatMessage({
    required this.role,
    required this.text,
    DateTime? ts,
    this.voiceTranscript,
    this.detectedLanguage,
  }) : timestamp = ts ?? DateTime.now();
}

// ─── Response models ──────────────────────────────────────────────────────────

class ChatResponse {
  final String reply;
  final String detectedLanguage;
  const ChatResponse({required this.reply, required this.detectedLanguage});
}

class VoiceResponse {
  final String reply;
  final String inputText;
  final String detectedLanguage;
  const VoiceResponse({
    required this.reply,
    required this.inputText,
    required this.detectedLanguage,
  });
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

  // ── Voice message ─────────────────────────────────────────────────────────
  /// Uploads [audioFile] to the backend voice endpoint.
  /// CAMB.AI performs STT + language detection on the server.
  /// Returns AI reply in the auto-detected language.
  Future<VoiceResponse> sendVoice(File audioFile, {String? languageHint}) async {
    final token = await _bearerToken();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_base/gemini/voice'),
    );

    if (token != null) request.headers['Authorization'] = 'Bearer $token';

    // Determine MIME type from extension
    final ext  = audioFile.path.split('.').last.toLowerCase();
    final mime = _mimeFromExt(ext);

    request.files.add(await http.MultipartFile.fromPath(
      'audio',
      audioFile.path,
      contentType: MediaType.parse(mime),
    ));

    // Optional: send app language as a hint (backend may override with detected lang)
    if (languageHint != null && languageHint.isNotEmpty) {
      request.fields['language'] = languageHint;
    }

    final streamed = await _client.send(request);
    final res      = await http.Response.fromStream(streamed);
    final body     = jsonDecode(res.body) as Map<String, dynamic>;

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return VoiceResponse(
        reply:            body['reply']            as String? ?? '',
        inputText:        body['inputText']        as String? ?? '',
        detectedLanguage: body['detectedLanguage'] as String? ?? 'English',
      );
    }

    final errMsg = body['error'] as String? ?? 'Voice request failed (${res.statusCode})';
    throw ApiException(errMsg, res.statusCode);
  }

  static String _mimeFromExt(String ext) {
    switch (ext) {
      case 'mp3':  return 'audio/mpeg';
      case 'm4a':  return 'audio/m4a';
      case 'ogg':  return 'audio/ogg';
      case 'webm': return 'audio/webm';
      case 'aac':  return 'audio/aac';
      default:     return 'audio/wav';
    }
  }

  void dispose() => _client.close();
}
