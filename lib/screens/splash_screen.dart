import 'dart:developer' as dev;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/app_theme.dart';
import '../app/providers/app_providers.dart';
import '../models/auth_role.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {

  // Continuous loop for swaying crops + particles
  late final AnimationController _loopCtrl;

  // One-shot entrance sequence
  late final AnimationController _entranceCtrl;

  late final Animation<double>  _iconScale;
  late final Animation<double>  _iconFade;
  late final Animation<double>  _titleFade;
  late final Animation<Offset>  _titleSlide;
  late final Animation<double>  _subtitleFade;
  late final Animation<Offset>  _subtitleSlide;
  late final Animation<double>  _cropReveal;

  @override
  void initState() {
    super.initState();

    _loopCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..forward();

    // Icon: spring pop-in
    _iconScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.15)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.15, end: 0.95)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.95, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
    ]).animate(CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.0, 0.55),
    ));

    _iconFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.30, curve: Curves.easeOut),
      ),
    );

    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.35, 0.65, curve: Curves.easeOut),
      ),
    );

    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.35, 0.70, curve: Curves.easeOutCubic),
    ));

    _subtitleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.55, 0.85, curve: Curves.easeOut),
      ),
    );

    _subtitleSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.55, 0.90, curve: Curves.easeOutCubic),
    ));

    _cropReveal = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.60, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // Run session check after a minimum 1.8s for splash visibility,
    // then navigate based on stored session.
    Future.wait([
      Future.delayed(const Duration(milliseconds: 1800)),
      _checkSession(),
    ]);
  }

  /// Reads persisted token + role and routes to the correct screen.
  /// Never throws — any error defaults to login.
  Future<void> _checkSession() async {
    try {
      final storage = ref.read(localUserStorageProvider);

      final token = await storage.readJwtToken();
      final role  = await storage.readRole();

      dev.log('[Splash] Token present: ${token != null && token.isNotEmpty}');
      dev.log('[Splash] Role stored: $role');

      if (!mounted) return;

      if (token != null && token.isNotEmpty) {
        // Valid session found — navigate directly to the correct home
        if (role == AuthRole.admin) {
          dev.log('[Splash] Resuming admin session → /admin/schemes');
          context.go('/admin/schemes');
        } else {
          dev.log('[Splash] Resuming user session → /home/state');
          context.go('/home/state');
        }
      } else {
        // No session — go to login
        dev.log('[Splash] No session found → /login');
        context.go('/login');
      }
    } catch (e) {
      dev.log('[Splash] Session check error: $e — defaulting to login');
      if (mounted) context.go('/login');
    }
  }

  @override
  void dispose() {
    _loopCtrl.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Icon + Text ───────────────────────────────────────────
            Expanded(
              flex: 5,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon with breathing glow
                    AnimatedBuilder(
                      animation: Listenable.merge([_loopCtrl, _entranceCtrl]),
                      builder: (_, __) {
                        final breathe =
                            0.92 + 0.08 * sin(_loopCtrl.value * 2 * pi);
                        final glowAlpha =
                            (0.15 + 0.12 * sin(_loopCtrl.value * 2 * pi))
                                .clamp(0.0, 1.0);
                        return FadeTransition(
                          opacity: _iconFade,
                          child: ScaleTransition(
                            scale: _iconScale,
                            child: Transform.scale(
                              scale: breathe,
                              child: Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E9),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primary
                                          .withValues(alpha: glowAlpha),
                                      blurRadius: 36,
                                      spreadRadius: 10,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.agriculture_rounded,
                                  size: 58,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 28),

                    // App name
                    FadeTransition(
                      opacity: _titleFade,
                      child: SlideTransition(
                        position: _titleSlide,
                        child: Text(
                          'KrishiMitra',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1B5E20),
                                letterSpacing: 0.5,
                              ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Tagline
                    FadeTransition(
                      opacity: _subtitleFade,
                      child: SlideTransition(
                        position: _subtitleSlide,
                        child: Text(
                          'Agriculture assistance for farmers',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xFF66BB6A),
                                    letterSpacing: 0.3,
                                  ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),

                    const SizedBox(height: 36),

                    // Subtle loading indicator — visible during session check
                    FadeTransition(
                      opacity: _subtitleFade,
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.primary.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Crop Field ────────────────────────────────────────────
            AnimatedBuilder(
              animation: Listenable.merge([_loopCtrl, _entranceCtrl]),
              builder: (_, __) => SizedBox(
                height: 170,
                width: double.infinity,
                child: CustomPaint(
                  painter: _CropFieldPainter(
                    loopValue: _loopCtrl.value,
                    revealFraction: _cropReveal.value,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Crop Field Painter — unchanged from original
// ─────────────────────────────────────────────────────────────────────────────
class _CropFieldPainter extends CustomPainter {
  final double loopValue;
  final double revealFraction;

  _CropFieldPainter({
    required this.loopValue,
    required this.revealFraction,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = loopValue * 2 * pi;
    final w = size.width;
    final h = size.height;

    // ── Back hill ────────────────────────────────────────────────────
    final backPath = Path();
    backPath.moveTo(0, h);
    for (double x = 0; x <= w; x += 2) {
      final y = h * 0.52
          - 18 * sin(x / w * pi + t * 0.25)
          - 8 * sin(x / w * 2 * pi + 0.6);
      x == 0 ? backPath.moveTo(x, y) : backPath.lineTo(x, y);
    }
    backPath.lineTo(w, h);
    backPath.close();
    canvas.drawPath(
      backPath,
      Paint()
        ..color = const Color(0xFFDCEDC8).withValues(alpha: revealFraction),
    );

    // ── Front hill ───────────────────────────────────────────────────
    final frontPath = Path();
    for (double x = 0; x <= w; x += 2) {
      final y = h * 0.68
          - 16 * sin(x / w * pi * 1.4 + t * 0.35 + 1.1)
          - 7 * sin(x / w * 3 * pi + 0.2);
      x == 0 ? frontPath.moveTo(x, y) : frontPath.lineTo(x, y);
    }
    frontPath.lineTo(w, h);
    frontPath.lineTo(0, h);
    frontPath.close();
    canvas.drawPath(
      frontPath,
      Paint()
        ..color = const Color(0xFFC8E6C9).withValues(alpha: revealFraction),
    );

    // ── Soil strip ───────────────────────────────────────────────────
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.82, w, h * 0.18),
      Paint()
        ..color = const Color(0xFFD7CCC8).withValues(alpha: revealFraction),
    );

    // ── Wheat stalks ─────────────────────────────────────────────────
    final stemPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final int cropCount = (w / 26).floor() + 1;

    for (int i = 0; i < cropCount; i++) {
      final phase = i * 0.65;
      final baseX = i * 26.0 + 13;
      final baseY = h * 0.83;
      final sway = sin(t * 0.75 + phase) * 4.5;

      final cropReveal = (revealFraction * cropCount - i).clamp(0.0, 1.0);
      if (cropReveal <= 0) continue;

      final stemH = 50.0 * cropReveal;
      final topX = baseX + sway;
      final topY = baseY - stemH;

      stemPaint
        ..color = const Color(0xFF4CAF50)
        ..strokeWidth = 1.8;

      canvas.drawPath(
        Path()
          ..moveTo(baseX, baseY)
          ..quadraticBezierTo(
            baseX + sway * 0.45,
            baseY - stemH * 0.5,
            topX,
            topY,
          ),
        stemPaint,
      );

      if (cropReveal > 0.4) {
        final lf = ((cropReveal - 0.4) / 0.6).clamp(0.0, 1.0);
        canvas.save();
        canvas.translate(baseX + sway * 0.4, baseY - stemH * 0.44);
        canvas.rotate(-0.45 + sin(t * 0.55 + phase) * 0.08);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: 13 * lf,
            height: 4.5 * lf,
          ),
          Paint()
            ..color =
                const Color(0xFF81C784).withValues(alpha: 0.85 * lf),
        );
        canvas.restore();
      }

      if (cropReveal > 0.72) {
        final hf = ((cropReveal - 0.72) / 0.28).clamp(0.0, 1.0);
        final headPaint = Paint()
          ..color = const Color(0xFFFFB300).withValues(alpha: hf)
          ..strokeWidth = 1.6
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        for (int s = 0; s < 5; s++) {
          final angle = -pi / 2 + (s - 2) * 0.26;
          final len = (9.0 + (s % 2) * 3) * hf;
          canvas.drawLine(
            Offset(topX, topY),
            Offset(topX + cos(angle) * len, topY + sin(angle) * len),
            headPaint,
          );
        }

        canvas.drawCircle(
          Offset(topX, topY),
          2.8 * hf,
          Paint()
            ..color = const Color(0xFFFF8F00).withValues(alpha: hf),
        );
      }
    }

    // ── Floating pollen dots ─────────────────────────────────────────
    if (revealFraction > 0.8) {
      final alpha = ((revealFraction - 0.8) / 0.2).clamp(0.0, 1.0);
      final rng = Random(7);
      final paint = Paint();
      for (int p = 0; p < 12; p++) {
        final px = rng.nextDouble() * w;
        final seed = rng.nextDouble() * 2 * pi;
        final py = h * 0.45
            + sin(t * 0.8 + seed) * 15
            - (loopValue * 28 + p * 8) % (h * 0.55);
        paint.color = const Color(0xFFA5D6A7)
            .withValues(alpha: (0.2 + 0.3 * sin(t + seed)) * alpha);
        canvas.drawCircle(Offset(px, py), 2.2 + rng.nextDouble() * 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_CropFieldPainter old) =>
      old.loopValue != loopValue || old.revealFraction != revealFraction;
}