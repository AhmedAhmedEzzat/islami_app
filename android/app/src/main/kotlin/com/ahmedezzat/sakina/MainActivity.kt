package com.ahmedezzat.sakina

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Lets the app redraw the home screen widget as soon as the times change.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sakina/widget")
            .setMethodCallHandler { call, result ->
                if (call.method == "update") {
                    PrayerWidget.updateAll(applicationContext)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }
}
