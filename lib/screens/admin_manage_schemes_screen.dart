import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/app_theme.dart';
import '../app/providers/app_providers.dart';
import '../models/scheme.dart';
import '../widgets/scheme_editor_dialog.dart';
import '../widgets/skeleton_loader.dart';

class AdminManageSchemesScreen extends ConsumerWidget {
  const AdminManageSchemesScreen({super.key});

  Future<void> _showEditor(BuildContext context, WidgetRef ref,
      {Scheme? initial}) async {
    final updated = await showDialog<Scheme>(
      context: context,
      builder: (_) => SchemeEditorDialog(initial: initial),
    );
    if (updated == null) return;

    final repo    = ref.read(schemesRepositoryProvider);
    final current = await repo.fetchSchemesWithAdminOverrides();
    final exists  = current.any((s) => s.id == updated.id);
    final next    = <Scheme>[];
    if (exists) {
      next.addAll(current.map((s) => s.id == updated.id ? updated : s));
    } else {
      next..addAll(current)..add(updated);
    }
    await repo.saveAllSchemes(next);
    ref.invalidate(schemesProvider);
  }

  Future<void> _deleteScheme(
      BuildContext context, WidgetRef ref, Scheme scheme) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Scheme'),
        content: Text('Delete "${scheme.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final repo    = ref.read(schemesRepositoryProvider);
    final current = await repo.fetchSchemesWithAdminOverrides();
    final next = current.where((s) => s.id != scheme.id).toList();
    await repo.saveAllSchemes(next);
    ref.invalidate(schemesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schemesAsync = ref.watch(schemesProvider);
    final isDark       = Theme.of(context).brightness == Brightness.dark;
    final tt           = Theme.of(context).textTheme;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: schemesAsync.when(
          loading: () => ListView.separated(
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, __) => Container(
              height: 110,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.surface : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLoader(width: 200, height: 16, borderRadius: 6),
                  const SizedBox(height: 10),
                  SkeletonLoader(width: double.infinity, height: 12, borderRadius: 6),
                  const SizedBox(height: 6),
                  SkeletonLoader(width: 140, height: 12, borderRadius: 6),
                ],
              ),
            ),
          ),
          error: (err, _) =>
              Center(child: Text('Failed to load schemes: $err')),
          data: (schemes) {
            // Stats header
            final centralCount =
                schemes.where((s) => s.type == SchemeType.central).length;
            final stateCount   = schemes.length - centralCount;

            return Column(
              children: [
                // Stat chips row
                Row(
                  children: [
                    _StatChip(
                      label: 'Total',
                      count: schemes.length,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      label: 'Central',
                      count: centralCount,
                      color: const Color(0xFF00A3FF),
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      label: 'State',
                      count: stateCount,
                      color: AppTheme.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: schemes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.article_outlined,
                                  size: 56,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outline),
                              const SizedBox(height: 16),
                              Text('No schemes yet', style: tt.titleMedium),
                              const SizedBox(height: 8),
                              Text('Tap + to add the first scheme',
                                  style: tt.bodySmall),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: schemes.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final scheme = schemes[index];
                            final isCentral =
                                scheme.type == SchemeType.central;
                            final typeColor = isCentral
                                ? const Color(0xFF00A3FF)
                                : AppTheme.primary;

                            return Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppTheme.surface
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.07)
                                      : Colors.black.withOpacity(0.06),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: typeColor,
                                      borderRadius: const BorderRadius
                                          .vertical(top: Radius.circular(16)),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(scheme.name,
                                                  style: tt.titleSmall
                                                      ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w700),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis),
                                            ),
                                            _AdminAction(
                                              icon: Icons.edit_rounded,
                                              color: AppTheme.primary,
                                              onTap: () => _showEditor(
                                                  context, ref,
                                                  initial: scheme),
                                            ),
                                            const SizedBox(width: 4),
                                            _AdminAction(
                                              icon: Icons.delete_rounded,
                                              color: Colors.redAccent,
                                              onTap: () => _deleteScheme(
                                                  context, ref, scheme),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(scheme.description,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: tt.bodySmall),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            _MiniTag(
                                              label: isCentral
                                                  ? 'Central'
                                                  : scheme.state.isEmpty
                                                      ? 'State'
                                                      : scheme.state,
                                              color: typeColor,
                                            ),
                                            if (scheme.deadline.isNotEmpty)
                                              ...[
                                              const SizedBox(width: 6),
                                              _MiniTag(
                                                label: scheme.deadline,
                                                color: AppTheme.accent,
                                                icon: Icons.schedule_rounded,
                                              ),
                                            ],
                                            const Spacer(),
                                            GestureDetector(
                                              onTap: () => context.go(
                                                '/scheme/${Uri.encodeComponent(scheme.id)}',
                                              ),
                                              child: Text('View →',
                                                  style: tt.labelSmall
                                                      ?.copyWith(
                                                          color: typeColor,
                                                          fontWeight:
                                                              FontWeight.w600)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => _showEditor(context, ref),
          tooltip: 'Add Scheme',
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add_rounded, color: Colors.white),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int    count;
  final Color  color;

  const _StatChip(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$count',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  )),
          const SizedBox(width: 5),
          Text(label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                  )),
        ],
      ),
    );
  }
}

class _AdminAction extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final VoidCallback onTap;

  const _AdminAction(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String   label;
  final Color    color;
  final IconData? icon;

  const _MiniTag({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
