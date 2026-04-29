import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/app_theme.dart';
import '../app/providers/app_providers.dart';
import '../data/app_constants.dart';
import '../models/user_profile.dart';
import '../widgets/multi_select_chips.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() =>
      _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen>
    with SingleTickerProviderStateMixin {
  final _formKey            = GlobalKey<FormState>();
  final _mobileController   = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController     = TextEditingController();
  final _acresController    = TextEditingController();

  String _selectedState    = kIndianStates.first;
  String _selectedLanguage = kLanguages.first;
  String _selectedSoilType = kSoilTypes.first;
  final Set<String> _selectedCrops = {};

  bool _isSubmitting = false;
  bool _obscurePass  = true;

  // Step tracker (1 = personal info, 2 = farm info)
  int _step = 1;

  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400))
      ..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _mobileController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _acresController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;
    if (_selectedCrops.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one crop type.')),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final authService = ref.read(localAuthServiceProvider);
      final mobile   = _mobileController.text.trim();
      final password = _passwordController.text;
      final name     = _nameController.text.trim();
      final landSize = int.tryParse(_acresController.text.trim()) ?? 0;

      final profile = UserProfile(
        id:       '',
        mobile:   mobile,
        name:     name,
        state:    _selectedState,
        language: _selectedLanguage,
        crops:    _selectedCrops.toList(growable: false),
        soilType: _selectedSoilType,
        landSize: landSize,
        role:     'user',
      );

      final authData = UserAuthData(
        mobile:  mobile,
        password: password,
        profile: profile,
      );

      await authService.registerUser(authData);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Registration successful! Please login.')),
      );
      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt     = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.background : AppTheme.backgroundLight,
      body: Stack(
        children: [
          // Glow
          Positioned(
            top: -60,
            left: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppTheme.primary.withOpacity(0.14),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                children: [
                  // ── Header ──────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            if (_step == 2) {
                              setState(() => _step = 1);
                            } else {
                              context.go('/login');
                            }
                          },
                          icon: const Icon(Icons.arrow_back_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: isDark
                                ? Colors.white.withOpacity(0.08)
                                : Colors.black.withOpacity(0.06),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Create Account',
                                style: tt.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800)),
                            Text(
                              _step == 1
                                  ? 'Step 1 of 2 · Personal Info'
                                  : 'Step 2 of 2 · Farm Details',
                              style: tt.bodySmall,
                            ),
                          ],
                        ),
                        const Spacer(),
                        // Progress dots
                        Row(
                          children: [1, 2].map((s) {
                            final active = s == _step;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 3),
                              width: active ? 20 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: active
                                    ? AppTheme.primary
                                    : AppTheme.primary.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Progress bar ─────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _step / 2,
                        backgroundColor: AppTheme.primary.withOpacity(0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppTheme.primary),
                        minHeight: 4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Form ──────────────────────────────────────────────────
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: Form(
                        key: _formKey,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _step == 1
                              ? _Step1(
                                  key: const ValueKey(1),
                                  mobileCtrl:   _mobileController,
                                  passwordCtrl: _passwordController,
                                  nameCtrl:     _nameController,
                                  obscurePass:  _obscurePass,
                                  onTogglePass: () => setState(
                                      () => _obscurePass = !_obscurePass),
                                  onNext: () {
                                    // Validate step 1 fields
                                    final m = _mobileController.text.trim();
                                    final pw = _passwordController.text;
                                    final n = _nameController.text.trim();
                                    if (m.isEmpty || m.length < 10) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'Enter a valid mobile number')));
                                      return;
                                    }
                                    if (pw.length < 4) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'Password must be at least 4 chars')));
                                      return;
                                    }
                                    if (n.isEmpty) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content:
                                                  Text('Name is required')));
                                      return;
                                    }
                                    setState(() => _step = 2);
                                  },
                                )
                              : _Step2(
                                  key: const ValueKey(2),
                                  selectedState:    _selectedState,
                                  selectedLanguage: _selectedLanguage,
                                  selectedSoilType: _selectedSoilType,
                                  selectedCrops:    _selectedCrops,
                                  acresCtrl:        _acresController,
                                  onStateChanged: (v) =>
                                      setState(() => _selectedState = v!),
                                  onLanguageChanged: (v) =>
                                      setState(() => _selectedLanguage = v!),
                                  onSoilChanged: (v) =>
                                      setState(() => _selectedSoilType = v!),
                                  onCropsChanged: (next) => setState(() {
                                    _selectedCrops
                                      ..clear()
                                      ..addAll(next);
                                  }),
                                  isSubmitting: _isSubmitting,
                                  onSubmit: _submit,
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 1 widget ─────────────────────────────────────────────────────────────
class _Step1 extends StatelessWidget {
  final TextEditingController mobileCtrl;
  final TextEditingController passwordCtrl;
  final TextEditingController nameCtrl;
  final bool       obscurePass;
  final VoidCallback onTogglePass;
  final VoidCallback onNext;

  const _Step1({
    super.key,
    required this.mobileCtrl,
    required this.passwordCtrl,
    required this.nameCtrl,
    required this.obscurePass,
    required this.onTogglePass,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Personal Information',
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        TextFormField(
          controller: mobileCtrl,
          keyboardType: TextInputType.phone,
          style: tt.bodyMedium,
          decoration: const InputDecoration(
            labelText: 'Mobile Number',
            prefixIcon: Icon(Icons.phone_rounded, size: 20),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Required';
            if (v.trim().length < 10) return 'Enter a valid mobile number';
            return null;
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: passwordCtrl,
          obscureText: obscurePass,
          style: tt.bodyMedium,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_rounded, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                obscurePass
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              onPressed: onTogglePass,
            ),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Required';
            if (v.length < 4) return 'At least 4 characters';
            return null;
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: nameCtrl,
          style: tt.bodyMedium,
          decoration: const InputDecoration(
            labelText: 'Full Name',
            prefixIcon: Icon(Icons.person_rounded, size: 20),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Required';
            return null;
          },
        ),
        const SizedBox(height: 28),
        _GradBtn(label: 'Continue →', onTap: onNext),
        const SizedBox(height: 16),
        Center(
          child: GestureDetector(
            onTap: () => GoRouter.of(context).go('/login'),
            child: RichText(
              text: TextSpan(
                text: 'Already have an account? ',
                style: tt.bodySmall,
                children: [
                  TextSpan(
                    text: 'Sign In',
                    style: tt.bodySmall?.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Step 2 widget ─────────────────────────────────────────────────────────────
class _Step2 extends StatelessWidget {
  final String selectedState;
  final String selectedLanguage;
  final String selectedSoilType;
  final Set<String> selectedCrops;
  final TextEditingController acresCtrl;
  final ValueChanged<String?> onStateChanged;
  final ValueChanged<String?> onLanguageChanged;
  final ValueChanged<String?> onSoilChanged;
  final ValueChanged<Set<String>> onCropsChanged;
  final bool         isSubmitting;
  final VoidCallback onSubmit;

  const _Step2({
    super.key,
    required this.selectedState,
    required this.selectedLanguage,
    required this.selectedSoilType,
    required this.selectedCrops,
    required this.acresCtrl,
    required this.onStateChanged,
    required this.onLanguageChanged,
    required this.onSoilChanged,
    required this.onCropsChanged,
    required this.isSubmitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Farm Details',
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: selectedState,
          isExpanded: true,
          style: tt.bodyMedium,
          decoration: const InputDecoration(
            labelText: 'State',
            prefixIcon: Icon(Icons.location_city_rounded, size: 20),
          ),
          items: kIndianStates
              .map((s) =>
                  DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: onStateChanged,
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          value: selectedLanguage,
          isExpanded: true,
          style: tt.bodyMedium,
          decoration: const InputDecoration(
            labelText: 'Preferred Language',
            prefixIcon: Icon(Icons.translate_rounded, size: 20),
          ),
          items: kLanguages
              .map((s) =>
                  DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: onLanguageChanged,
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          value: selectedSoilType,
          isExpanded: true,
          style: tt.bodyMedium,
          decoration: const InputDecoration(
            labelText: 'Soil Type',
            prefixIcon: Icon(Icons.landscape_rounded, size: 20),
          ),
          items: kSoilTypes
              .map((s) =>
                  DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: onSoilChanged,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: acresCtrl,
          keyboardType: TextInputType.number,
          style: tt.bodyMedium,
          decoration: const InputDecoration(
            labelText: 'Land Size (Acres)',
            prefixIcon: Icon(Icons.grain_rounded, size: 20),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Required';
            final parsed = int.tryParse(v.trim());
            if (parsed == null || parsed <= 0) {
              return 'Enter a valid number (> 0)';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        MultiSelectChips(
          label: 'Crops You Grow',
          options: kCropOptions,
          selected: selectedCrops,
          onChanged: onCropsChanged,
        ),
        const SizedBox(height: 28),
        isSubmitting
            ? const Center(
                child: CircularProgressIndicator(
                    color: AppTheme.primary, strokeWidth: 2.5))
            : _GradBtn(label: 'Create Account', onTap: onSubmit),
      ],
    );
  }
}

// ── Shared gradient button ────────────────────────────────────────────────────
class _GradBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _GradBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
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
