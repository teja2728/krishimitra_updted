import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app_theme.dart';
import '../app/providers/app_providers.dart';
import '../l10n/app_strings.dart';
import '../models/auth_role.dart';
import '../widgets/language_selector.dart';

class HomeShell extends ConsumerWidget {
  final Widget child;
  final String currentPath;

  const HomeShell({
    super.key,
    required this.child,
    required this.currentPath,
  });

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final authService = ref.read(localAuthServiceProvider);
    await authService.logout();
    ref.invalidate(authRoleProvider);
    ref.invalidate(userProfileProvider);
    ref.invalidate(registeredUserAuthProvider);
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleAsync  = ref.watch(authRoleProvider);
    final isAdminPath = currentPath.startsWith('/admin/');
    final isDark     = Theme.of(context).brightness == Brightness.dark;

    // AppBar title
    String appBarTitle = isAdminPath ? 'KrishiMitra Admin' : 'KrishiMitra';
    if (currentPath.contains('/home/about')) appBarTitle = 'About';
    if (currentPath.contains('/home/feedback')) appBarTitle = 'Feedback';
    if (currentPath.contains('/home/account')) appBarTitle = 'Account';
    if (currentPath.contains('/home/ai')) appBarTitle = 'AI Chat';
    if (currentPath.contains('/home/crop-advisor')) appBarTitle = 'Crop Advisor';

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.background : AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor:
            isDark ? AppTheme.background : AppTheme.backgroundLight,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.eco_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            Text(
              appBarTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
        actions: [
          // Language selector — only on user screens
          if (!isAdminPath)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: const LanguageSelector(),
            ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: IconButton(
              tooltip: 'Logout',
              style: IconButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.logout_rounded,
                  size: 20, color: Colors.redAccent),
              onPressed: () => _logout(context, ref),
            ),
          ),
        ],
      ),

      body: child,

      bottomNavigationBar: roleAsync.when(
        loading: () => const SizedBox.shrink(),
        error:   (_, __) => const SizedBox.shrink(),
        data: (role) {
          final isAdmin = role == AuthRole.admin || isAdminPath;

          // ── Floating nav container ────────────────────────────────
          return Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141928) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.black.withOpacity(0.06),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: isAdmin
                ? _AdminNav(currentPath: currentPath)
                : _UserNav(currentPath: currentPath),
          );
        },
      ),
    );
  }
}

// ─── User bottom nav ──────────────────────────────────────────────────────────
class _UserNav extends ConsumerWidget {
  final String currentPath;
  const _UserNav({required this.currentPath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider); // rebuilds instantly on language switch
    final idx = currentPath.startsWith('/home/ai')
        ? 1
        : currentPath.startsWith('/home/crop-advisor')
            ? 2
            : currentPath.startsWith('/home/about')
                ? 3
                : currentPath.startsWith('/home/feedback')
                    ? 4
                    : currentPath.startsWith('/home/account')
                        ? 5
                        : 0;

    return BottomNavigationBar(
      currentIndex: idx,
      elevation: 0,
      backgroundColor: Colors.transparent,
      onTap: (i) {
        switch (i) {
          case 0: context.go('/home/state'); break;
          case 1: context.go('/home/ai'); break;
          case 2: context.go('/home/crop-advisor'); break;
          case 3: context.go('/home/about'); break;
          case 4: context.go('/home/feedback'); break;
          case 5: context.go('/home/account'); break;
        }
      },
      items: [
        BottomNavigationBarItem(
          icon: const Icon(Icons.home_outlined),
          activeIcon: const Icon(Icons.home_rounded),
          label: tr('nav_home'),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.auto_awesome_outlined),
          activeIcon: const Icon(Icons.auto_awesome_rounded),
          label: tr('nav_ai_chat'),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.agriculture_outlined),
          activeIcon: const Icon(Icons.agriculture_rounded),
          label: tr('nav_crop_ai'),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.eco_outlined),
          activeIcon: const Icon(Icons.eco_rounded),
          label: tr('nav_about'),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.feedback_outlined),
          activeIcon: const Icon(Icons.feedback_rounded),
          label: tr('nav_feedback'),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.person_outline_rounded),
          activeIcon: const Icon(Icons.person_rounded),
          label: tr('nav_account'),
        ),
      ],
    );
  }
}


// ─── Admin bottom nav ─────────────────────────────────────────────────────────
class _AdminNav extends StatelessWidget {
  final String currentPath;
  const _AdminNav({required this.currentPath});

  @override
  Widget build(BuildContext context) {
    final idx = currentPath.startsWith('/admin/feedback')
        ? 1
        : currentPath.startsWith('/admin/notifications')
            ? 2
            : currentPath.startsWith('/admin/users')
                ? 3
                : 0;

    return BottomNavigationBar(
      currentIndex: idx,
      elevation: 0,
      backgroundColor: Colors.transparent,
      onTap: (i) {
        switch (i) {
          case 0: context.go('/admin/schemes'); break;
          case 1: context.go('/admin/feedback'); break;
          case 2: context.go('/admin/notifications'); break;
          case 3: context.go('/admin/users'); break;
        }
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.manage_accounts_outlined),
          activeIcon: Icon(Icons.manage_accounts_rounded),
          label: 'Schemes',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.feedback_outlined),
          activeIcon: Icon(Icons.feedback_rounded),
          label: 'Feedback',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.notifications_outlined),
          activeIcon: Icon(Icons.notifications_rounded),
          label: 'Alerts',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.people_outline_rounded),
          activeIcon: Icon(Icons.people_rounded),
          label: 'Users',
        ),
      ],
    );
  }
}
