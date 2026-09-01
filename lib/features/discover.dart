import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:installed_apps/installed_apps.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_core.dart';
import '../core/apk_installer.dart';
import '../core/download_manager.dart';
import '../core/models.dart';

/// ---------------------------------------------------------------------
/// PROVIDERS
/// ---------------------------------------------------------------------
final featuredAppsProvider =
    FutureProvider.autoDispose<List<AppModel>>((ref) {
  return ref.watch(appsRepositoryProvider).fetchFeatured();
});

final recentAppsProvider = FutureProvider.autoDispose<List<AppModel>>((ref) {
  return ref.watch(appsRepositoryProvider).fetchPublishedApps(limit: 20);
});

final popularAppsProvider =
    FutureProvider.autoDispose<List<AppModel>>((ref) async {
  final apps =
      await ref.watch(appsRepositoryProvider).fetchPublishedApps(limit: 50);
  final sorted = [...apps]
    ..sort((a, b) => b.downloadCount.compareTo(a.downloadCount));
  return sorted.take(10).toList();
});

final betaAppsProvider =
    FutureProvider.autoDispose<List<AppModel>>((ref) async {
  final apps =
      await ref.watch(appsRepositoryProvider).fetchPublishedApps(limit: 50);
  return apps.where((a) => a.isBeta).take(10).toList();
});

final categoryAppsProvider = FutureProvider.family
    .autoDispose<List<AppModel>, AppCategory>((ref, category) {
  return ref.watch(appsRepositoryProvider).fetchByCategory(category);
});

final appDetailsProvider =
    FutureProvider.family.autoDispose<AppModel, String>((ref, appId) {
  return ref.watch(appsRepositoryProvider).fetchAppById(appId);
});

final appVersionsProvider = FutureProvider.family
    .autoDispose<List<AppVersion>, String>((ref, appId) {
  return ref.watch(appsRepositoryProvider).fetchVersions(appId);
});

final searchResultsProvider =
    FutureProvider.family.autoDispose<List<AppModel>, String>((ref, query) {
  if (query.trim().isEmpty) {
    return ref.watch(appsRepositoryProvider).fetchPublishedApps();
  }
  return ref.watch(appsRepositoryProvider).searchApps(query.trim());
});

final discoverCategoryFilterProvider =
    StateProvider.autoDispose<AppCategory?>((ref) => null);
final discoverSearchQueryProvider =
    StateProvider.autoDispose<String>((ref) => '');

// installedAppInfoProvider, InstallState, resolveInstallState live in
// core/models.dart — do not redefine them here.

/// ---------------------------------------------------------------------
/// HOME
/// ---------------------------------------------------------------------
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.zetraColors;
    final featured = ref.watch(featuredAppsProvider);
    final recent = ref.watch(recentAppsProvider);
    final popular = ref.watch(popularAppsProvider);
    final beta = ref.watch(betaAppsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('Zetra Store')),
      body: RefreshIndicator(
        color: colors.accentEnd,
        backgroundColor: colors.card,
        onRefresh: () async {
          ref.invalidate(featuredAppsProvider);
          ref.invalidate(recentAppsProvider);
          ref.invalidate(popularAppsProvider);
          ref.invalidate(betaAppsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _CategoryRow(),
            SectionHeader(
              title: 'Featured',
              onSeeAll: () => context.push('/discover'),
            ),
            _AppCarousel(asyncApps: featured),
            SectionHeader(
              title: 'Recently updated',
              onSeeAll: () => context.push('/discover'),
            ),
            _AppList(asyncApps: recent, limit: 5),
            SectionHeader(
              title: 'Popular apps',
              onSeeAll: () => context.push('/discover'),
            ),
            _AppList(asyncApps: popular, limit: 5),
            SectionHeader(
              title: 'Beta apps',
              onSeeAll: () => context.push('/discover'),
            ),
            _AppList(asyncApps: beta, limit: 5),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends ConsumerWidget {
  const _CategoryRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: AppCategory.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = AppCategory.values[index];
          return ActionChip(
            label: Text(category.label),
            onPressed: () {
              ref.read(discoverCategoryFilterProvider.notifier).state =
                  category;
              context.push('/discover');
            },
          );
        },
      ),
    );
  }
}

