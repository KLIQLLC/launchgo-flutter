package com.launchgo

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import org.json.JSONArray

/**
 * Foreground Service that monitors for call decline WITHOUT opening the app.
 *
 * This service starts when an incoming call push arrives and monitors
 * flutter_callkit_incoming's SharedPreferences. When our call disappears
 * from ACTIVE_CALLS (and wasn't accepted), we know it was declined.
 *
 * Flow:
 * 1. Push arrives (call.ring) → This service starts
 * 2. Service monitors ACTIVE_CALLS in SharedPreferences every 1 second
 * 3. When call_id disappears → Check if it was accepted
 * 4. If not accepted → Call was DECLINED → Reject via API
 * 5. Service stops itself
 */
class CallMonitorService : Service() {

    companion object {
        private const val TAG = "[VC] CallMonitorService"
        private const val NOTIFICATION_ID = 9999
        private const val CHANNEL_ID = "call_monitor_channel"

        private const val EXTRA_CALL_ID = "call_id"
        private const val EXTRA_CALL_CID = "call_cid"

        // Check interval in milliseconds
        private const val CHECK_INTERVAL_MS = 1000L
        // Max time to wait for call to appear in ACTIVE_CALLS (10 seconds)
        // Flutter background handler needs time to show CallKit notification
        private const val WAIT_FOR_CALL_TIMEOUT_MS = 10_000L
        // Max monitoring time after call appears (35 seconds - slightly more than ring duration)
        private const val MAX_MONITOR_TIME_MS = 35_000L

        fun startMonitoring(context: Context, callId: String, callCid: String?) {
            Log.d(TAG, "📞 ========== STARTING CALL MONITOR SERVICE ==========")
            Log.d(TAG, "📞 Call ID: $callId")
            Log.d(TAG, "📞 Call CID: $callCid")

            val intent = Intent(context, CallMonitorService::class.java).apply {
                putExtra(EXTRA_CALL_ID, callId)
                putExtra(EXTRA_CALL_CID, callCid)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }

            Log.d(TAG, "📞 Service start requested")
        }

        fun stopMonitoring(context: Context) {
            Log.d(TAG, "📞 Stopping call monitor service")
            context.stopService(Intent(context, CallMonitorService::class.java))
        }
    }

    private var callId: String? = null
    private var callCid: String? = null
    private var handler: Handler? = null
    private var monitorRunnable: Runnable? = null
    private var startTime: Long = 0
    private var wasAccepted = false
    private var prefsListener: SharedPreferences.OnSharedPreferenceChangeListener? = null

