package com.launchgo

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * BroadcastReceiver for handling CallKit events when app is in background.
 * This is needed because Flutter event listeners don't work when app is backgrounded.
 *
 * Handles:
 * - DECLINE: Start CallRejectService to reject via API
 * - ACCEPT: Mark call as accepted and cancel WorkManager monitoring
 * - INCOMING: Schedule WorkManager to monitor for decline
 */
class CallKitBroadcastReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "[VC] CallKitReceiver"

        // Store pending decline call ID for Flutter to retrieve (backup)
        @Volatile
        var pendingDeclineCallId: String? = null
            private set

        fun consumePendingDecline(): String? {
            val callId = pendingDeclineCallId
            pendingDeclineCallId = null
            return callId
        }

        /**
         * Mark a call as accepted in SharedPreferences
         */
        fun markCallAsAccepted(context: Context, callId: String) {
            Log.d(TAG, "📞 Marking call as accepted: $callId")
            val prefs = context.getSharedPreferences("call_status", Context.MODE_PRIVATE)
            prefs.edit().putBoolean("accepted_$callId", true).apply()
        }
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        Log.d(TAG, "📞 ========== BROADCAST RECEIVED ==========")
        Log.d(TAG, "📞 Action: ${intent?.action}")
        Log.d(TAG, "📞 Extras: ${intent?.extras?.keySet()?.toList()}")

        if (context == null) {
            Log.w(TAG, "📞 Context is null, cannot process")
            return
        }

        val action = intent?.action ?: ""
        Log.d(TAG, "📞 Checking action: $action")

        // Check for decline action (various formats)
        val isDeclineAction = action.endsWith("ACTION_CALL_DECLINE") ||
                              action.contains("DECLINE", ignoreCase = true)

        // Check for accept action (various formats)
        val isAcceptAction = action.endsWith("ACTION_CALL_ACCEPT") ||
                             action.contains("ACCEPT", ignoreCase = true)

        // Check for incoming action (various formats)
        val isIncomingAction = action.endsWith("ACTION_CALL_INCOMING") ||
                               action.contains("INCOMING", ignoreCase = true)

        if (intent != null) {
            val (callId, callCid) = extractCallData(intent)
            Log.d(TAG, "📞 Extracted call ID: $callId")
            Log.d(TAG, "📞 Extracted call CID: $callCid")

            when {
                isDeclineAction -> {
                    Log.d(TAG, "📞 ****************************************************")
                    Log.d(TAG, "📞 DECLINE ACTION DETECTED!")
                    Log.d(TAG, "📞 ****************************************************")

                    if (callId != null) {
                        // Store for Flutter backup
                        pendingDeclineCallId = callId
                        Log.d(TAG, "📞 Stored pending decline for call: $callId")

                        // Cancel the WorkManager monitoring
                        CallMonitorWorker.cancelMonitoring(context, callId)

                        // Immediately start service to reject via API
                        Log.d(TAG, "📞 Starting CallRejectService...")
                        CallRejectService.startService(context, callId, callCid)
                        Log.d(TAG, "📞 CallRejectService started")
                    } else {
                        Log.w(TAG, "📞 Could not extract call ID from decline intent")
                    }
                }

                isAcceptAction -> {
                    Log.d(TAG, "📞 ****************************************************")
                    Log.d(TAG, "📞 ACCEPT ACTION DETECTED!")
                    Log.d(TAG, "📞 ****************************************************")

                    if (callId != null) {
                        // Mark call as accepted
                        markCallAsAccepted(context, callId)
                        // Cancel the WorkManager monitoring
                        CallMonitorWorker.cancelMonitoring(context, callId)
                        Log.d(TAG, "📞 Call marked as accepted and monitor cancelled")
                    }
                }

                isIncomingAction -> {
                    Log.d(TAG, "📞 ****************************************************")
                    Log.d(TAG, "📞 INCOMING CALL DETECTED!")
                    Log.d(TAG, "📞 ****************************************************")

                    if (callId != null) {
                        // Schedule WorkManager to monitor for decline
                        Log.d(TAG, "📞 Scheduling WorkManager to monitor call: $callId")
                        CallMonitorWorker.scheduleMonitoring(context, callId, callCid)
                        Log.d(TAG, "📞 WorkManager scheduled")
                    }
                }

                else -> {
                    Log.d(TAG, "📞 Unknown/unhandled action: $action")
                }
            }
        }

        Log.d(TAG, "📞 ========== END BROADCAST ==========")
    }

    private fun extractCallData(intent: Intent): Pair<String?, String?> {
        val extras = intent.extras ?: return Pair(null, null)

        // Log all extras
        for (key in extras.keySet()) {
            Log.d(TAG, "📞 Extra[$key]: ${extras.get(key)}")
        }

        var callId: String? = null
        var callCid: String? = null

        // Try EXTRA_CALLKIT_CALL_DATA bundle
        val callDataBundle = extras.getBundle("EXTRA_CALLKIT_CALL_DATA")
        if (callDataBundle != null) {
            Log.d(TAG, "📞 Found EXTRA_CALLKIT_CALL_DATA")

            // Log bundle contents
            for (key in callDataBundle.keySet() ?: emptySet()) {
                Log.d(TAG, "📞 Bundle[$key]: ${callDataBundle.get(key)}")
            }

            // Try EXTRA_CALLKIT_EXTRA HashMap
            @Suppress("UNCHECKED_CAST")
            val extraMap = callDataBundle.getSerializable("EXTRA_CALLKIT_EXTRA") as? HashMap<String, Any>
            if (extraMap != null) {
                Log.d(TAG, "📞 Found EXTRA_CALLKIT_EXTRA: $extraMap")
                callId = extraMap["call_id"] as? String
                callCid = extraMap["call_cid"] as? String

                if (callId == null && callCid != null && callCid.contains(':')) {
                    callId = callCid.split(':').last()
                }
            }

            // Fallback: try 'id' field from bundle (notification ID is now call_id)
            if (callId == null) {
                callId = callDataBundle.getString("id")
                    ?: callDataBundle.getString("call_id")
            }
        }

        // Also try direct extras
        if (callId == null) {
            callId = extras.getString("id")
                ?: extras.getString("call_id")
        }

        return Pair(callId, callCid)
    }
}
