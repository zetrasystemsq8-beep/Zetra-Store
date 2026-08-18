import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_core.dart';
import '../core/models.dart';

/// ... [providers stay the same - not shown for brevity] ...

class _AppDetailsBody extends ConsumerWidget {
  const _AppDetailsBody({required this.app});

  final AppModel app;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionsAsync = ref.watch(appVersionsProvider(app.id));

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: app.iconUrl != null
                  ? Image.network(app.iconUrl!,
                      width: 80, height: 80, fit: BoxFit.cover)
                  : Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(gradient: ZetraColors.accentGradient),
                      child: const Icon(Icons.apps_rounded, color: Colors.white, size: 32),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(app.name,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text('by ${app.developerName}',
                      style: const TextStyle(color: ZetraColors.textSecondary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      StatusBadge(status: app.status),
                      if (app.isBeta)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.withOpacity(0.4)),
                          ),
                          child: Text('v${app.currentVersion}',
                              style: const TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        GradientButton(
          label: 'Download APK',
          icon: Icons.download_rounded,
          onPressed: () => _handleDownload(context, ref),
        ),
        const SizedBox(height: 8),
        Text(
          '${app.fileSizeLabel} • ${app.downloadCount} downloads'
          '${app.minAndroidVersion != null ? ' • Android ${app.minAndroidVersion}+' : ''}',
          style: const TextStyle(color: ZetraColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 24),
        Text('About this app',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          app.fullDescription.isNotEmpty
              ? app.fullDescription
              : app.shortDescription,
          style: const TextStyle(color: ZetraColors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 24),
        if (app.screenshotUrls.isNotEmpty) ...[
          Text('Screenshots', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: app.screenshotUrls.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) => ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(app.screenshotUrls[index],
                    width: 100, fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
        Text('Version history',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        versionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: ZetraColors.accentEnd)),
          error: (e, st) => const Text('Could not load version history',
              style: TextStyle(color: ZetraColors.textSecondary)),
          data: (versions) {
            if (versions.isEmpty) {
              return const Text('No versions uploaded yet.',
                  style: TextStyle(color: ZetraColors.textSecondary));
            }
            return Column(
              children: versions
                  .map((v) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          v.isCurrent
                              ? Icons.check_circle_rounded
                              : Icons.history_rounded,
                          color: v.isCurrent ? const Color(0xFF34D399) : ZetraColors.textMuted,
                        ),
                        title: Text('v${v.versionName}'),
                        subtitle: Text(v.releaseNotes.isNotEmpty
                            ? v.releaseNotes
                            : 'No release notes',
                            style: const TextStyle(color: ZetraColors.textSecondary)),
                        trailing: Text('${v.downloadCount} downloads',
                            style: const TextStyle(color: ZetraColors.textMuted, fontSize: 12)),
                      ))
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push('/apps/${app.id}/report-bug'),
                icon: const Icon(Icons.bug_report_outlined),
                label: const Text('Report bug'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push('/apps/${app.id}/feedback'),
                icon: const Icon(Icons.rate_review_outlined),
                label: const Text('Feedback'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  void _handleDownload(BuildContext context, WidgetRef ref) {
    _download(context, ref).catchError((e, st) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download error: $e')),
        );
      }
    });
  }

  Future<void> _maybeShowInstallGuide(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('seen_install_guide') ?? false;
    if (seen || !context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: ZetraColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Before you install'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Android blocks installs from outside the Play Store by '
                'default — this is normal for any beta-testing app, not '
                'a problem with this one.',
                style: TextStyle(color: ZetraColors.textSecondary, height: 1.4),
              ),
              SizedBox(height: 12),
              Text(
                '1. When the install screen appears, tap "Settings"\n'
                '2. Turn on "Allow from this source"\n'
                '3. Go back and tap Install again\n\n'
                'If you instead see "blocked for your protection":\n'
                '4. Tap "More details" (small text, easy to miss)\n'
                '5. Tap "Install anyway"',
                style: TextStyle(color: ZetraColors.textSecondary, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await prefs.setBool('seen_install_guide', true);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Got it, install'),
          ),
        ],
      ),
    );
  }

  Future<void> _download(BuildContext context, WidgetRef ref) async {
    try {
      final versions = await ref.read(appVersionsProvider(app.id).future);
      
      if (versions.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No versions available for download.')),
        );
        return;
      }

      final current = versions.where((v) => v.isCurrent).toList();
      final version = current.isNotEmpty ? current.first : versions.first;

      if (version.apkStoragePath.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download link not available.')),
        );
        return;
      }

      await ref.read(appsRepositoryProvider).recordDownload(
            app.id,
            version.id,
            null,
          );

      if (!context.mounted) return;
      await _maybeShowInstallGuide(context);
      if (!context.mounted) return;

      final progress = ValueNotifier<double>(0);
      var cancelled = false;

      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (context, value, _) => AlertDialog(
            backgroundColor: ZetraColors.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Downloading'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: value > 0 ? value : null,
                    color: ZetraColors.accentEnd,
                    backgroundColor: ZetraColors.cardBorder,
                  ),
                ),
                const SizedBox(height: 12),
                Text(value > 0
                    ? '${(value * 100).toStringAsFixed(0)}%'
                    : 'Starting...'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  cancelled = true;
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      );

      final client = http.Client();
      try {
        final request = http.Request('GET', Uri.parse(version.apkStoragePath));
        final response = await client.send(request);

        if (response.statusCode != 200) {
          throw Exception('Server returned ${response.statusCode}');
        }

        final total = response.contentLength ?? 0;
        var received = 0;

        final dir = await getTemporaryDirectory();
        final safeName = app.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
        final filePath = '${dir.path}/${safeName}_v${version.versionName}.apk';
        final file = File(filePath);
        final sink = file.openWrite();

        await for (final chunk in response.stream) {
          if (cancelled) {
            await sink.close();
            return;
          }
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) {
            progress.value = received / total;
          }
        }

        await sink.close();

        if (cancelled) return;
        if (!context.mounted) return;

        Navigator.of(context, rootNavigator: true).pop();
        await OpenFilex.open(filePath);
      } finally {
        client.close();
      }
    } catch (e, st) {
      print('Download error: $e');
      print('Stack: $st');
      if (context.mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }
}