    // Track if we've seen the call appear in ACTIVE_CALLS
    // CRITICAL: We must NOT reject a call that never appeared!
    // The call might not appear immediately because Flutter's background handler
    // needs to run and show the CallKit notification first.
    private var hasSeenCallActive = false
    private var waitingForCallToAppear = true

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "📞 Service onCreate")
        createNotificationChannel()
        handler = Handler(Looper.getMainLooper())
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "📞 ========== SERVICE onStartCommand ==========")

        callId = intent?.getStringExtra(EXTRA_CALL_ID)
        callCid = intent?.getStringExtra(EXTRA_CALL_CID)

        Log.d(TAG, "📞 Call ID: $callId")
        Log.d(TAG, "📞 Call CID: $callCid")

        if (callId == null) {
            Log.w(TAG, "📞 No call ID, stopping service")
            stopSelf()
            return START_NOT_STICKY
        }

        // Reset state for this monitoring session
        hasSeenCallActive = false
        waitingForCallToAppear = true
        wasAccepted = false

        // Start as foreground service with minimal notification
        startForeground(NOTIFICATION_ID, createNotification())

        // Start monitoring
        startTime = System.currentTimeMillis()
        startMonitoringActiveCalls()

        Log.d(TAG, "📞 Monitoring started, waiting for call to appear in ACTIVE_CALLS")
        Log.d(TAG, "📞 Will wait up to ${WAIT_FOR_CALL_TIMEOUT_MS}ms for call to appear")
        Log.d(TAG, "📞 Then monitor for up to ${MAX_MONITOR_TIME_MS}ms for decline")

        return START_NOT_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Call Monitor",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitoring incoming call"
                setShowBadge(false)
            }

            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Incoming call")
            .setContentText("Processing...")
            .setSmallIcon(android.R.drawable.ic_menu_call)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }

    private fun startMonitoringActiveCalls() {
        Log.d(TAG, "📞 Starting to monitor ACTIVE_CALLS")

        // Also listen for SharedPreferences changes for faster detection
        setupPrefsListener()

        // Periodic check as backup
        monitorRunnable = object : Runnable {
            override fun run() {
                checkCallStatus()

                // Check if we should continue monitoring
                val elapsed = System.currentTimeMillis() - startTime
                // Total timeout = wait time + monitor time
                val totalTimeout = WAIT_FOR_CALL_TIMEOUT_MS + MAX_MONITOR_TIME_MS

                if (elapsed < totalTimeout && !wasAccepted) {
                    handler?.postDelayed(this, CHECK_INTERVAL_MS)
                } else {
                    if (wasAccepted) {
                        Log.d(TAG, "📞 Call was accepted, stopping monitoring")
                    } else {
                        Log.d(TAG, "📞 Monitoring timeout (${elapsed}ms), stopping")
                    }
                    cleanup()
                }
            }
        }

        handler?.postDelayed(monitorRunnable!!, CHECK_INTERVAL_MS)
    }

    private fun setupPrefsListener() {
        val prefs = getCallKitPrefs()

        prefsListener = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
            if (key == "ACTIVE_CALLS") {
                Log.d(TAG, "📞 ACTIVE_CALLS changed (via listener)")
                checkCallStatus()
            }
        }

        prefs?.registerOnSharedPreferenceChangeListener(prefsListener)
        Log.d(TAG, "📞 SharedPreferences listener registered")
    }

    private fun checkCallStatus() {
        val currentCallId = callId ?: return
        val elapsed = System.currentTimeMillis() - startTime

        // Check if call is currently active
        val isActive = isCallActive(currentCallId)
        Log.d(TAG, "📞 Call $currentCallId active: $isActive")
        Log.d(TAG, "📞 Has seen call active: $hasSeenCallActive")
        Log.d(TAG, "📞 Waiting for call to appear: $waitingForCallToAppear")
        Log.d(TAG, "📞 Elapsed time: ${elapsed}ms")

        if (isActive) {
            // Call is now active - mark that we've seen it
            if (!hasSeenCallActive) {
                Log.d(TAG, "📞 ****************************************************")
                Log.d(TAG, "📞 CALL APPEARED IN ACTIVE_CALLS!")
                Log.d(TAG, "📞 Now monitoring for decline...")
                Log.d(TAG, "📞 ****************************************************")
                hasSeenCallActive = true
                waitingForCallToAppear = false
            }
        } else {
            // Call is not active
            if (waitingForCallToAppear) {
                // We're still waiting for the call to appear
                if (elapsed > WAIT_FOR_CALL_TIMEOUT_MS) {
                    // Timeout waiting for call to appear
                    Log.d(TAG, "📞 Timeout waiting for call to appear in ACTIVE_CALLS")
                    Log.d(TAG, "📞 This could mean:")
                    Log.d(TAG, "📞   - Flutter background handler failed to show CallKit")
                    Log.d(TAG, "📞   - Call was cancelled by caller before we could show it")
                    Log.d(TAG, "📞 NOT rejecting since we never saw the call active")
                    cleanup()
                    return
                }
                // Keep waiting
                Log.d(TAG, "📞 Still waiting for call to appear (${elapsed}ms / ${WAIT_FOR_CALL_TIMEOUT_MS}ms)")
                return
            }

            // We've seen the call active before, and now it's gone
            // Check if it was accepted
            val accepted = wasCallAccepted(currentCallId)
            Log.d(TAG, "📞 Call was accepted: $accepted")

            if (!accepted) {
                // Call was DECLINED!
                Log.d(TAG, "📞 ****************************************************")
                Log.d(TAG, "📞 CALL DECLINED DETECTED (SERVICE)!")
                Log.d(TAG, "📞 Call ID: $currentCallId")
                Log.d(TAG, "📞 Call was active, then disappeared, and wasn't accepted")
                Log.d(TAG, "📞 Rejecting via API...")
                Log.d(TAG, "📞 ****************************************************")

                // Reject the call via API
                CallRejectService.startService(this, currentCallId, callCid)

                // Clear pending call
                clearPendingCall(currentCallId)
            } else {
                wasAccepted = true
                Log.d(TAG, "📞 Call was accepted, not rejecting")
            }

            // Stop monitoring
            cleanup()
        }
    }

    private fun isCallActive(callId: String): Boolean {
        val prefs = getCallKitPrefs() ?: run {
            Log.w(TAG, "📞 isCallActive: Could not get CallKit SharedPreferences")
            return false
        }
        val json = prefs.getString("ACTIVE_CALLS", "[]") ?: "[]"

        Log.d(TAG, "📞 isCallActive: Looking for callId='$callId'")
        Log.d(TAG, "📞 isCallActive: ACTIVE_CALLS=$json")

        return try {
            val array = JSONArray(json)
            Log.d(TAG, "📞 isCallActive: Found ${array.length()} active calls")

            for (i in 0 until array.length()) {
                val obj = array.optJSONObject(i)
                if (obj == null) {
                    Log.d(TAG, "📞 isCallActive: Entry $i is null")
                    continue
                }

                val id = obj.optString("id")
                Log.d(TAG, "📞 isCallActive: Entry $i - id='$id'")

                // Check if extra is a JSONObject or String
                val extraRaw = obj.opt("extra")
                Log.d(TAG, "📞 isCallActive: Entry $i - extra type=${extraRaw?.javaClass?.simpleName}")

                var extraCallId: String? = null
                var extraCallCid: String? = null

                if (extraRaw is org.json.JSONObject) {
                    extraCallId = extraRaw.optString("call_id")
                    extraCallCid = extraRaw.optString("call_cid")
                } else if (extraRaw is String && extraRaw.isNotEmpty()) {
                    // Try parsing extra as JSON string
                    try {
                        val extraJson = org.json.JSONObject(extraRaw)
                        extraCallId = extraJson.optString("call_id")
                        extraCallCid = extraJson.optString("call_cid")
                    } catch (e: Exception) {
                        Log.d(TAG, "📞 isCallActive: Could not parse extra as JSON: $extraRaw")
                    }
                }

                Log.d(TAG, "📞 isCallActive: Entry $i - extra.call_id='$extraCallId', extra.call_cid='$extraCallCid'")

                // Try multiple matching strategies
                val foundCallId = id.takeIf { it.isNotEmpty() && it != "null" }
                    ?: extraCallId?.takeIf { it.isNotEmpty() && it != "null" }
                    ?: extraCallCid?.split(":")?.lastOrNull()

                Log.d(TAG, "📞 isCallActive: Entry $i - foundCallId='$foundCallId'")

                if (foundCallId == callId) {
                    Log.d(TAG, "📞 isCallActive: ✅ MATCH FOUND!")
                    return true
                }
            }

            Log.d(TAG, "📞 isCallActive: ❌ No match found for callId='$callId'")
            false
        } catch (e: Exception) {
            Log.e(TAG, "📞 isCallActive: Error parsing ACTIVE_CALLS: ${e.message}", e)
            false
        }
    }

    private fun wasCallAccepted(callId: String): Boolean {
        val prefs = getSharedPreferences("call_status", Context.MODE_PRIVATE)
        return prefs.getBoolean("accepted_$callId", false)
    }

    private fun clearPendingCall(callId: String) {
        // Clear from Flutter's SharedPreferences
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val savedCallId = prefs.getString("flutter.pending_call_id", null)
        if (savedCallId == callId) {
            prefs.edit()
                .remove("flutter.pending_call_id")
                .remove("flutter.pending_call_cid")
                .remove("flutter.pending_call_timestamp")
                .apply()
            Log.d(TAG, "📞 Cleared pending call from SharedPreferences")
        }
    }

    private fun getCallKitPrefs(): SharedPreferences? {
        return getSharedPreferences("flutter_callkit_incoming", Context.MODE_PRIVATE)
    }

    private fun cleanup() {
        Log.d(TAG, "📞 Cleaning up service")

        // Remove runnable
        monitorRunnable?.let { handler?.removeCallbacks(it) }
        monitorRunnable = null

        // Unregister listener
        prefsListener?.let { listener ->
            getCallKitPrefs()?.unregisterOnSharedPreferenceChangeListener(listener)
        }
        prefsListener = null

        // Stop service
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()

        Log.d(TAG, "📞 Service stopped")
    }

    override fun onDestroy() {
        Log.d(TAG, "📞 Service onDestroy")
        cleanup()
        super.onDestroy()
    }
}
