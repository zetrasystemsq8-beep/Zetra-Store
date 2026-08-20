import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_core.dart';
import '../core/models.dart';
import 'developer.dart';
import 'developer_auth.dart';
import 'discover.dart';

/// ---------------------------------------------------------------------
/// REPOSITORY
/// ---------------------------------------------------------------------
class PlatformRepository {
  PlatformRepository(this._client);

  final SupabaseClient _client;

  Future<String> uploadBugScreenshot(String appId, Uint8List bytes) async {
    final path =
        'apps/$appId/bug-screenshots/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _client.storage.from('apps').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return _client.storage.from('apps').getPublicUrl(path);
  }

  Future<List<BugReport>> fetchMyBugReports(String testerId) async {
    final rows = await _client
        .from('bug_reports')
        .select()
        .eq('reporter_id', testerId)
        .order('created_at', ascending: false);
    return rows.map((r) => BugReport.fromMap(r)).toList();
  }

  Future<List<FeedbackModel>> fetchMyFeedback(String testerId) async {
    final rows = await _client
        .from('feedback')
        .select()
        .eq('user_id', testerId)
        .order('created_at', ascending: false);
    return rows.map((r) => FeedbackModel.fromMap(r)).toList();
  }

  Future<List<AppModel>> fetchPendingApps() async {
    final rows = await _client
        .from('apps')
        .select()
        .eq('status', AppStatus.pendingReview.name)
        .order('created_at', ascending: false);
    return rows.map((r) => AppModel.fromMap(r)).toList();
  }

  Future<void> approveApp(String appId) async {
    await _client
        .from('apps')
        .update({'status': AppStatus.published.name}).eq('id', appId);
  }

  Future<void> rejectApp(String appId) async {
    await _client
        .from('apps')
        .update({'status': AppStatus.draft.name}).eq('id', appId);
  }
}

final platformRepositoryProvider = Provider<PlatformRepository>((ref) {
  return PlatformRepository(ref.watch(supabaseClientProvider));
});

/// The current guest/anonymous tester ID — for now, just a stable
/// per-session placeholder for anyone who isn't a signed-in developer.
/// (Testers don't need accounts per your guest-mode decision.)
const kPlaceholderTesterId = 'guest-tester';

final myBugReportsProvider =
    FutureProvider.autoDispose<List<BugReport>>((ref) {
  return ref
      .watch(platformRepositoryProvider)
      .fetchMyBugReports(kPlaceholderTesterId);
});

final myFeedbackProvider =
    FutureProvider.autoDispose<List<FeedbackModel>>((ref) {
  return ref
      .watch(platformRepositoryProvider)
      .fetchMyFeedback(kPlaceholderTesterId);
});

final pendingAppsProvider = FutureProvider.autoDispose<List<AppModel>>((ref) {
  return ref.watch(platformRepositoryProvider).fetchPendingApps();
});

final adminUnlockedProvider = StateProvider<bool>((ref) => false);

/// ---------------------------------------------------------------------
/// BUG REPORT FORM
/// ---------------------------------------------------------------------
class BugReportScreen extends ConsumerStatefulWidget {
  const BugReportScreen({super.key, required this.appId});

  final String appId;

  @override
  ConsumerState<BugReportScreen> createState() => _BugReportScreenState();
}

