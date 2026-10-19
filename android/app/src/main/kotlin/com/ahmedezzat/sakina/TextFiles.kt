package com.ahmedezzat.sakina

import android.app.Activity
import android.content.Intent
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Opens a text file the user picks and hands back its contents
 * ("sakina/files"), for restoring a backup.
 */
class TextFiles(private val activity: Activity) : MethodChannel.MethodCallHandler {
    private var pending: MethodChannel.Result? = null
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "openText") return result.notImplemented()
        if (pending != null) return result.success(null)
        pending = result
        try {
            activity.startActivityForResult(
                Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    // Shared JSON files come with all sorts of types.
                    type = "*/*"
                },
                REQUEST,
            )
        } catch (e: Exception) {
            pending = null
            result.error("no_picker", e.message, null)
        }
    }

    /** Called from MainActivity.onActivityResult; true when it was ours. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST) return false
        val result = pending ?: return true
        pending = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return true
        }
        io.execute {
            try {
                val bytes = activity.contentResolver.openInputStream(uri)!!.use { input ->
                    val buffer = java.io.ByteArrayOutputStream()
                    val chunk = ByteArray(64 * 1024)
                    while (true) {
                        val n = input.read(chunk)
                        if (n < 0) break
                        buffer.write(chunk, 0, n)
                        if (buffer.size() > MAX_BYTES) throw IllegalStateException("Too large for a backup")
                    }
                    buffer.toByteArray()
                }
                val text = String(bytes, Charsets.UTF_8)
                main.post { result.success(text) }
            } catch (e: Exception) {
                main.post { result.error("read_failed", e.message, null) }
            }
        }
        return true
    }

    companion object {
        private const val REQUEST = 7201
        private const val MAX_BYTES = 10 * 1024 * 1024
    }
}
