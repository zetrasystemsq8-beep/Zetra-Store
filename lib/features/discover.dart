import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
      appBar: AppBar(title: const Text('Zetra Store')),
      body: RefreshIndicator(
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
        child: Center(child: CircularProgressIndicator()),
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
        child: Center(child: CircularProgressIndicator()),
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
      appBar: AppBar(title: const Text('Discover')),
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
                    const Center(child: CircularProgressIndicator()),
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
      appBar: AppBar(),
      body: appAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
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
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.1),
                      child: Icon(Icons.apps_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 32),
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
                      style: TextStyle(color: Colors.grey.shade600)),
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
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Text('v${app.currentVersion}',
                              style: TextStyle(
                                  color: Colors.orange.shade800,
                                  fontWeight: FontWeight.w600,
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
        ElevatedButton.icon(
          onPressed: () => _download(context, ref),
          icon: const Icon(Icons.download_rounded),
          label: const Text('Download APK'),
        ),
        const SizedBox(height: 8),
        Text(
          '${app.fileSizeLabel} • ${app.downloadCount} downloads'
          '${app.minAndroidVersion != null ? ' • Android ${app.minAndroidVersion}+' : ''}',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        const SizedBox(height: 24),
        Text('About this app',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(app.fullDescription.isNotEmpty
            ? app.fullDescription
            : app.shortDescription),
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
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => const Text('Could not load version history'),
          data: (versions) {
            if (versions.isEmpty) {
              return Text('No versions uploaded yet.',
                  style: TextStyle(color: Colors.grey.shade600));
            }
            return Column(
              children: versions
                  .map((v) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          v.isCurrent
                              ? Icons.check_circle_rounded
                              : Icons.history_rounded,
                          color: v.isCurrent ? Colors.green : Colors.grey,
                        ),
                        title: Text('v${v.versionName}'),
                        subtitle: Text(v.releaseNotes.isNotEmpty
                            ? v.releaseNotes
                            : 'No release notes'),
                        trailing: Text('${v.downloadCount} downloads',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 12)),
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

  Future<void> _download(BuildContext context, WidgetRef ref) async {
    final versions = await ref.read(appVersionsProvider(app.id).future);
    final current = versions.where((v) => v.isCurrent).toList();
    final version = current.isNotEmpty ? current.first : null;

    await ref.read(appsRepositoryProvider).recordDownload(
          app.id,
          version?.id,
          null, // wire in the signed-in user's ID once auth is back
        );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(version != null
            ? 'Download recorded for v${version.versionName}.'
            : 'No published version to download yet.'),
      ),
    );
  }
}
