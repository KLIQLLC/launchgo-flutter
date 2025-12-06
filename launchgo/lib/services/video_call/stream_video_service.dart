import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart' as callkit_entities;
import 'package:rxdart/rxdart.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import 'package:stream_video_push_notification/stream_video_push_notification.dart';
import '../../config/environment.dart';
import '../../models/user_model.dart';
import '../secure_storage_service.dart';

/// Callback type for when a call is accepted (already joined) - used for navigation
typedef OnCallAcceptedCallback = void Function(Call call);

/// Service for managing Stream Video calls
/// Only mentors can initiate calls, students can only receive
class StreamVideoService extends ChangeNotifier {
  StreamVideo? _client;
  Call? _activeCall;
  Call? _incomingCall; // Store the actual incoming Call object
  String? _incomingCallId;
  String? _incomingCallerName;
  bool _isInitialized = false;
  StreamSubscription<Call?>? _incomingCallSubscription; // Track the subscription to prevent duplicates
  String? _lastProcessedCallId; // Track the last call we processed to prevent duplicates
  CompositeSubscription? _ringingEventsSubscription; // Subscription for ringing events (CallKit/push)
  StreamSubscription<callkit_entities.CallEvent?>? _callKitSubscription; // Direct CallKit listener
  OnCallAcceptedCallback? _onCallAcceptedCallback; // Callback for navigation after call is accepted

  // Static pending call data for when app is launched from terminated state
  // This stores the call ID that was accepted via push notification before client was ready
  static String? _pendingAcceptedCallId;
  static String? _pendingAcceptedCallCid; // Full call CID (e.g., "default:callId")

  // Static lock to prevent concurrent initialization
  static bool _isInitializing = false;

  StreamVideo? get client => _client;
  Call? get activeCall => _activeCall;
  bool get hasActiveCall => _activeCall != null;
  String? get incomingCallId => _incomingCallId;
  String? get incomingCallerName => _incomingCallerName;
  bool get isInitialized => _isInitialized;

  /// Set callback for when a call is accepted (call is already joined) - for navigation
  /// IMPORTANT: If there's already an active call (e.g., from pending call processed during init),
  /// the callback will be invoked immediately to trigger navigation
  void setOnCallAcceptedCallback(OnCallAcceptedCallback? callback) {
    _onCallAcceptedCallback = callback;

    // Check if there's already an active call that needs navigation
    // This handles the race condition where pending call was processed during initialize()
    // before the UI had a chance to set the callback
    if (callback != null && _activeCall != null) {
      debugPrint('📞 [Callback] Active call exists, checking if it needs navigation');
      debugPrint('📞 [Callback] Active call ID: ${_activeCall!.id}');

      // Validate the call is in a state that warrants navigation
      // Only invoke callback if call is actually connected/connecting/incoming
      final callStatus = _activeCall!.state.value.status;
      final isValidForNavigation = callStatus is CallStatusConnected ||
          callStatus is CallStatusConnecting ||
          callStatus is CallStatusIncoming;

      debugPrint('📞 [Callback] Call status: ${callStatus.runtimeType}, isValidForNavigation: $isValidForNavigation');

      if (isValidForNavigation) {
        debugPrint('📞 [Callback] Invoking callback immediately for navigation');
        // Use Future.microtask to avoid calling callback synchronously during setState
        Future.microtask(() {
          if (_activeCall != null && _onCallAcceptedCallback != null) {
            _onCallAcceptedCallback!(_activeCall!);
          }
        });
      } else {
        debugPrint('📞 [Callback] Call status not valid for navigation - clearing active call');
        // If call is in an invalid state (e.g., stale data), clear it
        _activeCall = null;
      }
    }
  }

