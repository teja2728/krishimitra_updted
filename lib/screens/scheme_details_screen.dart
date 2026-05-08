import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/app_theme.dart';
import '../app/providers/app_providers.dart';
import '../l10n/app_strings.dart';
import '../models/scheme.dart';
import '../services/url_service.dart';
import '../services/pdf_download_service.dart';

class SchemeDetailsScreen extends ConsumerStatefulWidget {
  final String schemeId;
  const SchemeDetailsScreen({super.key, required this.schemeId});

  @override
  ConsumerState<SchemeDetailsScreen> createState() =>
      _SchemeDetailsScreenState();
}

class _SchemeDetailsScreenState extends ConsumerState<SchemeDetailsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();
    _fadeAnim =
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  /// Safe back navigation: tries GoRouter pop first, falls back to Navigator.pop
  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      // Fallback: navigate to home if there's nothing to pop to
      context.go('/home/state');
    }
  }

  /// Safely launch a URL with full error handling
  Future<void> _launchUrl(String rawUrl) async {
    final link = rawUrl.trim();
    if (link.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No link available for this scheme.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    try {
      await UrlService.openUrl(link);
    } catch (e) {
      dev.log('[SchemeDetails] Failed to open URL: $link — $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('Could not open link: ${e.toString()}')),
            ],
          ),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  /// Download PDF from a URL
  Future<void> _downloadPdf(String rawUrl, String schemeName) async {
    final safeName = '${schemeName.replaceAll(RegExp(r'[^\w\s]'), '_')}.pdf';
    await PdfDownloadService.downloadPdf(
      rawUrl: rawUrl,
      fileName: safeName,
      scaffoldMessenger: ScaffoldMessenger.of(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schemesAsync   = ref.watch(schemesProvider);
    final bookmarksAsync = ref.watch(bookmarksProvider);
    final remindersAsync = ref.watch(remindersProvider);
    final tr             = ref.watch(trProvider);
    final bookmarkedIds  = bookmarksAsync.value ?? <String>{};
    final reminderIds    = remindersAsync.value ?? <String>{};
    final isDark         = Theme.of(context).brightness == Brightness.dark;
    final tt             = Theme.of(context).textTheme;

    return PopScope(
      canPop: true,
      child: Scaffold(
        body: schemesAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppTheme.primary)),
          error:   (err, _) => Center(child: Text('Error: $err')),
          data:    (schemes) {
            final scheme = schemes
                .where((s) => s.id == widget.schemeId)
                .cast<Scheme?>()
                .firstWhere((_) => true, orElse: () => null);

            if (scheme == null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search_off_rounded,
                        size: 64,
                        color: Theme.of(context).colorScheme.outline),
                    const SizedBox(height: 16),
                    Text('Scheme not found',
                        style: tt.titleMedium),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: _goBack,
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Go Back'),
                    ),
                  ],
                ),
              );
            }

            final isBookmarked = bookmarkedIds.contains(scheme.id);
            final isReminded   = reminderIds.contains(scheme.id);
            final isCentral    = scheme.type == SchemeType.central;
            final typeColor    = isCentral
                ? const Color(0xFF00A3FF)
                : AppTheme.primary;

            // Check if applyLink looks like a PDF
            final isPdfLink = scheme.applyLink.trim().toLowerCase().endsWith('.pdf');

            return FadeTransition(
              opacity: _fadeAnim,
              child: CustomScrollView(
                slivers: [
                  // ── Hero app bar ─────────────────────────────────
                  SliverAppBar(
                    expandedHeight: 200,
                    pinned: true,
                    backgroundColor:
                        isDark ? AppTheme.background : AppTheme.backgroundLight,
                    leading: IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.black.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.arrow_back_rounded,
                            size: 18,
                            color: isDark ? Colors.white : Colors.black),
                      ),
                      onPressed: _goBack,
                    ),
                    actions: [
                      _AppBarAction(
                        icon: isBookmarked
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_outline_rounded,
                        color: isBookmarked ? AppTheme.accent : null,
                        onTap: () async {
                          await ref
                              .read(bookmarksProvider.notifier)
                              .toggle(scheme.id);
                        },
                      ),
                      const SizedBox(width: 4),
                      _AppBarAction(
                        icon: isReminded
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_none_rounded,
                        color: isReminded ? AppTheme.primary : null,
                        onTap: () async {
                          await ref
                              .read(remindersProvider.notifier)
                              .toggle(scheme.id);
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              typeColor.withOpacity(0.85),
                              typeColor.withOpacity(0.3),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _TypeBadge(
                                  label: isCentral ? tr('central') : tr('state'),
                                  color: typeColor),
                              const SizedBox(height: 10),
                              Text(
                                scheme.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Body ─────────────────────────────────────────
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // State tag
                        if (scheme.type == SchemeType.state &&
                            scheme.state.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              children: [
                                Icon(Icons.place_rounded,
                                    size: 16,
                                    color: typeColor),
                                const SizedBox(width: 6),
                                Text(scheme.state,
                                    style: tt.labelMedium?.copyWith(
                                        color: typeColor,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),

                        // Description card
                        _SectionCard(
                          title: tr('overview'),
                          icon: Icons.info_outline_rounded,
                          typeColor: typeColor,
                          child: Text(scheme.description,
                              style: tt.bodyMedium?.copyWith(height: 1.6)),
                        ),
                        const SizedBox(height: 12),

                        // Benefits
                        if (scheme.benefits.isNotEmpty) ...[
                          _SectionCard(
                            title: tr('benefits'),
                            icon: Icons.star_outline_rounded,
                            typeColor: typeColor,
                            child: Column(
                              children: scheme.benefits
                                  .map((b) => _BulletItem(text: b,
                                      color: typeColor))
                                  .toList(),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Eligibility
                        if (scheme.eligibility.isNotEmpty) ...[
                          _SectionCard(
                            title: tr('eligibility'),
                            icon: Icons.verified_user_outlined,
                            typeColor: typeColor,
                            child: Column(
                              children: scheme.eligibility
                                  .map((e) => _BulletItem(text: e,
                                      color: typeColor))
                                  .toList(),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Documents
                        if (scheme.documents.isNotEmpty) ...[
                          _SectionCard(
                            title: tr('documents'),
                            icon: Icons.description_outlined,
                            typeColor: typeColor,
                            child: Column(
                              children: scheme.documents
                                  .map((d) => _BulletItem(text: d,
                                      color: typeColor))
                                  .toList(),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Deadline
                        if (scheme.deadline.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: AppTheme.accent.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.schedule_rounded,
                                    color: AppTheme.accent, size: 20),
                                const SizedBox(width: 10),
                                Text('${tr('last_date')}: ${scheme.deadline}',
                                    style: tt.labelMedium?.copyWith(
                                      color: AppTheme.accent,
                                      fontWeight: FontWeight.w600,
                                    )),
                              ],
                            ),
                          ),

                        // Download PDF button (if link ends with .pdf)
                        if (isPdfLink) ...[
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: () => _downloadPdf(
                                scheme.applyLink, scheme.name),
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withOpacity(0.08)
                                    : Colors.black.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: typeColor.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.download_rounded,
                                      color: typeColor, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    tr('download_pdf'),
                                    style: TextStyle(
                                      color: typeColor,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ]),
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        // ── Sticky Apply button ────────────────────────────────────
        bottomNavigationBar: schemesAsync.whenData((schemes) {
          final scheme = schemes
              .where((s) => s.id == widget.schemeId)
              .cast<Scheme?>()
              .firstWhere((_) => true, orElse: () => null);
          if (scheme == null) return null;
          final isCentral = scheme.type == SchemeType.central;
          final typeColor =
              isCentral ? const Color(0xFF00A3FF) : AppTheme.primary;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                height: 54,
                child: GestureDetector(
                  onTap: () => _launchUrl(scheme.applyLink),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [typeColor, typeColor.withOpacity(0.75)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: typeColor.withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.open_in_new_rounded,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          tr('apply_now'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }).valueOrNull,
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _AppBarAction extends StatelessWidget {
  final IconData icon;
  final Color?   color;
  final VoidCallback onTap;

  const _AppBarAction(
      {required this.icon, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon,
            size: 18, color: color ?? (isDark ? Colors.white : Colors.black)),
      ),
      onPressed: onTap,
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String label;
  final Color  color;
  const _TypeBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
      ),
      child: Text(label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          )),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String   title;
  final IconData icon;
  final Color    typeColor;
  final Widget   child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.typeColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: typeColor),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      )),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _BulletItem extends StatelessWidget {
  final String text;
  final Color  color;
  const _BulletItem({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 5),
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(height: 1.5)),
          ),
        ],
      ),
    );
  }
}
