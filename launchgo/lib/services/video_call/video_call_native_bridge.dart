import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Native bridge for video call operations
/// Provides static methods for calling Android native code from anywhere
/// including background isolates
class VideoCallNativeBridge {
  static const MethodChannel _channel = MethodChannel('com.launchgo/video_call');

  // SharedPreferences keys for pending calls (must match Android PendingCallsManager)
  static const String _pendingCallIdKey = 'pending_call_id';
  static const String _pendingCallCidKey = 'pending_call_cid';
  static const String _pendingCallTimestampKey = 'pending_call_timestamp';
  static const String _prefsName = 'pending_incoming_calls';

  /// Save pending incoming call to SharedPreferences
  /// This works in background isolate! Called when showing CallKit notification.
  static Future<void> savePendingCall({
    required String callId,
    String? callCid,
  }) async {
    if (!Platform.isAndroid) return;

    try {
      debugPrint('[VC] 📞 [VideoCallNativeBridge] Saving pending call: $callId');

      // Use SharedPreferences directly - works in background isolate
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingCallIdKey, callId);
      if (callCid != null) {
        await prefs.setString(_pendingCallCidKey, callCid);
      }
      await prefs.setInt(_pendingCallTimestampKey, DateTime.now().millisecondsSinceEpoch);

      debugPrint('[VC] 📞 [VideoCallNativeBridge] Pending call saved to SharedPreferences');
    } catch (e) {
      debugPrint('[VC] ⚠️ [VideoCallNativeBridge] Error saving pending call: $e');
    }
  }

  /// Clear pending call from SharedPreferences
  static Future<void> clearPendingCall({String? callId}) async {
    if (!Platform.isAndroid) return;

    try {
      debugPrint('[VC] 📞 [VideoCallNativeBridge] Clearing pending call: $callId');

      final prefs = await SharedPreferences.getInstance();

      // Only clear if callId matches or no callId specified
      if (callId != null) {
        final savedCallId = prefs.getString(_pendingCallIdKey);
        if (savedCallId != callId) {
          debugPrint('[VC] 📞 [VideoCallNativeBridge] Call ID mismatch, not clearing');
          return;
        }
      }

      await prefs.remove(_pendingCallIdKey);
      await prefs.remove(_pendingCallCidKey);
      await prefs.remove(_pendingCallTimestampKey);

      debugPrint('[VC] 📞 [VideoCallNativeBridge] Pending call cleared');
    } catch (e) {
      debugPrint('[VC] ⚠️ [VideoCallNativeBridge] Error clearing pending call: $e');
    }
  }

  /// Schedule WorkManager to monitor for call decline
  /// Should be called when showing incoming call notification on Android
  static Future<bool> scheduleCallMonitor({
    required String callId,
    String? callCid,
  }) async {
    if (!Platform.isAndroid) return false;

    try {
      debugPrint('[VC] 📞 [VideoCallNativeBridge] Scheduling call monitor for: $callId');
      final result = await _channel.invokeMethod<bool>('scheduleCallMonitor', {
        'callId': callId,
        'callCid': callCid,
      });
      debugPrint('[VC] 📞 [VideoCallNativeBridge] Schedule result: $result');
      return result ?? false;
    } catch (e) {
      debugPrint('[VC] ⚠️ [VideoCallNativeBridge] Error scheduling call monitor: $e');
      return false;
    }
  }

  /// Cancel WorkManager monitoring for a call
  /// Should be called when call is accepted via Flutter
  static Future<bool> cancelCallMonitor({required String callId}) async {
    if (!Platform.isAndroid) return false;

    try {
      debugPrint('[VC] 📞 [VideoCallNativeBridge] Cancelling call monitor for: $callId');
      final result = await _channel.invokeMethod<bool>('cancelCallMonitor', {
        'callId': callId,
      });
      debugPrint('[VC] 📞 [VideoCallNativeBridge] Cancel result: $result');
      return result ?? false;
    } catch (e) {
      debugPrint('[VC] ⚠️ [VideoCallNativeBridge] Error cancelling call monitor: $e');
      return false;
    }
  }

  /// Get pending call ID (accept) from native
  static Future<String?> getPendingCallId() async {
    if (!Platform.isAndroid) return null;

    try {
      final result = await _channel.invokeMethod<String>('getPendingCallId');
      return result;
    } catch (e) {
      debugPrint('[VC] ⚠️ [VideoCallNativeBridge] Error getting pending call ID: $e');
      return null;
    }
  }

  /// Get pending decline call ID from native
  static Future<String?> getPendingDeclineCallId() async {
    if (!Platform.isAndroid) return null;

    try {
      final result = await _channel.invokeMethod<String>('getPendingDeclineCallId');
      return result;
    } catch (e) {
      debugPrint('[VC] ⚠️ [VideoCallNativeBridge] Error getting pending decline call ID: $e');
      return null;
    }
  }
}
