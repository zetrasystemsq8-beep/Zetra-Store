import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_core.dart';

/// One in-progress or just-finished download, tracked globally so its
/// progress can be shown as a small corner card instead of a blocking
/// dialog — and so more than one download can run at the same time.
class DownloadTask {
  DownloadTask({
    required this.id,
    required this.appName,
    this.progress = 0,
    this.status = DownloadStatus.downloading,
    this.errorMessage,
  });

  final String id; // use the app id, or app id + version for rollback
  final String appName;
  final double progress; // 0.0 - 1.0
  final DownloadStatus status;
  final String? errorMessage;

  DownloadTask copyWith({
    double? progress,
    DownloadStatus? status,
    String? errorMessage,
  }) {
    return DownloadTask(
      id: id,
      appName: appName,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

enum DownloadStatus { downloading, installing, done, failed, cancelled }

class DownloadManager extends StateNotifier<Map<String, DownloadTask>> {
  DownloadManager() : super({});

  void start(String id, String appName) {
    state = {
      ...state,
      id: DownloadTask(id: id, appName: appName),
    };
  }

  void updateProgress(String id, double progress) {
    final task = state[id];
    if (task == null) return;
    state = {...state, id: task.copyWith(progress: progress)};
  }

  void setInstalling(String id) {
    final task = state[id];
    if (task == null) return;
    state = {
      ...state,
      id: task.copyWith(status: DownloadStatus.installing),
    };
  }

  void finish(String id) {
    final task = state[id];
    if (task == null) return;
    state = {...state, id: task.copyWith(status: DownloadStatus.done)};
    // Auto-remove the finished card after a short delay.
    Future.delayed(const Duration(seconds: 3), () => dismiss(id));
  }

  void fail(String id, String message) {
    final task = state[id];
    if (task == null) return;
    state = {
      ...state,
      id: task.copyWith(status: DownloadStatus.failed, errorMessage: message),
    };
  }

  bool cancelRequested(String id) =>
      state[id]?.status == DownloadStatus.cancelled;

  void cancel(String id) {
    final task = state[id];
    if (task == null) return;
    state = {...state, id: task.copyWith(status: DownloadStatus.cancelled)};
    Future.delayed(const Duration(milliseconds: 500), () => dismiss(id));
  }

  void dismiss(String id) {
    final next = {...state};
    next.remove(id);
    state = next;
  }
}

final downloadManagerProvider =
    StateNotifierProvider<DownloadManager, Map<String, DownloadTask>>(
        (ref) => DownloadManager());

/// Small stack of corner cards showing every active download. Drop this
/// once, near the top of the widget tree (in ZetraScaffold), so it
/// floats above every screen without blocking navigation.
class DownloadOverlay extends ConsumerWidget {
  const DownloadOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(downloadManagerProvider);
    final colors = context.zetraColors;

    if (tasks.isEmpty) return const SizedBox.shrink();

    return Positioned(
      left: 12,
      right: 12,
      bottom: 90, // sits above the bottom nav bar
      child: IgnorePointer(
        ignoring: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: tasks.values.map((task) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: task.status == DownloadStatus.failed
                        ? Icon(Icons.error_outline_rounded,
                            color: colors.errorSoft, size: 20)
                        : task.status == DownloadStatus.done
                            ? const Icon(Icons.check_circle_rounded,
                                color: Color(0xFF34D399), size: 20)
                            : CircularProgressIndicator(
                                strokeWidth: 2.4,
                                value: task.progress > 0 ? task.progress : null,
                                color: colors.accentEnd,
                              ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(task.appName,
                            style: TextStyle(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        Text(
                          task.status == DownloadStatus.failed
                              ? (task.errorMessage ?? 'Download failed')
                              : task.status == DownloadStatus.installing
                                  ? 'Installing...'
                                  : task.status == DownloadStatus.done
                                      ? 'Done'
                                      : task.progress > 0
                                          ? '${(task.progress * 100).toStringAsFixed(0)}%'
                                          : 'Starting...',
                          style: TextStyle(
                              color: colors.textSecondary, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  if (task.status == DownloadStatus.downloading)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      color: colors.textMuted,
                      onPressed: () => ref
                          .read(downloadManagerProvider.notifier)
                          .cancel(task.id),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      color: colors.textMuted,
                      onPressed: () => ref
                          .read(downloadManagerProvider.notifier)
                          .dismiss(task.id),
                    ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
