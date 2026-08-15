import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_core.dart';
import '../core/models.dart';
import 'discover.dart';

/// Placeholder "current developer" until ZetraMail auth is wired back
/// in. Every app created here is attributed to this ID.
const kPlaceholderDeveloperId = 'demo-developer';
const kPlaceholderDeveloperName = 'You';

/// ---------------------------------------------------------------------
/// REPOSITORY
/// ---------------------------------------------------------------------
class DeveloperRepository {
  DeveloperRepository(this._client);

  final SupabaseClient _client;

  static const bucket = 'apps';

  Future<String> createApp({
    required String name,
    required String shortDescription,
    required String fullDescription,
    required AppCategory category,
  }) async {
    final row = await _client
        .from('apps')
        .insert({
          'developer_id': kPlaceholderDeveloperId,
          'developer_name': kPlaceholderDeveloperName,
          'name': name,
          'short_description': shortDescription,
          'full_description': fullDescription,
          'category': category.name,
          'status': AppStatus.draft.name,
          'current_version': '0.1.0',
          'version_code': 1,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<String> uploadImage(
      String appId, String fileName, Uint8List bytes) async {
    final path = 'apps/$appId/media/$fileName';
    await _client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  Future<void> updateIcon(String appId, String url) async {
    await _client.from('apps').update({'icon_url': url}).eq('id', appId);
  }

  Future<void> updateScreenshots(String appId, List<String> urls) async {
    await _client
        .from('apps')
        .update({'screenshot_urls': urls}).eq('id', appId);
  }

  /// Sends the APK to the Zetra Store Releases Worker, which creates a
  /// GitHub Release and uploads the APK as an asset there. Returns the
  /// worker's JSON response, including the public download URL.
  Future<Map<String, dynamic>> uploadApk({
    required String appId,
    required String versionName,
    required Uint8List bytes,
  }) async {
    final uri = Uri.parse(
      '${Env.workerUrl}/upload-apk?appId=$appId&versionName=$versionName',
    );
    final response = await http.post(
      uri,
      headers: {
        'X-Api-Key': Env.workerApiKey,
        'Content-Type': 'application/vnd.android.package-archive',
      },
      body: bytes,
    );
    if (response.statusCode != 200) {
      throw Exception('Upload failed: ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> createVersion({
    required String appId,
    required String versionName,
    required int versionCode,
    required String apkStoragePath,
    required String releaseNotes,
    required int fileSizeBytes,
  }) async {
    await _client
        .from('app_versions')
        .update({'is_current': false}).eq('app_id', appId);

    await _client.from('app_versions').insert({
      'app_id': appId,
      'version_name': versionName,
      'version_code': versionCode,
      'apk_storage_path': apkStoragePath,
      'release_notes': releaseNotes,
      'file_size_bytes': fileSizeBytes,
      'is_current': true,
    });

    await _client.from('apps').update({
      'current_version': versionName,
      'version_code': versionCode,
      'file_size_bytes': fileSizeBytes,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', appId);
  }

  Future<void> submitForReview(String appId) async {
    await _client
        .from('apps')
        .update({'status': AppStatus.pendingReview.name}).eq('id', appId);
  }

  Future<void> setUnpublished(String appId) async {
    await _client
        .from('apps')
        .update({'status': AppStatus.unpublished.name}).eq('id', appId);
  }
}

final developerRepositoryProvider = Provider<DeveloperRepository>((ref) {
  return DeveloperRepository(ref.watch(supabaseClientProvider));
});

final myAppsProvider = FutureProvider.autoDispose<List<AppModel>>((ref) {
  return ref
      .watch(appsRepositoryProvider)
      .fetchAppsByDeveloper(kPlaceholderDeveloperId);
});

final appBugReportsProvider = FutureProvider.family
    .autoDispose<List<BugReport>, String>((ref, appId) {
  return ref.watch(appsRepositoryProvider).fetchBugReportsForApp(appId);
});

final appFeedbackProvider = FutureProvider.family
    .autoDispose<List<FeedbackModel>, String>((ref, appId) {
  return ref.watch(appsRepositoryProvider).fetchFeedbackForApp(appId);
});

/// ---------------------------------------------------------------------
/// MY APPS
/// ---------------------------------------------------------------------
class MyAppsScreen extends ConsumerWidget {
  const MyAppsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appsAsync = ref.watch(myAppsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My apps'),
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard_outlined),
            onPressed: () => context.push('/developer'),
            tooltip: 'Dashboard',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/developer/create-app'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New app'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myAppsProvider),
        child: appsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => ErrorState(
            message: 'Could not load your apps',
            onRetry: () => ref.invalidate(myAppsProvider),
          ),
          data: (apps) {
            if (apps.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 80),
                  EmptyState(
                    icon: Icons.rocket_launch_outlined,
                    title: 'No apps yet',
                    subtitle: 'Create your first app to start beta testing.',
                  ),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: apps
                  .map((app) => AppCard(
                        app: app,
                        onTap: () =>
                            context.push('/developer/apps/${app.id}'),
                      ))
                  .toList(),
            );
          },
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------
/// DASHBOARD
/// ---------------------------------------------------------------------
class DeveloperDashboardScreen extends ConsumerWidget {
  const DeveloperDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appsAsync = ref.watch(myAppsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Developer dashboard')),
      body: appsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => ErrorState(
          message: 'Could not load dashboard',
          onRetry: () => ref.invalidate(myAppsProvider),
        ),
        data: (apps) {
          final published =
              apps.where((a) => a.status == AppStatus.published).length;
          final drafts =
              apps.where((a) => a.status == AppStatus.draft).length;
          final totalDownloads =
              apps.fold<int>(0, (sum, a) => sum + a.downloadCount);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: [
                  _StatCard(label: 'Total apps', value: '${apps.length}'),
                  _StatCard(label: 'Published', value: '$published'),
                  _StatCard(label: 'Drafts', value: '$drafts'),
                  _StatCard(
                      label: 'Total downloads', value: '$totalDownloads'),
                ],
              ),
              const SizedBox(height: 16),
              SectionHeader(
                title: 'Your apps',
                onSeeAll: () => context.push('/my-apps'),
              ),
              if (apps.isEmpty)
                const EmptyState(
                  icon: Icons.rocket_launch_outlined,
                  title: 'No apps yet',
                  subtitle: 'Create your first app to see stats here.',
                )
              else
                ...apps.take(5).map((app) => AppCard(
                      app: app,
                      onTap: () => context.push('/developer/apps/${app.id}'),
                    )),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => context.push('/developer/create-app'),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create app'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------
/// CREATE APP
/// ---------------------------------------------------------------------
class CreateAppScreen extends ConsumerStatefulWidget {
  const CreateAppScreen({super.key});

  @override
  ConsumerState<CreateAppScreen> createState() => _CreateAppScreenState();
}

class _CreateAppScreenState extends ConsumerState<CreateAppScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _shortDescription = TextEditingController();
  final _fullDescription = TextEditingController();
  final _versionName = TextEditingController(text: '0.1.0');
  final _versionCode = TextEditingController(text: '1');
  final _releaseNotes = TextEditingController();

  AppCategory _category = AppCategory.productivity;
  XFile? _icon;
  final List<XFile> _screenshots = [];
  PlatformFile? _apk;
  bool _saving = false;
  String? _statusText;

  @override
  void dispose() {
    _name.dispose();
    _shortDescription.dispose();
    _fullDescription.dispose();
    _versionName.dispose();
    _versionCode.dispose();
    _releaseNotes.dispose();
    super.dispose();
  }

  Future<void> _pickIcon() async {
    final file = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file != null) setState(() => _icon = file);
  }

  Future<void> _pickScreenshots() async {
    final files = await ImagePicker().pickMultiImage(imageQuality: 85);
    if (files.isNotEmpty) {
      setState(() {
        _screenshots
          ..clear()
          ..addAll(files.take(6));
      });
    }
  }

  /// Only grabs the file path here — never loads bytes at pick time.
  /// Reading a large APK into memory synchronously during the picker
  /// callback is what was crashing the app.
  Future<void> _pickApk() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['apk'],
        withData: false,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path == null) {
          _showError('Could not read that file. Try again.');
          return;
        }
        setState(() => _apk = file);
      }
    } catch (e) {
      _showError('Could not open file picker: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit({required bool submitForReview}) async {
    if (!_formKey.currentState!.validate()) return;
    if (submitForReview && _apk == null) {
      _showError('Add an APK before submitting for review.');
      return;
    }

    setState(() {
      _saving = true;
      _statusText = 'Creating app...';
    });

    final repo = ref.read(developerRepositoryProvider);

    try {
      final appId = await repo.createApp(
        name: _name.text.trim(),
        shortDescription: _shortDescription.text.trim(),
        fullDescription: _fullDescription.text.trim(),
        category: _category,
      );

      if (_icon != null) {
        setState(() => _statusText = 'Uploading icon...');
        final bytes = await _icon!.readAsBytes();
        final url = await repo.uploadImage(appId, 'icon.jpg', bytes);
        await repo.updateIcon(appId, url);
      }

      if (_screenshots.isNotEmpty) {
        setState(() => _statusText = 'Uploading screenshots...');
        final urls = <String>[];
        for (var i = 0; i < _screenshots.length; i++) {
          final bytes = await _screenshots[i].readAsBytes();
          urls.add(await repo.uploadImage(appId, 'screenshot_$i.jpg', bytes));
        }
        await repo.updateScreenshots(appId, urls);
      }

      if (_apk != null) {
        setState(() => _statusText = 'Reading APK...');
        final apkBytes = await File(_apk!.path!).readAsBytes();

        setState(() => _statusText = 'Uploading to GitHub Releases...');
        final versionName = _versionName.text.trim();
        final result = await repo.uploadApk(
          appId: appId,
          versionName: versionName,
          bytes: apkBytes,
        );
        final downloadUrl = result['downloadUrl'] as String;

        await repo.createVersion(
          appId: appId,
          versionName: versionName,
          versionCode: int.tryParse(_versionCode.text.trim()) ?? 1,
          apkStoragePath: downloadUrl,
          releaseNotes: _releaseNotes.text.trim(),
          fileSizeBytes: _apk!.size,
        );
      }

      if (submitForReview) {
        setState(() => _statusText = 'Submitting for review...');
        await repo.submitForReview(appId);
      }

      ref.invalidate(myAppsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(submitForReview
              ? 'App submitted for review.'
              : 'Saved as draft.'),
        ),
      );
      context.pop();
    } catch (e) {
      _showError('Something went wrong: $e');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _statusText = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create app')),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _saving,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'App name'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _shortDescription,
                    decoration:
                        const InputDecoration(labelText: 'Short description'),
                    maxLength: 120,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: _fullDescription,
                    decoration:
                        const InputDecoration(labelText: 'Full description'),
                    maxLines: 4,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<AppCategory>(
                    value: _category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: AppCategory.values
                        .map((c) =>
                            DropdownMenuItem(value: c, child: Text(c.label)))
                        .toList(),
                    onChanged: (c) => setState(() => _category = c ?? _category),
                  ),
                  const SizedBox(height: 20),
                  Text('App icon', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  _PickerTile(
                    label: _icon == null ? 'Choose icon image' : _icon!.name,
                    icon: Icons.image_outlined,
                    onTap: _pickIcon,
                  ),
                  const SizedBox(height: 16),
                  Text('Screenshots',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  _PickerTile(
                    label: _screenshots.isEmpty
                        ? 'Choose screenshots'
                        : '${_screenshots.length} screenshot(s) selected',
                    icon: Icons.photo_library_outlined,
                    onTap: _pickScreenshots,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _versionName,
                          decoration: const InputDecoration(labelText: 'Version'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _versionCode,
                          decoration:
                              const InputDecoration(labelText: 'Version code'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _releaseNotes,
                    decoration: const InputDecoration(labelText: 'Release notes'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  Text('APK file', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  _PickerTile(
                    label: _apk == null
                        ? 'Choose APK'
                        : '${_apk!.name} (${(_apk!.size / (1024 * 1024)).toStringAsFixed(1)} MB)',
                    icon: Icons.android_rounded,
                    onTap: _pickApk,
                  ),
                  const SizedBox(height: 28),
                  if (_statusText != null) ...[
                    Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Text(_statusText!),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  ElevatedButton(
                    onPressed:
                        _saving ? null : () => _submit(submitForReview: true),
                    child: const Text('Submit for review'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed:
                        _saving ? null : () => _submit(submitForReview: false),
                    child: const Text('Save as draft'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile(
      {required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey.shade600),
            const SizedBox(width: 12),
            Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------
/// UPLOAD NEW VERSION
/// ---------------------------------------------------------------------
class UploadVersionScreen extends ConsumerStatefulWidget {
  const UploadVersionScreen({super.key, required this.appId});

  final String appId;

  @override
  ConsumerState<UploadVersionScreen> createState() =>
      _UploadVersionScreenState();
}

class _UploadVersionScreenState extends ConsumerState<UploadVersionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _versionName = TextEditingController();
  final _versionCode = TextEditingController();
  final _releaseNotes = TextEditingController();
  PlatformFile? _apk;
  bool _saving = false;
  String? _statusText;

  @override
  void dispose() {
    _versionName.dispose();
    _versionCode.dispose();
    _releaseNotes.dispose();
    super.dispose();
  }

  Future<void> _pickApk() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['apk'],
        withData: false,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() => _apk = result.files.first);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file picker: $e')));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_apk == null || _apk!.path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose an APK file first.')));
      return;
    }

    setState(() {
      _saving = true;
      _statusText = 'Reading APK...';
    });

    final repo = ref.read(developerRepositoryProvider);

    try {
      final versionName = _versionName.text.trim();
      final apkBytes = await File(_apk!.path!).readAsBytes();

      setState(() => _statusText = 'Uploading to GitHub Releases...');
      final result = await repo.uploadApk(
        appId: widget.appId,
        versionName: versionName,
        bytes: apkBytes,
      );
      final downloadUrl = result['downloadUrl'] as String;

      await repo.createVersion(
        appId: widget.appId,
        versionName: versionName,
        versionCode: int.tryParse(_versionCode.text.trim()) ?? 1,
        apkStoragePath: downloadUrl,
        releaseNotes: _releaseNotes.text.trim(),
        fileSizeBytes: _apk!.size,
      );

      ref.invalidate(appDetailsProvider(widget.appId));
      ref.invalidate(appVersionsProvider(widget.appId));
      ref.invalidate(myAppsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('New version uploaded.')));
      context.pop();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _statusText = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload new version')),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _saving,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _versionName,
                          decoration: const InputDecoration(labelText: 'Version'),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _versionCode,
                          decoration:
                              const InputDecoration(labelText: 'Version code'),
                          keyboardType: TextInputType.number,
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _releaseNotes,
                    decoration: const InputDecoration(labelText: 'Release notes'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  _PickerTile(
                    label: _apk == null
                        ? 'Choose APK'
                        : '${_apk!.name} (${(_apk!.size / (1024 * 1024)).toStringAsFixed(1)} MB)',
                    icon: Icons.android_rounded,
                    onTap: _pickApk,
                  ),
                  const SizedBox(height: 24),
                  if (_statusText != null) ...[
                    Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Text(_statusText!),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    child: const Text('Upload version'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------
/// MANAGE APP (developer detail view)
/// ---------------------------------------------------------------------
class DeveloperAppDetailScreen extends ConsumerWidget {
  const DeveloperAppDetailScreen({super.key, required this.appId});

  final String appId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appAsync = ref.watch(appDetailsProvider(appId));

    return Scaffold(
      appBar: AppBar(title: const Text('Manage app')),
      body: appAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => ErrorState(
          message: 'Could not load this app',
          onRetry: () => ref.invalidate(appDetailsProvider(appId)),
        ),
        data: (app) => _DeveloperAppBody(app: app),
      ),
    );
  }
}

class _DeveloperAppBody extends ConsumerWidget {
  const _DeveloperAppBody({required this.app});

  final AppModel app;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child:
                  Text(app.name, style: Theme.of(context).textTheme.headlineSmall),
            ),
            StatusBadge(status: app.status),
          ],
        ),
        const SizedBox(height: 4),
        Text('v${app.currentVersion} • ${app.category.label}',
            style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 20),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.8,
          children: [
            _StatCard(label: 'Downloads', value: '${app.downloadCount}'),
            _StatCard(label: 'Testers', value: '${app.testerCount}'),
          ],
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton.icon(
              onPressed: () => context.push('/developer/apps/${app.id}/upload'),
              icon: const Icon(Icons.upload_rounded),
              label: const Text('Upload new version'),
            ),
            if (app.status == AppStatus.draft)
              OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(developerRepositoryProvider).submitForReview(app.id);
                  ref.invalidate(appDetailsProvider(app.id));
                  ref.invalidate(myAppsProvider);
                },
                icon: const Icon(Icons.send_rounded),
                label: const Text('Submit for review'),
              ),
            if (app.status == AppStatus.published)
              OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(developerRepositoryProvider).setUnpublished(app.id);
                  ref.invalidate(appDetailsProvider(app.id));
                  ref.invalidate(myAppsProvider);
                },
                icon: const Icon(Icons.visibility_off_outlined),
                label: const Text('Unpublish'),
              ),
            OutlinedButton.icon(
              onPressed: () => context.push('/developer/apps/${app.id}/bugs'),
              icon: const Icon(Icons.bug_report_outlined),
              label: const Text('Bug reports'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.push('/developer/apps/${app.id}/feedback'),
              icon: const Icon(Icons.rate_review_outlined),
              label: const Text('Feedback'),
            ),
          ],
        ),
      ],
    );
  }
}

/// ---------------------------------------------------------------------
/// BUGS / FEEDBACK (developer view)
/// ---------------------------------------------------------------------
class DeveloperAppBugsScreen extends ConsumerWidget {
  const DeveloperAppBugsScreen({super.key, required this.appId});

  final String appId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bugsAsync = ref.watch(appBugReportsProvider(appId));

    return Scaffold(
      appBar: AppBar(title: const Text('Bug reports')),
      body: bugsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => ErrorState(
          message: 'Could not load bug reports',
          onRetry: () => ref.invalidate(appBugReportsProvider(appId)),
        ),
        data: (bugs) {
          if (bugs.isEmpty) {
            return const EmptyState(
              icon: Icons.bug_report_outlined,
              title: 'No bug reports yet',
              subtitle: 'Reports from testers will show up here.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bugs.length,
            itemBuilder: (context, index) {
              final bug = bugs[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(bug.title,
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                          SeverityBadge(severity: bug.severity),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(bug.description),
                      if (bug.stepsToReproduce != null) ...[
                        const SizedBox(height: 6),
                        Text('Steps: ${bug.stepsToReproduce}',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        '${bug.device ?? 'Unknown device'} • ${bug.androidVersion ?? '-'} • ${bug.status.label}',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class DeveloperAppFeedbackScreen extends ConsumerWidget {
  const DeveloperAppFeedbackScreen({super.key, required this.appId});

  final String appId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedbackAsync = ref.watch(appFeedbackProvider(appId));

    return Scaffold(
      appBar: AppBar(title: const Text('Feedback')),
      body: feedbackAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => ErrorState(
          message: 'Could not load feedback',
          onRetry: () => ref.invalidate(appFeedbackProvider(appId)),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.rate_review_outlined,
              title: 'No feedback yet',
              subtitle: 'Tester feedback will show up here.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final f = items[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < f.rating
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: Colors.amber,
                            size: 18,
                          ),
                        ),
                      ),
                      if (f.liked != null && f.liked!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Liked: ${f.liked}'),
                      ],
                      if (f.disliked != null && f.disliked!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('Disliked: ${f.disliked}'),
                      ],
                      if (f.suggestions != null && f.suggestions!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('Suggestions: ${f.suggestions}'),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
