package com.launchgo

import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder
import android.util.Log
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

/**
 * Background service for rejecting calls via Stream Video API.
 * This is needed because when the app is in background/terminated,
 * Flutter engine is not active and cannot process decline events.
 *
 * Flow:
 * 1. User taps Decline on CallKit notification
 * 2. CallKitBroadcastReceiver receives the event
 * 3. CallKitBroadcastReceiver starts this service
 * 4. This service reads auth token from SharedPreferences
 * 5. This service makes HTTP request to Stream Video API to reject the call
 * 6. Caller is notified that call was rejected
 */
class CallRejectService : Service() {
    companion object {
        private const val TAG = "[VC] CallRejectService"
        private const val EXTRA_CALL_ID = "call_id"
        private const val EXTRA_CALL_CID = "call_cid"

        fun startService(context: Context, callId: String, callCid: String?) {
            Log.d(TAG, "📞 Starting CallRejectService for call: $callId")
            val intent = Intent(context, CallRejectService::class.java).apply {
                putExtra(EXTRA_CALL_ID, callId)
                putExtra(EXTRA_CALL_CID, callCid)
            }
            context.startService(intent)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "📞 ========== SERVICE STARTED ==========")

        val callId = intent?.getStringExtra(EXTRA_CALL_ID)
        val callCid = intent?.getStringExtra(EXTRA_CALL_CID)

        Log.d(TAG, "📞 Call ID: $callId")
        Log.d(TAG, "📞 Call CID: $callCid")

        if (callId != null) {
            thread {
                try {
                    rejectCall(callId, callCid)
                } catch (e: Exception) {
                    Log.e(TAG, "📞 Error rejecting call: ${e.message}", e)
                } finally {
                    stopSelf(startId)
                }
            }
        } else {
            Log.w(TAG, "📞 No call ID provided, stopping service")
            stopSelf(startId)
        }

        return START_NOT_STICKY
    }

    private fun rejectCall(callId: String, callCid: String?) {
        Log.d(TAG, "📞 ========== REJECTING CALL VIA STREAM API ==========")
        Log.d(TAG, "📞 Call ID: $callId")
        Log.d(TAG, "📞 Call CID: $callCid")

        // Read auth data from Flutter's SharedPreferences
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        // Log all keys for debugging
        Log.d(TAG, "📞 SharedPreferences all keys: ${prefs.all.keys}")

        // Log all stream-related values for debugging
        prefs.all.entries.filter {
            it.key.contains("stream", ignoreCase = true) ||
            it.key.contains("token", ignoreCase = true)
        }.forEach { entry ->
            val value = entry.value?.toString()?.take(50) ?: "null"
            Log.d(TAG, "📞 ${entry.key} = $value...")
        }

        // Try different key formats Flutter might use
        // Flutter SharedPreferences prefixes all keys with "flutter."
        val tokenKeys = listOf(
            "flutter.stream_video_token",
            "flutter.call_get_stream_token",
            "flutter.callGetStreamToken",
            "flutter.user_token"
        )

        var token: String? = null
        for (key in tokenKeys) {
            token = prefs.getString(key, null)
            if (!token.isNullOrEmpty()) {
                Log.d(TAG, "📞 Found token with key: $key")
                Log.d(TAG, "📞 Token first 50 chars: ${token.take(50)}...")
                break
            }
        }

        // Also try to get API key
        val apiKeyKeys = listOf(
            "flutter.stream_video_api_key",
            "flutter.streamVideoApiKey"
        )

        var apiKey: String? = null
        for (key in apiKeyKeys) {
            apiKey = prefs.getString(key, null)
            if (!apiKey.isNullOrEmpty()) {
                Log.d(TAG, "📞 Found API key with key: $key")
                break
            }
        }

        // Get user ID for the request
        val userIdKeys = listOf(
            "flutter.stream_video_user_id",
            "flutter.user_id"
        )

        var userId: String? = null
        for (key in userIdKeys) {
            userId = prefs.getString(key, null)
            if (!userId.isNullOrEmpty()) {
                Log.d(TAG, "📞 Found user ID with key: $key")
                break
            }
        }

        if (token == null) {
            Log.e(TAG, "📞 ❌ No auth token found in SharedPreferences!")
            Log.d(TAG, "📞 Available keys with 'token' or 'stream': ${prefs.all.keys.filter {
                it.contains("token", ignoreCase = true) || it.contains("stream", ignoreCase = true)
            }}")
            return
        }

        if (apiKey == null) {
            Log.e(TAG, "📞 ❌ No API key found in SharedPreferences!")
            return
        }

        // Determine call type from call_cid (format: "type:id")
        val callType = if (callCid?.contains(":") == true) {
            callCid.split(":").first()
        } else {
            "default"
        }

        // Make HTTP request to Stream Video API
        // API endpoint: POST /video/call/{type}/{id}/reject?api_key={api_key}
        val baseUrl = "https://video.stream-io-api.com"
        val endpoint = "$baseUrl/video/call/$callType/$callId/reject?api_key=$apiKey"

        Log.d(TAG, "📞 Making request to: $endpoint")
        Log.d(TAG, "📞 Call type: $callType")
        Log.d(TAG, "📞 User ID: $userId")

        try {
            val url = URL(endpoint)
            val connection = url.openConnection() as HttpURLConnection

            connection.requestMethod = "POST"
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Accept", "application/json")
            connection.connectTimeout = 15000
            connection.readTimeout = 15000

            // Add authorization header with Bearer prefix
            connection.setRequestProperty("Authorization", "Bearer $token")

            // Add Stream auth type header
            connection.setRequestProperty("Stream-Auth-Type", "jwt")

            // Add X-Stream-Client header (optional but recommended)
            connection.setRequestProperty("X-Stream-Client", "stream-video-android")

            connection.doOutput = true
            connection.outputStream.use { os ->
                os.write("{}".toByteArray())
            }

            val responseCode = connection.responseCode
            Log.d(TAG, "📞 Response code: $responseCode")

            if (responseCode == HttpURLConnection.HTTP_OK ||
                responseCode == HttpURLConnection.HTTP_CREATED ||
                responseCode == HttpURLConnection.HTTP_ACCEPTED) {
                val responseBody = connection.inputStream?.bufferedReader()?.readText()
                Log.d(TAG, "📞 ✅ CALL REJECTED SUCCESSFULLY!")
                Log.d(TAG, "📞 Response: ${responseBody?.take(200)}")
            } else {
                val errorStream = connection.errorStream?.bufferedReader()?.readText()
                Log.e(TAG, "📞 ❌ API returned error: $responseCode")
                Log.e(TAG, "📞 ❌ Error body: $errorStream")

                // If unauthorized, token might be expired
                if (responseCode == HttpURLConnection.HTTP_UNAUTHORIZED) {
                    Log.e(TAG, "📞 ❌ Token might be expired or invalid!")
                }
            }

            connection.disconnect()
        } catch (e: Exception) {
            Log.e(TAG, "📞 ❌ HTTP request failed: ${e.message}", e)
        }

        Log.d(TAG, "📞 ========== REJECT CALL SERVICE COMPLETED ==========")
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "📞 Service destroyed")
    }
}
