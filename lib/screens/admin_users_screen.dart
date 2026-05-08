import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app_theme.dart';
import '../app/providers/app_providers.dart';
import '../models/user_profile.dart';

// ── Filter enum ───────────────────────────────────────────────────────────────
enum _UserFilter { all, active, online, suspended, blocked, deleted }

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  _UserFilter _filter = _UserFilter.all;
  String _search = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _search = val.trim().toLowerCase());
    });
  }

  List<UserProfile> _applyFilters(List<UserProfile> users) {
    var filtered = users;
    switch (_filter) {
      case _UserFilter.active:
        filtered = filtered.where((u) => u.status == 'ACTIVE').toList();
        break;
      case _UserFilter.online:
        filtered = filtered.where((u) => u.isOnline).toList();
        break;
      case _UserFilter.suspended:
        filtered = filtered.where((u) => u.status == 'SUSPENDED').toList();
        break;
      case _UserFilter.blocked:
        filtered = filtered.where((u) => u.status == 'BLOCKED').toList();
        break;
      case _UserFilter.deleted:
        filtered = filtered.where((u) => u.status == 'DELETED').toList();
        break;
      case _UserFilter.all:
        break;
    }
    if (_search.isNotEmpty) {
      filtered = filtered.where((u) {
        return u.name.toLowerCase().contains(_search) ||
            u.mobile.toLowerCase().contains(_search);
      }).toList();
    }
    return filtered;
  }

  Map<String, int> _computeStats(List<UserProfile> users) {
    int active = 0, online = 0, suspended = 0, blocked = 0, deleted = 0;
    for (final u in users) {
      if (u.isOnline) online++;
      switch (u.status) {
        case 'ACTIVE':
          active++;
          break;
        case 'SUSPENDED':
          suspended++;
          break;
        case 'BLOCKED':
          blocked++;
          break;
        case 'DELETED':
          deleted++;
          break;
      }
    }
    return {
      'total': users.length,
      'active': active,
      'online': online,
      'suspended': suspended,
      'blocked': blocked,
      'deleted': deleted,
    };
  }

  // ── Moderation actions ────────────────────────────────────────────────────
  Future<void> _confirmAction(String title, String body, VoidCallback onOk) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white),
              child: const Text('Confirm')),
        ],
      ),
    );
    if (ok == true) onOk();
  }

  Future<void> _suspendUser(UserProfile u) async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Suspend User'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(labelText: 'Reason (optional)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, reasonCtrl.text),
              child: const Text('Suspend')),
        ],
      ),
    );
    if (reason == null) return;
    try {
      await ref.read(adminUsersProvider.notifier).suspendUser(u.id, reason: reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${u.name} suspended')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _blockUser(UserProfile u) async {
    _confirmAction('Block ${u.name}?', 'This will permanently restrict access.', () async {
      try {
        await ref.read(adminUsersProvider.notifier).blockUser(u.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${u.name} blocked')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    });
  }

  Future<void> _deleteUser(UserProfile u) async {
    _confirmAction('Delete ${u.name}?', 'This will soft-delete the account.', () async {
      try {
        await ref.read(adminUsersProvider.notifier).deleteUser(u.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${u.name} deleted')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    });
  }

  Future<void> _activateUser(UserProfile u) async {
    try {
      await ref.read(adminUsersProvider.notifier).activateUser(u.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${u.name} activated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(adminUsersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: usersAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (err, _) => _ErrorView(
          error: err.toString(),
          onRetry: () => ref.read(adminUsersProvider.notifier).refresh(),
        ),
        data: (allUsers) {
          final stats = _computeStats(allUsers);
          final filtered = _applyFilters(allUsers);

          return RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: () => ref.read(adminUsersProvider.notifier).refresh(),
            child: CustomScrollView(
              slivers: [
                // ── Stats row ────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text('User Management',
                        style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800)),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 88,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      children: [
                        _StatChip('Total', stats['total']!, Icons.people_rounded,
                            const Color(0xFF00A3FF), isDark),
                        _StatChip('Active', stats['active']!, Icons.check_circle_rounded,
                            AppTheme.primary, isDark),
                        _StatChip('Online', stats['online']!, Icons.circle,
                            const Color(0xFF00E5FF), isDark),
                        _StatChip('Suspended', stats['suspended']!,
                            Icons.pause_circle_rounded, Colors.orange, isDark),
                        _StatChip('Blocked', stats['blocked']!,
                            Icons.block_rounded, Colors.redAccent, isDark),
                        _StatChip('Deleted', stats['deleted']!,
                            Icons.delete_rounded, Colors.grey, isDark),
                      ],
                    ),
                  ),
                ),

                // ── Search ───────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: TextField(
                      onChanged: _onSearch,
                      decoration: InputDecoration(
                        hintText: 'Search by name or phone...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF1E2535)
                            : Colors.black.withOpacity(0.05),
                      ),
                    ),
                  ),
                ),

                // ── Filter chips ─────────────────────────────────────
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: _UserFilter.values
                          .map((f) => _FilterChipW(
                                label: f.name[0].toUpperCase() +
                                    f.name.substring(1),
                                selected: _filter == f,
                                onTap: () => setState(() => _filter = f),
                              ))
                          .toList(),
                    ),
                  ),
                ),

                // ── Count label ──────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Text(
                      '${filtered.length} user${filtered.length == 1 ? '' : 's'}',
                      style: tt.labelSmall,
                    ),
                  ),
                ),

                // ── User list ────────────────────────────────────────
                if (filtered.isEmpty)
                  SliverFillRemaining(child: _EmptyState(isDark: isDark))
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _UserCard(
                            user: filtered[i],
                            isDark: isDark,
                            onSuspend: () => _suspendUser(filtered[i]),
                            onBlock: () => _blockUser(filtered[i]),
                            onDelete: () => _deleteUser(filtered[i]),
                            onActivate: () => _activateUser(filtered[i]),
                          ),
                        ),
                        childCount: filtered.length,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Stat chip ────────────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _StatChip(this.label, this.count, this.icon, this.color, this.isDark);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2535) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: color.withOpacity(0.25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          Text('$count',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

// ─── Filter chip ──────────────────────────────────────────────────────────────
class _FilterChipW extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipW(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppTheme.primary.withOpacity(0.2),
        labelStyle: TextStyle(
          color: selected ? AppTheme.primary : null,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          fontSize: 12,
        ),
        side: BorderSide(
            color: selected
                ? AppTheme.primary.withOpacity(0.4)
                : Colors.transparent),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

// ─── User card ────────────────────────────────────────────────────────────────
class _UserCard extends StatefulWidget {
  final UserProfile user;
  final bool isDark;
  final VoidCallback onSuspend;
  final VoidCallback onBlock;
  final VoidCallback onDelete;
  final VoidCallback onActivate;

  const _UserCard({
    required this.user,
    required this.isDark,
    required this.onSuspend,
    required this.onBlock,
    required this.onDelete,
    required this.onActivate,
  });

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  bool _expanded = false;

  Color _statusColor() {
    if (widget.user.isOnline) return const Color(0xFF00E5FF);
    switch (widget.user.status) {
      case 'ACTIVE':
        return AppTheme.primary;
      case 'SUSPENDED':
        return Colors.orange;
      case 'BLOCKED':
        return Colors.redAccent;
      case 'DELETED':
        return Colors.grey;
      default:
        return AppTheme.primary;
    }
  }

  String _statusLabel() {
    if (widget.user.isOnline) return 'ONLINE';
    return widget.user.status;
  }

  String _timeAgo(DateTime? dt) {
    if (dt == null) return 'N/A';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final tt = Theme.of(context).textTheme;
    final sColor = _statusColor();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: widget.isDark ? AppTheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withOpacity(0.07)
              : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Column(
        children: [
          // ── Header row ────────────────────────────────────────
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Avatar with online dot
                  Stack(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            u.name.isNotEmpty
                                ? u.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      if (u.isOnline)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: const Color(0xFF00E5FF),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: widget.isDark
                                      ? AppTheme.surface
                                      : Colors.white,
                                  width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // Name & phone
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(u.name,
                            style: tt.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(u.mobile, style: tt.bodySmall),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: sColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(_statusLabel(),
                        style: tt.labelSmall?.copyWith(
                          color: sColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        )),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: Colors.white38,
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded detail ──────────────────────────────────
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildExpanded(u, tt, sColor),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildExpanded(UserProfile u, TextTheme tt, Color sColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        children: [
          const Divider(),
          const SizedBox(height: 8),
          // Info grid
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoTile(Icons.badge_rounded, 'Role',
                  u.role.toUpperCase(), widget.isDark),
              _InfoTile(Icons.location_city_rounded, 'State',
                  u.state.isEmpty ? 'N/A' : u.state, widget.isDark),
              _InfoTile(Icons.translate_rounded, 'Language',
                  u.language.isEmpty ? 'N/A' : u.language, widget.isDark),
              _InfoTile(Icons.landscape_rounded, 'Soil',
                  u.soilType.isEmpty ? 'N/A' : u.soilType, widget.isDark),
              _InfoTile(Icons.grain_rounded, 'Land',
                  '${u.landSize} acres', widget.isDark),
              _InfoTile(Icons.access_time_rounded, 'Last Seen',
                  _timeAgo(u.lastSeen), widget.isDark),
              _InfoTile(Icons.calendar_today_rounded, 'Joined',
                  _timeAgo(u.createdAt), widget.isDark),
            ],
          ),
          // Crops
          if (u.crops.isNotEmpty) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: u.crops
                    .map((c) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(c,
                              style: tt.labelSmall?.copyWith(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10)),
                        ))
                    .toList(),
              ),
            ),
          ],
          const SizedBox(height: 14),
          // Action buttons
          Row(
            children: [
              if (u.status != 'ACTIVE')
                _ActionBtn(Icons.restore_rounded, 'Restore',
                    AppTheme.primary, widget.onActivate),
              if (u.status == 'ACTIVE') ...[
                _ActionBtn(Icons.pause_circle_outline_rounded,
                    'Suspend', Colors.orange, widget.onSuspend),
                const SizedBox(width: 8),
                _ActionBtn(Icons.block_rounded, 'Block',
                    Colors.redAccent, widget.onBlock),
              ],
              const Spacer(),
              if (u.status != 'DELETED')
                _ActionBtn(Icons.delete_outline_rounded, 'Delete',
                    Colors.grey, widget.onDelete),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Info tile ────────────────────────────────────────────────────────────────
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  const _InfoTile(this.icon, this.label, this.value, this.isDark);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.04)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppTheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontSize: 9)),
                Text(value,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Action button ────────────────────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn(this.icon, this.label, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool isDark;
  const _EmptyState({required this.isDark});

  @override
  Widget build(BuildContext context) {
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
            child: const Icon(Icons.people_outline_rounded,
                size: 48, color: AppTheme.primary),
          ),
          const SizedBox(height: 20),
          Text('No users found',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Try adjusting your filters.',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

// ─── Error view ───────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: Colors.redAccent.withOpacity(0.7)),
            const SizedBox(height: 16),
            Text('Failed to load users',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(error,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
