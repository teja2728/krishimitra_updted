import 'package:go_router/go_router.dart';

import '../screens/account_screen.dart';
import '../screens/about_screen.dart';
import '../screens/bookmark_screen.dart';
import '../screens/feedback_screen.dart';
import '../screens/admin_feedback_screen.dart';
import '../screens/admin_manage_schemes_screen.dart';
import '../screens/admin_notifications_screen.dart';
import '../screens/admin_users_screen.dart';
import '../screens/home_shell.dart';
import '../screens/login_register_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/scheme_details_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/state_schemes_screen.dart';
import '../screens/registration_screen.dart';
import '../screens/gemini_chat_screen.dart';
import '../screens/crop_advisor_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    // ── Public ────────────────────────────────────────────────────────────────
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginRegisterScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegistrationScreen(),
    ),

    // ── Scheme detail (full-screen, no shell nav) ─────────────────────────────
    GoRoute(
      path: '/scheme/:schemeId',
      builder: (context, state) {
        final schemeId = state.pathParameters['schemeId'] ?? '';
        return SchemeDetailsScreen(schemeId: schemeId);
      },
    ),

    // ── User shell ────────────────────────────────────────────────────────────
    ShellRoute(
      builder: (context, state, child) => HomeShell(
        currentPath: state.uri.path,
        child: child,
      ),
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const StateSchemesScreen(),
        ),
        GoRoute(
          path: '/home/state',
          builder: (context, state) => const StateSchemesScreen(),
        ),
        GoRoute(
          path: '/home/about',
          builder: (context, state) => const AboutScreen(),
        ),
        GoRoute(
          path: '/home/feedback',
          builder: (context, state) => const FeedbackScreen(),
        ),
        GoRoute(
          path: '/home/account',
          builder: (context, state) => const AccountScreen(),
        ),

        // Gemini AI Chat
        GoRoute(
          path: '/home/ai',
          builder: (context, state) => const GeminiChatScreen(),
        ),

        // AI Crop Advisor
        GoRoute(
          path: '/home/crop-advisor',
          builder: (context, state) => const CropAdvisorScreen(),
        ),

        // Bookmarks & Notifications share the user shell (so they keep the nav)
        GoRoute(
          path: '/bookmarks',
          builder: (context, state) => const BookmarkScreen(),
        ),
        GoRoute(
          path: '/notifications',
          builder: (context, state) => const NotificationsScreen(),
        ),
      ],
    ),

    // ── Admin shell ───────────────────────────────────────────────────────────
    ShellRoute(
      builder: (context, state, child) => HomeShell(
        currentPath: state.uri.path,
        child: child,
      ),
      routes: [
        GoRoute(
          path: '/admin/schemes',
          builder: (context, state) => const AdminManageSchemesScreen(),
        ),
        GoRoute(
          path: '/admin/feedback',
          builder: (context, state) => const AdminFeedbackScreen(),
        ),
        GoRoute(
          path: '/admin/notifications',
          builder: (context, state) => const AdminNotificationsScreen(),
        ),
        GoRoute(
          path: '/admin/users',
          builder: (context, state) => const AdminUsersScreen(),
        ),
      ],
    ),
  ],
);
