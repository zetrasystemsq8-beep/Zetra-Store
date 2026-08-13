import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ---------------------------------------------------------------------
/// ENUMS
/// ---------------------------------------------------------------------
enum AppCategory {
  productivity,
  education,
  finance,
  ai,
  social,
  business,
  games,
  utilities,
  other;

  String get label {
    switch (this) {
      case AppCategory.productivity:
        return 'Productivity';
      case AppCategory.education:
        return 'Education';
      case AppCategory.finance:
        return 'Finance';
      case AppCategory.ai:
        return 'AI';
      case AppCategory.social:
        return 'Social';
      case AppCategory.business:
        return 'Business';
      case AppCategory.games:
        return 'Games';
      case AppCategory.utilities:
        return 'Utilities';
      case AppCategory.other:
        return 'Other';
    }
  }

  static AppCategory fromValue(String? value) {
    return AppCategory.values.firstWhere(
      (c) => c.name == value,
      orElse: () => AppCategory.other,
    );
  }
}

enum AppStatus {
  draft,
  pendingReview,
  published,
  unpublished;

  String get label {
    switch (this) {
      case AppStatus.draft:
        return 'Draft';
      case AppStatus.pendingReview:
        return 'Pending review';
      case AppStatus.published:
        return 'Published';
      case AppStatus.unpublished:
        return 'Unpublished';
    }
  }

  static AppStatus fromValue(String? value) {
    return AppStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => AppStatus.draft,
    );
  }
}

enum BugSeverity {
  critical,
  major,
  minor,
  cosmetic;

  String get label {
    switch (this) {
      case BugSeverity.critical:
        return 'Critical';
      case BugSeverity.major:
        return 'Major';
      case BugSeverity.minor:
        return 'Minor';
      case BugSeverity.cosmetic:
        return 'Cosmetic';
    }
  }

  static BugSeverity fromValue(String? value) {
    return BugSeverity.values.firstWhere(
      (s) => s.name == value,
      orElse: () => BugSeverity.minor,
    );
  }
}

enum BugStatus {
  submitted,
  reviewing,
  confirmed,
  rejected,
  resolved;

  String get label {
    switch (this) {
      case BugStatus.submitted:
        return 'Submitted';
      case BugStatus.reviewing:
        return 'Reviewing';
      case BugStatus.confirmed:
        return 'Confirmed';
      case BugStatus.rejected:
        return 'Rejected';
      case BugStatus.resolved:
        return 'Resolved';
    }
  }

  static BugStatus fromValue(String? value) {
    return BugStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => BugStatus.submitted,
    );
  }
}

/// ---------------------------------------------------------------------
/// MODELS
/// ---------------------------------------------------------------------
class AppModel {
  AppModel({
    required this.id,
    required this.developerId,
    required this.developerName,
    required this.name,
    required this.shortDescription,
    required this.fullDescription,
    required this.category,
    required this.status,
    required this.currentVersion,
    required this.versionCode,
    required this.downloadCount,
    required this.testerCount,
    required this.createdAt,
    required this.updatedAt,
    this.iconUrl,
    this.screenshotUrls = const [],
    this.fileSizeBytes,
    this.minAndroidVersion,
  });

  final String id;
  final String developerId;
  final String developerName;
  final String name;
  final String shortDescription;
  final String fullDescription;
  final AppCategory category;
  final AppStatus status;
  final String currentVersion;
  final int versionCode;
  final int downloadCount;
  final int testerCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? iconUrl;
  final List<String> screenshotUrls;
  final int? fileSizeBytes;
  final String? minAndroidVersion;

  bool get isBeta => status == AppStatus.published && versionCode < 10;

