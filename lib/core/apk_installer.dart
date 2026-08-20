import 'package:flutter/services.dart';

/// Bridges to native Android code (see MainActivity.kt) to trigger the
/// system package installer directly via ACTION_INSTALL_PACKAGE, instead
/// of going through OpenFilex's generic ACTION_VIEW (which can trigger a
/// "Complete action using..." chooser popup on some devices).
///
/// Uses the same MethodChannel as the existing installed-version/launch
/// checks (zetra_store/package_info) rather than a separate channel.
class ApkInstaller {
  ApkInstaller._();

  static const _channel = MethodChannel('zetra_store/package_info');

  /// Prompts Android to install (or update) the APK at [filePath].
  /// Throws a PlatformException if the native side reports a failure
  /// (e.g. file not found).
  static Future<void> install(String filePath) async {
    await _channel.invokeMethod<void>('installApk', {'filePath': filePath});
  }
}
