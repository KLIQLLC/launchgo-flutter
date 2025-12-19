package com.launchgo

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import com.hiennv.flutter_callkit_incoming.CallkitEventCallback
import com.hiennv.flutter_callkit_incoming.FlutterCallkitIncomingPlugin

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.launchgo/video_call"
    private val TAG = "[VC] MainActivity"
    private var pendingCallId: String? = null
    private var pendingDeclineCallId: String? = null
    private var methodChannel: MethodChannel? = null

    // Track active calls to detect decline
    private var lastKnownCallIds: Set<String> = emptySet()
    private var callKitPrefsListener: SharedPreferences.OnSharedPreferenceChangeListener? = null

    /**
     * Native callback for CallKit events.
     * This works even when app is in terminated/killed state!
     */
    private val callkitEventCallback = object : CallkitEventCallback {
        override fun onCallEvent(event: CallkitEventCallback.CallEvent, callData: Bundle) {
            Log.d(TAG, "📞 ****************************************************")
            Log.d(TAG, "📞 NATIVE CALLKIT EVENT RECEIVED!")
            Log.d(TAG, "📞 Event: $event")
            Log.d(TAG, "📞 ****************************************************")

            // Log all call data
            for (key in callData.keySet()) {
                Log.d(TAG, "📞 CallData[$key]: ${callData.get(key)}")
            }

            // Extract call ID from bundle
            val callId = extractCallIdFromBundle(callData)
            Log.d(TAG, "📞 Extracted call ID: $callId")

            when (event) {
                CallkitEventCallback.CallEvent.ACCEPT -> {
                    Log.d(TAG, "📞 ========== CALL ACCEPTED (NATIVE CALLBACK) ==========")
                    if (callId != null) {
                        pendingCallId = callId
                        markCallAsAccepted(callId)
                        CallMonitorWorker.cancelMonitoring(this@MainActivity, callId)
                        CallMonitorService.stopMonitoring(this@MainActivity)
                        PendingCallsManager.clearPendingCall(this@MainActivity, callId)

                        // Notify Flutter if ready
                        methodChannel?.invokeMethod("onCallAcceptedFromIntent", mapOf("callId" to callId))
                    }
                    Log.d(TAG, "📞 ========== END ACCEPT ==========")
                }
                CallkitEventCallback.CallEvent.DECLINE -> {
                    Log.d(TAG, "📞 ========== CALL DECLINED (NATIVE CALLBACK) ==========")
                    if (callId != null) {
                        // Get call_cid if available
                        val callCid = callData.getString("call_cid")
                            ?: extractCallCidFromBundle(callData)

                        Log.d(TAG, "📞 Call ID: $callId")
                        Log.d(TAG, "📞 Call CID: $callCid")

                        // Cancel monitoring and clear pending call
                        CallMonitorWorker.cancelMonitoring(this@MainActivity, callId)
                        CallMonitorService.stopMonitoring(this@MainActivity)
                        PendingCallsManager.clearPendingCall(this@MainActivity, callId)

                        // IMMEDIATELY reject the call via API
                        Log.d(TAG, "📞 Starting CallRejectService to notify caller...")
                        CallRejectService.startService(this@MainActivity, callId, callCid)

                        // Store for Flutter backup
                        pendingDeclineCallId = callId

                        // Notify Flutter if ready
                        methodChannel?.invokeMethod("onCallDeclinedFromIntent", mapOf("callId" to callId))
                    } else {
                        Log.w(TAG, "📞 Could not extract call ID from decline event")
                    }
                    Log.d(TAG, "📞 ========== END DECLINE ==========")
                }
                else -> {
                    Log.d(TAG, "📞 Unhandled event type: $event")
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "📞 ========== onCreate called ==========")
        Log.d(TAG, "📞 Intent: $intent")
        Log.d(TAG, "📞 Intent action: ${intent?.action}")

        // Register native CallKit callback
        Log.d(TAG, "📞 Registering CallkitEventCallback...")
        FlutterCallkitIncomingPlugin.registerEventCallback(callkitEventCallback)
        Log.d(TAG, "📞 CallkitEventCallback registered!")

        handleIntent(intent)
        setupCallKitPrefsListener()

        // Check for declined call from terminated state
        // This must happen AFTER handleIntent so accept is processed first
        checkForDeclinedCallOnStartup()
    }

    /**
     * Check if there's a declined call that happened while app was terminated.
     * This is called on app startup to detect declines that we couldn't catch via callback.
     */
    private fun checkForDeclinedCallOnStartup() {
        Log.d(TAG, "📞 ========== CHECKING FOR DECLINED CALL ON STARTUP ==========")

        // Get active calls from flutter_callkit_incoming
        val activeCallIds = getActiveCallIds()
        Log.d(TAG, "📞 Active calls from plugin: $activeCallIds")

        // Check if our pending call was declined
        val declinedCall = PendingCallsManager.checkForDeclinedCall(this, activeCallIds)

        if (declinedCall != null) {
            val (callId, callCid) = declinedCall
            Log.d(TAG, "📞 ****************************************************")
            Log.d(TAG, "📞 PROCESSING DECLINED CALL FROM TERMINATED STATE")
            Log.d(TAG, "📞 Call ID: $callId")
            Log.d(TAG, "📞 Call CID: $callCid")
            Log.d(TAG, "📞 ****************************************************")

            // Reject the call via API
            CallRejectService.startService(this, callId, callCid)

            // Store for Flutter
            pendingDeclineCallId = callId
        } else {
            Log.d(TAG, "📞 No declined call detected on startup")
        }

        Log.d(TAG, "📞 ========== END STARTUP CHECK ==========")
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        Log.d(TAG, "📞 ========== onNewIntent called ==========")
        Log.d(TAG, "📞 Intent: $intent")
        Log.d(TAG, "📞 Intent action: ${intent.action}")
        setIntent(intent)
        handleIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        Log.d(TAG, "📞 onResume - checking for declined calls")
        checkForDeclinedCalls()
    }

    override fun onDestroy() {
        super.onDestroy()
        // Unregister CallKit event callback
        Log.d(TAG, "📞 Unregistering CallkitEventCallback...")
        FlutterCallkitIncomingPlugin.unregisterEventCallback(callkitEventCallback)

        // Unregister SharedPreferences listener
        callKitPrefsListener?.let { listener ->
            getCallKitPrefs()?.unregisterOnSharedPreferenceChangeListener(listener)
        }
    }

    private fun getCallKitPrefs(): SharedPreferences? {
        return getSharedPreferences("flutter_callkit_incoming", Context.MODE_PRIVATE)
    }

    private fun setupCallKitPrefsListener() {
        Log.d(TAG, "📞 Setting up CallKit SharedPreferences listener")

        // Get initial state
        lastKnownCallIds = getActiveCallIds()
        Log.d(TAG, "📞 Initial active calls: $lastKnownCallIds")

        callKitPrefsListener = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
            if (key == "ACTIVE_CALLS") {
                Log.d(TAG, "📞 ****************************************************")
                Log.d(TAG, "📞 ACTIVE_CALLS changed!")
                Log.d(TAG, "📞 ****************************************************")
                checkForDeclinedCalls()
            }
        }

        getCallKitPrefs()?.registerOnSharedPreferenceChangeListener(callKitPrefsListener)
    }

    private fun getActiveCallIds(): Set<String> {
        val prefs = getCallKitPrefs() ?: return emptySet()
        val json = prefs.getString("ACTIVE_CALLS", "[]") ?: "[]"

        Log.d(TAG, "📞 ACTIVE_CALLS JSON: $json")

        return try {
            val array = JSONArray(json)
            val ids = mutableSetOf<String>()
            for (i in 0 until array.length()) {
                val obj = array.optJSONObject(i)
                Log.d(TAG, "📞 Call object $i: $obj")

                // The 'id' field now contains the call_id (we set it in push_notification_service.dart)
                val id = obj?.optString("id")
                val extra = obj?.optJSONObject("extra")
                val extraCallId = extra?.optString("call_id")
                val extraCallCid = extra?.optString("call_cid")

                Log.d(TAG, "📞   id: $id")
                Log.d(TAG, "📞   extra.call_id: $extraCallId")
                Log.d(TAG, "📞   extra.call_cid: $extraCallCid")

                // Prefer 'id' field (which is now the call_id), then extra fields
                val callId = id?.takeIf { it.isNotEmpty() && it != "null" }
                    ?: extraCallId?.takeIf { it.isNotEmpty() && it != "null" }
                    ?: extraCallCid?.split(":")?.lastOrNull()

                if (!callId.isNullOrEmpty()) {
                    ids.add(callId)
                    Log.d(TAG, "📞   -> Added call ID: $callId")
                }
            }
            Log.d(TAG, "📞 Total active call IDs: $ids")
            ids
        } catch (e: Exception) {
            Log.e(TAG, "📞 Error parsing ACTIVE_CALLS: ${e.message}", e)
            emptySet()
        }
    }

    private fun checkForDeclinedCalls() {
        val currentCallIds = getActiveCallIds()
        Log.d(TAG, "📞 Previous calls: $lastKnownCallIds")
        Log.d(TAG, "📞 Current calls: $currentCallIds")

        // Find calls that were removed (declined)
        val declinedCalls = lastKnownCallIds - currentCallIds
        Log.d(TAG, "📞 Declined calls detected: $declinedCalls")

        if (declinedCalls.isNotEmpty()) {
            for (callId in declinedCalls) {
                Log.d(TAG, "📞 ========== CALL DECLINED DETECTED ==========")
                Log.d(TAG, "📞 Call ID: $callId")

                // Start service to reject via API
                CallRejectService.startService(this, callId, null)

                // Also notify Flutter if ready
                methodChannel?.invokeMethod("onCallDeclinedFromIntent", mapOf("callId" to callId))

                Log.d(TAG, "📞 ========================================")
            }
        }

        lastKnownCallIds = currentCallIds
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPendingCallId" -> {
                    Log.d(TAG, "📞 Flutter requested pending call ID: $pendingCallId")
                    result.success(pendingCallId)
                    // Clear after sending
                    pendingCallId = null
                }
                "getPendingDeclineCallId" -> {
                    // First check our local pending, then check BroadcastReceiver
                    val localPending = pendingDeclineCallId
                    val receiverPending = CallKitBroadcastReceiver.consumePendingDecline()
                    val finalPending = localPending ?: receiverPending

                    Log.d(TAG, "📞 Flutter requested pending decline call ID")
                    Log.d(TAG, "📞   Local pending: $localPending")
                    Log.d(TAG, "📞   Receiver pending: $receiverPending")
                    Log.d(TAG, "📞   Final: $finalPending")

                    result.success(finalPending)
                    // Clear local after sending
                    pendingDeclineCallId = null
                }
                "scheduleCallMonitor" -> {
                    val callId = call.argument<String>("callId")
                    val callCid = call.argument<String>("callCid")
                    Log.d(TAG, "📞 Flutter requested to schedule call monitor")
                    Log.d(TAG, "📞   callId: $callId")
                    Log.d(TAG, "📞   callCid: $callCid")

                    if (callId != null) {
                        CallMonitorWorker.scheduleMonitoring(this, callId, callCid)
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                "cancelCallMonitor" -> {
                    val callId = call.argument<String>("callId")
                    Log.d(TAG, "📞 Flutter requested to cancel call monitor: $callId")

                    if (callId != null) {
                        CallMonitorWorker.cancelMonitoring(this, callId)
                        markCallAsAccepted(callId) // Also mark as accepted
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                "savePendingCall" -> {
                    val callId = call.argument<String>("callId")
                    val callCid = call.argument<String>("callCid")
                    Log.d(TAG, "📞 Flutter saving pending call: $callId")

                    if (callId != null) {
                        PendingCallsManager.savePendingCall(this, callId, callCid)
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                "clearPendingCall" -> {
                    val callId = call.argument<String>("callId")
                    Log.d(TAG, "📞 Flutter clearing pending call: $callId")

                    if (callId != null) {
                        PendingCallsManager.clearPendingCall(this, callId)
                    } else {
                        PendingCallsManager.clearPendingCall(this)
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        Log.d(TAG, "📞 MethodChannel configured, pendingCallId: $pendingCallId, pendingDeclineCallId: $pendingDeclineCallId")

        // If we have a pending call ID (accept), notify Flutter immediately
        if (pendingCallId != null) {
            Log.d(TAG, "📞 Notifying Flutter about pending accept call: $pendingCallId")
            methodChannel?.invokeMethod("onCallAcceptedFromIntent", mapOf("callId" to pendingCallId))
        }

        // If we have a pending decline call ID, notify Flutter immediately
        if (pendingDeclineCallId != null) {
            Log.d(TAG, "📞 Notifying Flutter about pending decline call: $pendingDeclineCallId")
            methodChannel?.invokeMethod("onCallDeclinedFromIntent", mapOf("callId" to pendingDeclineCallId))
            pendingDeclineCallId = null
        }
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) {
            Log.d(TAG, "📞 Intent is null")
            return
        }

        Log.d(TAG, "📞 handleIntent - action: ${intent.action}")
        Log.d(TAG, "📞 handleIntent - extras: ${intent.extras?.keySet()?.toList()}")

        // Check if this is a CallKit decline action (various formats)
        val isDeclineAction = intent.action?.let { action ->
            action == "com.hiennv.flutter_callkit_incoming.ACTION_CALL_DECLINE" ||
            action.endsWith(".com.hiennv.flutter_callkit_incoming.ACTION_CALL_DECLINE") ||
            action == "ACTION_CALL_DECLINE"
        } ?: false

        if (isDeclineAction) {
            Log.d(TAG, "📞 ========================================")
            Log.d(TAG, "📞 CALL DECLINED VIA CALLKIT")
            Log.d(TAG, "📞 ========================================")

            val callId = extractCallIdFromIntent(intent)

            if (callId != null) {
                Log.d(TAG, "📞 Decline - Call ID: $callId")

                // If Flutter is ready, send immediately
                if (methodChannel != null) {
                    Log.d(TAG, "📞 Sending decline to Flutter immediately")
                    methodChannel?.invokeMethod("onCallDeclinedFromIntent", mapOf("callId" to callId))
                } else {
                    Log.d(TAG, "📞 Flutter not ready yet, storing decline for later")
                    pendingDeclineCallId = callId
                }
            } else {
                Log.w(TAG, "📞 No call ID found for decline action")
            }
            return
        }

        // Check if this is a CallKit accept action (various formats)
        val isAcceptAction = intent.action?.let { action ->
            action == "com.hiennv.flutter_callkit_incoming.ACTION_CALL_ACCEPT" ||
            action.endsWith(".com.hiennv.flutter_callkit_incoming.ACTION_CALL_ACCEPT") ||
            action == "ACTION_CALL_ACCEPT"
        } ?: false

        if (isAcceptAction) {
            val callId = extractCallIdFromIntent(intent)

            if (callId != null) {
                Log.d(TAG, "📞 ========================================")
                Log.d(TAG, "📞 CALL ACCEPTED VIA INTENT - Call ID: $callId")
                Log.d(TAG, "📞 ========================================")

                // Mark this call as accepted so WorkManager doesn't reject it
                markCallAsAccepted(callId)
                // Cancel any pending monitoring for this call
                CallMonitorWorker.cancelMonitoring(this, callId)

                pendingCallId = callId

                // If Flutter is already running, send immediately
                if (methodChannel != null) {
                    Log.d(TAG, "📞 Sending call ID to Flutter immediately")
                    methodChannel?.invokeMethod("onCallAcceptedFromIntent", mapOf("callId" to callId))
                    pendingCallId = null // Clear after sending
                } else {
                    Log.d(TAG, "📞 Flutter not ready yet, storing call ID for later")
                }
            } else {
                Log.w(TAG, "📞 No call ID found in intent extras or bundle")
            }
        }
    }

    /**
     * Mark a call as accepted to prevent WorkManager from rejecting it
     */
    private fun markCallAsAccepted(callId: String) {
        Log.d(TAG, "📞 Marking call as accepted: $callId")
        val prefs = getSharedPreferences("call_status", Context.MODE_PRIVATE)
        prefs.edit().putBoolean("accepted_$callId", true).apply()
    }

    /**
     * Extract call ID from CallKit event callback Bundle
     */
    private fun extractCallIdFromBundle(bundle: Bundle): String? {
        // Log all bundle keys for debugging
        Log.d(TAG, "📞 extractCallIdFromBundle - keys: ${bundle.keySet().toList()}")

        // The 'id' field contains the notification ID (which we set to call_id)
        var callId = bundle.getString("id")
        Log.d(TAG, "📞 extractCallIdFromBundle - id: $callId")

        // Try extra HashMap
        if (callId == null) {
            @Suppress("UNCHECKED_CAST")
            val extra = bundle.getSerializable("extra") as? HashMap<String, Any>
            if (extra != null) {
                Log.d(TAG, "📞 extractCallIdFromBundle - extra: $extra")
                callId = extra["call_id"] as? String
                Log.d(TAG, "📞 extractCallIdFromBundle - extra.call_id: $callId")

                // Try extracting from call_cid
                if (callId == null) {
                    val callCid = extra["call_cid"] as? String
                    if (callCid != null && callCid.contains(':')) {
                        callId = callCid.split(':').last()
                        Log.d(TAG, "📞 extractCallIdFromBundle - from call_cid: $callId")
                    }
                }
            }
        }

        return callId
    }

    /**
     * Extract call CID from CallKit event callback Bundle
     */
    private fun extractCallCidFromBundle(bundle: Bundle): String? {
        @Suppress("UNCHECKED_CAST")
        val extra = bundle.getSerializable("extra") as? HashMap<String, Any>
        return extra?.get("call_cid") as? String
    }

    /**
     * Extract call ID from CallKit intent extras
     * Handles various formats: direct extras, bundle extras, JSON, etc.
     */
    private fun extractCallIdFromIntent(intent: Intent): String? {
        val extras = intent.extras ?: return null

        // Log all extras for debugging
        for (key in extras.keySet()) {
            Log.d(TAG, "📞 Intent extra - $key: ${extras.get(key)}")
        }

        var callId: String? = null

        // CallKit data comes in EXTRA_CALLKIT_CALL_DATA Bundle
        val callDataBundle = extras.getBundle("EXTRA_CALLKIT_CALL_DATA")
        if (callDataBundle != null) {
            Log.d(TAG, "📞 Found EXTRA_CALLKIT_CALL_DATA bundle, keys: ${callDataBundle.keySet()?.toList()}")

            // Log all bundle contents
            for (key in callDataBundle.keySet() ?: emptySet()) {
                Log.d(TAG, "📞 Bundle[$key]: ${callDataBundle.get(key)}")
            }

            // Try EXTRA_CALLKIT_EXTRA which contains our custom data as HashMap
            @Suppress("UNCHECKED_CAST")
            val extraMap = callDataBundle.getSerializable("EXTRA_CALLKIT_EXTRA") as? HashMap<String, Any>
            if (extraMap != null) {
                Log.d(TAG, "📞 Found EXTRA_CALLKIT_EXTRA map: $extraMap")

                // Extract call_id from the map
                callId = extraMap["call_id"] as? String
                if (callId != null) {
                    Log.d(TAG, "📞 Extracted call_id from EXTRA_CALLKIT_EXTRA: $callId")
                } else {
                    // Try extracting from call_cid if call_id is not present
                    val callCid = extraMap["call_cid"] as? String
                    if (callCid != null && callCid.contains(':')) {
                        callId = callCid.split(':').last()
                        Log.d(TAG, "📞 Extracted call_id from call_cid in EXTRA_CALLKIT_EXTRA: $callId")
                    }
                }
            }

            // Fallback: try 'extra' field as JSON string (legacy)
            if (callId == null) {
                val extraData = callDataBundle.getString("extra")
                if (extraData != null) {
                    Log.d(TAG, "📞 Found extra data string in bundle: $extraData")
                    try {
                        val callIdPattern = """"call_id"\s*:\s*"([^"]+)"""".toRegex()
                        val match = callIdPattern.find(extraData)
                        if (match != null) {
                            callId = match.groupValues[1]
                            Log.d(TAG, "📞 Extracted call_id from extra JSON: $callId")
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "📞 Error parsing extra JSON: $e")
                    }
                }
            }

            // Fallback to direct bundle keys
            if (callId == null) {
                callId = callDataBundle.getString("call_id")
                    ?: callDataBundle.getString("id")
                    ?: callDataBundle.getString("uuid")
            }
        } else {
            // Fallback: try direct extras (legacy)
            val extraData = extras.getString("extra")
            if (extraData != null) {
                Log.d(TAG, "📞 Found extra data in direct extras: $extraData")
                try {
                    val callIdPattern = """"call_id"\s*:\s*"([^"]+)"""".toRegex()
                    val match = callIdPattern.find(extraData)
                    if (match != null) {
                        callId = match.groupValues[1]
                        Log.d(TAG, "📞 Extracted call_id from extra JSON: $callId")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "📞 Error parsing extra JSON: $e")
                }
            }

            // Fallback to direct keys
            if (callId == null) {
                callId = extras.getString("call_id")
                    ?: extras.getString("id")
                    ?: extras.getString("uuid")
            }
        }

        return callId
    }
}