  /// Initialize the video client for the authenticated user
  Future<void> initialize(UserModel user) async {
    debugPrint('📞 [INIT] StreamVideoService.initialize() called for user: ${user.id}');
    debugPrint('📞 [INIT] User role: ${user.role}');

    // EARLY: Set up CallKit listener immediately for students to catch accept events
    // This must happen BEFORE any async operations that might delay catching the event
    if (user.role == UserRole.student && _callKitSubscription == null) {
      debugPrint('📞 [INIT] Setting up CallKit listener EARLY for students');
      _setupCallKitListener();
    }

    // Skip if already initialized AND client exists
    if (_isInitialized && _client != null) {
      debugPrint('⚠️ StreamVideoService already initialized, skipping');
      return;
    }

    // Prevent concurrent initialization attempts using static lock
    if (_isInitializing) {
      debugPrint('⚠️ [INIT] Another initialization is in progress, skipping');
      return;
    }
    _isInitializing = true;

    // Set initialized flag immediately to prevent concurrent initialization attempts
    _isInitialized = true;
    debugPrint('📞 [INIT] Marked as initialized to prevent race conditions');

    try {
      final apiKey = EnvironmentConfig.streamVideoApiKey;
      debugPrint('📞 [INIT] API Key exists: ${apiKey.isNotEmpty}');

      // Get token from user's API data
      String callGetStreamToken = user.callGetStreamToken ?? '';

      debugPrint('📞 [INIT] Has video token: ${callGetStreamToken.isNotEmpty}');

      if (callGetStreamToken.isEmpty) {
        debugPrint('❌ [INIT] No video call token found for user ${user.id}');
        _isInitialized = false; // Reset so initialization can be retried
        return;
      }

      if (callGetStreamToken.isNotEmpty) {
        try {
          // Decode JWT to check expiration (basic parsing, not validation)
          final parts = callGetStreamToken.split('.');
          if (parts.length == 3) {
            final payload = parts[1];
            // Add padding if needed
            final normalized = base64.normalize(payload);
            final decoded = utf8.decode(base64.decode(normalized));
            debugPrint('📞 Stream Video Token Info: $decoded');

            // Parse expiration time
            final jsonData = json.decode(decoded);
            if (jsonData['exp'] != null) {
              final expTime = DateTime.fromMillisecondsSinceEpoch(jsonData['exp'] * 1000);
              final now = DateTime.now();
              final isExpired = now.isAfter(expTime);
              final timeLeft = expTime.difference(now);

              debugPrint('📞 Token expires at: $expTime');
              debugPrint('📞 Current time: $now');
              debugPrint('📞 Token expired: $isExpired');
              if (!isExpired) {
                debugPrint('📞 Time until expiration: ${timeLeft.inMinutes} minutes');
              }

              if (isExpired) {
                debugPrint('❌ [INIT] Stream Video token has EXPIRED! Token expired at: $expTime, Current time: $now');
                debugPrint('❌ [INIT] No valid token available. User needs to re-authenticate.');
                _isInitialized = false; // Reset so initialization can be retried
                return;
              }
            }
          }
        } catch (e) {
          debugPrint('⚠️ Could not parse token expiration: $e');
        }
      }

      // Check if StreamVideo singleton already exists (e.g., from background push handler)
      // If so, use it instead of creating a new one to avoid conflicts
      try {
        final existingInstance = StreamVideo.instance;
        debugPrint('📞 Found existing StreamVideo instance, reusing it');
        _client = existingInstance;
        // Skip creating a new instance since we already have one
      } catch (e) {
        // No existing instance, need to reset and create new
        debugPrint('📞 No existing StreamVideo instance, creating new one');
        await StreamVideo.reset();
        debugPrint('📞 StreamVideo singleton reset');

        _client = StreamVideo(
        apiKey,
        user: User.regular(
          userId: user.id,
          name: user.name,
          image: user.avatarUrl,
        ),
        userToken: callGetStreamToken,
        options: const StreamVideoOptions(
          logPriority: Priority.verbose,
          keepConnectionsAliveWhenInBackground: true, // Keep WebSocket alive in background
        ),
        pushNotificationManagerProvider: StreamVideoPushNotificationManager.create(
          iosPushProvider: const StreamVideoPushProvider.apn(
            name: 'voip_apns',
          ),
          androidPushProvider: const StreamVideoPushProvider.firebase(
            name: 'firebase',
          ),
        ),
      );
      }

      // Connect to establish WebSocket for receiving incoming call events
      debugPrint('📞 Connecting Stream Video client...');
      await _client!.connect();
      debugPrint('✅ Stream Video client connected');

      // Save credentials for background push handling (Android)
      await SecureStorageService.saveVideoCallCredentials(
        userId: user.id,
        userName: user.name,
        token: callGetStreamToken,
      );
      debugPrint('📞 Video call credentials saved for background handling');

      await _logVoIPToken();

      // Listen for incoming calls (for students)
      if (user.role == UserRole.student) {
        debugPrint('📞 User is a student, setting up incoming call listener');

        // Request call-related permissions for Android
        await _requestCallPermissions();

        _listenForIncomingCalls();
        // NOTE: _setupCallKitListener() is now called EARLY at the start of initialize()
        // NOTE: _observeRingingEvents() disabled - it requires VoIP push to be fully configured
        // (com.apple.developer.pushkit.voip entitlement + VoIP cert on Stream dashboard)

        // Check for pending accepted calls (from terminated app state)
        // This must be done AFTER client is initialized
        debugPrint('📞 Checking for pending/active calls after initialization...');
        await _checkForActiveCallKitCalls();
        await _processPendingAcceptedCall();
        // Fallback: Check pendingRingingCallId if we didn't find a pending accepted call
        // This handles the case where user accepted but we didn't catch the event
        await _processPendingRingingCall();

        // IMPORTANT: Clean up any stale pending call data if we didn't end up with an active call
        // This prevents stale data from previous sessions from causing issues
        if (_activeCall == null) {
          debugPrint('📞 [INIT] No active call after pending checks - clearing any stale pending data');
          await SecureStorageService.deletePendingAcceptedCallId();
          await SecureStorageService.deletePendingRingingCallId();
        }
      } else {
        debugPrint('📞 User is a mentor, skipping incoming call listener');
      }

      notifyListeners();
      debugPrint('✅ [INIT] StreamVideoService initialized for user: ${user.id} (role: ${user.role})');
    } catch (e) {
      debugPrint('❌ [INIT] Error initializing StreamVideoService: $e');
      debugPrint('❌ [INIT] Stack trace: ${StackTrace.current}');
      // Reset the flag so initialization can be retried
      _isInitialized = false;
    } finally {
      // Always reset the initialization lock
      _isInitializing = false;
    }
  }

