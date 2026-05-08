import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/app_theme.dart';
import '../app/providers/app_providers.dart';
import '../app/providers/language_provider.dart';
import '../l10n/app_strings.dart';

class LoginRegisterScreen extends ConsumerStatefulWidget {
  const LoginRegisterScreen({super.key});

  @override
  ConsumerState<LoginRegisterScreen> createState() =>
      _LoginRegisterScreenState();
}

class _LoginRegisterScreenState extends ConsumerState<LoginRegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey         = GlobalKey<FormState>();
  final _mobileController   = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isAdminLogin  = false;
  bool _isSubmitting  = false;
  bool _obscurePass   = true;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _mobileController.dispose();
    _passwordController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;
    setState(() => _isSubmitting = true);

    final mobile   = _mobileController.text.trim();
    final password = _passwordController.text.trim();
    final authService = ref.read(localAuthServiceProvider);

    try {
      if (_isAdminLogin) {
        await authService.loginAdminWithCredentials(
            mobile: mobile, password: password);
        if (!mounted) return;
        // Force all session-dependent providers to rebuild with the new user.
        ref.invalidate(userProfileProvider);
        ref.invalidate(authRoleProvider);
        context.go('/admin/schemes');
      } else {
        await authService.loginUser(mobile: mobile, password: password);
        if (!mounted) return;
        // Force all session-dependent providers to rebuild with the new user.
        ref.invalidate(userProfileProvider);
        ref.invalidate(authRoleProvider);
        ref.invalidate(bookmarksProvider);
        ref.invalidate(remindersProvider);
        context.go('/home/state');
      }
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

    return Scaffold(
      backgroundColor: isDark ? AppTheme.background : AppTheme.backgroundLight,
      body: Stack(
        children: [
          // ── Glow background ────────────────────────────────────────
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppTheme.primary.withOpacity(0.18),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFF00A3FF).withOpacity(0.12),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          // ── Main content ───────────────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo + title
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppTheme.primaryGradient,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withOpacity(0.35),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.eco_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Text('Welcome back',
                          style: tt.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          )),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        ref.watch(trProvider)('select_language') == 'select_language'
                            ? 'Sign in to continue to KrishiMitra'
                            : 'Sign in to continue to KrishiMitra',
                        style: tt.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // ── Role toggle ──────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E2535)
                            : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          _RoleTab(
                            label: 'Farmer',
                            icon: Icons.agriculture_rounded,
                            selected: !_isAdminLogin,
                            onTap: () =>
                                setState(() => _isAdminLogin = false),
                          ),
                          _RoleTab(
                            label: 'Admin',
                            icon: Icons.admin_panel_settings_rounded,
                            selected: _isAdminLogin,
                            onTap: () =>
                                setState(() => _isAdminLogin = true),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Form ─────────────────────────────────────────
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _PremiumField(
                            controller: _mobileController,
                            label: _isAdminLogin ? 'Username' : 'Mobile Number',
                            icon: _isAdminLogin
                                ? Icons.person_rounded
                                : Icons.phone_rounded,
                            keyboardType: _isAdminLogin
                                ? TextInputType.text
                                : TextInputType.phone,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return _isAdminLogin
                                    ? 'Username is required'
                                    : 'Mobile number is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _PremiumField(
                            controller: _passwordController,
                            label: 'Password',
                            icon: Icons.lock_rounded,
                            obscure: _obscurePass,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePass
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                size: 20,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              onPressed: () =>
                                  setState(() => _obscurePass = !_obscurePass),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Password is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 28),

                          // ── Login button ─────────────────────────
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: _isSubmitting
                                ? Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: AppTheme.primary,
                                        strokeWidth: 2.5,
                                      ),
                                    ),
                                  )
                                : _GradientBtn(
                                    label: 'Sign In',
                                    onTap: _submit,
                                  ),
                          ),
                          const SizedBox(height: 20),

                          // ── Register link ─────────────────────────
                          if (!_isAdminLogin)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "New to KrishiMitra? ",
                                  style: tt.bodySmall,
                                ),
                                GestureDetector(
                                  onTap: () => context.go('/register'),
                                  child: Text(
                                    'Create Account',
                                    style: tt.bodySmall?.copyWith(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Role tab button ──────────────────────────────────────────────────────────
class _RoleTab extends StatelessWidget {
  final String   label;
  final IconData icon;
  final bool     selected;
  final VoidCallback onTap;

  const _RoleTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: selected ? Colors.white : Colors.white38),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: selected ? Colors.white : Colors.white38,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Premium text field ───────────────────────────────────────────────────────
class _PremiumField extends StatelessWidget {
  final TextEditingController controller;
  final String   label;
  final IconData icon;
  final bool     obscure;
  final Widget?  suffixIcon;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const _PremiumField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.suffixIcon,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: Theme.of(context).textTheme.bodyMedium,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: suffixIcon,
      ),
    );
  }
}

// ─── Gradient button ──────────────────────────────────────────────────────────
class _GradientBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _GradientBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
