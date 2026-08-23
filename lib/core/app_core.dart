import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/contact_screen.dart';
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
  static const String githubPat = String.fromEnvironment('GH_PAT');
  static const String githubOwner = String.fromEnvironment('GH_OWNER');
  static const String githubRepo = String.fromEnvironment('GH_REPO');
}

/// ---------------------------------------------------------------------
/// BRAND PALETTE - SEPARATE LIGHT & DARK
/// ---------------------------------------------------------------------
class ZetraColors {
  ZetraColors._();

  // ===== DARK MODE =====
  static const darkBgTop = Color(0xFF0B0F14);
  static const darkBgBottom = Color(0xFF141B23);
  static const darkCard = Color(0xFF1B2530);
  static const darkCardBorder = Color(0xFF2A3844);
  static const darkAccentStart = Color(0xFF3B82F6);
  static const darkAccentEnd = Color(0xFF60A5FA);
  static const darkTextPrimary = Color(0xFFF5F7FA);
  static const darkTextSecondary = Color(0xFF8B96A3);
  static const darkTextMuted = Color(0xFF5C6773);
  static const darkErrorSoft = Color(0xFFFF8A8A);

  // ===== LIGHT MODE =====
  static const lightBgPrimary = Color(0xFFFAFBFC);
  static const lightBgSecondary = Color(0xFFF3F5FA);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightCardBorder = Color(0xFFE5E9F0);
  static const lightAccentStart = Color(0xFF3B82F6);
  static const lightAccentEnd = Color(0xFF2563EB);
  static const lightTextPrimary = Color(0xFF0F172A);
  static const lightTextSecondary = Color(0xFF475569);
  static const lightTextMuted = Color(0xFF94A3B8);
  static const lightErrorSoft = Color(0xFFEF5350);

  // ===== GRADIENTS =====
  static const darkAccentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [darkAccentStart, darkAccentEnd],
  );

  static const lightAccentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [lightAccentStart, lightAccentEnd],
  );

  // Fallback for backwards compatibility
  @Deprecated('Use theme-aware colors instead')
  static const bgTop = darkBgTop;
  @Deprecated('Use theme-aware colors instead')
  static const bgBottom = darkBgBottom;
  @Deprecated('Use theme-aware colors instead')
  static const card = darkCard;
  @Deprecated('Use theme-aware colors instead')
  static const cardBorder = darkCardBorder;
  @Deprecated('Use theme-aware colors instead')
  static const accentStart = darkAccentStart;
  @Deprecated('Use theme-aware colors instead')
  static const accentEnd = darkAccentEnd;
  @Deprecated('Use theme-aware colors instead')
  static const textPrimary = darkTextPrimary;
  @Deprecated('Use theme-aware colors instead')
  static const textSecondary = darkTextSecondary;
  @Deprecated('Use theme-aware colors instead')
  static const textMuted = darkTextMuted;
  @Deprecated('Use theme-aware colors instead')
  static const errorSoft = darkErrorSoft;
  @Deprecated('Use theme-aware colors instead')
  static const accentGradient = darkAccentGradient;
}

/// Helper extension for brightness-aware colors
extension ZetraColorScheme on BuildContext {
  ZetraColorPalette get zetraColors {
    return Theme.of(this).brightness == Brightness.dark
        ? const ZetraColorPalette.dark()
        : const ZetraColorPalette.light();
  }
}

/// Brightness-aware color palette
class ZetraColorPalette {
  final Color bgPrimary;
  final Color bgSecondary;
  final Color card;
  final Color cardBorder;
  final Color accentStart;
  final Color accentEnd;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color errorSoft;
  final LinearGradient accentGradient;

  const ZetraColorPalette.dark()
      : bgPrimary = ZetraColors.darkBgTop,
        bgSecondary = ZetraColors.darkBgBottom,
        card = ZetraColors.darkCard,
        cardBorder = ZetraColors.darkCardBorder,
        accentStart = ZetraColors.darkAccentStart,
        accentEnd = ZetraColors.darkAccentEnd,
        textPrimary = ZetraColors.darkTextPrimary,
        textSecondary = ZetraColors.darkTextSecondary,
        textMuted = ZetraColors.darkTextMuted,
        errorSoft = ZetraColors.darkErrorSoft,
        accentGradient = ZetraColors.darkAccentGradient;

  const ZetraColorPalette.light()
      : bgPrimary = ZetraColors.lightBgPrimary,
        bgSecondary = ZetraColors.lightBgSecondary,
        card = ZetraColors.lightCard,
        cardBorder = ZetraColors.lightCardBorder,
        accentStart = ZetraColors.lightAccentStart,
        accentEnd = ZetraColors.lightAccentEnd,
        textPrimary = ZetraColors.lightTextPrimary,
        textSecondary = ZetraColors.lightTextSecondary,
        textMuted = ZetraColors.lightTextMuted,
        errorSoft = ZetraColors.lightErrorSoft,
        accentGradient = ZetraColors.lightAccentGradient;
}

