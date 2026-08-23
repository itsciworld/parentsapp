package com.app.parent.app

import android.Manifest
import android.content.ContentValues
import android.content.pm.PackageManager
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Extends FlutterFragmentActivity rather than FlutterActivity because
 * local_auth shows AndroidX's BiometricPrompt, which is a Fragment and can only
 * be hosted by a FragmentActivity. On a plain FlutterActivity every biometric
 * call fails at runtime.
 */
class MainActivity : FlutterFragmentActivity() {
    private val downloadsChannel = "vigil/downloads"
    private val storagePermissionRequest = 4901

    /** A save waiting on the WRITE_EXTERNAL_STORAGE grant (API < 29 only). */
    private data class PendingSave(
        val name: String,
        val mimeType: String,
        val bytes: ByteArray,
        val result: MethodChannel.Result,
    )

    private var pendingSave: PendingSave? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, downloadsChannel)
            .setMethodCallHandler { call, result ->
                if (call.method != "saveToDownloads") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val name = call.argument<String>("name")
                val bytes = call.argument<ByteArray>("bytes")
                val mimeType = call.argument<String>("mimeType") ?: "application/pdf"
                if (name.isNullOrBlank() || bytes == null) {
                    result.error("BAD_ARGS", "name and bytes are required", null)
                    return@setMethodCallHandler
                }

                // API < 29 writes a raw file into the public Downloads folder,
                // which needs the (runtime) WRITE_EXTERNAL_STORAGE permission.
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q &&
                    ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.WRITE_EXTERNAL_STORAGE,
                    ) != PackageManager.PERMISSION_GRANTED
                ) {
                    pendingSave = PendingSave(name, mimeType, bytes, result)
                    ActivityCompat.requestPermissions(
                        this,
                        arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                        storagePermissionRequest,
                    )
                    return@setMethodCallHandler
                }

                completeSave(name, mimeType, bytes, result)
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != storagePermissionRequest) return
        val save = pendingSave ?: return
        pendingSave = null
        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            completeSave(save.name, save.mimeType, save.bytes, save.result)
        } else {
            save.result.error(
                "PERMISSION_DENIED",
                "Storage permission is required to save into Downloads",
                null,
            )
        }
    }

    private fun completeSave(
        name: String,
        mimeType: String,
        bytes: ByteArray,
        result: MethodChannel.Result,
    ) {
        try {
            result.success(saveToDownloads(name, mimeType, bytes))
        } catch (e: Exception) {
            result.error("SAVE_FAILED", e.message ?: "Could not save the file", null)
        }
    }

    /**
     * Writes [bytes] into the device's public Downloads collection so the file
     * shows up in the Files/Downloads app. Returns a user-facing location.
     */
    private fun saveToDownloads(name: String, mimeType: String, bytes: ByteArray): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // MediaStore handles duplicate names by appending " (1)" etc.
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, name)
                put(MediaStore.Downloads.MIME_TYPE, mimeType)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("Could not create an entry in Downloads")
            contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
                ?: throw IllegalStateException("Could not write the file")
            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            contentResolver.update(uri, values, null, null)
            return "Downloads/$name"
        }

        val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        if (!dir.exists()) dir.mkdirs()
        val dot = name.lastIndexOf('.')
        val base = if (dot == -1) name else name.substring(0, dot)
        val ext = if (dot == -1) "" else name.substring(dot)
        var file = File(dir, name)
        var i = 1
        while (file.exists()) {
            file = File(dir, "$base ($i)$ext")
            i++
        }
        file.writeBytes(bytes)
        return file.absolutePath
    }
}
