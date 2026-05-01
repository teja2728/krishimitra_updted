import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../app/app_theme.dart';
import '../app/providers/app_providers.dart';
import '../app/providers/language_provider.dart';
import '../services/gemini_chat_service.dart';

// ─── Message model ────────────────────────────────────────────────────────────

enum _Role { user, ai }

class _Message {
  _Message({required this.role, required this.text, DateTime? ts, this.langTag})
      : timestamp = ts ?? DateTime.now();

  final _Role    role;
  final String   text;
  final DateTime timestamp;
  /// Optional tag shown below voice transcripts, e.g. '🎤 Telugu'
  final String?  langTag;
}

// ─── Quick-prompt chips shown when chat is empty ──────────────────────────────

const _quickPrompts = [
  '🌾 Best crops for black soil?',
  '💧 Tips for drip irrigation',
  '🌿 How to improve soil fertility?',
  '🏛️ PM-Kisan scheme eligibility',
  '🌦️ Crop insurance options',
  '🐛 Organic pest control methods',
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class GeminiChatScreen extends ConsumerStatefulWidget {
  const GeminiChatScreen({super.key});

  @override
  ConsumerState<GeminiChatScreen> createState() => _GeminiChatScreenState();
}

class _GeminiChatScreenState extends ConsumerState<GeminiChatScreen>
    with TickerProviderStateMixin {
  final _messages   = <_Message>[];
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode  = FocusNode();

  late GeminiChatService _service;
  bool   _loading        = false;
  bool   _isRecording    = false;
  bool   _voiceProcessing = false;
  String _errorText      = '';
  final _recorder = AudioRecorder();

  // Typing-dots animation
  late final AnimationController _dotAnim;

  @override
  void initState() {
    super.initState();
    _dotAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final storage = ref.read(localUserStorageProvider);
    _service = GeminiChatService(storage);
  }

  @override
  void dispose() {
    _dotAnim.dispose();
    _controller.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    _service.dispose();
    _recorder.dispose();
    super.dispose();
  }

  // ── Voice recording ───────────────────────────────────────────────────────
  Future<void> _toggleRecording() async {
    if (_loading || _voiceProcessing) return;

    if (_isRecording) {
      await _stopAndSendVoice();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      setState(() => _errorText = 'Microphone permission denied.');
      return;
    }
    final dir  = await getTemporaryDirectory();
    final path = '${dir.path}/krishi_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 16000),
      path: path,
    );
    if (!mounted) return;
    setState(() {
      _isRecording   = true;
      _errorText     = '';
    });
  }

  Future<void> _stopAndSendVoice() async {
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() => _isRecording = false);

    if (path == null || path.isEmpty) {
      setState(() => _errorText = 'Recording failed — no audio captured.');
      return;
    }

    final file = File(path);
    if (!file.existsSync() || file.lengthSync() < 1000) {
      setState(() => _errorText = 'Recording too short. Please try again.');
      return;
    }

    setState(() {
      _voiceProcessing = true;
      _loading         = true;
      _errorText       = '';
    });

    try {
      // Read current app language to send as hint
      final lang = ref.read(languageProvider).value ?? 'English';
      final result = await _service.sendVoice(file, languageHint: lang);

      if (!mounted) return;
      setState(() {
        // Show transcribed text as user bubble
        if (result.inputText.isNotEmpty) {
          _messages.add(_Message(
            role: _Role.user,
            text: result.inputText,
            langTag: '🎤 ${result.detectedLanguage}',
          ));
        }
        _messages.add(_Message(role: _Role.ai, text: result.reply));
        _voiceProcessing = false;
        _loading         = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _voiceProcessing = false;
        _loading         = false;
        _errorText       = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      // Clean up temp file
      try { File(path).deleteSync(); } catch (_) {}
    }
  }

  // ── Scroll to bottom ─────────────────────────────────────────────────────
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Send message ─────────────────────────────────────────────────────────
  Future<void> _send(String text) async {
    text = text.trim();
    if (text.isEmpty || _loading) return;

    _controller.clear();
    final lang = ref.read(languageProvider).value ?? 'English';
    setState(() {
      _messages.add(_Message(role: _Role.user, text: text));
      _loading   = true;
      _errorText = '';
    });
    _scrollToBottom();

    try {
      final result = await _service.sendMessage(text, language: lang);
      if (!mounted) return;
      setState(() {
        _messages.add(_Message(role: _Role.ai, text: result.reply));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading   = false;
        _errorText = e.toString();
      });
    }
    _scrollToBottom();
  }

  // ── Clear chat ───────────────────────────────────────────────────────────
  void _clearChat() {
    setState(() {
      _messages.clear();
      _errorText = '';
    });
  }

  // ── Copy to clipboard ────────────────────────────────────────────────────
  void _copyText(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.background : AppTheme.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isDark),
            Expanded(child: _buildMessageList(isDark)),
            if (_errorText.isNotEmpty) _buildErrorBanner(),
            _buildInputBar(isDark),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withOpacity(isDark ? 0.18 : 0.10),
            const Color(0xFF00A3FF).withOpacity(isDark ? 0.10 : 0.06),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.07)
                : Colors.black.withOpacity(0.06),
          ),
        ),
      ),
      child: Row(
        children: [
          // AI avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KrishiMitra AI',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.only(right: 5),
                      decoration: const BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text(
                      'Powered by Gemini AI',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_messages.isNotEmpty)
            IconButton(
              tooltip: 'Clear chat',
              icon: const Icon(Icons.delete_sweep_rounded,
                  size: 20, color: Colors.redAccent),
              style: IconButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _clearChat,
            ),
        ],
      ),
    );
  }

  // ── Message list ──────────────────────────────────────────────────────────
  Widget _buildMessageList(bool isDark) {
    if (_messages.isEmpty) return _buildEmptyState(isDark);

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      itemCount: _messages.length + (_loading ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i == _messages.length) return _buildTypingIndicator(isDark);
        return _buildBubble(_messages[i], isDark);
      },
    );
  }

  // ── Empty / welcome state ─────────────────────────────────────────────────
  Widget _buildEmptyState(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Glow icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.40),
                  blurRadius: 28,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: Colors.white, size: 34),
          ),
          const SizedBox(height: 16),
          Text(
            'Ask KrishiMitra AI',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Get instant farming advice, scheme info,\ncrop tips & more — powered by Gemini.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 28),
          // Quick prompt chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _quickPrompts
                .map((p) => _QuickChip(
                      label: p,
                      onTap: () => _send(p),
                      isDark: isDark,
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  // ── Single chat bubble ────────────────────────────────────────────────────
  Widget _buildBubble(_Message msg, bool isDark) {
    final isUser = msg.role == _Role.user;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) _aiAvatar(),
          if (!isUser) const SizedBox(width: 8),
          Flexible(
            child: GestureDetector(
              onLongPress: () => _copyText(msg.text),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.76,
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  gradient: isUser ? AppTheme.primaryGradient : null,
                  color: isUser
                      ? null
                      : (isDark
                          ? const Color(0xFF1E2535)
                          : Colors.white),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isUser ? 18 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 18),
                  ),
                  border: isUser
                      ? null
                      : Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.07)
                              : Colors.black.withOpacity(0.07),
                        ),
                  boxShadow: [
                    BoxShadow(
                      color: isUser
                          ? AppTheme.primary.withOpacity(0.25)
                          : Colors.black.withOpacity(isDark ? 0.25 : 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      msg.text,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isUser ? Colors.white : null,
                            height: 1.45,
                            fontSize: 13.5,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(msg.timestamp),
                          style: TextStyle(
                            fontSize: 10,
                            color: isUser
                                ? Colors.white.withOpacity(0.55)
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant
                                    .withOpacity(0.6),
                          ),
                        ),
                        if (msg.langTag != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            msg.langTag!,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white.withOpacity(0.70),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
          if (isUser) _userAvatar(),
        ],
      ),
    );
  }

  Widget _aiAvatar() => Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          shape: BoxShape.circle,
        ),
        child:
            const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 15),
      );

  Widget _userAvatar() => Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppTheme.accent.withOpacity(0.85),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.person_rounded, color: Colors.white, size: 17),
      );

  // ── Typing indicator ──────────────────────────────────────────────────────
  Widget _buildTypingIndicator(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          _aiAvatar(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2535) : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.07)
                    : Colors.black.withOpacity(0.07),
              ),
            ),
            child: AnimatedBuilder(
              animation: _dotAnim,
              builder: (_, __) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final phase = ((_dotAnim.value * 3) - i).clamp(0.0, 1.0);
                    final opacity = (math.sin(phase * math.pi)).clamp(0.3, 1.0);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(opacity),
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Error banner ──────────────────────────────────────────────────────────
  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withOpacity(0.30)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 18, color: Colors.redAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorText,
              style: const TextStyle(
                  color: Colors.redAccent, fontSize: 12.5),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _errorText = ''),
            child: const Icon(Icons.close_rounded,
                size: 16, color: Colors.redAccent),
          ),
        ],
      ),
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────────────
  Widget _buildInputBar(bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141928) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.06),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: _isRecording
                // ── Listening indicator replaces text field ──────────────
                ? _ListeningIndicator(isDark: isDark)
                : _voiceProcessing
                    // ── Processing indicator ─────────────────────────────
                    ? _ProcessingIndicator(isDark: isDark)
                    // ── Normal text field ────────────────────────────────
                    : Container(
                        constraints: const BoxConstraints(maxHeight: 130),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E2535)
                              : const Color(0xFFF3F6F4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.10)
                                : Colors.black.withOpacity(0.08),
                          ),
                        ),
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          minLines: 1,
                          maxLines: 5,
                          textCapitalization: TextCapitalization.sentences,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Ask about crops, schemes, soil…',
                            hintStyle: TextStyle(
                              color: isDark
                                  ? Colors.white.withOpacity(0.30)
                                  : Colors.black38,
                              fontSize: 13.5,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                          ),
                          onSubmitted: _loading ? null : _send,
                        ),
                      ),
          ),
          const SizedBox(width: 8),
          // Mic button
          _MicButton(
            isRecording:    _isRecording,
            isProcessing:   _voiceProcessing,
            isDark:         isDark,
            onTap:          _toggleRecording,
          ),
          const SizedBox(width: 6),
          // Send button
          GestureDetector(
            onTap: (_loading || _isRecording) ? null : () => _send(_controller.text),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: (_loading || _isRecording) ? null : AppTheme.primaryGradient,
                color: (_loading || _isRecording)
                    ? (isDark
                        ? Colors.white.withOpacity(0.07)
                        : Colors.black.withOpacity(0.05))
                    : null,
                borderRadius: BorderRadius.circular(14),
                boxShadow: (_loading || _isRecording)
                    ? null
                    : [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.40),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: _loading
                  ? Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppTheme.primary),
                      ),
                    )
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ─── Quick prompt chip ────────────────────────────────────────────────────────

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.onTap,
    required this.isDark,
  });

  final String       label;
  final VoidCallback onTap;
  final bool         isDark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isDark
              ? AppTheme.primary.withOpacity(0.10)
              : AppTheme.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppTheme.primary.withOpacity(0.30),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
        ),
      ),
    );
  }
}