/// Helper function to build theme-aware text theme
TextTheme _buildTextTheme(Brightness brightness) {
  final baseTheme = brightness == Brightness.dark
      ? Typography.whiteMountainView
      : Typography.blackMountainView;

  return GoogleFonts.interTextTheme(baseTheme).copyWith(
    headlineSmall: GoogleFonts.manrope(
      fontWeight: FontWeight.w800,
      fontSize: 26,
      letterSpacing: -0.3,
      color: brightness == Brightness.dark
          ? ZetraColors.darkTextPrimary
          : ZetraColors.lightTextPrimary,
    ),
    titleLarge: GoogleFonts.manrope(
      fontWeight: FontWeight.w700,
      color: brightness == Brightness.dark
          ? ZetraColors.darkTextPrimary
          : ZetraColors.lightTextPrimary,
    ),
    titleMedium: GoogleFonts.manrope(
      fontWeight: FontWeight.w700,
      color: brightness == Brightness.dark
          ? ZetraColors.darkTextPrimary
          : ZetraColors.lightTextPrimary,
    ),
    titleSmall: GoogleFonts.manrope(
      fontWeight: FontWeight.w600,
      color: brightness == Brightness.dark
          ? ZetraColors.darkTextPrimary
          : ZetraColors.lightTextPrimary,
    ),
    bodyMedium: GoogleFonts.inter(
      color: brightness == Brightness.dark
          ? ZetraColors.darkTextSecondary
          : ZetraColors.lightTextSecondary,
      height: 1.45,
    ),
    labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w700),
  );
}

/// Helper function to build input decoration theme
InputDecorationTheme _buildInputDecorationTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final fillColor = isDark ? ZetraColors.darkCard : ZetraColors.lightCard;
  final borderColor =
      isDark ? ZetraColors.darkCardBorder : ZetraColors.lightCardBorder;
  final accentColor = isDark ? ZetraColors.darkAccentEnd : ZetraColors.lightAccentEnd;
  final textColor = isDark ? ZetraColors.darkTextMuted : ZetraColors.lightTextMuted;
  final labelColor =
      isDark ? ZetraColors.darkTextSecondary : ZetraColors.lightTextSecondary;

  return InputDecorationTheme(
    filled: true,
    fillColor: fillColor,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: borderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: borderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: accentColor, width: 1.6),
    ),
    hintStyle: GoogleFonts.inter(color: textColor),
    labelStyle: GoogleFonts.inter(color: labelColor),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  );
}

/// Helper function to build button themes
(ElevatedButtonThemeData, OutlinedButtonThemeData, TextButtonThemeData)
    _buildButtonThemes(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final accentColor = isDark ? ZetraColors.darkAccentEnd : ZetraColors.lightAccentEnd;
  final textColor = isDark ? Colors.white : ZetraColors.lightTextPrimary;
  final borderColor = isDark ? ZetraColors.darkCardBorder : ZetraColors.lightCardBorder;
  final disabledColor = accentColor.withOpacity(0.4);

  return (
    ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        disabledBackgroundColor: disabledColor,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        textStyle:
            GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15.5),
      ),
    ),
    OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: textColor,
        minimumSize: const Size.fromHeight(56),
        side: BorderSide(color: borderColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
      ),
    ),
    TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accentColor,
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
      ),
    ),
  );
}

/// Helper function to build chip theme
ChipThemeData _buildChipTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final bgColor = isDark ? ZetraColors.darkCard : ZetraColors.lightCard;
  final selectedColor =
      isDark ? ZetraColors.darkAccentEnd : ZetraColors.lightAccentEnd;
  final labelColor =
      isDark ? ZetraColors.darkTextSecondary : ZetraColors.lightTextSecondary;
  final borderColor =
      isDark ? ZetraColors.darkCardBorder : ZetraColors.lightCardBorder;

  return ChipThemeData(
    backgroundColor: bgColor,
    selectedColor: selectedColor,
    labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, color: labelColor),
    secondaryLabelStyle:
        GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
    shape: StadiumBorder(side: BorderSide(color: borderColor)),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  );
}

