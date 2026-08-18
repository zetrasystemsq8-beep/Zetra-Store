import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/discover.dart';
import '../features/developer.dart';
import '../features/developer_auth.dart';
import '../features/tester_actions.dart';
import '../features/welcome_role.dart';

/// ---------------------------------------------------------------------
/// ENVIRONMENT / SUPABASE CONFIG
/// ---------------------------------------------------------------------
class Env {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String workerUrl = String.fromEnvironment('WORKER_URL');
  static const String workerApiKey =
      String.fromEnvironment('WORKER_API_KEY');
  static const String adminPin = String.fromEnvironment('ADMIN_PIN');
}

/// ---------------------------------------------------------------------
/// BRAND PALETTE
/// ---------------------------------------------------------------------
class ZetraColors {
  ZetraColors._();

  static const bgTop = Color(0xFF0B0F14);
  static const bgBottom = Color(0xFF141B23);
  static const card = Color(0xFF1B2530);
  static const cardBorder = Color(0xFF2A3844);
  static const accentStart = Color(0xFF3B82F6);
  static const accentEnd = Color(0xFF60A5FA);
  static const textPrimary = Color(0xFFF5F7FA);
  static const textSecondary = Color(0xFF8B96A3);
  static const textMuted = Color(0xFF5C6773);
  static const errorSoft = Color(0xFFFF8A8A);

  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentStart, accentEnd],
  );
}

/// ---------------------------------------------------------------------
/// THEME
/// ---------------------------------------------------------------------
class AppTheme {
  AppTheme._();

  static ThemeData light = _buildLight();
  static ThemeData dark = _buildDark();

  static ThemeData _buildDark() {
    final textTheme = GoogleFonts.interTextTheme(Typography.whiteMountainView).copyWith(
      headlineSmall: GoogleFonts.manrope(
        fontWeight: FontWeight.w800,
        fontSize: 26,
        letterSpacing: -0.3,
        color: ZetraColors.textPrimary,
      ),
      titleLarge: GoogleFonts.manrope(
        fontWeight: FontWeight.w700,
        color: ZetraColors.textPrimary,
      ),
      titleMedium: GoogleFonts.manrope(
        fontWeight: FontWeight.w700,
        color: ZetraColors.textPrimary,
      ),
      titleSmall: GoogleFonts.manrope(
        fontWeight: FontWeight.w600,
        color: ZetraColors.textPrimary,
      ),
      bodyMedium: GoogleFonts.inter(
        color: ZetraColors.textSecondary,
        height: 1.45,
      ),
      labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w700),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: ZetraColors.bgTop,
      colorScheme: ColorScheme.dark(
        primary: ZetraColors.accentEnd,
        onPrimary: Colors.white,
        secondary: ZetraColors.accentStart,
        onSecondary: Colors.white,
        surface: ZetraColors.card,
        onSurface: ZetraColors.textPrimary,
        error: ZetraColors.errorSoft,
        onError: Colors.white,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.manrope(
          fontWeight: FontWeight.w800,
          fontSize: 22,
          color: ZetraColors.textPrimary,
        ),
        iconTheme: const IconThemeData(color: ZetraColors.textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ZetraColors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: ZetraColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: ZetraColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: ZetraColors.accentEnd, width: 1.6),
        ),
        hintStyle: GoogleFonts.inter(color: ZetraColors.textMuted),
        labelStyle: GoogleFonts.inter(color: ZetraColors.textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ZetraColors.accentEnd,
          foregroundColor: Colors.white,
          disabledBackgroundColor: ZetraColors.accentEnd.withOpacity(0.4),
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ZetraColors.textPrimary,
          minimumSize: const Size.fromHeight(56),
          side: const BorderSide(color: ZetraColors.cardBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ZetraColors.accentEnd,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
      cardTheme: CardThemeData(
        color: ZetraColors.card,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: ZetraColors.cardBorder),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: ZetraColors.card,
        selectedColor: ZetraColors.accentEnd,
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, color: ZetraColors.textSecondary),
        secondaryLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
        shape: const StadiumBorder(side: BorderSide(color: ZetraColors.cardBorder)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: ZetraColors.bgBottom,
        indicatorColor: ZetraColors.accentEnd.withOpacity(0.18),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? ZetraColors.accentEnd : ZetraColors.textMuted,
          );
        }),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: ZetraColors.accentEnd,
        foregroundColor: Colors.white,
        elevation: 6,
      ),
      dividerTheme: const DividerThemeData(color: ZetraColors.cardBorder, space: 1),
    );
  }

  static ThemeData _buildLight() {
    final textTheme = GoogleFonts.interTextTheme(Typography.blackMountainView);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF6F7FB),
      colorScheme: ColorScheme.fromSeed(
        seedColor: ZetraColors.accentStart,
        brightness: Brightness.light,
      ),
      textTheme: textTheme,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Colors.grey.shade200),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------
