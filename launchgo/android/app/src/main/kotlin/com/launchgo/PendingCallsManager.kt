package com.launchgo

import android.content.Context
import android.content.SharedPreferences
import android.util.Log

/**
 * Manages pending incoming calls to detect declined calls in terminated state.
 *
 * Problem: flutter_callkit_incoming uses explicit intents so we can't intercept
 * the decline broadcast. The CallkitEventCallback is registered too late.
 *
 * Solution:
 * 1. When showing incoming call notification, save call_id to our SharedPreferences
 * 2. When app starts, check if our saved call_id is NOT in plugin's activeCalls
 * 3. If not in activeCalls → call was declined → reject via API
 */
object PendingCallsManager {
    private const val TAG = "[VC] PendingCallsManager"
    // Flutter's shared_preferences uses this file name
    private const val PREFS_NAME = "FlutterSharedPreferences"
    // Flutter's shared_preferences adds "flutter." prefix to all keys
    private const val KEY_PENDING_CALL_ID = "flutter.pending_call_id"
    private const val KEY_PENDING_CALL_CID = "flutter.pending_call_cid"
    private const val KEY_PENDING_CALL_TIMESTAMP = "flutter.pending_call_timestamp"

    // Max age for a pending call (60 seconds - call should ring for ~30s)
    private const val MAX_PENDING_AGE_MS = 60_000L

    private fun getPrefs(context: Context): SharedPreferences {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    /**
     * Save a pending incoming call when notification is shown.
     * Call this from Flutter via MethodChannel when showing CallKit notification.
     */
    fun savePendingCall(context: Context, callId: String, callCid: String?) {
        Log.d(TAG, "📞 Saving pending call: $callId")
        getPrefs(context).edit()
            .putString(KEY_PENDING_CALL_ID, callId)
            .putString(KEY_PENDING_CALL_CID, callCid)
            .putLong(KEY_PENDING_CALL_TIMESTAMP, System.currentTimeMillis())
            .apply()
    }

    /**
     * Clear pending call when it's been handled (accepted or timeout).
     */
    fun clearPendingCall(context: Context) {
        Log.d(TAG, "📞 Clearing pending call")
        getPrefs(context).edit().clear().apply()
    }

    /**
     * Clear pending call for specific call ID.
     */
    fun clearPendingCall(context: Context, callId: String) {
        val prefs = getPrefs(context)
        val savedCallId = prefs.getString(KEY_PENDING_CALL_ID, null)
        if (savedCallId == callId) {
            Log.d(TAG, "📞 Clearing pending call: $callId")
            prefs.edit().clear().apply()
        }
    }

    /**
     * Get pending call if exists and not expired.
     * Returns Pair(callId, callCid) or null.
     */
    fun getPendingCall(context: Context): Pair<String, String?>? {
        val prefs = getPrefs(context)
        val callId = prefs.getString(KEY_PENDING_CALL_ID, null) ?: return null
        val callCid = prefs.getString(KEY_PENDING_CALL_CID, null)
        val timestamp = prefs.getLong(KEY_PENDING_CALL_TIMESTAMP, 0)

        // Check if pending call is too old
        val age = System.currentTimeMillis() - timestamp
        if (age > MAX_PENDING_AGE_MS) {
            Log.d(TAG, "📞 Pending call too old ($age ms), clearing")
            clearPendingCall(context)
            return null
        }

        Log.d(TAG, "📞 Found pending call: $callId (age: ${age}ms)")
        return Pair(callId, callCid)
    }

    /**
     * Check if there's a declined call that needs to be rejected.
     * This should be called when app starts/resumes.
     *
     * @param activeCallIds Set of currently active call IDs from flutter_callkit_incoming
     * @return Pair(callId, callCid) of declined call, or null if no decline detected
     */
    fun checkForDeclinedCall(context: Context, activeCallIds: Set<String>): Pair<String, String?>? {
        val pending = getPendingCall(context) ?: return null
        val (callId, callCid) = pending

        Log.d(TAG, "📞 Checking pending call: $callId")
        Log.d(TAG, "📞 Active calls: $activeCallIds")

        // If our pending call is NOT in active calls, it was declined
        if (!activeCallIds.contains(callId)) {
            Log.d(TAG, "📞 ****************************************************")
            Log.d(TAG, "📞 DECLINED CALL DETECTED!")
            Log.d(TAG, "📞 Call $callId is pending but not active → DECLINED")
            Log.d(TAG, "📞 ****************************************************")

            // Clear the pending call
            clearPendingCall(context)

            return Pair(callId, callCid)
        }

        Log.d(TAG, "📞 Call $callId is still active (not declined)")
        return null
    }
}