/// Helper function to build navigation bar theme
NavigationBarThemeData _buildNavigationBarTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final bgColor = isDark ? ZetraColors.darkBgBottom : ZetraColors.lightBgSecondary;
  final accentColor = isDark ? ZetraColors.darkAccentEnd : ZetraColors.lightAccentEnd;
  final selectedIconColor = accentColor;
  final unselectedIconColor =
      isDark ? ZetraColors.darkTextMuted : ZetraColors.lightTextMuted;

  return NavigationBarThemeData(
    backgroundColor: bgColor,
    indicatorColor: accentColor.withOpacity(0.18),
    elevation: 0,
    labelTextStyle: WidgetStateProperty.all(
      GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700),
    ),
    iconTheme: WidgetStateProperty.resolveWith((states) {
      final selected = states.contains(WidgetState.selected);
      return IconThemeData(
        color: selected ? selectedIconColor : unselectedIconColor,
      );
    }),
  );
}

/// Helper function to build card theme
CardThemeData _buildCardTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final cardColor = isDark ? ZetraColors.darkCard : ZetraColors.lightCard;
  final borderColor =
      isDark ? ZetraColors.darkCardBorder : ZetraColors.lightCardBorder;

  return CardThemeData(
    color: cardColor,
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: borderColor),
    ),
  );
}

/// Helper function to build app bar theme
AppBarTheme _buildAppBarTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final iconColor = isDark ? ZetraColors.darkTextPrimary : ZetraColors.lightTextPrimary;

  return AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    titleTextStyle: GoogleFonts.manrope(
      fontWeight: FontWeight.w800,
      fontSize: 22,
      color: iconColor,
    ),
    iconTheme: IconThemeData(color: iconColor),
  );
}

/// Helper function to build color scheme
ColorScheme _buildColorScheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;

  if (isDark) {
    return ColorScheme.dark(
      primary: ZetraColors.darkAccentEnd,
      onPrimary: Colors.white,
      secondary: ZetraColors.darkAccentStart,
      onSecondary: Colors.white,
      surface: ZetraColors.darkCard,
      onSurface: ZetraColors.darkTextPrimary,
      error: ZetraColors.darkErrorSoft,
      onError: Colors.white,
    );
  } else {
    return ColorScheme.light(
      primary: ZetraColors.lightAccentEnd,
      onPrimary: Colors.white,
      secondary: ZetraColors.lightAccentStart,
      onSecondary: Colors.white,
      surface: ZetraColors.lightCard,
      onSurface: ZetraColors.lightTextPrimary,
      error: ZetraColors.lightErrorSoft,
      onError: Colors.white,
    );
  }
}

/// Helper function to build divider theme
DividerThemeData _buildDividerTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final color = isDark ? ZetraColors.darkCardBorder : ZetraColors.lightCardBorder;

  return DividerThemeData(color: color, space: 1);
}

/// Helper function to build FAB theme
FloatingActionButtonThemeData _buildFABTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final bgColor = isDark ? ZetraColors.darkAccentEnd : ZetraColors.lightAccentEnd;

  return FloatingActionButtonThemeData(
    backgroundColor: bgColor,
    foregroundColor: Colors.white,
    elevation: 6,
  );
}

/// Main theme builder
ThemeData _buildThemeData(Brightness brightness) {
  final (elevatedTheme, outlinedTheme, textTheme) =
      _buildButtonThemes(brightness);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: brightness == Brightness.dark
        ? ZetraColors.darkBgTop
        : ZetraColors.lightBgPrimary,
    colorScheme: _buildColorScheme(brightness),
    textTheme: _buildTextTheme(brightness),
    appBarTheme: _buildAppBarTheme(brightness),
    inputDecorationTheme: _buildInputDecorationTheme(brightness),
    elevatedButtonTheme: elevatedTheme,
    outlinedButtonTheme: outlinedTheme,
    textButtonTheme: textTheme,
    cardTheme: _buildCardTheme(brightness),
    chipTheme: _buildChipTheme(brightness),
    navigationBarTheme: _buildNavigationBarTheme(brightness),
    floatingActionButtonTheme: _buildFABTheme(brightness),
    dividerTheme: _buildDividerTheme(brightness),
  );
}

/// Main theme class
class AppTheme {
  AppTheme._();

  static ThemeData light = _buildThemeData(Brightness.light);
  static ThemeData dark = _buildThemeData(Brightness.dark);
}

/// Glow background for dark mode
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
              colors: [ZetraColors.darkBgTop, ZetraColors.darkBgBottom],
            ),
          ),
        ),
        Positioned(
          top: -90,
          right: -70,
          child: _blob(220, ZetraColors.darkAccentStart.withOpacity(0.20)),
        ),
        Positioned(
          bottom: -110,
          left: -80,
          child: _blob(260, ZetraColors.darkAccentEnd.withOpacity(0.14)),
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

/// Router provider
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
        path: '/contact',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (c, s) => const ContactScreen(),
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

/// Bottom navigation scaffold
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
