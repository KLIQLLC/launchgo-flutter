package com.launchgo

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

/**
 * Helper class to control CallKit notifications from native Android code.
 *
 * This is needed when we receive call.missed/call.ended push notifications
 * while the app is terminated - we need to dismiss the incoming call UI
 * without opening the app.
 *
 * Uses the same mechanism as flutter_callkit_incoming library:
 * - Sends broadcast to CallkitIncomingBroadcastReceiver with ACTION_CALL_ENDED
 * - This properly clears notification, stops ringtone, and updates SharedPreferences
 */
object CallKitHelper {
    private const val TAG = "[VC] CallKitHelper"

    // flutter_callkit_incoming constants
    private const val ACTION_CALL_ENDED = "com.hiennv.flutter_callkit_incoming.ACTION_CALL_ENDED"
    private const val EXTRA_CALLKIT_INCOMING_DATA = "EXTRA_CALLKIT_INCOMING_DATA"

    /**
     * End all CallKit incoming call notifications.
     * Uses the proper flutter_callkit_incoming broadcast mechanism.
     */
    fun endAllCalls(context: Context) {
        Log.d(TAG, "📞 ========== ENDING ALL CALLKIT NOTIFICATIONS ==========")

        try {
            // Get all active calls from SharedPreferences
            val activeCalls = getActiveCalls(context)
            Log.d(TAG, "📞 Found ${activeCalls.size} active calls to end")

            if (activeCalls.isEmpty()) {
                Log.d(TAG, "📞 No active calls found, but will still try to cancel notifications")
                // Still try to cancel notifications in case SharedPreferences is out of sync
                cancelAllNotifications(context)
                stopVibration(context)
            } else {
                // End each call properly via broadcast
                for (callData in activeCalls) {
                    val callId = callData.optString("id")
                    Log.d(TAG, "📞 Ending call: $callId")
                    sendEndCallBroadcast(context, callData)

                    // Also cancel notification by ID directly
                    cancelNotificationById(context, callId)
                }
            }

            // Also directly clear ACTIVE_CALLS as backup
            clearActiveCalls(context)

            // Stop the CallkitNotificationService
            stopCallkitService(context)

            Log.d(TAG, "📞 ✅ All CallKit notifications ended successfully")
        } catch (e: Exception) {
            Log.e(TAG, "📞 ❌ Error ending CallKit notifications: ${e.message}", e)
            // Fallback: try to cancel notifications directly
            cancelAllNotifications(context)
        }

        Log.d(TAG, "📞 ========== END CALLKIT CLEANUP ==========")
    }

    /**
     * End a specific call by ID.
     */
    fun endCall(context: Context, callId: String) {
        Log.d(TAG, "📞 Ending specific call: $callId")

        try {
            val activeCalls = getActiveCalls(context)
            var found = false

            for (callData in activeCalls) {
                val id = callData.optString("id")
                val extraCallId = callData.optJSONObject("extra")?.optString("call_id")
                val extraCallCid = callData.optJSONObject("extra")?.optString("call_cid")

                val matchesCallId = id == callId ||
                    extraCallId == callId ||
                    extraCallCid?.split(":")?.lastOrNull() == callId

                if (matchesCallId) {
                    Log.d(TAG, "📞 Found matching call, sending end broadcast")
                    sendEndCallBroadcast(context, callData)
                    found = true
                    break
                }
            }

            if (!found) {
                Log.w(TAG, "📞 Call $callId not found in active calls, trying direct cleanup")
                cancelAllNotifications(context)
                removeCallFromActiveCalls(context, callId)
            }

            Log.d(TAG, "📞 ✅ Call $callId ended")
        } catch (e: Exception) {
            Log.e(TAG, "📞 ❌ Error ending call $callId: ${e.message}", e)
            cancelAllNotifications(context)
        }
    }

    /**
     * Send the proper ACTION_CALL_ENDED broadcast to flutter_callkit_incoming's receiver.
     * This is the same mechanism the library uses internally.
     */
    private fun sendEndCallBroadcast(context: Context, callData: JSONObject) {
        try {
            val bundle = jsonToBundle(callData)
            val action = "${context.packageName}.$ACTION_CALL_ENDED"

            Log.d(TAG, "📞 Sending broadcast with action: $action")
            Log.d(TAG, "📞 Bundle data: id=${bundle.getString("id")}")

            // Use implicit broadcast with just the action
            // The receiver is registered in the manifest with this action
            val intent = Intent(action).apply {
                putExtra(EXTRA_CALLKIT_INCOMING_DATA, bundle)
                // Set package to ensure it goes to our app's receiver
                setPackage(context.packageName)
            }

            context.sendBroadcast(intent)
            Log.d(TAG, "📞 Broadcast sent successfully")

        } catch (e: Exception) {
            Log.e(TAG, "📞 Error sending end call broadcast: ${e.message}", e)
        }
    }

