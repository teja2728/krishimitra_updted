import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app_theme.dart';
import '../l10n/app_strings.dart';
import '../models/scheme.dart';
import '../models/user_profile.dart';
import '../services/personalization_service.dart';

// ─── Urgency helper ───────────────────────────────────────────────────────────
int? _daysUntilDeadline(String deadline) {
  if (deadline.trim().isEmpty || deadline.toLowerCase() == 'open') return null;
  try {
    final d = DateTime.tryParse(deadline);
    if (d == null) return null;
    return d.difference(DateTime.now()).inDays;
  } catch (_) {
    return null;
  }
}

// ─── Main card widget ─────────────────────────────────────────────────────────
class SchemeCard extends ConsumerStatefulWidget {
  final Scheme       scheme;
  final bool         isBookmarked;
  final bool         isReminded;
  final VoidCallback onTap;
  final VoidCallback onToggleBookmark;
  final VoidCallback onToggleReminder;
  final VoidCallback onApply;
  final UserProfile? userProfile;
  final PersonalizationService? personalizationService;

  const SchemeCard({
    super.key,
    required this.scheme,
    required this.isBookmarked,
    required this.isReminded,
    required this.onTap,
    required this.onToggleBookmark,
    required this.onToggleReminder,
    required this.onApply,
    this.userProfile,
    this.personalizationService,
  });

  @override
  ConsumerState<SchemeCard> createState() => _SchemeCardState();
}

