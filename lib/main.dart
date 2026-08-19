import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/app_core.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

  runApp(const ProviderScope(child: ZetraApp()));
}

class ZetraApp extends ConsumerWidget {
  const ZetraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Zetra Store',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: router,
      builder: (context, child) {
        return UpdateGate(child: child ?? const SizedBox.shrink());
      },
    );
  }
}

/// Wraps the whole app. Checks Supabase for the latest version on launch.
/// If the installed version is outdated and it's been more than 3 days
/// since that version was released, blocks the app with a mandatory
/// update screen.
class UpdateGate extends StatefulWidget {
  final Widget child;
  const UpdateGate({super.key, required this.child});

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  bool _checking = true;
  bool _mustUpdate = false;
  String? _updateUrl;

  @override
  void initState() {
    super.initState();
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // e.g. "0.1.0"

      final response = await Supabase.instance.client
          .from('app_config')
          .select('latest_version, release_date, update_url')
          .limit(1)
          .maybeSingle();

      if (response == null) {
        setState(() => _checking = false);
        return;
      }

      final latestVersion = response['latest_version'] as String?;
      final releaseDateRaw = response['release_date'] as String?;
      final updateUrl = response['update_url'] as String?;

      if (latestVersion == null || releaseDateRaw == null) {
        setState(() => _checking = false);
        return;
      }

      final releaseDate = DateTime.parse(releaseDateRaw);
      final daysSinceRelease = DateTime.now().difference(releaseDate).inDays;
      final isOutdated = _isVersionLower(currentVersion, latestVersion);

      if (isOutdated && daysSinceRelease >= 3) {
        setState(() {
          _mustUpdate = true;
          _updateUrl = updateUrl;
          _checking = false;
        });
      } else {
        setState(() => _checking = false);
      }
    } catch (e) {
      // If the check fails (offline, etc), don't block the user.
      setState(() => _checking = false);
    }
  }

  /// Compares two dot-separated version strings, e.g. "1.2.0" vs "1.10.0".
  bool _isVersionLower(String current, String latest) {
    final currentParts = current.split('+').first.split('.').map(int.tryParse).toList();
    final latestParts = latest.split('+').first.split('.').map(int.tryParse).toList();

    for (var i = 0; i < latestParts.length; i++) {
      final c = i < currentParts.length ? (currentParts[i] ?? 0) : 0;
      final l = latestParts[i] ?? 0;
      if (c < l) return true;
      if (c > l) return false;
    }
    return false;
  }

  Future<void> _launchUpdate() async {
    if (_updateUrl == null) return;
    final uri = Uri.tryParse(_updateUrl!);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_mustUpdate) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.system_update, color: Colors.white, size: 64),
                  const SizedBox(height: 24),
                  const Text(
                    'Update Required',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'A new version of Zetra Store is available. Please update to continue.',
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _launchUpdate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    ),
                    child: const Text('Update Now', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}
