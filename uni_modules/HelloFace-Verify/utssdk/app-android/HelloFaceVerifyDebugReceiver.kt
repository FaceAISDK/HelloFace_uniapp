package uts.sdk.modules.HelloFaceVerify

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import org.json.JSONObject
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.Executors
import java.util.zip.ZipInputStream

/** ADB-only, debug-only transport. It is not part of the public plugin API. */
class HelloFaceVerifyDebugReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (!isOrderedBroadcast) return
        if (!HelloFaceVerifyDebug.enabled(context)) {
            setResult(Activity.RESULT_CANCELED, reply("NOT_DEBUGGABLE").toString(), null); return
        }
        if (intent.action == INFO) {
            setResult(Activity.RESULT_OK, reply("OK").put("busy", HelloFaceVerifyNative.job != null).toString(), null); return
        }
        if (intent.action != SYNC) {
            setResult(Activity.RESULT_CANCELED, reply("UNKNOWN_ACTION").toString(), null); return
        }
        if (HelloFaceVerifyNative.job != null) {
            setResult(Activity.RESULT_CANCELED, reply("BUSY").toString(), null); return
        }
        // Hold the same slot as face operations while files are being replaced.
        val lock = CameraJob("debug-sync", "debugSync", JSONObject(), {})
        HelloFaceVerifyNative.job = lock
        val pending = goAsync()
        worker.execute {
            var phase = "validate_request"
            val response = try {
                val appid = intent.getStringExtra("appid") ?: ""
                val request = intent.getStringExtra("request") ?: ""
                val expected = intent.getStringExtra("sha256") ?: ""
                require(appid.matches(Regex("[A-Za-z0-9_-]{1,80}")))
                require(request.matches(Regex("[0-9a-f]{32}")))
                require(expected.matches(Regex("[0-9a-f]{64}")))
                val archive = File(context.filesDir, "helloface-debug/$request.zip")
                try {
                    phase = "verify_archive"
                    require(archive.length() in 1..MAX_BYTES)
                    val digest = archive.inputStream().use { stream ->
                        val hash = MessageDigest.getInstance("SHA-256")
                        val buffer = ByteArray(65536)
                        while (true) { val count = stream.read(buffer); if (count < 0) break; hash.update(buffer, 0, count) }
                        hash.digest().joinToString("") { "%02x".format(it.toInt() and 255) }
                    }
                    require(digest == expected)
                    phase = "validate_appid"
                    val bundled = context.assets.open("apps/$appid/www/manifest.json").bufferedReader().use { it.readText() }
                    require(JSONObject(bundled).optString("id") == appid)
                    val root = context.getExternalFilesDir(null)?.parentFile ?: error("External app storage unavailable")
                    phase = "replace_resources"
                    val count = install(archive, File(root, "apps/$appid"), appid, request)
                    reply("OK").put("request", request).put("sha256", digest).put("files", count)
                } finally { archive.delete() }
            } catch (_: Exception) { reply("SYNC_FAILED").put("phase", phase) }
            HelloFaceVerifyNative.main.post {
                if (HelloFaceVerifyNative.job === lock) HelloFaceVerifyNative.job = null
                pending.setResultCode(if (response.optString("code") == "OK") Activity.RESULT_OK else Activity.RESULT_CANCELED)
                pending.setResultData(response.toString())
                pending.finish()
            }
        }
    }

    private fun install(archive: File, parent: File, appid: String, request: String): Int {
        val stage = File(parent, "www.debug-stage-$request")
        val current = File(parent, "www")
        val backup = File(parent, "www.debug-backup")
        check(stage.mkdirs())
        var count = 0
        var total = 0L
        try {
            ZipInputStream(archive.inputStream().buffered()).use { zip ->
                val seen = HashSet<String>()
                while (true) {
                    val entry = zip.nextEntry ?: break
                    require(++count <= MAX_ENTRIES)
                    require(!entry.name.startsWith("/") && !entry.name.contains('\\'))
                    val file = File(stage, entry.name).canonicalFile
                    require(file.path.startsWith(stage.canonicalPath + File.separator))
                    require(seen.add(file.path))
                    if (entry.isDirectory) { check(file.mkdirs() || file.isDirectory); continue }
                    check(file.parentFile?.let { it.mkdirs() || it.isDirectory } == true)
                    file.outputStream().use { out ->
                        val buffer = ByteArray(65536)
                        while (true) {
                            val length = zip.read(buffer); if (length < 0) break
                            total += length; require(total <= MAX_BYTES); out.write(buffer, 0, length)
                        }
                    }
                }
            }
            require(JSONObject(File(stage, "manifest.json").readText()).optString("id") == appid)
            require(File(stage, "__uniappview.html").isFile && File(stage, "app-service.js").isFile)
            check(!backup.exists() || backup.deleteRecursively())
            val hadCurrent = current.exists()
            if (hadCurrent) check(current.renameTo(backup))
            if (!stage.renameTo(current)) {
                if (hadCurrent) check(backup.renameTo(current))
                error("Unable to activate page resources")
            }
            return count
        } finally { if (stage.exists()) stage.deleteRecursively() }
    }

    private fun reply(code: String) = JSONObject().put("protocol", 1).put("code", code)
        .put("fingerprint", HelloFaceVerifyBuildInfo.FINGERPRINT)

    companion object {
        const val INFO = "uts.sdk.modules.HelloFaceVerify.DEBUG_INFO"
        const val SYNC = "uts.sdk.modules.HelloFaceVerify.DEBUG_SYNC"
        private const val MAX_BYTES = 32L * 1024 * 1024
        private const val MAX_ENTRIES = 512
        private val worker = Executors.newSingleThreadExecutor()
    }
}
