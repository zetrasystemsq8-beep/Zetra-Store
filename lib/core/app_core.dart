import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/discover.dart';
import '../features/developer.dart';
import '../features/tester_actions.dart';

/// ---------------------------------------------------------------------
/// ENVIRONMENT / SUPABASE CONFIG
/// ---------------------------------------------------------------------
/// Values come from --dart-define at build time (see your GitHub
/// Actions workflow), never hardcoded here.
class Env {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String workerUrl = String.fromEnvironment('WORKER_URL');
  static const String workerApiKey =
      String.fromEnvironment('WORKER_API_KEY');
}

/// ---------------------------------------------------------------------
/// THEME
/// ---------------------------------------------------------------------
class AppTheme {
  AppTheme._();

  static const Color _brandSeed = Color(0xFF3457D5); // Zetra blue

  static ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _brandSeed,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: const Color(0xFFF7F8FA),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _brandSeed, width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    cardTheme: CardTheme(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
    ),
  );

  static ThemeData dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _brandSeed,
      brightness: Brightness.dark,
    ),
  );
}

/// ---------------------------------------------------------------------
/// ROUTER
/// ---------------------------------------------------------------------
final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
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