class _AppCarousel extends StatelessWidget {
  const _AppCarousel({required this.asyncApps});

  final AsyncValue<List<AppModel>> asyncApps;

  @override
  Widget build(BuildContext context) {
    final colors = context.zetraColors;
    return asyncApps.when(
      loading: () => SizedBox(
        height: 96,
        child: Center(child: CircularProgressIndicator(color: colors.accentEnd)),
      ),
      error: (e, st) =>
          const ErrorState(message: 'Could not load featured apps'),
      data: (apps) {
        if (apps.isEmpty) {
          return const EmptyState(
            icon: Icons.star_outline_rounded,
            title: 'No featured apps yet',
            subtitle: 'Check back soon.',
          );
        }
        return SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: apps.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final app = apps[index];
              return SizedBox(
                width: 280,
                child: AppCard(
                  app: app,
                  onTap: () => context.push('/apps/${app.id}'),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _AppList extends StatelessWidget {
  const _AppList({required this.asyncApps, this.limit});

  final AsyncValue<List<AppModel>> asyncApps;
  final int? limit;

  @override
  Widget build(BuildContext context) {
    final colors = context.zetraColors;
    return asyncApps.when(
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: colors.accentEnd)),
      ),
      error: (e, st) => const ErrorState(message: 'Could not load apps'),
      data: (apps) {
        final list = limit != null ? apps.take(limit!).toList() : apps;
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.apps_outlined,
            title: 'No apps here yet',
            subtitle: 'New apps will show up as developers publish them.',
          );
        }
        return Column(
          children: list
              .map((app) => AppCard(
                    app: app,
                    onTap: () => context.push('/apps/${app.id}'),
                  ))
              .toList(),
        );
      },
    );
  }
}

/// ---------------------------------------------------------------------
/// DISCOVER
/// ---------------------------------------------------------------------
class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.zetraColors;
    final query = ref.watch(discoverSearchQueryProvider);
    final category = ref.watch(discoverCategoryFilterProvider);

