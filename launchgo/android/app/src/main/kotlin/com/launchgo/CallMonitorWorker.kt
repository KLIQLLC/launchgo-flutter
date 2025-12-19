package com.launchgo

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.work.*
import org.json.JSONArray
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.TimeUnit

/**
 * WorkManager Worker that monitors for declined calls.
 *
 * When a push notification for an incoming call arrives, this worker is scheduled
 * to run periodically for the ring duration. It monitors the ACTIVE_CALLS in
 * SharedPreferences to detect when a call is declined (removed from active calls).
 *
 * Flow:
 * 1. Push notification triggers this worker with call_id
 * 2. Worker checks if call_id is still in ACTIVE_CALLS
 * 3. If call is no longer active and wasn't accepted, reject it via API
 */
class CallMonitorWorker(
    context: Context,
    params: WorkerParameters
) : Worker(context, params) {

    companion object {
        private const val TAG = "[VC] CallMonitorWorker"
        private const val KEY_CALL_ID = "call_id"
        private const val KEY_CALL_CID = "call_cid"
        private const val KEY_CHECK_COUNT = "check_count"
        private const val MAX_CHECKS = 15 // Monitor for ~30 seconds (15 checks * 2 second intervals)

        /**
         * Schedule call monitoring when an incoming call push is received.
         * This should be called from the background message handler.
         */
        fun scheduleMonitoring(context: Context, callId: String, callCid: String?) {
            Log.d(TAG, "📞 ========== SCHEDULING CALL MONITORING ==========")
            Log.d(TAG, "📞 Call ID: $callId")
            Log.d(TAG, "📞 Call CID: $callCid")

            val inputData = Data.Builder()
                .putString(KEY_CALL_ID, callId)
                .putString(KEY_CALL_CID, callCid)
                .putInt(KEY_CHECK_COUNT, 0)
                .build()

            // Use periodic work that runs every 15 seconds
            // We'll use OneTimeWorkRequest with delay for more control
            val workRequest = OneTimeWorkRequestBuilder<CallMonitorWorker>()
                .setInputData(inputData)
                .setInitialDelay(2, TimeUnit.SECONDS) // First check after 2 seconds
                .addTag("call_monitor_$callId")
                .build()

            WorkManager.getInstance(context)
                .enqueueUniqueWork(
                    "call_monitor_$callId",
                    ExistingWorkPolicy.REPLACE,
                    workRequest
                )

            Log.d(TAG, "📞 Work scheduled for call: $callId")
            Log.d(TAG, "📞 ========== END SCHEDULING ==========")
        }

        /**
         * Cancel monitoring for a specific call (when accepted or already processed).
         */
        fun cancelMonitoring(context: Context, callId: String) {
            Log.d(TAG, "📞 Cancelling monitoring for call: $callId")
            WorkManager.getInstance(context).cancelUniqueWork("call_monitor_$callId")
        }
    }

    override fun doWork(): Result {
        val callId = inputData.getString(KEY_CALL_ID)
        val callCid = inputData.getString(KEY_CALL_CID)
        val checkCount = inputData.getInt(KEY_CHECK_COUNT, 0)

        Log.d(TAG, "📞 ========== WORKER RUNNING ==========")
        Log.d(TAG, "📞 Call ID: $callId")
        Log.d(TAG, "📞 Check count: $checkCount / $MAX_CHECKS")

        if (callId == null) {
            Log.w(TAG, "📞 No call ID, stopping worker")
            return Result.failure()
        }

        // Check if call is still in ACTIVE_CALLS
        val isCallActive = isCallActive(callId)
        Log.d(TAG, "📞 Is call still active: $isCallActive")

        if (!isCallActive) {
            // Call was removed from ACTIVE_CALLS - could be accept or decline
            // Check if Flutter/native accepted the call by checking a flag
            val wasAccepted = wasCallAccepted(callId)
            Log.d(TAG, "📞 Was call accepted: $wasAccepted")

            if (!wasAccepted) {
                // Call was declined - reject via API
                Log.d(TAG, "📞 Call appears to be DECLINED, starting rejection...")
                CallRejectService.startService(applicationContext, callId, callCid)
                Log.d(TAG, "📞 Rejection service started")
            } else {
                Log.d(TAG, "📞 Call was accepted, no rejection needed")
            }

            Log.d(TAG, "📞 ========== WORKER COMPLETE (call ended) ==========")
            return Result.success()
        }

        // Call is still active - schedule next check if within limit
        if (checkCount < MAX_CHECKS) {
            scheduleNextCheck(callId, callCid, checkCount + 1)
            Log.d(TAG, "📞 Scheduled next check (${checkCount + 1})")
        } else {
            Log.d(TAG, "📞 Max checks reached, stopping monitor")
        }

        Log.d(TAG, "📞 ========== WORKER COMPLETE (continuing) ==========")
        return Result.success()
    }

    private fun isCallActive(callId: String): Boolean {
        val prefs = getCallKitPrefs() ?: return false
        val json = prefs.getString("ACTIVE_CALLS", "[]") ?: "[]"

        Log.d(TAG, "📞 ACTIVE_CALLS JSON: $json")

        return try {
            val array = JSONArray(json)
            for (i in 0 until array.length()) {
                val obj = array.optJSONObject(i)
                val id = obj?.optString("id")
                val extra = obj?.optJSONObject("extra")
                val extraCallId = extra?.optString("call_id")
                val extraCallCid = extra?.optString("call_cid")

                // Check various places for call_id
                val foundCallId = id?.takeIf { it.isNotEmpty() && it != "null" }
                    ?: extraCallId?.takeIf { it.isNotEmpty() && it != "null" }
                    ?: extraCallCid?.split(":")?.lastOrNull()

                if (foundCallId == callId) {
                    return true
                }
            }
            false
        } catch (e: Exception) {
            Log.e(TAG, "📞 Error parsing ACTIVE_CALLS: ${e.message}", e)
            false
        }
    }

    private fun wasCallAccepted(callId: String): Boolean {
        // Check if we stored an acceptance flag for this call
        val prefs = applicationContext.getSharedPreferences("call_status", Context.MODE_PRIVATE)
        return prefs.getBoolean("accepted_$callId", false)
    }

    private fun getCallKitPrefs(): SharedPreferences? {
        return applicationContext.getSharedPreferences("flutter_callkit_incoming", Context.MODE_PRIVATE)
    }

    private fun scheduleNextCheck(callId: String, callCid: String?, checkCount: Int) {
        val inputData = Data.Builder()
            .putString(KEY_CALL_ID, callId)
            .putString(KEY_CALL_CID, callCid)
            .putInt(KEY_CHECK_COUNT, checkCount)
            .build()

        val workRequest = OneTimeWorkRequestBuilder<CallMonitorWorker>()
            .setInputData(inputData)
            .setInitialDelay(2, TimeUnit.SECONDS) // Check every 2 seconds
            .addTag("call_monitor_$callId")
            .build()

        WorkManager.getInstance(applicationContext)
            .enqueueUniqueWork(
                "call_monitor_$callId",
                ExistingWorkPolicy.REPLACE,
                workRequest
            )
    }
}