  /// Retrieve and log VoIP device token from flutter_callkit_incoming
  Future<void> _logVoIPToken() async {
    try {
      const platform = MethodChannel('flutter_callkit_incoming');
      final String voipToken = await platform.invokeMethod('getDevicePushTokenVoIP');
      debugPrint('📞 VoIP Device Token: $voipToken');
    } catch (e) {
      debugPrint('Error retrieving VoIP token: $e');
    }
  }

  /// Request permissions required for incoming call notifications on Android
  /// - Notification permission (Android 13+)
  /// - Full-screen intent permission (Android 10+)
  /// - Display over other apps (SYSTEM_ALERT_WINDOW) for full-screen call UI
  Future<void> _requestCallPermissions() async {
    if (!Platform.isAndroid) {
      debugPrint('📞 Skipping Android-specific call permissions on iOS');
      return;
    }

    debugPrint('📞 Requesting call-related permissions for Android...');

    try {
      // Request notification permission (required for Android 13+)
      await FlutterCallkitIncoming.requestNotificationPermission({
        'rationaleMessagePermission': 'Notification permission is required for incoming call alerts',
        'postNotificationMessageRequired': 'Please allow notifications to receive incoming calls',
      });
      debugPrint('✅ Notification permission requested');

      // Request full-screen intent permission (Android 10+)
      // This allows the app to show full-screen incoming call UI
      await FlutterCallkitIncoming.requestFullIntentPermission();
      debugPrint('✅ Full-screen intent permission requested');
    } catch (e) {
      debugPrint('⚠️ Error requesting call permissions: $e');
    }
  }