    /**
     * Get all active calls from SharedPreferences.
     */
    private fun getActiveCalls(context: Context): List<JSONObject> {
        val prefs = context.getSharedPreferences("flutter_callkit_incoming", Context.MODE_PRIVATE)
        val json = prefs.getString("ACTIVE_CALLS", "[]") ?: "[]"

        Log.d(TAG, "📞 ACTIVE_CALLS JSON: $json")

        val result = mutableListOf<JSONObject>()
        try {
            val array = JSONArray(json)
            for (i in 0 until array.length()) {
                array.optJSONObject(i)?.let { result.add(it) }
            }
        } catch (e: Exception) {
            Log.e(TAG, "📞 Error parsing ACTIVE_CALLS: ${e.message}")
        }

        return result
    }

    /**
     * Convert JSONObject to Bundle for the broadcast.
     */
    private fun jsonToBundle(json: JSONObject): Bundle {
        val bundle = Bundle()

        val keys = json.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            when (val value = json.opt(key)) {
                is String -> bundle.putString(key, value)
                is Int -> bundle.putInt(key, value)
                is Long -> bundle.putLong(key, value)
                is Boolean -> bundle.putBoolean(key, value)
                is Double -> bundle.putDouble(key, value)
                is JSONObject -> bundle.putBundle(key, jsonToBundle(value))
                else -> bundle.putString(key, value?.toString())
            }
        }

        return bundle
    }

    /**
     * Clear ACTIVE_CALLS from SharedPreferences.
     */
    private fun clearActiveCalls(context: Context) {
        try {
            val prefs = context.getSharedPreferences("flutter_callkit_incoming", Context.MODE_PRIVATE)
            prefs.edit().putString("ACTIVE_CALLS", "[]").apply()
            Log.d(TAG, "📞 Cleared ACTIVE_CALLS")
        } catch (e: Exception) {
            Log.e(TAG, "📞 Error clearing ACTIVE_CALLS: ${e.message}")
        }
    }

    /**
     * Remove a specific call from ACTIVE_CALLS.
     */
    private fun removeCallFromActiveCalls(context: Context, callId: String) {
        try {
            val prefs = context.getSharedPreferences("flutter_callkit_incoming", Context.MODE_PRIVATE)
            val json = prefs.getString("ACTIVE_CALLS", "[]") ?: "[]"

            val array = JSONArray(json)
            val newArray = JSONArray()

            for (i in 0 until array.length()) {
                val obj = array.optJSONObject(i)
                val id = obj?.optString("id")
                val extraCallId = obj?.optJSONObject("extra")?.optString("call_id")

                val shouldRemove = id == callId || extraCallId == callId
                if (!shouldRemove) {
                    newArray.put(obj)
                }
            }

            prefs.edit().putString("ACTIVE_CALLS", newArray.toString()).apply()
            Log.d(TAG, "📞 Removed call $callId from ACTIVE_CALLS")
        } catch (e: Exception) {
            Log.e(TAG, "📞 Error removing call: ${e.message}")
        }
    }

    /**
     * Cancel all notifications directly via NotificationManager.
     * This is a fallback if the broadcast approach doesn't work.
     */
    private fun cancelAllNotifications(context: Context) {
        try {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancelAll()
            Log.d(TAG, "📞 Cancelled all notifications via NotificationManager")
        } catch (e: Exception) {
            Log.e(TAG, "📞 Error cancelling notifications: ${e.message}")
        }
    }

    /**
     * Cancel notification by call ID.
     * flutter_callkit_incoming uses callId.hashCode() as notification ID.
     */
    private fun cancelNotificationById(context: Context, callId: String) {
        try {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            // The notification ID is the hashCode of the call ID (or "callkit_incoming" as fallback)
            val notificationId = callId.hashCode()
            notificationManager.cancel(notificationId)
            Log.d(TAG, "📞 Cancelled notification with ID: $notificationId (from callId: $callId)")

            // Also try with the fallback ID
            val fallbackId = "callkit_incoming".hashCode()
            notificationManager.cancel(fallbackId)
            Log.d(TAG, "📞 Also cancelled fallback notification ID: $fallbackId")
        } catch (e: Exception) {
            Log.e(TAG, "📞 Error cancelling notification by ID: ${e.message}")
        }
    }

    /**
     * Stop the CallkitNotificationService.
     */
    private fun stopCallkitService(context: Context) {
        try {
            // Try to stop the service using reflection
            val serviceClass = Class.forName("com.hiennv.flutter_callkit_incoming.CallkitNotificationService")
            val stopIntent = Intent(context, serviceClass)
            context.stopService(stopIntent)
            Log.d(TAG, "📞 CallkitNotificationService stopped")
        } catch (e: Exception) {
            Log.d(TAG, "📞 Could not stop CallkitNotificationService (may not be running): ${e.message}")
        }
    }

    /**
     * Stop vibration.
     */
    private fun stopVibration(context: Context) {
        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vibratorManager.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            vibrator.cancel()
            Log.d(TAG, "📞 Vibration cancelled")
        } catch (e: Exception) {
            Log.w(TAG, "📞 Could not stop vibration: ${e.message}")
        }
    }
}