// ─── Mic Button ───────────────────────────────────────────────────────────────

class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.isRecording,
    required this.isProcessing,
    required this.isDark,
    required this.onTap,
  });

  final bool         isRecording;
  final bool         isProcessing;
  final bool         isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color bg = isRecording
        ? Colors.redAccent
        : isDark
            ? Colors.white.withOpacity(0.10)
            : Colors.black.withOpacity(0.06);

    final Widget icon = isProcessing
        ? const SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
        : Icon(
            isRecording ? Icons.stop_rounded : Icons.mic_rounded,
            color: isRecording
                ? Colors.white
                : (isDark ? Colors.white70 : Colors.black54),
            size: 22,
          );

    return GestureDetector(
      onTap: isProcessing ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isRecording
              ? [BoxShadow(
                  color: Colors.redAccent.withOpacity(0.45),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )]
              : null,
        ),
        child: Center(child: icon),
      ),
    );
  }
}

// ─── Listening indicator ──────────────────────────────────────────────────────

class _ListeningIndicator extends StatefulWidget {
  const _ListeningIndicator({required this.isDark});
  final bool isDark;
  @override
  State<_ListeningIndicator> createState() => _ListeningIndicatorState();
}

class _ListeningIndicatorState extends State<_ListeningIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
  }
  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(widget.isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.4 + 0.6 * _pulse.value),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Listening… Tap ■ to stop',
            style: TextStyle(
              color: Colors.redAccent,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Processing indicator ─────────────────────────────────────────────────────

class _ProcessingIndicator extends StatelessWidget {
  const _ProcessingIndicator({required this.isDark});
  final bool isDark;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Processing voice…',
            style: TextStyle(
              color: AppTheme.primary,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