  /// Observe ringing events using Stream's official pattern
  /// This handles CallKit accept/decline on iOS and push notifications on Android
  /// The call is ALREADY JOINED when onCallAccepted is called
  void _observeRingingEvents() {
    debugPrint('📞 Setting up ringing events observer (Stream official pattern)');

    // Cancel existing subscription
    _ringingEventsSubscription?.cancel();

    // Use Stream's observeCoreCallKitEvents which handles:
    // - CallKit accept/decline on iOS
    // - Push notification handling
    // - Automatic call joining
    // Note: In stream_video 1.0.0+, this was renamed to observeCoreRingingEvents
    _ringingEventsSubscription = _client?.observeCoreCallKitEvents(
      onCallAccepted: (callToJoin) {
        debugPrint('📞 [RingingEvents] Call accepted - call is already joined!');
        debugPrint('📞 [RingingEvents] Call ID: ${callToJoin.id}');

        // The call is already joined by the SDK - just update state and navigate
        _activeCall = callToJoin;
        _incomingCall = null;
        _incomingCallId = null;
        _incomingCallerName = null;
        _lastProcessedCallId = null;
        notifyListeners();

        // Invoke callback for navigation
        if (_onCallAcceptedCallback != null) {
          debugPrint('📞 [RingingEvents] Invoking callback for navigation');
          _onCallAcceptedCallback!(callToJoin);
        }
      },
    );

    debugPrint('✅ Ringing events observer setup complete');
  }

  /// Setup direct CallKit event listener using FlutterCallkitIncoming
  /// This handles accept/decline when user interacts with native iOS CallKit UI
  /// Works even when app was terminated and wakes up from CallKit
  void _setupCallKitListener() {
    debugPrint('📞 Setting up direct CallKit event listener');

    // Cancel existing subscription
    _callKitSubscription?.cancel();

    _callKitSubscription = FlutterCallkitIncoming.onEvent.listen((callkit_entities.CallEvent? event) {
      if (event == null) return;

      debugPrint('📞 [CallKit] Event received: ${event.event}');
      debugPrint('📞 [CallKit] Event body: ${event.body}');

      // Extract call ID from event body
      // Stream Video sends call_cid in format "type:callId" (e.g., "default:abc123")
      String? callId;
      final body = event.body;
      if (body is Map) {
        // Try different possible keys for call ID
        final extraData = body['extra'] as Map<String, dynamic>?;
        if (extraData != null) {
          final callCid = extraData['call_cid'] as String?;
          if (callCid != null && callCid.contains(':')) {
            callId = callCid.split(':').last;
          }
        }
        // Fallback to id field
        callId ??= body['id'] as String?;
      }

      if (callId == null) {
        debugPrint('⚠️ [CallKit] Could not extract call ID from event');
        return;
      }

      debugPrint('📞 [CallKit] Call ID: $callId');

      switch (event.event) {
        case callkit_entities.Event.actionCallAccept:
          debugPrint('📞 [CallKit] User ACCEPTED call via native UI: $callId');
          _handleCallKitAccept(callId);
          break;
        case callkit_entities.Event.actionCallDecline:
          debugPrint('📞 [CallKit] User DECLINED call via native UI: $callId');
          _handleCallKitDecline(callId);
          break;
        case callkit_entities.Event.actionCallEnded:
          debugPrint('📞 [CallKit] Call ended: $callId');
          break;
        case callkit_entities.Event.actionCallTimeout:
          debugPrint('📞 [CallKit] Call timeout: $callId');
          break;
        default:
          debugPrint('📞 [CallKit] Unhandled event: ${event.event}');
          break;
      }
    });

    debugPrint('✅ Direct CallKit event listener setup complete');
  }

  /// Handle CallKit accept action - user accepted via native iOS call UI or Android notification
  Future<void> _handleCallKitAccept(String callId) async {
    debugPrint('📞 [CallKit] Handling accept for call: $callId');

    // If client isn't ready yet, store the pending call ID for processing after init
    // Store both in memory (for same isolate) and persistent storage (for cross-isolate)
    if (_client == null) {
      debugPrint('⚠️ [CallKit] Client not ready - storing pending call ID for later: $callId');
      _pendingAcceptedCallId = callId;
      _pendingAcceptedCallCid = 'default:$callId'; // Store full CID
      // Also save to persistent storage in case this is from a different isolate
      await SecureStorageService.savePendingAcceptedCallId(callId);
      debugPrint('📞 [CallKit] Saved pending call ID to persistent storage');
      return;
    }

    try {
      // Clear any pending call from storage since we're handling it now
      await SecureStorageService.deletePendingAcceptedCallId();

      // Accept and get the call
      final call = await acceptIncomingCall(callId: callId);
      if (call != null) {
        debugPrint('✅ [CallKit] Call accepted successfully: $callId');
        // Invoke callback for navigation
        if (_onCallAcceptedCallback != null) {
          debugPrint('📞 [CallKit] Invoking navigation callback');
          _onCallAcceptedCallback!(call);
        }
      } else {
        debugPrint('❌ [CallKit] Failed to accept call: $callId');
      }
    } catch (e) {
      debugPrint('❌ [CallKit] Error accepting call: $e');
    }
  }