class _SchemeCardState extends ConsumerState<SchemeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hover;
  late final Animation<double>   _scale;

  PersonalizationResult? _personalization;
  bool _loadingPersonalization = false;
  bool _showSteps = false;

  @override
  void initState() {
    super.initState();
    _hover = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.975).animate(
      CurvedAnimation(parent: _hover, curve: Curves.easeOut),
    );
    if (widget.personalizationService != null && widget.userProfile != null) {
      _fetchPersonalization();
    }
  }

  @override
  void dispose() {
    _hover.dispose();
    super.dispose();
  }

  Future<void> _fetchPersonalization() async {
    if (_loadingPersonalization) return;
    setState(() => _loadingPersonalization = true);
    try {
      final result = await widget.personalizationService!.personalize(
        schemeId:    widget.scheme.id,
        schemeName:  widget.scheme.name,
        description: widget.scheme.description,
        benefits:    widget.scheme.benefits,
        eligibility: widget.scheme.eligibility,
        deadline:    widget.scheme.deadline,
        userState:   widget.userProfile!.state,
        userCrops:   widget.userProfile!.crops,
        userSoilType:widget.userProfile!.soilType,
        userLandSize:widget.userProfile!.landSize,
      );
      if (mounted) setState(() => _personalization = result);
    } catch (_) {}
    if (mounted) setState(() => _loadingPersonalization = false);
  }

  bool get _isCentral => widget.scheme.type == SchemeType.central;
  Color get _typeColor =>
      _isCentral ? const Color(0xFF00A3FF) : const Color(0xFF00C896);
  IconData get _typeIcon =>
      _isCentral ? Icons.account_balance_rounded : Icons.location_city_rounded;

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final tt     = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tr     = ref.watch(trProvider);
    final days   = _daysUntilDeadline(widget.scheme.deadline);
    final isUrgent  = days != null && days <= 3 && days >= 0;
    final isExpired = days != null && days < 0;

    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTapDown:  (_) => _hover.forward(),
        onTapUp:    (_) => _hover.reverse(),
        onTapCancel: () => _hover.reverse(),
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.surface : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isUrgent
                  ? Colors.orangeAccent.withOpacity(0.5)
                  : isDark
                      ? Colors.white.withOpacity(0.07)
                      : Colors.black.withOpacity(0.06),
              width: isUrgent ? 1.5 : 1,
            ),
            boxShadow: isDark
                ? [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 4))]
                : [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 20, offset: const Offset(0, 6))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Gradient top bar ──────────────────────────────────────────
              Container(
                height: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isUrgent
                        ? [Colors.orangeAccent, Colors.deepOrange]
                        : [_typeColor, _typeColor.withOpacity(0.4)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
              ),

              // ── Urgent deadline banner ────────────────────────────────────
              if (isUrgent)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  color: Colors.orangeAccent.withOpacity(0.12),
                  child: Row(
                    children: [
                      const Icon(Icons.alarm_rounded, size: 14, color: Colors.orangeAccent),
                      const SizedBox(width: 6),
                      Text(
                        days == 0
                            ? tr('deadline_today')
                            : '${tr('deadline_days')} $days ${tr('days')}!',
                        style: tt.labelSmall?.copyWith(
                          color: Colors.orangeAccent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

              if (isExpired)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  color: Colors.redAccent.withOpacity(0.10),
                  child: Row(
                    children: [
                      const Icon(Icons.block_rounded, size: 14, color: Colors.redAccent),
                      const SizedBox(width: 6),
                      Text(
                        tr('deadline_passed'),
                        style: tt.labelSmall?.copyWith(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ────────────────────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            color: _typeColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(_typeIcon, color: _typeColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.scheme.name,
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _ActionIcon(
                          icon: widget.isBookmarked
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_outline_rounded,
                          color: widget.isBookmarked
                              ? AppTheme.accent
                              : cs.onSurfaceVariant,
                          onTap: widget.onToggleBookmark,
                          tooltip: widget.isBookmarked ? tr('remove_bookmark') : tr('bookmark'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // ── "Why for you" personalization chip ────────────────
                    if (_personalization != null &&
                        _personalization!.whyRelevant.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppTheme.primary.withOpacity(0.20)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.stars_rounded,
                                size: 14, color: AppTheme.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _personalization!.whyRelevant,
                                style: tt.labelSmall?.copyWith(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_personalization!.relevanceScore}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (_loadingPersonalization)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 12, height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    AppTheme.primary),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              tr('analyzing_profile'),
                              style: tt.labelSmall?.copyWith(
                                  color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),

                    // ── Description ────────────────────────────────────────
                    Text(
                      widget.scheme.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(
                        height: 1.55,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Tags ───────────────────────────────────────────────
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _Tag(label: _isCentral ? 'Central' : 'State', color: _typeColor),
                        if (!_isCentral && widget.scheme.state.trim().isNotEmpty)
                          _Tag(label: widget.scheme.state,
                              color: cs.onSurfaceVariant, small: true),
                        if (widget.scheme.deadline.isNotEmpty)
                          _Tag(
                            label: days != null
                                ? (days < 0
                                    ? 'Expired'
                                    : days == 0
                                        ? 'Today!'
                                        : '$days days left')
                                : widget.scheme.deadline,
                            icon: Icons.schedule_rounded,
                            color: isUrgent
                                ? Colors.orangeAccent
                                : isExpired
                                    ? Colors.redAccent
                                    : cs.onSurfaceVariant,
                            small: true,
                          ),
                        if (_personalization != null &&
                            _personalization!.highlight.isNotEmpty)
                          _Tag(
                            label: '✨ ${_personalization!.highlight}',
                            color: AppTheme.accent,
                            small: true,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── How to Apply (expandable) ──────────────────────────
                    if (_personalization != null &&
                        _personalization!.steps.isNotEmpty) ...[
                      GestureDetector(
                        onTap: () => setState(() => _showSteps = !_showSteps),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.black.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withOpacity(0.08)
                                  : Colors.black.withOpacity(0.06),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.list_alt_rounded,
                                  size: 15, color: AppTheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                tr('how_to_apply'),
                                style: tt.labelMedium?.copyWith(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                _showSteps
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                size: 18,
                                color: AppTheme.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_showSteps)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _personalization!.steps
                                .asMap()
                                .entries
                                .map((e) => Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 20, height: 20,
                                            decoration: const BoxDecoration(
                                              color: AppTheme.primary,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Text(
                                                '${e.key + 1}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(e.value,
                                                style: tt.bodySmall?.copyWith(
                                                    height: 1.5)),
                                          ),
                                        ],
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                      const SizedBox(height: 8),
                    ],

                    // ── Action row ─────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _GradientButton(
                            label: tr('apply_now'),
                            icon: Icons.open_in_new_rounded,
                            onTap: widget.onApply,
                            typeColor: _typeColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _ActionIcon(
                          icon: widget.isReminded
                              ? Icons.notifications_active_rounded
                              : Icons.notifications_none_rounded,
                          color: widget.isReminded
                              ? AppTheme.primary
                              : cs.onSurfaceVariant,
                          onTap: widget.onToggleReminder,
                          tooltip: widget.isReminded
                              ? tr('remove_reminder')
                              : tr('set_reminder'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Tag chip ─────────────────────────────────────────────────────────────────
class _Tag extends StatelessWidget {
  final String    label;
  final Color     color;
  final IconData? icon;
  final bool      small;

  const _Tag({
    required this.label,
    required this.color,
    this.icon,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical:   small ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border:       Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color:      color,
                  fontWeight: FontWeight.w600,
                  fontSize:   small ? 10 : 11,
                ),
          ),
        ],
      ),
    );
  }
}

// ─── Gradient apply button ────────────────────────────────────────────────────
class _GradientButton extends StatelessWidget {
  final String     label;
  final IconData   icon;
  final VoidCallback onTap;
  final Color      typeColor;

  const _GradientButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.typeColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [typeColor, typeColor.withOpacity(0.7)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color:      Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize:   12,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Small icon action button ─────────────────────────────────────────────────
class _ActionIcon extends StatelessWidget {
  final IconData     icon;
  final Color        color;
  final VoidCallback onTap;
  final String       tooltip;

  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color:        color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}
