package com.launchgo

import android.content.Intent
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.launchgo/video_call"
    private val TAG = "MainActivity"
    private var pendingCallId: String? = null
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "📞 onCreate called")
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        Log.d(TAG, "📞 onNewIntent called")
        setIntent(intent)
        handleIntent(intent)
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
                else -> result.notImplemented()
            }
        }

        Log.d(TAG, "📞 MethodChannel configured, pendingCallId: $pendingCallId")

        // If we have a pending call ID, notify Flutter immediately
        if (pendingCallId != null) {
            Log.d(TAG, "📞 Notifying Flutter about pending call: $pendingCallId")
            methodChannel?.invokeMethod("onCallAcceptedFromIntent", mapOf("callId" to pendingCallId))
        }
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) {
            Log.d(TAG, "📞 Intent is null")
            return
        }

        Log.d(TAG, "📞 handleIntent - action: ${intent.action}")
        Log.d(TAG, "📞 handleIntent - extras: ${intent.extras?.keySet()?.toList()}")

        // Check if this is a CallKit accept action
        if (intent.action == "com.hiennv.flutter_callkit_incoming.ACTION_CALL_ACCEPT") {
            val extras = intent.extras
            if (extras != null) {
                // Log all extras for debugging
                for (key in extras.keySet()) {
                    Log.d(TAG, "📞 Intent extra - $key: ${extras.get(key)}")
                }

                // Try to extract call ID from various possible keys
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

                if (callId != null) {
                    Log.d(TAG, "📞 ========================================")
                    Log.d(TAG, "📞 CALL ACCEPTED VIA INTENT - Call ID: $callId")
                    Log.d(TAG, "📞 ========================================")

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
    }
}