/// GLOW BACKGROUND — applied once behind the whole bottom-nav shell
/// ---------------------------------------------------------------------
class GlowBackground extends StatelessWidget {
  const GlowBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) return child;

    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [ZetraColors.bgTop, ZetraColors.bgBottom],
            ),
          ),
        ),
        Positioned(
          top: -90,
          right: -70,
          child: _blob(220, ZetraColors.accentStart.withOpacity(0.20)),
        ),
        Positioned(
          bottom: -110,
          left: -80,
          child: _blob(260, ZetraColors.accentEnd.withOpacity(0.14)),
        ),
        child,
      ],
    );
  }

  Widget _blob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

/// ---------------------------------------------------------------------
/// ROUTER
/// ---------------------------------------------------------------------
final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      final path = state.matchedLocation;
      const guardedPrefixes = ['/developer', '/my-apps'];
      const authRoutes = ['/developer-login', '/developer-otp'];
      final needsAuth = guardedPrefixes.any((p) => path.startsWith(p)) &&
          !authRoutes.contains(path);
      final loggedIn = Supabase.instance.client.auth.currentSession != null;
      if (needsAuth && !loggedIn) {
        return '/developer-login';
      }
      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ZetraScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/', builder: (c, s) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/discover',
                  builder: (c, s) => const DiscoverScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/my-apps',
                  builder: (c, s) => const MyAppsScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/profile', builder: (c, s) => const ProfileScreen()),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/welcome-role',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (c, s) => const WelcomeRoleScreen(),
      ),
      GoRoute(
        path: '/developer-login',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (c, s) => const DeveloperLoginScreen(),
      ),
      GoRoute(
        path: '/developer-otp',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (c, s) => const DeveloperOtpScreen(),
      ),
      GoRoute(
        path: '/apps/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (c, s) =>
            AppDetailsScreen(appId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/apps/:id/report-bug',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (c, s) => BugReportScreen(appId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/apps/:id/feedback',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (c, s) => FeedbackScreen(appId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/tests',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (c, s) => const MyTestsScreen(),
      ),
      GoRoute(
        path: '/developer',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (c, s) => const DeveloperDashboardScreen(),
      ),
      GoRoute(
        path: '/developer/create-app',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (c, s) => const CreateAppScreen(),
      ),
      GoRoute(
        path: '/developer/apps/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (c, s) =>
            DeveloperAppDetailScreen(appId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/developer/apps/:id/upload',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (c, s) => UploadVersionScreen(appId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/developer/apps/:id/bugs',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (c, s) =>
            DeveloperAppBugsScreen(appId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/developer/apps/:id/feedback',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (c, s) =>
            DeveloperAppFeedbackScreen(appId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/admin',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (c, s) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/admin/apps/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (c, s) => AppReviewScreen(appId: s.pathParameters['id']!),
      ),
    ],
  );
});

/// ---------------------------------------------------------------------
/// BOTTOM-NAV SCAFFOLD
/// ---------------------------------------------------------------------
class ZetraScaffold extends StatelessWidget {
  const ZetraScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: GlowBackground(child: SafeArea(bottom: false, child: navigationShell)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(Icons.apps_outlined),
            selectedIcon: Icon(Icons.apps_rounded),
            label: 'My Apps',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
