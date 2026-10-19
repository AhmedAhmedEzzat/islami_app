package com.ahmedezzat.sakina

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.provider.OpenableColumns
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Lets the user choose their own adhan recording ("sakina/sounds").
 *
 * A notification sound must be a URI the system itself can read, so a file
 * the user picks is copied into the shared Notifications folder through
 * MediaStore rather than played from wherever it came from. Sounds already on
 * the phone come from the system's own sound picker, whose URIs qualify.
 */
class AdhanSounds(private val activity: Activity) : MethodChannel.MethodCallHandler {
    private var pending: MethodChannel.Result? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickSystem" -> start(result, REQUEST_SYSTEM) {
                Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
                    putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_ALL)
                    putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
                    putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, false)
                    call.argument<String>("current")?.let {
                        putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, Uri.parse(it))
                    }
                }
            }
            "pickFile" -> {
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                    // Saving to the shared folder needs storage permission before Android 10.
                    result.error("unsupported", "Needs Android 10 or later", null)
                    return
                }
                start(result, REQUEST_FILE) {
                    Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "audio/*"
                    }
                }
            }
            "canPickFile" -> result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
            "exists" -> result.success(exists(Uri.parse(call.argument<String>("uri")!!)))
            else -> result.notImplemented()
        }
    }

    private fun start(result: MethodChannel.Result, request: Int, intent: () -> Intent) {
        // A second tap while a picker is open replaces the first request.
        pending?.success(null)
        pending = result
        try {
            activity.startActivityForResult(intent(), request)
        } catch (e: Exception) {
            pending = null
            result.error("no_picker", e.message, null)
        }
    }

    /** Called from MainActivity.onActivityResult; true when it was ours. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_SYSTEM && requestCode != REQUEST_FILE) return false
        val result = pending ?: return true
        pending = null
        if (resultCode != Activity.RESULT_OK || data == null) {
            result.success(null)
            return true
        }
        try {
            val picked = if (requestCode == REQUEST_SYSTEM) {
                @Suppress("DEPRECATION")
                data.getParcelableExtra<Uri>(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
                    ?.let { it to RingtoneManager.getRingtone(activity, it)?.getTitle(activity) }
            } else {
                data.data?.let { copyToNotifications(it) }
            }
            result.success(picked?.let { (uri, title) -> mapOf("uri" to uri.toString(), "title" to (title ?: "")) })
        } catch (e: Exception) {
            result.error("copy_failed", e.message, null)
        }
        return true
    }

    /** Copies [source] into Notifications/Sakina and returns its MediaStore URI and name. */
    private fun copyToNotifications(source: Uri): Pair<Uri, String> {
        val resolver = activity.contentResolver
        var name = "adhan"
        resolver.query(source, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
            if (it.moveToFirst()) name = it.getString(0) ?: name
        }
        val values = ContentValues().apply {
            put(MediaStore.Audio.Media.DISPLAY_NAME, name)
            put(MediaStore.Audio.Media.MIME_TYPE, resolver.getType(source) ?: "audio/mpeg")
            put(MediaStore.Audio.Media.RELATIVE_PATH, "Notifications/Sakina")
            put(MediaStore.Audio.Media.IS_NOTIFICATION, 1)
            put(MediaStore.Audio.Media.IS_PENDING, 1)
        }
        val target = resolver.insert(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("MediaStore refused the file")
        try {
            resolver.openInputStream(source).use { input ->
                resolver.openOutputStream(target).use { output ->
                    input!!.copyTo(output!!)
                }
            }
            resolver.update(target, ContentValues().apply { put(MediaStore.Audio.Media.IS_PENDING, 0) }, null, null)
        } catch (e: Exception) {
            resolver.delete(target, null, null)
            throw e
        }
        return target to name.substringBeforeLast('.')
    }

    private fun exists(uri: Uri): Boolean = try {
        activity.contentResolver.openAssetFileDescriptor(uri, "r")?.use { true } ?: false
    } catch (e: Exception) {
        false
    }

    companion object {
        private const val REQUEST_SYSTEM = 7101
        private const val REQUEST_FILE = 7102
    }
}
