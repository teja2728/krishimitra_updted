import 'package:flutter/material.dart';

import '../app/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tt     = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs     = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Hero banner ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary.withOpacity(0.85),
                    const Color(0xFF00A3FF).withOpacity(0.75),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.eco_rounded,
                        color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'KrishiMitra',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Empowering Indian farmers with the right information at the right time.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _HeroBadge(label: '32+ Schemes'),
                      _HeroBadge(label: '29 States'),
                      _HeroBadge(label: 'Free & Open'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // ── What is KrishiMitra ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle(title: 'What is KrishiMitra?'),
                  const SizedBox(height: 12),
                  _InfoCard(
                    isDark: isDark,
                    child: Text(
                      'KrishiMitra is a digital platform that connects Indian farmers with government welfare schemes — both State and Central — in one place. We cut through the noise so farmers can find, understand, and apply for schemes they are eligible for.',
                      style: tt.bodyMedium?.copyWith(height: 1.65),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // ── Feature cards ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle(title: 'Key Features'),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.05,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: const [
                      _FeatureCard(
                        icon: Icons.search_rounded,
                        title: 'Smart Search',
                        desc: 'Find schemes by state, category, or deadline instantly.',
                        color: Color(0xFF00C896),
                      ),
                      _FeatureCard(
                        icon: Icons.filter_list_rounded,
                        title: 'Filter & Sort',
                        desc: 'Filter Central vs State schemes. Sort A–Z or Z–A.',
                        color: Color(0xFF00A3FF),
                      ),
                      _FeatureCard(
                        icon: Icons.bookmark_rounded,
                        title: 'Bookmarks',
                        desc: 'Save your favourite schemes and access them offline.',
                        color: Color(0xFFFFD166),
                      ),
                      _FeatureCard(
                        icon: Icons.notifications_rounded,
                        title: 'Reminders',
                        desc: 'Set reminders so you never miss an application deadline.',
                        color: Color(0xFFFF6B9D),
                      ),
                      _FeatureCard(
                        icon: Icons.person_rounded,
                        title: 'Profile',
                        desc: 'Personalise by state, crops, and soil type for tailored results.',
                        color: Color(0xFF9B59B6),
                      ),
                      _FeatureCard(
                        icon: Icons.admin_panel_settings_rounded,
                        title: 'Admin Panel',
                        desc: 'Admins can add, edit, or remove schemes and notify users.',
                        color: Color(0xFF2ECC71),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // ── Who benefits ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle(title: 'Who Benefits?'),
                  const SizedBox(height: 12),
                  _InfoCard(
                    isDark: isDark,
                    child: Column(
                      children: [
                        _BeneficiaryRow(
                          icon: Icons.agriculture_rounded,
                          color: AppTheme.primary,
                          title: 'Small & Marginal Farmers',
                          desc: 'Access financial aid, crop insurance, and subsidies in minutes.',
                        ),
                        const Divider(height: 20),
                        _BeneficiaryRow(
                          icon: Icons.school_rounded,
                          color: const Color(0xFF00A3FF),
                          title: 'Agriculture Students',
                          desc: 'Research active schemes and understand policy structures.',
                        ),
                        const Divider(height: 20),
                        _BeneficiaryRow(
                          icon: Icons.groups_rounded,
                          color: const Color(0xFFFFD166),
                          title: 'NGOs & Field Workers',
                          desc: 'Quickly identify relevant schemes to help communities they serve.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // ── Mission ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.primary.withOpacity(0.1)
                      : AppTheme.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppTheme.primary.withOpacity(0.25)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.format_quote_rounded,
                        color: AppTheme.primary, size: 32),
                    const SizedBox(height: 10),
                    Text(
                      '"Every farmer deserves to know their rights. KrishiMitra makes that knowledge accessible, simple, and free."',
                      textAlign: TextAlign.center,
                      style: tt.bodyMedium?.copyWith(
                        height: 1.7,
                        fontStyle: FontStyle.italic,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('— KrishiMitra Team',
                        style: tt.labelMedium?.copyWith(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w700,
                        )),
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _HeroBadge extends StatelessWidget {
  final String label;
  const _HeroBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.35)),
      ),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final bool   isDark;
  final Widget child;
  const _InfoCard({required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
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
      child: child,
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String   title;
  final String   desc;
  final Color    color;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.desc,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tt     = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
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
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withOpacity(0.13),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 10),
          Text(title,
              style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 5),
          Expanded(
            child: Text(desc,
                style: tt.bodySmall?.copyWith(height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _BeneficiaryRow extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   title;
  final String   desc;

  const _BeneficiaryRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(desc,
                  style: tt.bodySmall?.copyWith(height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}
