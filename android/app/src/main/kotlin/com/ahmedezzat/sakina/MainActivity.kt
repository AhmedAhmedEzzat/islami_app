package com.ahmedezzat.sakina

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val sounds = AdhanSounds(this)
    private val files = TextFiles(this)

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
        // Choosing the user's own adhan recording.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sakina/sounds")
            .setMethodCallHandler(sounds)
        // Restoring a backup.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sakina/files")
            .setMethodCallHandler(files)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (!sounds.onActivityResult(requestCode, resultCode, data) &&
            !files.onActivityResult(requestCode, resultCode, data)
        ) {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }
}
