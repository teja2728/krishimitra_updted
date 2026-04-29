import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app_theme.dart';
import '../app/providers/app_providers.dart';
import '../models/user_profile.dart';

class AdminUsersScreen extends ConsumerWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(registeredUserAuthProvider);
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final tt        = Theme.of(context).textTheme;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: userAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppTheme.primary)),
          error: (err, _) => Center(child: Text('Failed: $err')),
          data: (auth) {
            if (auth == null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.people_outline_rounded,
                          size: 48, color: AppTheme.primary),
                    ),
                    const SizedBox(height: 20),
                    Text('No users yet', style: tt.titleMedium),
                    const SizedBox(height: 8),
                    Text('Registered users will appear here.',
                        style: tt.bodySmall),
                  ],
                ),
              );
            }

            final UserProfile profile = auth.profile;

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Registered User',
                      style:
                          tt.labelMedium?.copyWith(fontWeight: FontWeight.w600,
                              color: AppTheme.primary)),
                  const SizedBox(height: 12),

                  // Profile card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.surface : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.07)
                            : Colors.black.withOpacity(0.06),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Avatar row
                        Row(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  profile.name.isNotEmpty
                                      ? profile.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(profile.name,
                                    style: tt.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Text(profile.mobile, style: tt.bodySmall),
                              ],
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('Farmer',
                                  style: tt.labelSmall?.copyWith(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w700,
                                  )),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const Divider(),
                        const SizedBox(height: 14),

                        // Info grid
                        _UserInfoGrid(profile: profile, isDark: isDark),
                        const SizedBox(height: 16),

                        // Crops
                        if (profile.crops.isNotEmpty) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Crops',
                                style: tt.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w600)),
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
                                        color: AppTheme.primary
                                            .withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        border: Border.all(
                                            color: AppTheme.primary
                                                .withOpacity(0.25)),
                                      ),
                                      child: Text(c,
                                          style: tt.labelSmall?.copyWith(
                                            color: AppTheme.primary,
                                            fontWeight: FontWeight.w600,
                                          )),
                                    ))
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _UserInfoGrid extends StatelessWidget {
  final UserProfile profile;
  final bool        isDark;

  const _UserInfoGrid({required this.profile, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('State', profile.state, Icons.location_city_rounded),
      ('Language', profile.language, Icons.translate_rounded),
      ('Soil Type', profile.soilType, Icons.landscape_rounded),
      ('Land Size', '${profile.landSize} acres', Icons.grain_rounded),
    ];

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 2.4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.04)
                : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(item.$3, size: 16, color: AppTheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(item.$1,
                        style: Theme.of(context).textTheme.labelSmall),
                    Text(item.$2,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
