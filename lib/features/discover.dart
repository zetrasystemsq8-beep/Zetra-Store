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

/// ---------------------------------------------------------------------
/// HOME
/// ---------------------------------------------------------------------
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featured = ref.watch(featuredAppsProvider);
    final recent = ref.watch(recentAppsProvider);
    final popular = ref.watch(popularAppsProvider);
    final beta = ref.watch(betaAppsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('Zetra Store')),
      body: RefreshIndicator(
        color: ZetraColors.accentEnd,
        backgroundColor: ZetraColors.card,
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
    return asyncApps.when(
      loading: () => const SizedBox(
        height: 96,
        child: Center(child: CircularProgressIndicator(color: ZetraColors.accentEnd)),
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
    return asyncApps.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: ZetraColors.accentEnd)),
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
                    const Center(child: CircularProgressIndicator(color: ZetraColors.accentEnd)),
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
    final appAsync = ref.watch(appDetailsProvider(appId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: appAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: ZetraColors.accentEnd)),
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
          onPressed: () => _download(context, ref),
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
    final versions = await ref.read(appVersionsProvider(app.id).future);
    final current = versions.where((v) => v.isCurrent).toList();
    final version = current.isNotEmpty ? current.first : null;

    if (version == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No published version to download yet.')),
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
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    } finally {
      client.close();
    }
  }
}
