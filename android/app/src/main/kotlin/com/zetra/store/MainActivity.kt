package com.zetra.store

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "zetra_store/package_info"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInstalledVersion" -> {
                        val packageName = call.argument<String>("packageName")
                        if (packageName.isNullOrBlank()) {
                            result.error("INVALID_ARGUMENT", "packageName is required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val info = packageManager.getPackageInfo(packageName, 0)
                            val versionCode = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                                info.longVersionCode.toInt()
                            } else {
                                @Suppress("DEPRECATION")
                                info.versionCode
                            }
                            result.success(mapOf("installed" to true, "versionCode" to versionCode))
                        } catch (e: PackageManager.NameNotFoundException) {
                            result.success(mapOf("installed" to false, "versionCode" to 0))
                        }
                    }
                    "launchApp" -> {
                        val packageName = call.argument<String>("packageName")
                        if (packageName.isNullOrBlank()) {
                            result.error("INVALID_ARGUMENT", "packageName is required", null)
                            return@setMethodCallHandler
                        }
                        val intent = packageManager.getLaunchIntentForPackage(packageName)
                        if (intent != null) {
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