class _BugReportScreenState extends ConsumerState<BugReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _device = TextEditingController();
  final _androidVersion = TextEditingController();
  final _steps = TextEditingController();
  BugSeverity _severity = BugSeverity.minor;
  XFile? _screenshot;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _device.dispose();
    _androidVersion.dispose();
    _steps.dispose();
    super.dispose();
  }

  Future<void> _pickScreenshot() async {
    final file = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file != null) setState(() => _screenshot = file);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      String? screenshotUrl;
      if (_screenshot != null) {
        final bytes = await _screenshot!.readAsBytes();
        screenshotUrl = await ref
            .read(platformRepositoryProvider)
            .uploadBugScreenshot(widget.appId, bytes);
      }

      final app = await ref.read(appDetailsProvider(widget.appId).future);

      await ref.read(appsRepositoryProvider).submitBugReport(
            BugReport(
              id: '',
              appId: widget.appId,
              appName: app.name,
              reporterId: kPlaceholderTesterId,
              title: _title.text.trim(),
              description: _description.text.trim(),
              severity: _severity,
              status: BugStatus.submitted,
              createdAt: DateTime.now(),
              device:
                  _device.text.trim().isEmpty ? null : _device.text.trim(),
              androidVersion: _androidVersion.text.trim().isEmpty
                  ? null
                  : _androidVersion.text.trim(),
              stepsToReproduce:
                  _steps.text.trim().isEmpty ? null : _steps.text.trim(),
              screenshotUrl: screenshotUrl,
            ),
          );

      ref.invalidate(myBugReportsProvider);
      ref.invalidate(appBugReportsProvider(widget.appId));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bug report submitted. Thanks!')));
      context.pop();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not submit: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('Report a bug')),
      body: GlowBackground(
        child: SafeArea(
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
                      controller: _title,
                      decoration: const InputDecoration(labelText: 'Title'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _description,
                      decoration:
                          const InputDecoration(labelText: 'Description'),
                      maxLines: 4,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<BugSeverity>(
                      value: _severity,
                      dropdownColor: ZetraColors.card,
                      decoration: const InputDecoration(labelText: 'Severity'),
                      items: BugSeverity.values
                          .map((s) =>
                              DropdownMenuItem(value: s, child: Text(s.label)))
                          .toList(),
                      onChanged: (s) => setState(() => _severity = s ?? _severity),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _device,
                            decoration: const InputDecoration(
                                labelText: 'Device (optional)'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _androidVersion,
                            decoration:
                                const InputDecoration(labelText: 'Android version'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _steps,
                      decoration: const InputDecoration(
                          labelText: 'Steps to reproduce (optional)'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    _PickerTile(
                      label: _screenshot == null
                          ? 'Attach screenshot (optional)'
                          : _screenshot!.name,
                      icon: Icons.image_outlined,
                      onTap: _pickScreenshot,
                    ),
                    const SizedBox(height: 24),
                    GradientButton(
                      label: 'Submit report',
                      isLoading: _saving,
                      onPressed: _saving ? null : _submit,
                    ),
                  ],
                ),
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
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: ZetraColors.cardBorder),
          borderRadius: BorderRadius.circular(14),
          color: ZetraColors.card,
        ),
        child: Row(
          children: [
            Icon(icon, color: ZetraColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: ZetraColors.textPrimary))),
            const Icon(Icons.chevron_right_rounded, color: ZetraColors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------
/// FEEDBACK FORM
/// ---------------------------------------------------------------------
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key, required this.appId});

  final String appId;

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  int _rating = 5;
  final _liked = TextEditingController();
  final _disliked = TextEditingController();
  final _suggestions = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _liked.dispose();
    _disliked.dispose();
    _suggestions.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final app = await ref.read(appDetailsProvider(widget.appId).future);

      await ref.read(appsRepositoryProvider).submitFeedback(
            FeedbackModel(
              id: '',
              appId: widget.appId,
              appName: app.name,
              userId: kPlaceholderTesterId,
              rating: _rating,
              createdAt: DateTime.now(),
              liked: _liked.text.trim().isEmpty ? null : _liked.text.trim(),
              disliked:
                  _disliked.text.trim().isEmpty ? null : _disliked.text.trim(),
              suggestions: _suggestions.text.trim().isEmpty
                  ? null
                  : _suggestions.text.trim(),
            ),
          );

      ref.invalidate(myFeedbackProvider);
      ref.invalidate(appFeedbackProvider(widget.appId));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Feedback submitted. Thanks!')));
      context.pop();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not submit: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('Give feedback')),
      body: GlowBackground(
        child: SafeArea(
          child: AbsorbPointer(
            absorbing: _saving,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('How would you rate this app?',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(5, (i) {
                      final filled = i < _rating;
                      return IconButton(
                        icon: Icon(
                            filled
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: Colors.amber,
                            size: 32),
                        onPressed: () => setState(() => _rating = i + 1),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _liked,
                    decoration: const InputDecoration(
                        labelText: 'What did you like? (optional)'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _disliked,
                    decoration: const InputDecoration(
                        labelText: 'What did you dislike? (optional)'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _suggestions,
                    decoration:
                        const InputDecoration(labelText: 'Suggestions (optional)'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  GradientButton(
                    label: 'Submit feedback',
                    isLoading: _saving,
                    onPressed: _saving ? null : _submit,
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
/// MY TESTS
/// ---------------------------------------------------------------------
class MyTestsScreen extends ConsumerWidget {
  const MyTestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bugsAsync = ref.watch(myBugReportsProvider);
    final feedbackAsync = ref.watch(myFeedbackProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('My tests')),
      body: GlowBackground(
        child: RefreshIndicator(
          color: ZetraColors.accentEnd,
          backgroundColor: ZetraColors.card,
          onRefresh: () async {
            ref.invalidate(myBugReportsProvider);
            ref.invalidate(myFeedbackProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SectionHeader(title: 'Bug reports you submitted'),
              bugsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator(color: ZetraColors.accentEnd)),
                error: (e, st) =>
                    const ErrorState(message: 'Could not load your bug reports'),
                data: (bugs) {
                  if (bugs.isEmpty) {
                    return const EmptyState(
                      icon: Icons.bug_report_outlined,
                      title: 'No bug reports yet',
                      subtitle: 'Reports you submit will show up here.',
                    );
                  }
                  return Column(
                    children: bugs
                        .map((b) => Card(
                              child: ListTile(
                                title: Text(b.title),
                                subtitle: Text(b.appName,
                                    style: const TextStyle(color: ZetraColors.textSecondary)),
                                trailing: SeverityBadge(severity: b.severity),
                              ),
                            ))
                        .toList(),
                  );
                },
              ),
              const SectionHeader(title: 'Feedback you gave'),
              feedbackAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator(color: ZetraColors.accentEnd)),
                error: (e, st) =>
                    const ErrorState(message: 'Could not load your feedback'),
                data: (items) {
                  if (items.isEmpty) {
                    return const EmptyState(
                      icon: Icons.rate_review_outlined,
                      title: 'No feedback yet',
                      subtitle: 'Feedback you give will show up here.',
                    );
                  }
                  return Column(
                    children: items
                        .map((f) => Card(
                              child: ListTile(
                                title: Text(f.appName),
                                subtitle: Text('${f.rating} / 5',
                                    style: const TextStyle(color: ZetraColors.textSecondary)),
                              ),
                            ))
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------
/// PROFILE
/// ---------------------------------------------------------------------
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loggedIn = ref.watch(developerLoggedInProvider).value ?? false;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const GlowIcon(icon: Icons.person_rounded, size: 72),
          const SizedBox(height: 14),
          Text(loggedIn ? 'Developer account' : 'Browsing as guest',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            loggedIn
                ? 'Signed in with your Zetra ID.'
                : 'Sign in with your Zetra ID to publish apps. '
                  'You can browse and test apps without an account.',
            style: const TextStyle(color: ZetraColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.dashboard_outlined),
            title: const Text('Developer dashboard'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/developer'),
          ),
          ListTile(
            leading: const Icon(Icons.fact_check_outlined),
            title: const Text('My tests'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/tests'),
          ),
          ListTile(
            leading: const Icon(Icons.admin_panel_settings_outlined),
            title: const Text('Admin panel'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/admin'),
          ),
          ListTile(
            leading: const Icon(Icons.support_agent_rounded),
            title: const Text('Contact us'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/contact'),
          ),
          if (loggedIn) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: ZetraColors.errorSoft),
              title: const Text('Sign out', style: TextStyle(color: ZetraColors.errorSoft)),
              onTap: () async {
                await ref.read(developerAuthRepositoryProvider).signOut();
                if (context.mounted) context.go('/');
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------
/// ADMIN
/// ---------------------------------------------------------------------
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlocked = ref.watch(adminUnlockedProvider);

    if (!unlocked) {
      return const _AdminPinGate();
    }

    return const _AdminPendingList();
  }
}

class _AdminPinGate extends ConsumerStatefulWidget {
  const _AdminPinGate();

  @override
  ConsumerState<_AdminPinGate> createState() => _AdminPinGateState();
}

class _AdminPinGateState extends ConsumerState<_AdminPinGate> {
  final _pin = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_pin.text == Env.adminPin && Env.adminPin.isNotEmpty) {
      ref.read(adminUnlockedProvider.notifier).state = true;
    } else {
      setState(() => _error = 'Incorrect PIN');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('Admin access')),
      body: GlowBackground(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Center(child: GlowIcon(icon: Icons.lock_outline_rounded)),
                const SizedBox(height: 20),
                Text('Enter admin PIN',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 6),
                const Text(
                  'App review and approval are restricted.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ZetraColors.textSecondary),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _pin,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'PIN',
                    errorText: _error,
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Enter the PIN' : null,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 20),
                GradientButton(label: 'Unlock', onPressed: _submit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminPendingList extends ConsumerWidget {
  const _AdminPendingList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingAppsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('Admin — pending review')),
      body: GlowBackground(
        child: RefreshIndicator(
          color: ZetraColors.accentEnd,
          backgroundColor: ZetraColors.card,
          onRefresh: () async => ref.invalidate(pendingAppsProvider),
          child: pendingAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator(color: ZetraColors.accentEnd)),
            error: (e, st) => ErrorState(
              message: 'Could not load pending apps',
              onRetry: () => ref.invalidate(pendingAppsProvider),
            ),
            data: (apps) {
              if (apps.isEmpty) {
                return ListView(
                  children: const [
                    SizedBox(height: 80),
                    EmptyState(
                      icon: Icons.task_alt_rounded,
                      title: 'Nothing pending review',
                      subtitle: 'Submitted apps will show up here.',
                    ),
                  ],
                );
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: apps
                    .map((app) => AppCard(
                          app: app,
                          onTap: () => context.push('/admin/apps/${app.id}'),
                        ))
                    .toList(),
              );
            },
          ),
        ),
      ),
    );
  }
}

class AppReviewScreen extends ConsumerWidget {
  const AppReviewScreen({super.key, required this.appId});

  final String appId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlocked = ref.watch(adminUnlockedProvider);
    if (!unlocked) {
      return const _AdminPinGate();
    }

    final appAsync = ref.watch(appDetailsProvider(appId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('Review app')),
      body: GlowBackground(
        child: appAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: ZetraColors.accentEnd)),
          error: (e, st) => ErrorState(
            message: 'Could not load this app',
            onRetry: () => ref.invalidate(appDetailsProvider(appId)),
          ),
          data: (app) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(app.name, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text('by ${app.developerName}',
                  style: const TextStyle(color: ZetraColors.textSecondary)),
              const SizedBox(height: 12),
              StatusBadge(status: app.status),
              const SizedBox(height: 20),
              Text(
                app.fullDescription.isNotEmpty
                    ? app.fullDescription
                    : app.shortDescription,
                style: const TextStyle(color: ZetraColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await ref
                            .read(platformRepositoryProvider)
                            .approveApp(appId);
                        ref.invalidate(appDetailsProvider(appId));
                        ref.invalidate(pendingAppsProvider);
                        ref.invalidate(myAppsProvider);
                        if (context.mounted) context.pop();
                      },
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Approve'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await ref
                            .read(platformRepositoryProvider)
                            .rejectApp(appId);
                        ref.invalidate(appDetailsProvider(appId));
                        ref.invalidate(pendingAppsProvider);
                        ref.invalidate(myAppsProvider);
                        if (context.mounted) context.pop();
                      },
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Send back to draft'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
