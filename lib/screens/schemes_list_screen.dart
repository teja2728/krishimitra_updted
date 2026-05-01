import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/app_theme.dart';
import '../app/providers/app_providers.dart';
import '../l10n/app_strings.dart';
import '../models/scheme.dart';
import '../services/url_service.dart';
import '../widgets/scheme_card.dart';
import '../widgets/skeleton_loader.dart';

// ─── Filter / Sort State ──────────────────────────────────────────────────────

enum SchemeFilter { all, state, central }
enum SchemeSort   { nameAsc, nameDesc }

class _FilterState {
  final SchemeFilter filter;
  final SchemeSort   sort;
  const _FilterState({this.filter = SchemeFilter.all, this.sort = SchemeSort.nameAsc});

  _FilterState copyWith({SchemeFilter? filter, SchemeSort? sort}) =>
      _FilterState(filter: filter ?? this.filter, sort: sort ?? this.sort);

  bool get isDefault => filter == SchemeFilter.all && sort == SchemeSort.nameAsc;

  String get summary {
    final parts = <String>[];
    if (filter == SchemeFilter.state)   parts.add('State');
    if (filter == SchemeFilter.central) parts.add('Central');
    parts.add(sort == SchemeSort.nameAsc ? 'A→Z' : 'Z→A');
    return parts.join(' · ');
  }
}

// ─── Main Screen ──────────────────────────────────────────────────────────────

class SchemesListScreen extends ConsumerStatefulWidget {
  final SchemeType filterType;
  final String title;
  /// Override the default active filter (e.g. SchemeFilter.all for Home tab)
  final SchemeFilter? initialFilter;

  const SchemesListScreen({
    super.key,
    required this.filterType,
    required this.title,
    this.initialFilter,
  });

  @override
  ConsumerState<SchemesListScreen> createState() => _SchemesListScreenState();
}

class _SchemesListScreenState extends ConsumerState<SchemesListScreen> {
  late _FilterState _fs;
  bool _fetching = false;

  @override
  void initState() {
    super.initState();
    final defaultFilter = widget.initialFilter ??
        (widget.filterType == SchemeType.state
            ? SchemeFilter.state
            : SchemeFilter.central);
    _fs = _FilterState(filter: defaultFilter);
  }

