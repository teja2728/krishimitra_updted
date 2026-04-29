import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/app_theme.dart';
import '../app/providers/app_providers.dart';
import '../services/url_service.dart';
import '../widgets/scheme_card.dart';
import '../widgets/skeleton_loader.dart';

class BookmarkScreen extends ConsumerWidget {
  const BookmarkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schemesAsync   = ref.watch(schemesProvider);
    final bookmarksAsync = ref.watch(bookmarksProvider);
    final remindersAsync = ref.watch(remindersProvider);
    final bookmarkedIds  = bookmarksAsync.value ?? <String>{};
    final reminderIds    = remindersAsync.value ?? <String>{};
    final isDark         = Theme.of(context).brightness == Brightness.dark;
    final tt             = Theme.of(context).textTheme;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: schemesAsync.when(
          loading: () => ListView.separated(
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, __) => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.surface : Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLoader(width: 200, height: 18, borderRadius: 6),
                  const SizedBox(height: 10),
                  SkeletonLoader(width: double.infinity, height: 13, borderRadius: 6),
                  const SizedBox(height: 6),
                  SkeletonLoader(width: 160, height: 13, borderRadius: 6),
                ],
              ),
            ),
          ),
          error: (err, _) => Center(child: Text('Failed to load: $err')),
          data: (schemes) {
            final bookmarked = schemes
                .where((s) => bookmarkedIds.contains(s.id))
                .toList(growable: false);

            if (bookmarked.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.bookmark_outline_rounded,
                          size: 48, color: AppTheme.accent),
                    ),
                    const SizedBox(height: 20),
                    Text('No bookmarks yet', style: tt.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the bookmark icon on any scheme to save it here.',
                      style: tt.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(Icons.bookmark_rounded,
                          size: 16, color: AppTheme.accent),
                      const SizedBox(width: 6),
                      Text(
                        '${bookmarked.length} saved scheme${bookmarked.length == 1 ? '' : 's'}',
                        style: tt.labelMedium?.copyWith(
                          color: AppTheme.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: bookmarked.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final scheme = bookmarked[index];
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration:
                            Duration(milliseconds: 250 + index * 50),
                        curve: Curves.easeOut,
                        builder: (ctx, val, child) => Opacity(
                          opacity: val,
                          child: Transform.translate(
                            offset: Offset(0, 16 * (1 - val)),
                            child: child,
                          ),
                        ),
                        child: SchemeCard(
                          scheme: scheme,
                          isBookmarked: true,
                          isReminded: reminderIds.contains(scheme.id),
                          onTap: () => context.go(
                            '/scheme/${Uri.encodeComponent(scheme.id)}',
                          ),
                          onApply: () async {
                            final link = scheme.applyLink.trim();
                            if (link.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('No apply link available.')),
                              );
                              return;
                            }
                            try {
                              await UrlService.openUrl(link);
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            }
                          },
                          onToggleBookmark: () async {
                            await ref
                                .read(bookmarksProvider.notifier)
                                .toggle(scheme.id);
                          },
                          onToggleReminder: () async {
                            await ref
                                .read(remindersProvider.notifier)
                                .toggle(scheme.id);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
