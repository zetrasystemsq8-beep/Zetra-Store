import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// =====================================================================
/// ANNOUNCEMENT MODEL
/// =====================================================================
class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.minAppVersion,
    this.maxAppVersion,
    this.requireAcknowledgment = false,
    this.enabled = true,
  });

  final String id;
  final String title;
  final String message;
  final AnnouncementType type;
  final int? minAppVersion;
  final int? maxAppVersion;
  final bool requireAcknowledgment;
  final bool enabled;

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      type: AnnouncementType.fromString(json['type'] as String),
      minAppVersion: json['min_app_version'] as int?,
      maxAppVersion: json['max_app_version'] as int?,
      requireAcknowledgment: json['require_acknowledgment'] as bool? ?? false,
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}

enum AnnouncementType {
  warning,
  info,
  critical;

  factory AnnouncementType.fromString(String value) {
    return AnnouncementType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => AnnouncementType.info,
    );
  }

  Color get color {
    switch (this) {
      case AnnouncementType.warning:
        return Colors.orange;
      case AnnouncementType.critical:
        return Colors.red;
      case AnnouncementType.info:
        return Colors.blue;
    }
  }

  IconData get icon {
    switch (this) {
      case AnnouncementType.warning:
        return Icons.warning_rounded;
      case AnnouncementType.critical:
        return Icons.error_rounded;
      case AnnouncementType.info:
        return Icons.info_rounded;
    }
  }

  String get label {
    switch (this) {
      case AnnouncementType.warning:
        return 'Warning';
      case AnnouncementType.critical:
        return 'Critical';
      case AnnouncementType.info:
        return 'Notice';
    }
  }
}

/// =====================================================================
/// ANNOUNCEMENT SERVICE
/// =====================================================================
class AnnouncementService {
  AnnouncementService(this._supabase);

  final SupabaseClient _supabase;

  Future<List<Announcement>> fetchActiveAnnouncements({
    required int currentAppVersion,
  }) async {
    try {
      final response = await _supabase
          .from('announcements')
          .select()
          .eq('enabled', true)
          .order('created_at', ascending: false);

      final announcements =
          (response as List).map((json) => Announcement.fromJson(json)).toList();

      // Filter by app version
      return announcements.where((announcement) {
        final minVersion = announcement.minAppVersion;
        final maxVersion = announcement.maxAppVersion;

        if (minVersion != null && currentAppVersion < minVersion) {
          return false;
        }
        if (maxVersion != null && currentAppVersion > maxVersion) {
          return false;
        }
        return true;
      }).toList();
    } catch (e) {
      debugPrint('Error fetching announcements: $e');
      return [];
    }
  }

  Future<void> acknowledgeAnnouncement(String announcementId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase.from('announcement_acknowledgments').insert({
        'announcement_id': announcementId,
        'user_id': userId,
        'acknowledged_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error acknowledging announcement: $e');
    }
  }

  Future<bool> hasAcknowledged(String announcementId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('announcement_acknowledgments')
          .select()
          .eq('announcement_id', announcementId)
          .eq('user_id', userId)
          .single();

      return response != null;
    } catch (e) {
      // Not found is OK
      return false;
    }
  }
}

/// =====================================================================
/// PROVIDERS
/// =====================================================================
final announcementServiceProvider = Provider((ref) {
  return AnnouncementService(Supabase.instance.client);
});

// App version from pubspec.yaml (you'll need to import package_info_plus)
const currentAppVersion = 1; // Update this with each release

final activeAnnouncementsProvider = FutureProvider.autoDispose((ref) async {
  final service = ref.watch(announcementServiceProvider);
  return service.fetchActiveAnnouncements(
    currentAppVersion: currentAppVersion,
  );
});

final announcementAcknowledgedProvider = FutureProvider.autoDispose
    .family<bool, String>((ref, announcementId) async {
  final service = ref.watch(announcementServiceProvider);
  return service.hasAcknowledged(announcementId);
});

/// =====================================================================
/// UI COMPONENTS
/// =====================================================================

/// Display a single announcement card
class AnnouncementCard extends ConsumerWidget {
  const AnnouncementCard({
    super.key,
    required this.announcement,
    this.onDismiss,
    this.onAcknowledge,
  });

  final Announcement announcement;
  final VoidCallback? onDismiss;
  final VoidCallback? onAcknowledge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: announcement.type.color.withOpacity(0.3),
          width: 1.5,
        ),
        color: announcement.type.color.withOpacity(0.08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                announcement.type.icon,
                color: announcement.type.color,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  announcement.type.label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: announcement.type.color,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              if (onDismiss != null && !announcement.requireAcknowledgment)
                GestureDetector(
                  onTap: onDismiss,
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: colors.onSurface.withOpacity(0.5),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            announcement.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            announcement.message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  height: 1.5,
                ),
          ),
          if (announcement.requireAcknowledgment) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onAcknowledge,
                child: const Text('I understand'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Display all active announcements
class AnnouncementsList extends ConsumerStatefulWidget {
  const AnnouncementsList({super.key, this.onAllDismissed});

  final VoidCallback? onAllDismissed;

  @override
  ConsumerState<AnnouncementsList> createState() => _AnnouncementsListState();
}

class _AnnouncementsListState extends ConsumerState<AnnouncementsList> {
  final Set<String> _dismissed = {};

  @override
  Widget build(BuildContext context) {
    final announcementsAsync = ref.watch(activeAnnouncementsProvider);
    final service = ref.watch(announcementServiceProvider);

    return announcementsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, st) => SizedBox.shrink(),
      data: (announcements) {
        // Filter out dismissed and acknowledged announcements
        final visibleAnnouncements = announcements.where((announcement) {
          if (_dismissed.contains(announcement.id)) return false;
          return true;
        }).toList();

        if (visibleAnnouncements.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          children: visibleAnnouncements
              .map((announcement) => AnnouncementCard(
                    announcement: announcement,
                    onDismiss: announcement.requireAcknowledgment
                        ? null
                        : () {
                            setState(() {
                              _dismissed.add(announcement.id);
                            });
                            if (_dismissed.length ==
                                visibleAnnouncements.length) {
                              widget.onAllDismissed?.call();
                            }
                          },
                    onAcknowledge: announcement.requireAcknowledgment
                        ? () async {
                            await service
                                .acknowledgeAnnouncement(announcement.id);
                            if (mounted) {
                              setState(() {
                                _dismissed.add(announcement.id);
                              });
                              if (_dismissed.length ==
                                  visibleAnnouncements.length) {
                                widget.onAllDismissed?.call();
                              }
                            }
                          }
                        : null,
                  ))
              .toList(),
        );
      },
    );
  }
}

/// Launch announcements dialog on app start
Future<void> showAnnouncementsDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final announcements = await ref.read(activeAnnouncementsProvider.future);

  if (announcements.isEmpty || !context.mounted) return;

  // Show modal that must be dismissed
  if (context.mounted) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Important'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: announcements
                .map((announcement) => AnnouncementCard(
                      announcement: announcement,
                      onDismiss: announcements.indexOf(announcement) ==
                              announcements.length - 1
                          ? () => Navigator.of(dialogContext).pop()
                          : null,
                      onAcknowledge: () async {
                        await ref
                            .read(announcementServiceProvider)
                            .acknowledgeAnnouncement(announcement.id);
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                      },
                    ))
                .toList(),
          ),
        ),
        actions: announcements.every((a) => a.requireAcknowledgment)
            ? []
            : [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Dismiss'),
                ),
              ],
      ),
    );
  }
}