  Future<void> _fetchSchemes() async {
    if (_fetching) return;
    setState(() => _fetching = true);
    ref.invalidate(schemesProvider);
    // Small delay to let the provider rebuild
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) setState(() => _fetching = false);
  }

  // ─── Transform pipeline ────────────────────────────────────────────────────
  List<Scheme> _transform(List<Scheme> all, String farmerState) {
    var result = all.toList();

    // 1. Category filter
    if (_fs.filter == SchemeFilter.state) {
      result = result.where((s) => s.type == SchemeType.state).toList();
      result = result.where((s) => s.matchesFarmerState(farmerState)).toList();
    } else if (_fs.filter == SchemeFilter.central) {
      result = result.where((s) => s.type == SchemeType.central).toList();
    }

    // 2. Sort
    result.sort((a, b) {
      final cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return _fs.sort == SchemeSort.nameAsc ? cmp : -cmp;
    });

    return result;
  }

  // ─── Open filter bottom sheet ──────────────────────────────────────────────
  void _openFilterPanel() async {
    final updated = await showModalBottomSheet<_FilterState>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterPanel(initial: _fs),
    );
    if (updated != null) setState(() => _fs = updated);
  }

  @override
  Widget build(BuildContext context) {
    final schemesAsync   = ref.watch(schemesProvider);
    final profileAsync   = ref.watch(userProfileProvider);
    final bookmarksAsync = ref.watch(bookmarksProvider);
    final remindersAsync = ref.watch(remindersProvider);
    final tr             = ref.watch(trProvider);

    final bookmarkedIds = bookmarksAsync.value ?? <String>{};
    final reminderIds   = remindersAsync.value ?? <String>{};

    final hasActiveFilters = !_fs.isDefault &&
        !(_fs.filter ==
                (widget.filterType == SchemeType.state
                    ? SchemeFilter.state
                    : SchemeFilter.central) &&
            _fs.sort == SchemeSort.nameAsc);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Hero header ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary.withOpacity(0.15),
                    const Color(0xFF00A3FF).withOpacity(0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: AppTheme.primary.withOpacity(0.18)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tr('browse_schemes'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _IconBtn(
                    icon: Icons.notifications_outlined,
                    tooltip: tr('notifications'),
                    onTap: () => context.go('/notifications'),
                  ),
                  const SizedBox(width: 4),
                  _IconBtn(
                    icon: Icons.bookmark_outline_rounded,
                    tooltip: tr('bookmarks'),
                    onTap: () => context.go('/bookmarks'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // ── Fetch Schemes button ─────────────────────────────────────
            GestureDetector(
              onTap: _fetching ? null : _fetchSchemes,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 48,
                decoration: BoxDecoration(
                  gradient: _fetching ? null : AppTheme.primaryGradient,
                  color: _fetching
                      ? (Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withOpacity(0.07)
                          : Colors.black.withOpacity(0.05))
                      : null,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _fetching
                      ? null
                      : [
                          BoxShadow(
                            color: AppTheme.primary.withOpacity(0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_fetching)
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.primary),
                        ),
                      )
                    else
                      const Icon(Icons.download_rounded,
                          size: 18, color: Colors.white),
                    const SizedBox(width: 10),
                    Text(
                      _fetching ? tr('fetching_schemes') : tr('fetch_schemes'),
                      style: TextStyle(
                        color: _fetching
                            ? AppTheme.primary
                            : Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // ── Filter bar row ────────────────────────────────────────────
            Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GestureDetector(
                      onTap: _openFilterPanel,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: hasActiveFilters
                              ? AppTheme.primary.withOpacity(0.12)
                              : (Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color(0xFF1E2535)
                                  : Colors.white),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: hasActiveFilters
                                ? AppTheme.primary
                                : Theme.of(context)
                                    .colorScheme
                                    .outline
                                    .withOpacity(0.25),
                            width: hasActiveFilters ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.tune_rounded,
                                size: 16,
                                color: hasActiveFilters
                                    ? AppTheme.primary
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant),
                            const SizedBox(width: 6),
                            Text(tr('filter_sort'),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                      color: hasActiveFilters
                                          ? AppTheme.primary
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                      fontWeight: hasActiveFilters
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    )),
                          ],
                        ),
                      ),
                    ),
                    if (hasActiveFilters)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _fs.summary,
                      key: ValueKey(_fs.summary),
                      style:
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Schemes list ──────────────────────────────────────────────
            Expanded(
              child: schemesAsync.when(
                loading: () => _SkeletonList(),
                error: (err, _) =>
                    Center(child: Text('Failed to load schemes: $err')),
                data: (schemes) {
                  final farmerState =
                      profileAsync.valueOrNull?.state ?? '';
                  final filtered = _transform(schemes, farmerState);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '${filtered.length} ${filtered.length == 1 ? tr('scheme_count_single') : tr('scheme_count_plural')}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ),
                      Expanded(
                        child: filtered.isEmpty
                            ? _EmptyState(
                                filter: _fs.filter,
                                farmerState: farmerState,
                                onFetch: _fetchSchemes,
                              )
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, i) {
                                  final scheme = filtered[i];
                                  return SchemeCard(
                                    scheme: scheme,
                                    isBookmarked:
                                        bookmarkedIds.contains(scheme.id),
                                    isReminded:
                                        reminderIds.contains(scheme.id),
                                    onTap: () => context.go(
                                      '/scheme/${Uri.encodeComponent(scheme.id)}',
                                    ),
                                    onApply: () async {
                                      final link = scheme.applyLink.trim();
                                      if (link.isEmpty) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                          content: Text(tr('no_apply_link')),
                                        ));
                                        return;
                                      }
                                      try {
                                        await UrlService.openUrl(link);
                                      } catch (e) {
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                          content: Text(e.toString()),
                                        ));
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
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Filter Panel (Bottom Sheet) ──────────────────────────────────────────────

class _FilterPanel extends ConsumerStatefulWidget {
  final _FilterState initial;
  const _FilterPanel({required this.initial});

  @override
  ConsumerState<_FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends ConsumerState<_FilterPanel> {
  late SchemeFilter _filter;
  late SchemeSort   _sort;

  @override
  void initState() {
    super.initState();
    _filter = widget.initial.filter;
    _sort   = widget.initial.sort;
  }

  void _apply() => Navigator.pop(
        context,
        _FilterState(filter: _filter, sort: _sort),
      );

  void _clear() => setState(() {
        _filter = SchemeFilter.all;
        _sort   = SchemeSort.nameAsc;
      });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs    = theme.colorScheme;
    final tr    = ref.watch(trProvider);

    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outline.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.tune_rounded,
                    size: 18, color: AppTheme.primary),
              ),
              const SizedBox(width: 10),
              Text(tr('filter_sort'),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton(
                onPressed: _clear,
                child: Text(tr('clear_all'),
                    style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                  child: Text(tr('category'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      )),
                ),
                _FilterCheckTile(
                  label: tr('all_schemes'),
                  icon: Icons.all_inclusive_rounded,
                  checked: _filter == SchemeFilter.all,
                  onTap: () => setState(() => _filter = SchemeFilter.all),
                ),
                _FilterCheckTile(
                  label: tr('state_govt_schemes'),
                  icon: Icons.location_city_outlined,
                  checked: _filter == SchemeFilter.state,
                  onTap: () => setState(() => _filter =
                      _filter == SchemeFilter.state
                          ? SchemeFilter.all
                          : SchemeFilter.state),
                ),
                _FilterCheckTile(
                  label: tr('central_govt_schemes'),
                  icon: Icons.account_balance_outlined,
                  checked: _filter == SchemeFilter.central,
                  onTap: () => setState(() => _filter =
                      _filter == SchemeFilter.central
                          ? SchemeFilter.all
                          : SchemeFilter.central),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                  child: Text(tr('sort_by_name'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      )),
                ),
                _SortRadioTile(
                  label: tr('sort_a_z'),
                  icon: Icons.arrow_upward_rounded,
                  value: SchemeSort.nameAsc,
                  groupValue: _sort,
                  onChanged: (v) => setState(() => _sort = v),
                ),
                _SortRadioTile(
                  label: tr('sort_z_a'),
                  icon: Icons.arrow_downward_rounded,
                  value: SchemeSort.nameDesc,
                  groupValue: _sort,
                  onChanged: (v) => setState(() => _sort = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _apply,
            child: Container(
              height: 52,
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
              child: Text(tr('apply_filters'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  )),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Checkbox tile ────────────────────────────────────────────────────────────

class _FilterCheckTile extends StatelessWidget {
  final String   label;
  final IconData icon;
  final bool     checked;
  final VoidCallback onTap;

  const _FilterCheckTile({
    required this.label,
    required this.icon,
    required this.checked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: cs.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight:
                            checked ? FontWeight.w600 : FontWeight.normal,
                      )),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: checked ? cs.primary : Colors.transparent,
                border: Border.all(
                  color: checked ? cs.primary : cs.outline.withOpacity(0.6),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: checked
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Radio tile ───────────────────────────────────────────────────────────────

class _SortRadioTile extends StatelessWidget {
  final String     label;
  final IconData   icon;
  final SchemeSort value;
  final SchemeSort groupValue;
  final ValueChanged<SchemeSort> onChanged;

  const _SortRadioTile({
    required this.label,
    required this.icon,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Icon(icon,
                size: 20,
                color: selected ? cs.primary : cs.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.normal,
                        color: selected ? cs.primary : null,
                      )),
            ),
            Radio<SchemeSort>(
              value: value,
              groupValue: groupValue,
              onChanged: (_) => onChanged(value),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Small icon button ────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String   tooltip;
  final VoidCallback onTap;

  const _IconBtn(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.10)
                  : Colors.black.withOpacity(0.08),
            ),
          ),
          child: Icon(icon,
              size: 18,
              color: Theme.of(context).colorScheme.onSurface),
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final SchemeFilter filter;
  final String farmerState;
  final VoidCallback onFetch;

  const _EmptyState({
    required this.filter,
    required this.farmerState,
    required this.onFetch,
  });

  @override
  Widget build(BuildContext context) {
    final msg = filter == SchemeFilter.state && farmerState.trim().isNotEmpty
        ? 'No state schemes found for $farmerState.\nTap below to fetch from the server.'
        : 'No schemes found.\nTap below to fetch from the server.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(msg,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onFetch,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 13),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.download_rounded,
                        size: 16, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Fetch Schemes',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Skeleton loader list ─────────────────────────────────────────────────────

class _SkeletonList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView.separated(
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surface : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SkeletonLoader(width: 42, height: 42, borderRadius: 12),
                const SizedBox(width: 12),
                Expanded(
                  child: SkeletonLoader(
                      width: double.infinity, height: 18, borderRadius: 6),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SkeletonLoader(width: double.infinity, height: 13, borderRadius: 6),
            const SizedBox(height: 6),
            SkeletonLoader(width: 200, height: 13, borderRadius: 6),
            const SizedBox(height: 12),
            SkeletonLoader(width: 100, height: 28, borderRadius: 8),
          ],
        ),
      ),
    );
  }
}