  /// Check for and process any pending accepted call after initialization
  /// This handles the case where user accepted a call from push notification
  /// while the app was terminated and the client wasn't ready yet
  Future<void> _processPendingAcceptedCall() async {
    // First check memory (same isolate)
    String? callId = _pendingAcceptedCallId;

    // If not in memory, check persistent storage (cross-isolate)
    if (callId == null) {
      debugPrint('📞 [Pending] Checking persistent storage for pending call...');
      callId = await SecureStorageService.getPendingAcceptedCallId();
    }

    if (callId == null) {
      debugPrint('📞 [Pending] No pending accepted call to process');
      return;
    }

    debugPrint('📞 [Pending] Processing pending accepted call: $callId');

    // Clear the pending call ID immediately to prevent reprocessing
    _pendingAcceptedCallId = null;
    _pendingAcceptedCallCid = null;
    await SecureStorageService.deletePendingAcceptedCallId();

    if (_client == null) {
      debugPrint('❌ [Pending] Client still not ready, cannot process pending call');
      return;
    }

    try {
      // Accept and get the call
      final call = await acceptIncomingCall(callId: callId);
      if (call != null) {
        debugPrint('✅ [Pending] Pending call accepted successfully: $callId');
        // Invoke callback for navigation
        if (_onCallAcceptedCallback != null) {
          debugPrint('📞 [Pending] Invoking navigation callback');
          _onCallAcceptedCallback!(call);
        }
      } else {
        debugPrint('❌ [Pending] Failed to accept pending call: $callId');
      }
    } catch (e) {
      debugPrint('❌ [Pending] Error accepting pending call: $e');
    }
  }

  /// Check for pending ringing call that was shown via push notification
  /// This is a fallback for when user accepted but we didn't catch the event
  /// The background handler saves the call ID when push arrives, and we check if the call is still valid
  Future<void> _processPendingRingingCall() async {
    // Skip if we already have an active call (previous checks succeeded)
    if (_activeCall != null) {
      debugPrint('📞 [PendingRinging] Already have active call, skipping ringing check');
      // Clear any pending ringing call since we already have a call
      await SecureStorageService.deletePendingRingingCallId();
      return;
    }

    final ringingCallId = await SecureStorageService.getPendingRingingCallId();
    if (ringingCallId == null) {
      debugPrint('📞 [PendingRinging] No pending ringing call found');
      return;
    }

    debugPrint('📞 [PendingRinging] Found pending ringing call: $ringingCallId');

    // Clear the ringing call ID to prevent reprocessing
    await SecureStorageService.deletePendingRingingCallId();

    if (_client == null) {
      debugPrint('❌ [PendingRinging] Client not ready');
      return;
    }

    try {
      // Query Stream for this call to see if it's still active/ringing
      debugPrint('📞 [PendingRinging] Querying Stream for call status...');
      final call = _client!.makeCall(
        callType: StreamCallType.defaultType(),
        id: ringingCallId,
      );

      // Get the call from Stream to check its status
      await call.getOrCreate();
      debugPrint('📞 [PendingRinging] Call fetched, state: ${call.state.value.status}');

      // Check if the call is still in a state where we can join
      // If the user accepted via native UI, the call should be in a joinable state
      final callStatus = call.state.value.status;

      // CallStatus is an abstract class with subclasses:
      // - CallStatusIdle, CallStatusOutgoing, CallStatusIncoming
      // - CallStatusConnecting, CallStatusConnected, CallStatusReconnecting
      final isIncoming = callStatus is CallStatusIncoming;
      final isConnected = callStatus is CallStatusConnected;
      final isConnecting = callStatus is CallStatusConnecting;

      debugPrint('📞 [PendingRinging] Call status type: ${callStatus.runtimeType}');
      debugPrint('📞 [PendingRinging] isIncoming: $isIncoming, isConnected: $isConnected, isConnecting: $isConnecting');

      // If call is incoming (ringing) or already connected/connecting, we should join it
      // The user likely accepted but we didn't catch the event
      if (isIncoming || isConnected || isConnecting) {
        debugPrint('📞 [PendingRinging] Call is joinable - accepting and joining...');

        // Accept the call (in case it's still ringing)
        if (isIncoming) {
          await call.accept();
          debugPrint('📞 [PendingRinging] Call accepted');
        }

        _activeCall = call;
        _incomingCall = null;
        _incomingCallId = null;
        _incomingCallerName = null;
        notifyListeners();

        // Invoke callback for navigation
        if (_onCallAcceptedCallback != null) {
          debugPrint('📞 [PendingRinging] Invoking navigation callback');
          _onCallAcceptedCallback!(call);
        }

        debugPrint('✅ [PendingRinging] Successfully joined pending ringing call');
      } else {
        debugPrint('📞 [PendingRinging] Call status is $callStatus - not joining');
      }
    } catch (e) {
      debugPrint('❌ [PendingRinging] Error processing pending ringing call: $e');
    }
  }

