import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app_theme.dart';
import '../app/providers/app_providers.dart';
import '../widgets/skeleton_loader.dart';

class AdminFeedbackScreen extends ConsumerWidget {
  const AdminFeedbackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedbackAsync = ref.watch(feedbackProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tt     = Theme.of(context).textTheme;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: feedbackAsync.when(
          loading: () => ListView.separated(
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, __) => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.surface : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLoader(width: 120, height: 12, borderRadius: 6),
                  const SizedBox(height: 10),
                  SkeletonLoader(width: double.infinity, height: 14, borderRadius: 6),
                  const SizedBox(height: 6),
                  SkeletonLoader(width: double.infinity, height: 14, borderRadius: 6),
                  const SizedBox(height: 8),
                  SkeletonLoader(width: 100, height: 11, borderRadius: 6),
                ],
              ),
            ),
          ),
          error: (err, _) => Center(child: Text('Failed to load: $err')),
          data: (feedback) {
            if (feedback.isEmpty) {
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
                      child: Icon(Icons.feedback_outlined,
                          size: 48, color: AppTheme.primary),
                    ),
                    const SizedBox(height: 20),
                    Text('No feedback yet', style: tt.titleMedium),
                    const SizedBox(height: 8),
                    Text('Feedback from farmers will appear here.',
                        style: tt.bodySmall),
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
                      Icon(Icons.feedback_rounded,
                          size: 16, color: AppTheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        '${feedback.length} submission${feedback.length == 1 ? '' : 's'}',
                        style: tt.labelMedium?.copyWith(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: feedback.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final entry = feedback[index];
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(milliseconds: 250 + index * 50),
                        curve: Curves.easeOut,
                        builder: (ctx, val, child) => Opacity(
                          opacity: val,
                          child: Transform.translate(
                            offset: Offset(0, 16 * (1 - val)),
                            child: child,
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.surface : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withOpacity(0.07)
                                  : Colors.black.withOpacity(0.06),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary
                                          .withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(Icons.person_rounded,
                                        size: 16, color: AppTheme.primary),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(entry.mobile,
                                      style: tt.labelMedium?.copyWith(
                                          fontWeight: FontWeight.w600)),
                                  const Spacer(),
                                  Text(
                                    _formatDate(entry.createdAt),
                                    style: tt.labelSmall,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.04)
                                      : Colors.black.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(entry.message,
                                    style: tt.bodyMedium
                                        ?.copyWith(height: 1.5)),
                              ),
                            ],
                          ),
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

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }
}
