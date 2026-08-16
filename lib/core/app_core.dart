import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/discover.dart';
import '../features/developer.dart';
import '../features/developer_auth.dart';
import '../features/tester_actions.dart';

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
/// THEME
/// ---------------------------------------------------------------------
class AppTheme {
  AppTheme._();

  static const Color _brandSeed = Color(0xFF3457D5);
  static const Color _surface = Color(0xFFF6F7FB);

  static ThemeData light = _build(Brightness.light);
  static ThemeData dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _brandSeed,
      brightness: brightness,
    );

    final baseText =
        isLight ? Typography.blackMountainView : Typography.whiteMountainView;
    final textTheme = GoogleFonts.interTextTheme(baseText).copyWith(
      headlineSmall: GoogleFonts.manrope(
        fontWeight: FontWeight.w700,
        fontSize: 24,
        letterSpacing: -0.4,
        color: colorScheme.onSurface,
      ),
      titleLarge: GoogleFonts.manrope(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: colorScheme.onSurface,
      ),
      titleMedium: GoogleFonts.manrope(
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      titleSmall: GoogleFonts.manrope(
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      bodyMedium: GoogleFonts.inter(
        color: colorScheme.onSurfaceVariant,
        height: 1.4,
      ),
      labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w600),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: isLight ? _surface : const Color(0xFF0E1116),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: isLight ? _surface : const Color(0xFF0E1116),
        titleTextStyle: GoogleFonts.manrope(
          fontWeight: FontWeight.w700,
          fontSize: 20,
          letterSpacing: -0.2,
          color: colorScheme.onSurface,
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? Colors.white : const Color(0xFF171B22),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: isLight ? Colors.grey.shade300 : Colors.grey.shade800),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: isLight ? Colors.grey.shade300 : Colors.grey.shade800),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _brandSeed, width: 1.6),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: GoogleFonts.inter(color: Colors.grey.shade500),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
          textStyle: GoogleFonts.inter(
              fontWeight: FontWeight.w600, letterSpacing: 0.1),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: BorderSide(
              color: isLight ? Colors.grey.shade300 : Colors.grey.shade700),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isLight ? Colors.white : const Color(0xFF171B22),
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
              color: isLight ? Colors.grey.shade200 : Colors.grey.shade800),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isLight ? Colors.white : const Color(0xFF171B22),
        selectedColor: colorScheme.primary.withOpacity(0.12),
        labelStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600, color: colorScheme.onSurface),
        secondaryLabelStyle:
            GoogleFonts.inter(fontWeight: FontWeight.w600, color: colorScheme.primary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
          side: BorderSide(
              color: isLight ? Colors.grey.shade300 : Colors.grey.shade700),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isLight ? Colors.white : const Color(0xFF12151B),
        indicatorColor: colorScheme.primary.withOpacity(0.14),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isLight ? Colors.grey.shade200 : Colors.grey.shade800,
        space: 1,
      ),
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
      body: navigationShell,
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