    final resultsAsync = category != null
        ? ref.watch(categoryAppsProvider(category))
        : ref.watch(searchResultsProvider(query));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('Discover')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'Search apps, developers, categories',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => ref
                            .read(discoverSearchQueryProvider.notifier)
                            .state = '',
                      )
                    : null,
              ),
              onChanged: (v) {
                ref.read(discoverCategoryFilterProvider.notifier).state =
                    null;
                ref.read(discoverSearchQueryProvider.notifier).state = v;
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: category == null,
                    onSelected: (_) => ref
                        .read(discoverCategoryFilterProvider.notifier)
                        .state = null,
                  ),
                  const SizedBox(width: 8),
                  ...AppCategory.values.map((c) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(c.label),
                          selected: category == c,
                          onSelected: (_) => ref
                              .read(discoverCategoryFilterProvider.notifier)
                              .state = c,
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: resultsAsync.when(
                loading: () =>
                    Center(child: CircularProgressIndicator(color: colors.accentEnd)),
                error: (e, st) => ErrorState(
                  message: 'Could not load apps',
                  onRetry: () {
                    ref.invalidate(searchResultsProvider);
                    ref.invalidate(categoryAppsProvider);
                  },
                ),
                data: (apps) {
                  if (apps.isEmpty) {
                    return const EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No apps found',
                      subtitle: 'Try a different search or category.',
                    );
                  }
                  return ListView.builder(
                    itemCount: apps.length,
                    itemBuilder: (context, index) {
                      final app = apps[index];
                      return AppCard(
                        app: app,
                        onTap: () => context.push('/apps/${app.id}'),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------
/// APP DETAILS
/// ---------------------------------------------------------------------
class AppDetailsScreen extends ConsumerWidget {
  const AppDetailsScreen({super.key, required this.appId});

  final String appId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.zetraColors;
    final appAsync = ref.watch(appDetailsProvider(appId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: appAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: colors.accentEnd)),
        error: (e, st) => ErrorState(
          message: 'Could not load this app',
          onRetry: () => ref.invalidate(appDetailsProvider(appId)),
        ),
        data: (app) => _AppDetailsBody(app: app),
      ),
    );
  }
}

class _AppDetailsBody extends ConsumerWidget {
  const _AppDetailsBody({required this.app});

  final AppModel app;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.zetraColors;
    final versionsAsync = ref.watch(appVersionsProvider(app.id));
    final installedAsync = app.isWebApp
        ? null
        : ref.watch(installedAppInfoProvider(app.packageName));

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
                      decoration: BoxDecoration(gradient: colors.accentGradient),
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
                      style: TextStyle(color: colors.textSecondary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      StatusBadge(status: app.status),
                      if (app.isWebApp)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: colors.accentStart.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.language_rounded,
                                  size: 12, color: colors.accentEnd),
                              const SizedBox(width: 4),
                              Text('Web app',
                                  style: TextStyle(
                                      color: colors.accentEnd,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                      if (!app.isWebApp && app.isBeta)
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
        if (app.isWebApp)
          GradientButton(
            label: 'Open Website',
            icon: Icons.language_rounded,
            onPressed: () async {
              final uri = Uri.tryParse(app.webUrl ?? '');
              if (uri == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('This app has no website link set.')),
                );
                return;
              }
              final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not open the website.')),
                );
              }
            },
          )
        else
          installedAsync!.when(
            loading: () => const GradientButton(
              label: 'Checking...',
              isLoading: true,
              onPressed: null,
            ),
            error: (e, st) => GradientButton(
              label: 'Install APK',
              icon: Icons.download_rounded,
              onPressed: () => _handleDownload(context, ref, null),
            ),
            data: (installed) {
              final state = resolveInstallState(installed, app.versionCode);
              switch (state) {
                case InstallState.notInstalled:
                  return GradientButton(
                    label: 'Install APK',
                    icon: Icons.download_rounded,
                    onPressed: () => _handleDownload(context, ref, null),
                  );
                case InstallState.updateAvailable:
                  return GradientButton(
                    label: 'Update to v${app.currentVersion}',
                    icon: Icons.system_update_rounded,
                    onPressed: () => _handleDownload(context, ref, null),
                  );
                case InstallState.upToDate:
                  return GradientButton(
                    label: 'Open App',
                    icon: Icons.open_in_new_rounded,
                    onPressed: () => InstalledApps.startApp(app.packageName),
                  );
              }
            },
          ),
        const SizedBox(height: 8),
        if (!app.isWebApp)
          Text(
            '${app.fileSizeLabel} • ${app.downloadCount} downloads'
            '${app.minAndroidVersion != null ? ' • Android ${app.minAndroidVersion}+' : ''}',
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ),
        const SizedBox(height: 24),
        Text('About this app',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          app.fullDescription.isNotEmpty
              ? app.fullDescription
              : app.shortDescription,
          style: TextStyle(color: colors.textSecondary, height: 1.5),
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
        if (!app.isWebApp) ...[
          Text('Version history',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 2),
          Text('Tap any version below to install it',
              style: TextStyle(color: colors.textMuted, fontSize: 12)),
          const SizedBox(height: 8),
          versionsAsync.when(
            loading: () => Center(child: CircularProgressIndicator(color: colors.accentEnd)),
            error: (e, st) => Text('Could not load version history',
                style: TextStyle(color: colors.textSecondary)),
            data: (versions) {
              if (versions.isEmpty) {
                return Text('No versions uploaded yet.',
                    style: TextStyle(color: colors.textSecondary));
              }
              return Column(
                children: versions
                    .map((v) => InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _handleVersionTap(context, ref, v),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              v.isCurrent
                                  ? Icons.check_circle_rounded
                                  : Icons.history_rounded,
                              color: v.isCurrent ? const Color(0xFF34D399) : colors.textMuted,
                            ),
                            title: Row(
                              children: [
                                Text('v${v.versionName}'),
                                if (!v.isCurrent) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: colors.accentStart.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text('Rollback',
                                        style: TextStyle(
                                            color: colors.accentEnd,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(v.releaseNotes.isNotEmpty
                                ? v.releaseNotes
                                : 'No release notes',
                                style: TextStyle(color: colors.textSecondary)),
                            trailing: Icon(Icons.download_for_offline_outlined,
                                color: colors.textMuted, size: 20),
                          ),
                        ))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
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

  void _handleVersionTap(BuildContext context, WidgetRef ref, AppVersion version) {
    if (version.isCurrent) {
      _handleDownload(context, ref, version);
      return;
    }

    final colors = context.zetraColors;
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Install older version?'),
          content: Text(
            'This installs v${version.versionName} over your current version. '
            'Android allows this as long as the app is signed the same way.',
            style: TextStyle(color: colors.textSecondary, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _handleDownload(context, ref, version);
              },
              child: const Text('Install this version'),
            ),
          ],
        );
      },
    );
  }

  /// Downloads no longer block the screen. Progress is tracked in the
  /// shared DownloadManager and shown as a small corner card (see
  /// DownloadOverlay in core/download_manager.dart), so the user can
  /// keep browsing — and start more than one download at once.
  void _handleDownload(BuildContext context, WidgetRef ref, AppVersion? specificVersion) {
    _download(context, ref, specificVersion).catchError((e, st) {
      // Errors are already reported into the DownloadManager inside
      // _download; this catch just prevents an unhandled Future error.
    });
  }

  /// One-time friendly explainer, shown before a user's very first
  /// install. Still a dialog since it only ever appears once — not the
  /// repeated friction the corner-card change is meant to remove.
  Future<bool> _maybeShowInstallGuide(BuildContext context) async {
    final colors = context.zetraColors;
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('seen_install_guide_v2') ?? false;
    if (seen || !context.mounted) return true;

    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.shield_outlined, color: colors.accentEnd),
            const SizedBox(width: 10),
            const Expanded(child: Text('Almost there')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'In a moment, Android will ask if it\'s okay to install '
                'this app. This happens for every app that doesn\'t come '
                'from the Play Store — it\'s completely normal and just '
                'means Android wants your final "yes."',
                style: TextStyle(color: colors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 14),
              Text(
                'Just tap "Install" when you see it — that\'s it.',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'You\'ll only see this Zetra explanation once — after this, '
                'installs and updates run quietly in the corner while you '
                'keep browsing.',
                style: TextStyle(color: colors.textMuted, fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await prefs.setBool('seen_install_guide_v2', true);
              if (context.mounted) Navigator.of(context).pop(true);
            },
            child: const Text('Got it, continue'),
          ),
        ],
      ),
    );

    return proceed ?? false;
  }

  Future<void> _download(
      BuildContext context, WidgetRef ref, AppVersion? specificVersion) async {
    final manager = ref.read(downloadManagerProvider.notifier);
    String? taskId;

    try {
      AppVersion? version = specificVersion;

      if (version == null) {
        final versions = await ref.read(appVersionsProvider(app.id).future);
        final current = versions.where((v) => v.isCurrent).toList();
        version = current.isNotEmpty ? current.first : null;
      }

      if (version == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No published version to download yet.')),
        );
        return;
      }

      final versionToInstall = version;
      taskId = '${app.id}-${versionToInstall.id}';

      if (!context.mounted) return;
      final proceed = await _maybeShowInstallGuide(context);
      if (!proceed) return;

      await ref.read(appsRepositoryProvider).recordDownload(
            app.id,
            versionToInstall.id,
            null,
          );

      manager.start(taskId, app.name);

      final client = http.Client();
      try {
        final request = http.Request('GET', Uri.parse(versionToInstall.apkStoragePath));
        final response = await client.send(request);

        if (response.statusCode != 200) {
          throw Exception('Server returned ${response.statusCode}');
        }

        final total = response.contentLength ?? 0;
        var received = 0;

        final dir = await getTemporaryDirectory();
        final safeName = app.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
        final filePath =
            '${dir.path}/${safeName}_v${versionToInstall.versionName}.apk';
        final file = File(filePath);
        final sink = file.openWrite();

        await for (final chunk in response.stream) {
          if (manager.cancelRequested(taskId)) {
            await sink.close();
            return;
          }
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) {
            manager.updateProgress(taskId, received / total);
          }
        }

        await sink.close();

        if (manager.cancelRequested(taskId)) return;

        manager.setInstalling(taskId);
        await ApkInstaller.install(filePath);
        manager.finish(taskId);
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('Download error: $e');
      if (taskId != null) {
        manager.fail(taskId, 'Download failed');
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download error: $e')),
        );
      }
    }
  }
}
