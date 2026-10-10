package com.netravision.apps

import android.content.Context
import android.view.accessibility.AccessibilityManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity is required by ultralytics_yolo so the native YOLOView
// platform view can be hosted inside a Fragment with a lifecycle.
class MainActivity : FlutterFragmentActivity() {
    private val channelName = "com.netravision.apps/accessibility"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isTalkBackEnabled" -> {
                        val am = getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
                        result.success(am.isTouchExplorationEnabled)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