  String get fileSizeLabel {
    if (fileSizeBytes == null) return '-';
    final mb = fileSizeBytes! / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  factory AppModel.fromMap(Map<String, dynamic> map) {
    return AppModel(
      id: map['id'] as String,
      developerId: map['developer_id'] as String? ?? '',
      developerName: map['developer_name'] as String? ?? 'Unknown developer',
      name: map['name'] as String? ?? '',
      shortDescription: map['short_description'] as String? ?? '',
      fullDescription: map['full_description'] as String? ?? '',
      category: AppCategory.fromValue(map['category'] as String?),
      status: AppStatus.fromValue(map['status'] as String?),
      currentVersion: map['current_version'] as String? ?? '0.1.0',
      versionCode: map['version_code'] as int? ?? 1,
      downloadCount: map['download_count'] as int? ?? 0,
      testerCount: map['tester_count'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      iconUrl: map['icon_url'] as String?,
      screenshotUrls: (map['screenshot_urls'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
      fileSizeBytes: map['file_size_bytes'] as int?,
      minAndroidVersion: map['min_android_version'] as String?,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'developer_id': developerId,
      'developer_name': developerName,
      'name': name,
      'short_description': shortDescription,
      'full_description': fullDescription,
      'category': category.name,
      'status': status.name,
      'current_version': currentVersion,
      'version_code': versionCode,
      'icon_url': iconUrl,
      'screenshot_urls': screenshotUrls,
      'min_android_version': minAndroidVersion,
    };
  }
}

class AppVersion {
  AppVersion({
    required this.id,
    required this.appId,
    required this.versionName,
    required this.versionCode,
    required this.apkStoragePath,
    required this.releaseNotes,
    required this.uploadedAt,
    required this.downloadCount,
    required this.isCurrent,
    this.fileSizeBytes,
  });

  final String id;
  final String appId;
  final String versionName;
  final int versionCode;
  final String apkStoragePath;
  final String releaseNotes;
  final DateTime uploadedAt;
  final int downloadCount;
  final bool isCurrent;
  final int? fileSizeBytes;

  factory AppVersion.fromMap(Map<String, dynamic> map) {
    return AppVersion(
      id: map['id'] as String,
      appId: map['app_id'] as String,
      versionName: map['version_name'] as String? ?? '',
      versionCode: map['version_code'] as int? ?? 1,
      apkStoragePath: map['apk_storage_path'] as String? ?? '',
      releaseNotes: map['release_notes'] as String? ?? '',
      uploadedAt: DateTime.parse(map['uploaded_at'] as String),
      downloadCount: map['download_count'] as int? ?? 0,
      isCurrent: map['is_current'] as bool? ?? false,
      fileSizeBytes: map['file_size_bytes'] as int?,
    );
  }
}

class BugReport {
  BugReport({
    required this.id,
    required this.appId,
    required this.appName,
    required this.reporterId,
    required this.title,
    required this.description,
    required this.severity,
    required this.status,
    required this.createdAt,
    this.device,
    this.androidVersion,
    this.stepsToReproduce,
    this.screenshotUrl,
  });

  final String id;
  final String appId;
  final String appName;
  final String reporterId;
  final String title;
  final String description;
  final BugSeverity severity;
  final BugStatus status;
  final DateTime createdAt;
  final String? device;
  final String? androidVersion;
  final String? stepsToReproduce;
  final String? screenshotUrl;

  factory BugReport.fromMap(Map<String, dynamic> map) {
    return BugReport(
      id: map['id'] as String,
      appId: map['app_id'] as String,
      appName: map['app_name'] as String? ?? '',
      reporterId: map['reporter_id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      severity: BugSeverity.fromValue(map['severity'] as String?),
      status: BugStatus.fromValue(map['status'] as String?),
      createdAt: DateTime.parse(map['created_at'] as String),
      device: map['device'] as String?,
      androidVersion: map['android_version'] as String?,
      stepsToReproduce: map['steps_to_reproduce'] as String?,
      screenshotUrl: map['screenshot_url'] as String?,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'app_id': appId,
      'app_name': appName,
      'reporter_id': reporterId,
      'title': title,
      'description': description,
      'severity': severity.name,
      'status': BugStatus.submitted.name,
      'device': device,
      'android_version': androidVersion,
      'steps_to_reproduce': stepsToReproduce,
      'screenshot_url': screenshotUrl,
    };
  }
}

class FeedbackModel {
  FeedbackModel({
    required this.id,
    required this.appId,
    required this.appName,
    required this.userId,
    required this.rating,
    required this.createdAt,
    this.liked,
    this.disliked,
    this.suggestions,
  });

  final String id;
  final String appId;
  final String appName;
  final String userId;
  final int rating;
  final DateTime createdAt;
  final String? liked;
  final String? disliked;
  final String? suggestions;

  factory FeedbackModel.fromMap(Map<String, dynamic> map) {
    return FeedbackModel(
      id: map['id'] as String,
      appId: map['app_id'] as String,
      appName: map['app_name'] as String? ?? '',
      userId: map['user_id'] as String? ?? '',
      rating: map['rating'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      liked: map['liked'] as String?,
      disliked: map['disliked'] as String?,
      suggestions: map['suggestions'] as String?,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'app_id': appId,
      'app_name': appName,
      'user_id': userId,
      'rating': rating,
      'liked': liked,
      'disliked': disliked,
      'suggestions': suggestions,
    };
  }
}

/// ---------------------------------------------------------------------
/// REPOSITORY
/// ---------------------------------------------------------------------
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

class AppsRepository {
  AppsRepository(this._client);

  final SupabaseClient _client;

  Future<List<AppModel>> fetchPublishedApps({int limit = 50}) async {
    final rows = await _client
        .from('apps')
        .select()
        .eq('status', AppStatus.published.name)
        .order('updated_at', ascending: false)
        .limit(limit);
    return rows.map((r) => AppModel.fromMap(r)).toList();
  }

  Future<List<AppModel>> fetchFeatured({int limit = 10}) async {
    final rows = await _client
        .from('apps')
        .select()
        .eq('status', AppStatus.published.name)
        .order('download_count', ascending: false)
        .limit(limit);
    return rows.map((r) => AppModel.fromMap(r)).toList();
  }

  Future<List<AppModel>> fetchByCategory(AppCategory category,
      {int limit = 50}) async {
    final rows = await _client
        .from('apps')
        .select()
        .eq('status', AppStatus.published.name)
        .eq('category', category.name)
        .order('updated_at', ascending: false)
        .limit(limit);
    return rows.map((r) => AppModel.fromMap(r)).toList();
  }

  Future<List<AppModel>> searchApps(String query) async {
    final rows = await _client
        .from('apps')
        .select()
        .eq('status', AppStatus.published.name)
        .or('name.ilike.%$query%,developer_name.ilike.%$query%,short_description.ilike.%$query%')
        .limit(50);
    return rows.map((r) => AppModel.fromMap(r)).toList();
  }

  Future<AppModel> fetchAppById(String id) async {
    final row = await _client.from('apps').select().eq('id', id).single();
    return AppModel.fromMap(row);
  }

  /// Apps belonging to a developer (any status). Pass a developer ID
  /// once auth (ZetraMail) is wired back in.
  Future<List<AppModel>> fetchAppsByDeveloper(String developerId) async {
    final rows = await _client
        .from('apps')
        .select()
        .eq('developer_id', developerId)
        .order('updated_at', ascending: false);
    return rows.map((r) => AppModel.fromMap(r)).toList();
  }

  Future<List<AppVersion>> fetchVersions(String appId) async {
    final rows = await _client
        .from('app_versions')
        .select()
        .eq('app_id', appId)
        .order('version_code', ascending: false);
    return rows.map((r) => AppVersion.fromMap(r)).toList();
  }

  Future<void> recordDownload(
      String appId, String? versionId, String? userId) async {
    await _client.from('downloads').insert({
      'app_id': appId,
      'version_id': versionId,
      'user_id': userId,
    });
    await _client.rpc('increment_download_count',
        params: {'app_id_input': appId});
  }

  Future<List<BugReport>> fetchBugReportsForApp(String appId) async {
    final rows = await _client
        .from('bug_reports')
        .select()
        .eq('app_id', appId)
        .order('created_at', ascending: false);
    return rows.map((r) => BugReport.fromMap(r)).toList();
  }

  Future<void> submitBugReport(BugReport report) async {
    await _client.from('bug_reports').insert(report.toInsertMap());
  }

  Future<List<FeedbackModel>> fetchFeedbackForApp(String appId) async {
    final rows = await _client
        .from('feedback')
        .select()
        .eq('app_id', appId)
        .order('created_at', ascending: false);
    return rows.map((r) => FeedbackModel.fromMap(r)).toList();
  }

  Future<void> submitFeedback(FeedbackModel feedback) async {
    await _client.from('feedback').insert(feedback.toInsertMap());
  }
}

final appsRepositoryProvider = Provider<AppsRepository>((ref) {
  return AppsRepository(ref.watch(supabaseClientProvider));
});

/// ---------------------------------------------------------------------
/// SHARED WIDGETS
/// ---------------------------------------------------------------------
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.app, this.onTap});

  final AppModel app;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: app.iconUrl != null
                    ? Image.network(
                        app.iconUrl!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => const _AppIconFallback(),
                      )
                    : const _AppIconFallback(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            app.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (app.isBeta) const _BetaChip(),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      app.developerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          app.category.label,
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 12),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.download_outlined,
                            size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 2),
                        Text(
                          '${app.downloadCount}',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 12),
                        ),
                        const Spacer(),
                        Text(
                          'v${app.currentVersion}',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppIconFallback extends StatelessWidget {
  const _AppIconFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
      child:
          Icon(Icons.apps_rounded, color: Theme.of(context).colorScheme.primary),
    );
  }
}

class _BetaChip extends StatelessWidget {
  const _BetaChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Text(
        'BETA',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.orange.shade800,
        ),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final AppStatus status;

  Color get _color {
    switch (status) {
      case AppStatus.draft:
        return Colors.grey;
      case AppStatus.pendingReview:
        return Colors.orange;
      case AppStatus.published:
        return Colors.green;
      case AppStatus.unpublished:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.label,
        style:
            TextStyle(color: _color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

class SeverityBadge extends StatelessWidget {
  const SeverityBadge({super.key, required this.severity});

  final BugSeverity severity;

  Color get _color {
    switch (severity) {
      case BugSeverity.critical:
        return Colors.red;
      case BugSeverity.major:
        return Colors.deepOrange;
      case BugSeverity.minor:
        return Colors.amber.shade800;
      case BugSeverity.cosmetic:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        severity.label,
        style:
            TextStyle(color: _color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.onSeeAll});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          if (onSeeAll != null)
            TextButton(onPressed: onSeeAll, child: const Text('See all')),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600)),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 48, color: Colors.red.shade300),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700)),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ],
      ),
    );
  }
}
