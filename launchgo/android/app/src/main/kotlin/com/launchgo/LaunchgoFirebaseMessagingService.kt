package com.launchgo

import android.util.Log
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

/**
 * Custom Firebase Messaging Service that intercepts push notifications
 * to start CallMonitorService for video call decline detection.
 *
 * When a call.ring push arrives, this service starts CallMonitorService
 * which monitors for decline WITHOUT opening the app.
 */
class LaunchgoFirebaseMessagingService : FirebaseMessagingService() {

    companion object {
        private const val TAG = "[VC] FcmService"
    }

    override fun onMessageReceived(message: RemoteMessage) {
        Log.d(TAG, "📞 ========== FCM MESSAGE RECEIVED ==========")
        Log.d(TAG, "📞 From: ${message.from}")
        Log.d(TAG, "📞 Data: ${message.data}")

        val data = message.data

        // Check if this is a video call notification
        val type = data["type"]
        val callCid = data["call_cid"]

        Log.d(TAG, "📞 Type: $type")
        Log.d(TAG, "📞 Call CID: $callCid")

        if (type == "call.ring" && callCid != null) {
            Log.d(TAG, "📞 ****************************************************")
            Log.d(TAG, "📞 INCOMING CALL PUSH DETECTED!")
            Log.d(TAG, "📞 ****************************************************")

            // ALWAYS start CallMonitorService for ring events.
            // Even if app thinks it's foreground, when the phone is locked Dart may be suspended.
            // Service is lightweight and self-stops.
            Log.d(TAG, "📞 Starting CallMonitorService for call monitoring")

            // Extract call_id from call_cid (format: "type:id")
            val callId = if (callCid.contains(':')) {
                callCid.split(':').last()
            } else {
                data["call_id"] ?: data["id"]
            }

            if (callId != null) {
                // Start the foreground service to monitor for decline
                CallMonitorService.startMonitoring(this, callId, callCid)
                Log.d(TAG, "📞 CallMonitorService started for call: $callId")
            } else {
                Log.w(TAG, "📞 Could not extract call_id from push")
            }
        } else if (type == "call.missed" || type == "call.ended") {
            Log.d(TAG, "📞 ****************************************************")
            Log.d(TAG, "📞 CALL MISSED/ENDED PUSH RECEIVED!")
            Log.d(TAG, "📞 Type: $type")
            Log.d(TAG, "📞 Call CID: $callCid")
            Log.d(TAG, "📞 This means the caller cancelled the call!")
            Log.d(TAG, "📞 Ending CallKit notification and stopping monitor...")
            Log.d(TAG, "📞 ****************************************************")

            // Stop the call monitor service first
            CallMonitorService.stopMonitoring(this)

            // End the CallKit notification (dismiss incoming call UI)
            // Try multiple approaches to ensure it works
            try {
                CallKitHelper.endAllCalls(this)
            } catch (e: Exception) {
                Log.e(TAG, "📞 Error in CallKitHelper.endAllCalls: ${e.message}")
            }

            // Also broadcast to end the CallkitIncomingActivity directly
            try {
                val endActivityIntent = android.content.Intent("${packageName}.com.hiennv.flutter_callkit_incoming.ACTION_ENDED_CALL_INCOMING")
                endActivityIntent.putExtra("ACCEPTED", false)
                sendBroadcast(endActivityIntent)
                Log.d(TAG, "📞 Sent ACTION_ENDED_CALL_INCOMING broadcast")
            } catch (e: Exception) {
                Log.e(TAG, "📞 Error sending ACTION_ENDED_CALL_INCOMING: ${e.message}")
            }

            Log.d(TAG, "📞 Call cancelled cleanup completed")
        }

        Log.d(TAG, "📞 ========== END FCM MESSAGE ==========")

        // Let the default handler (Flutter) also process the message
        super.onMessageReceived(message)
    }

    override fun onNewToken(token: String) {
        Log.d(TAG, "📞 New FCM token: $token")
        super.onNewToken(token)
    }
}
