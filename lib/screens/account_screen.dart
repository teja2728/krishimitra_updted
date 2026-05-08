import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app_theme.dart';
import '../app/providers/app_providers.dart';
import '../app/providers/language_provider.dart';
import '../data/app_constants.dart';
import '../l10n/app_strings.dart';
import '../models/auth_role.dart';
import '../models/user_profile.dart';
import '../widgets/multi_select_chips.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _isEditing = false;

  final _nameController  = TextEditingController();
  final _acresController = TextEditingController();

  String _selectedState    = kIndianStates.first;
  String _selectedLanguage = kLanguages.first;
  String _selectedSoilType = kSoilTypes.first;
  final Set<String> _selectedCrops = {};

  @override
  void dispose() {
    _nameController.dispose();
    _acresController.dispose();
    super.dispose();
  }

  void _loadProfileIntoForm(UserProfile profile) {
    _nameController.text  = profile.name;
    _acresController.text = profile.landSize.toString();
    _selectedState        = kIndianStates.contains(profile.state)
        ? profile.state
        : kIndianStates.first;
    _selectedLanguage = kLanguages.contains(profile.language)
        ? profile.language
        : kLanguages.first;
    _selectedSoilType = kSoilTypes.contains(profile.soilType)
        ? profile.soilType
        : kSoilTypes.first;
    _selectedCrops
      ..clear()
      ..addAll(profile.crops);
  }

  Future<void> _save(UserProfile existing) async {
    final storage    = ref.read(localUserStorageProvider);
    final api        = ref.read(apiServiceProvider);
    final repository = ref.read(schemesRepositoryProvider);
    final name       = _nameController.text.trim();
    final landSize   = int.tryParse(_acresController.text.trim()) ?? 0;

    if (name.isEmpty || landSize <= 0 || _selectedCrops.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill valid profile details.')),
      );
      return;
    }

    final stateChanged = _selectedState != existing.state;

    final updated = UserProfile(
      id:       existing.id,
      mobile:   existing.mobile,
      name:     name,
      state:    _selectedState,
      language: _selectedLanguage,
      crops:    _selectedCrops.toList(growable: false),
      soilType: _selectedSoilType,
      landSize: landSize,
      role:     existing.role,
    );

    await storage.updateProfile(updated);
    ref.invalidate(userProfileProvider);
    setState(() => _isEditing = false);

    // If the user changed their state, bust both scheme caches so the next
    // "Fetch From Server" (or automatic invalidation below) gets
    // state-specific schemes from the backend instead of the stale cache.
    if (stateChanged) {
      await repository.clearSchemeCache();
      ref.invalidate(schemesProvider);
    }

    try {
      final serverProfile = await api.updateProfile(updated);
      await storage.updateProfile(serverProfile);
      ref.invalidate(userProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved locally. Will sync when online.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final roleAsync    = ref.watch(authRoleProvider);
    final tr           = ref.watch(trProvider);
    final isDark       = Theme.of(context).brightness == Brightness.dark;
    final tt           = Theme.of(context).textTheme;

    return Scaffold(
      body: profileAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded,
                    size: 56, color: Colors.redAccent.withValues(alpha: 0.7)),
                const SizedBox(height: 16),
                Text('Failed to load profile',
                    style: tt.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text('$err',
                    textAlign: TextAlign.center,
                    style: tt.bodySmall),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(userProfileProvider),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
        data: (profile) {
          if (profile == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_off_rounded,
                        size: 56,
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.6)),
                    const SizedBox(height: 16),
                    Text('No profile found',
                        style: tt.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(
                      'Your profile could not be loaded.\nTry logging in again or tap Retry.',
                      textAlign: TextAlign.center,
                      style: tt.bodySmall,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () =>
                          ref.invalidate(userProfileProvider),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final isAdmin = roleAsync.valueOrNull == AuthRole.admin;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Profile hero ────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primary.withOpacity(0.15),
                        const Color(0xFF00A3FF).withOpacity(0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppTheme.primary.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withOpacity(0.3),
                              blurRadius: 16,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            profile.name.isNotEmpty
                                ? profile.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(profile.name,
                                style: tt.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(profile.mobile, style: tt.bodySmall),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isAdmin
                                    ? Colors.orange.withOpacity(0.15)
                                    : AppTheme.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isAdmin ? 'Admin' : 'Farmer',
                                style: tt.labelSmall?.copyWith(
                                  color: isAdmin
                                      ? Colors.orange
                                      : AppTheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!_isEditing)
                        IconButton(
                          tooltip: 'Edit profile',
                          onPressed: () {
                            _loadProfileIntoForm(profile);
                            setState(() => _isEditing = true);
                          },
                          style: IconButton.styleFrom(
                            backgroundColor:
                                AppTheme.primary.withOpacity(0.12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.edit_rounded,
                              size: 18, color: AppTheme.primary),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                if (!_isEditing) ...[
                  // ── View mode: info cards ────────────────────────────
                  Text(tr('edit_profile'),
                      style: tt.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  _InfoGrid(profile: profile, isDark: isDark),
                ] else ...[
                  // ── Edit mode ────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(tr('edit_profile'),
                          style: tt.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      TextButton(
                        onPressed: () =>
                            setState(() => _isEditing = false),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _EditField(
                    controller: _nameController,
                    label: 'Name',
                    icon: Icons.person_rounded,
                  ),
                  const SizedBox(height: 14),
                  _PremiumDropdown<String>(
                    label: 'State',
                    icon: Icons.location_city_rounded,
                    value: _selectedState,
                    items: kIndianStates,
                    onChanged: (v) =>
                        setState(() => _selectedState = v!),
                  ),
                  const SizedBox(height: 14),
                  _PremiumDropdown<String>(
                    label: tr('language'),
                    icon: Icons.translate_rounded,
                    value: _selectedLanguage,
                    items: kLanguages,
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _selectedLanguage = v);
                      // Instantly apply language across the whole app
                      ref.read(languageProvider.notifier).setLanguage(v);
                    },
                  ),
                  const SizedBox(height: 14),
                  _PremiumDropdown<String>(
                    label: 'Soil Type',
                    icon: Icons.landscape_rounded,
                    value: _selectedSoilType,
                    items: kSoilTypes,
                    onChanged: (v) =>
                        setState(() => _selectedSoilType = v!),
                  ),
                  const SizedBox(height: 14),
                  _EditField(
                    controller: _acresController,
                    label: 'Land Size (Acres)',
                    icon: Icons.grain_rounded,
                    inputType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  MultiSelectChips(
                    label: 'Crop Types',
                    options: kCropOptions,
                    selected: _selectedCrops,
                    onChanged: (next) => setState(() {
                      _selectedCrops
                        ..clear()
                        ..addAll(next);
                    }),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: GestureDetector(
                      onTap: () => _save(profile),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withOpacity(0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Text('Save Changes',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            )),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Info grid view ───────────────────────────────────────────────────────────
class _InfoGrid extends StatelessWidget {
  final UserProfile profile;
  final bool isDark;

  const _InfoGrid({required this.profile, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('State', profile.state, Icons.location_city_rounded),
      ('Language', profile.language, Icons.translate_rounded),
      ('Soil Type', profile.soilType, Icons.landscape_rounded),
      ('Land Size', '${profile.landSize} acres', Icons.grain_rounded),
    ];

    return Column(
      children: [
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.5,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: items.map((item) {
            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.surface : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.07)
                      : Colors.black.withOpacity(0.06),
                ),
              ),
              child: Row(
                children: [
                  Icon(item.$3,
                      size: 18, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(item.$1,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall),
                        Text(item.$2,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color:
                                        Theme.of(context).colorScheme.onSurface),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        if (profile.crops.isNotEmpty) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Crops',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: profile.crops
                .map((c) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppTheme.primary.withOpacity(0.25)),
                      ),
                      child: Text(c,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w600)),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}

// ─── Edit field ───────────────────────────────────────────────────────────────
class _EditField extends StatelessWidget {
  final TextEditingController controller;
  final String   label;
  final IconData icon;
  final TextInputType inputType;

  const _EditField({
    required this.controller,
    required this.label,
    required this.icon,
    this.inputType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: inputType,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
      ),
    );
  }
}

// ─── Premium dropdown ─────────────────────────────────────────────────────────
class _PremiumDropdown<T> extends StatelessWidget {
  final String   label;
  final IconData icon;
  final T        value;
  final List<T>  items;
  final ValueChanged<T?> onChanged;

  const _PremiumDropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: items.contains(value) ? value : null,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
      ),
      isExpanded: true,
      items: items
          .map((i) =>
              DropdownMenuItem(value: i, child: Text(i.toString())))
          .toList(),
      onChanged: onChanged,
    );
  }
}
