import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_core.dart';
import 'core/apk_installer.dart';
import 'core/announcement_system.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

  runApp(const ProviderScope(child: ZetraStoreApp()));
}

class ZetraStoreApp extends ConsumerStatefulWidget {
  const ZetraStoreApp({super.key});

  @override
  ConsumerState<ZetraStoreApp> createState() => _ZetraStoreAppState();
}

class _ZetraStoreAppState extends ConsumerState<ZetraStoreApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        await showAnnouncementsDialog(context, ref);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
/// update screen. Downloads and installs in-app instead of sending
/// users to the browser, since large GitHub downloads can stall
/// indefinitely on some Nigerian mobile networks.
///
/// NOTE: This build introduced a new release signing key. Anyone on an
/// older build signed with the previous (debug) key will hit a signature
/// mismatch on install — the UI below detects that failure and tells
/// them to uninstall first, one time only. Once everyone is on the new
/// key, in-app installs will just work silently going forward.
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
  bool _downloading = false;
  double _progress = 0;
  String? _error;
  bool _signatureMismatch = false;

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
          .from('zetra_store_app_config')
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

  Future<void> _downloadAndInstall() async {
    if (_updateUrl == null || _downloading) return;

    setState(() {
      _downloading = true;
      _progress = 0;
      _error = null;
      _signatureMismatch = false;
    });

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(_updateUrl!));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      final total = response.contentLength ?? 0;
      var received = 0;

      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/zetra_store_update.apk';
      final file = File(filePath);
      final sink = file.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0 && mounted) {
          setState(() => _progress = received / total);
        }
      }

      await sink.close();

      if (!mounted) return;

      try {
        await ApkInstaller.install(filePath);
        if (mounted) {
          setState(() => _downloading = false);
        }
      } catch (installError) {
        final message = installError.toString().toLowerCase();
        final looksLikeSignatureIssue = message.contains('signature') ||
            message.contains('conflict') ||
            message.contains('install_failed');

        if (mounted) {
          setState(() {
            _downloading = false;
            _signatureMismatch = looksLikeSignatureIssue;
            _error = looksLikeSignatureIssue
                ? null
                : 'Install failed: $installError';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _error = 'Download failed: $e';
        });
      }
    } finally {
      client.close();
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
                  if (_signatureMismatch) ...[
                    const Text(
                      'This update needs a fresh install — a one-time step.\n\n'
                      '1. Uninstall the current Zetra Store app\n'
                      '2. Reopen the download link below\n'
                      '3. Install the new version\n\n'
                      'After this, future updates will install automatically '
                      'with no extra steps.',
                      style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                  ] else ...[
                    const Text(
                      'A new version of Zetra Store is available. '
                      'Tap below to download and install it.',
                      style: TextStyle(color: Colors.white70, fontSize: 15),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 32),
                  if (_downloading) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _progress > 0 ? _progress : null,
                        color: Colors.blue,
                        backgroundColor: Colors.white24,
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _progress > 0
                          ? '${(_progress * 100).toStringAsFixed(0)}%'
                          : 'Starting...',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ] else ...[
                    ElevatedButton(
                      onPressed: _downloadAndInstall,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      ),
                      child: Text(
                        _signatureMismatch
                            ? 'Download Again After Uninstalling'
                            : 'Download Update',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
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
