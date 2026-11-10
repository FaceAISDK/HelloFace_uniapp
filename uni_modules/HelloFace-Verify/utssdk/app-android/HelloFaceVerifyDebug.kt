package uts.sdk.modules.HelloFaceVerify

import android.content.Context
import android.content.pm.ApplicationInfo
import android.os.SystemClock
import android.util.Log
import org.json.JSONObject
import java.util.UUID

/** Debug builds log operation metadata, never identifiers, features, images or scores. */
internal object HelloFaceVerifyDebug {
    const val TAG = "HelloFaceVerify"
    fun enabled(context: Context) = context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0

    fun trace(context: Context, method: String, completion: (String) -> Unit): (String) -> Unit {
        if (!enabled(context)) return completion
        val trace = UUID.randomUUID().toString().take(8)
        val started = SystemClock.elapsedRealtime()
        val operation = token(method)
        Log.i(TAG, "op=$trace method=$operation event=START")
        return { response ->
            try {
                val value = JSONObject(response)
                if (value.optString("event") != "progress") {
                    val code = token(value.optString("code"))
                    val outcome = token(value.optJSONObject("data")?.optString("outcome") ?: "")
                    Log.i(TAG, "op=$trace method=$operation event=END code=$code outcome=$outcome elapsedMs=${SystemClock.elapsedRealtime() - started}")
                }
            } catch (_: Exception) { Log.w(TAG, "op=$trace method=$operation event=MALFORMED_RESPONSE") }
            completion(response)
        }
    }
    private fun token(value: String) = value.take(64).replace(Regex("[^A-Za-z0-9_]"), "_")
}
