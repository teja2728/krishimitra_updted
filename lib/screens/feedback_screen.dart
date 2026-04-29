import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app_theme.dart';
import '../app/providers/app_providers.dart';
import '../models/feedback.dart';

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen>
    with SingleTickerProviderStateMixin {
  final _formKey          = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  bool  _isSubmitting     = false;
  bool  _submitted        = false;

  late final AnimationController _checkCtrl;
  late final Animation<double>   _checkScale;

  @override
  void initState() {
    super.initState();
    _checkCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _checkScale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _checkCtrl, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _checkCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;
    setState(() => _isSubmitting = true);

    try {
      final user   = ref.read(userProfileProvider).valueOrNull;
      final mobile = user?.mobile.isNotEmpty == true ? user!.mobile : 'unknown';
      final service = ref.read(feedbackServiceProvider);
      final entry  = FeedbackEntry(
        mobile:    mobile,
        message:   _messageController.text.trim(),
        createdAt: DateTime.now(),
      );
      await service.addFeedback(entry);
      _messageController.clear();
      setState(() => _submitted = true);
      _checkCtrl.forward();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt    = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_submitted) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _checkScale,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.4),
                          blurRadius: 28,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: Colors.white, size: 44),
                  ),
                ),
                const SizedBox(height: 28),
                Text('Thank you!',
                    style: tt.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Text(
                  'Your feedback has been submitted.\nWe appreciate your input.',
                  textAlign: TextAlign.center,
                  style: tt.bodyMedium,
                ),
                const SizedBox(height: 32),
                OutlinedButton(
                  onPressed: () => setState(() {
                    _submitted = false;
                    _checkCtrl.reset();
                  }),
                  child: const Text('Send Another'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary.withOpacity(0.15),
                    const Color(0xFF00A3FF).withOpacity(0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppTheme.primary.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.feedback_rounded,
                        color: AppTheme.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Share your thoughts',
                            style: tt.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(
                          'Help us improve KrishiMitra for farmers.',
                          style: tt.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Your Message',
                      style: tt.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _messageController,
                    maxLines: 8,
                    style: tt.bodyMedium,
                    decoration: InputDecoration(
                      hintText:
                          'Tell us what you like, what could be improved, or report an issue...',
                      hintStyle: TextStyle(
                        color: isDark
                            ? Colors.white.withOpacity(0.25)
                            : Colors.black26,
                        fontSize: 13,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Message is required';
                      }
                      if (v.trim().length < 5) {
                        return 'Please enter at least 5 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 54,
                    child: _isSubmitting
                        ? Center(
                            child: CircularProgressIndicator(
                                color: AppTheme.primary, strokeWidth: 2.5))
                        : GestureDetector(
                            onTap: _submit,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primary.withOpacity(0.35),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.send_rounded,
                                      color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text('Submit Feedback',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      )),
                                ],
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
