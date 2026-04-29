import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app_theme.dart';
import '../app/providers/app_providers.dart';
import '../widgets/skeleton_loader.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _markedOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _markAllReadOnce();
  }

  Future<void> _markAllReadOnce() async {
    if (_markedOnce) return;
    _markedOnce = true;
    final service = ref.read(notificationServiceProvider);
    final notifications = await service.loadAll();
    final readIds = await service.loadReadIds();
    final toMark = notifications.map((e) => e.id).toSet().difference(readIds);
    if (toMark.isEmpty) return;
    await service.markAsRead(toMark);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tt     = Theme.of(context).textTheme;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: notificationsAsync.when(
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
                  SkeletonLoader(width: double.infinity, height: 14, borderRadius: 6),
                  const SizedBox(height: 8),
                  SkeletonLoader(width: 120, height: 11, borderRadius: 6),
                ],
              ),
            ),
          ),
          error: (err, _) => Center(child: Text('Failed to load: $err')),
          data: (notifications) {
            if (notifications.isEmpty) {
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
                      child: Icon(Icons.notifications_off_outlined,
                          size: 48, color: AppTheme.primary),
                    ),
                    const SizedBox(height: 20),
                    Text('No notifications yet',
                        style: tt.titleMedium),
                    const SizedBox(height: 8),
                    Text('You\'re all caught up!',
                        style: tt.bodySmall),
                  ],
                ),
              );
            }

            return ListView.separated(
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final n = notifications[index];
                // Staggered entry
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 300 + index * 60),
                  curve: Curves.easeOut,
                  builder: (ctx, val, child) => Opacity(
                    opacity: val,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - val)),
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
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.notifications_rounded,
                              color: AppTheme.primary, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(n.message,
                                  style: tt.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w500,
                                      height: 1.4)),
                              const SizedBox(height: 6),
                              Text(
                                _formatDate(n.createdAt),
                                style: tt.labelSmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final now   = DateTime.now();
    final diff  = now.difference(local);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    if (diff.inDays < 7)     return '${diff.inDays}d ago';
    return '${local.day}/${local.month}/${local.year}';
  }
}