  /// Check for active CallKit calls that may have been accepted while app was launching
  /// This uses FlutterCallkitIncoming.activeCalls() to find calls in progress
  Future<void> _checkForActiveCallKitCalls() async {
    debugPrint('📞 [ActiveCalls] Checking for active CallKit calls...');

    try {
      final activeCalls = await FlutterCallkitIncoming.activeCalls();
      debugPrint('📞 [ActiveCalls] Found ${activeCalls?.length ?? 0} active calls');

      if (activeCalls == null || activeCalls.isEmpty) {
        debugPrint('📞 [ActiveCalls] No active calls found');
        return;
      }

      // Process the first active call (there should typically only be one)
      for (final callData in activeCalls) {
        debugPrint('📞 [ActiveCalls] Active call data: $callData');

        // Extract call ID from the call data
        String? callId;
        String? callCid;

        if (callData is Map) {
          // Try to get call_cid from extra data
          final extra = callData['extra'] as Map<String, dynamic>?;
          if (extra != null) {
            callCid = extra['callCid'] as String?;
            if (callCid != null && callCid.contains(':')) {
              callId = callCid.split(':').last;
            }
          }
          // Fallback to id field
          callId ??= callData['id'] as String?;

          // Check if call was accepted (isAccepted flag)
          final isAccepted = callData['isAccepted'] == true;
          debugPrint('📞 [ActiveCalls] Call $callId isAccepted: $isAccepted');

          if (isAccepted && callId != null) {
            debugPrint('📞 [ActiveCalls] Found accepted call, processing: $callId');
            await _handleCallKitAccept(callId);
            break; // Only process one call
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [ActiveCalls] Error checking active calls: $e');
    }
  }

  /// Handle CallKit decline action - user declined via native iOS call UI
  Future<void> _handleCallKitDecline(String callId) async {
    debugPrint('📞 [CallKit] Handling decline for call: $callId');

    if (_client == null) {
      debugPrint('⚠️ [CallKit] Client not ready for decline');
      return;
    }

    try {
      final call = _client!.makeCall(
        callType: StreamCallType.defaultType(),
        id: callId,
      );
      await call.getOrCreate();
      await call.reject();
      debugPrint('✅ [CallKit] Call declined: $callId');
    } catch (e) {
      debugPrint('❌ [CallKit] Error declining call: $e');
    }
  }

  /// Listen for incoming calls (students only) - for foreground UI
  void _listenForIncomingCalls() {
    debugPrint('📞 Setting up incoming call listener for student');

    // Cancel existing subscription to prevent duplicates
    _incomingCallSubscription?.cancel();
    debugPrint('📞 Cancelled previous incoming call subscription (if any)');

    _incomingCallSubscription = _client?.state.incomingCall.listen(
      (call) {
        debugPrint('📞 Incoming call listener triggered! Call: $call');

        if (call == null) {
          // Call was cancelled or rejected
          debugPrint('📞 Call was cancelled or rejected');
          _incomingCall = null;
          _incomingCallId = null;
          _incomingCallerName = null;
          _lastProcessedCallId = null;
          notifyListeners();
          return;
        }

        final callId = call.callCid.id;
        debugPrint('📞 Incoming video call detected: ${call.callCid}');

        // Prevent processing the same call multiple times (deduplication)
        if (_lastProcessedCallId == callId) {
          debugPrint('📞 Already processed this call, ignoring duplicate event: $callId');
          return;
        }

        _lastProcessedCallId = callId;
        _incomingCall = call; // Store the actual Call object
        _incomingCallId = callId; // Also store ID for display

        // Set a default caller name immediately
        _incomingCallerName = 'Mentor';

        // Notify immediately so the incoming call screen appears
        notifyListeners();
        debugPrint('📞 Notified listeners of incoming call - incomingCallId: $_incomingCallId');

        // Try to get actual caller name from call state (this updates the name if available)
        call.state.listen((callState) {
          final remoteParticipants = callState.callParticipants.where((p) => !p.isLocal).toList();

          if (remoteParticipants.isNotEmpty && remoteParticipants.first.name.isNotEmpty) {
            _incomingCallerName = remoteParticipants.first.name;
            notifyListeners();
            debugPrint('📞 Updated caller name: $_incomingCallerName');
          }
        });
      },
      onError: (error) {
        debugPrint('❌ Error in incoming call listener: $error');
      },
      onDone: () {
        debugPrint('⚠️ Incoming call listener stream closed');
      },
    );

    debugPrint('✅ Incoming call listener setup complete');
  }

  /// Create and initiate a call (mentor only)
  /// callId should be the student's ID for consistency
  Future<Call?> createCall({
    required String callId,
    required String recipientId,
    required String recipientName,
  }) async {
    debugPrint('📞 createCall called - callId: $callId, recipientId: $recipientId, recipientName: $recipientName');

    if (_client == null) {
      debugPrint('❌ Video client not initialized');
      return null;
    }

    try {
      // Clean up any stale active call before creating a new one
      if (_activeCall != null) {
        debugPrint('⚠️ Cleaning up stale active call before creating new one');
        try {
          await _activeCall!.leave();
          // Don't set _activeCall = null or call notifyListeners() here
          // to avoid race condition where VideoCallScreen sees null
        } catch (e) {
          debugPrint('⚠️ Error leaving stale call: $e');
        }
      }

      debugPrint('📞 Creating call to student: $recipientId');

      final call = _client!.makeCall(
        callType: StreamCallType.defaultType(),
        id: callId,
      );

      debugPrint('📞 Call object created, calling getOrCreate with ringing: true');

      await call.getOrCreate(
        memberIds: [recipientId],
        ringing: true, // VoIP Push → CallKit UI (native call screen)
        notify: false,  // Standard APN Push → text banner (fallback if VoIP fails)
      );

      debugPrint('📞 getOrCreate completed - setting activeCall for UI');

      // Set activeCall IMMEDIATELY so mentor sees "calling" UI right away
      _activeCall = call;
      notifyListeners();

      debugPrint('✅ Call created: $callId - UI can navigate now');

      // NOTE: Don't call join() here - StreamCallContainer handles joining
      // Calling join() twice can cause connection issues
      debugPrint('📞 Mentor will join via StreamCallContainer');

      return call;
    } catch (e) {
      debugPrint('❌ Error creating call: $e');
      return null;
    }
  }

  /// Accept an incoming call (student only) - for foreground accept via button
  Future<Call?> acceptIncomingCall({String? callId}) async {
    if (_client == null) {
      debugPrint('❌ Cannot accept call: client is null');
      return null;
    }

    try {
      // IMPORTANT: Ensure WebSocket is connected (might have disconnected while in background)
      debugPrint('📞 Ensuring WebSocket connection before accepting call...');
      await _client!.connect();
      debugPrint('✅ WebSocket connection ensured');

      Call call;

      // Check if we have a cached _incomingCall that matches the callId
      // The cached call is preferred because it has proper WebSocket connection
      if (_incomingCall != null) {
        final cachedCallId = _incomingCall!.callCid.id;
        debugPrint('📞 Have cached _incomingCall with ID: $cachedCallId');

        if (callId == null || callId == cachedCallId) {
          // Use cached Call object - it has active WebSocket connection
          call = _incomingCall!;
          debugPrint('📞 Using cached incoming Call object: ${call.id}');
        } else {
          // callId doesn't match cached call - fetch fresh
          debugPrint('⚠️ callId ($callId) doesn\'t match cached ($cachedCallId) - fetching fresh');
          call = _client!.makeCall(
            callType: StreamCallType.defaultType(),
            id: callId,
          );
          await call.getOrCreate();
          debugPrint('📞 Fresh call fetched: ${call.id}');
        }
      } else if (callId != null) {
        // No cached call - fetch by ID (app was terminated or WebSocket disconnected)
        debugPrint('📞 No cached _incomingCall, fetching by ID: $callId');

        call = _client!.makeCall(
          callType: StreamCallType.defaultType(),
          id: callId,
        );

        await call.getOrCreate();
        debugPrint('📞 Fresh call fetched successfully: ${call.id}');
      } else {
        debugPrint('❌ Cannot accept call: no incoming call and no callId provided');
        return null;
      }

      debugPrint('📞 Accepting call (StreamCallContainer will handle join)...');

      // Only call accept() - StreamCallContainer will handle join()
      // Calling join() twice (here and in StreamCallContainer) can cause connection issues
      await call.accept();
      debugPrint('✅ Call accepted - StreamCallContainer will join');

      _activeCall = call;
      _incomingCall = null;
      _incomingCallId = null;
      _incomingCallerName = null;
      _lastProcessedCallId = null;
      notifyListeners();

      debugPrint('✅ Call accepted - navigating to VideoCallScreen with StreamCallContainer');
      return call;
    } catch (e) {
      debugPrint('❌ Error accepting call: $e');
      return null;
    }
  }

  /// Decline an incoming call (student only)
  Future<void> declineIncomingCall() async {
    if (_client == null || _incomingCall == null) {
      debugPrint('Cannot decline call: client or incoming call is null');
      return;
    }

    try {
      debugPrint('Declining incoming call: ${_incomingCall!.id}');

      // Use the actual Call object to reject
      await _incomingCall!.reject();

      _incomingCall = null;
      _incomingCallId = null;
      _incomingCallerName = null;
      _lastProcessedCallId = null; // Clear so next call can be processed
      notifyListeners();

      debugPrint('Call declined successfully');

      // NOTE: No need to re-establish listener - it remains active for next call
    } catch (e) {
      debugPrint('Error declining call: $e');
    }
  }

  /// Join an existing call
  Future<void> joinCall(Call call) async {
    try {
      await call.join();
      _activeCall = call;
      notifyListeners();
      debugPrint('Joined call successfully');
    } catch (e) {
      debugPrint('Error joining call: $e');
    }
  }

  /// End the active call
  Future<void> endCall() async {
    if (_activeCall == null) {
      debugPrint('No active call to end');
      return;
    }

    try {
      final callId = _activeCall!.id;
      debugPrint('Ending call: $callId');

      await _activeCall!.leave();
      _activeCall = null;
      _lastProcessedCallId = null; // Clear to allow next call with same ID
      notifyListeners();
      debugPrint('Call ended successfully');

      // NOTE: No need to re-establish listener - it remains active for next call
    } catch (e) {
      debugPrint('Error ending call: $e');
    }
  }

  /// Disconnect and cleanup
  Future<void> disconnect() async {
    await endCall();
    await _incomingCallSubscription?.cancel();
    _incomingCallSubscription = null;
    _ringingEventsSubscription?.cancel();
    _ringingEventsSubscription = null;
    await _callKitSubscription?.cancel();
    _callKitSubscription = null;
    await _client?.disconnect();
    _client = null;
    _incomingCall = null;
    _incomingCallId = null;
    _incomingCallerName = null;
    _lastProcessedCallId = null;
    _isInitialized = false; // Reset so new user can initialize
    notifyListeners();
    debugPrint('StreamVideoService disconnected');
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
