// services/video_call/stream_video_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart'
    as callkit_entities;
import 'package:permission_handler/permission_handler.dart';
import 'package:rxdart/rxdart.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import 'package:stream_video_push_notification/stream_video_push_notification.dart';
import '../../config/environment.dart';
import '../../models/user_model.dart';

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
  StreamSubscription<Call?>?
  _incomingCallSubscription; // Track the subscription to prevent duplicates
  String?
  _lastProcessedCallId; // Track the last call we processed to prevent duplicates
  CompositeSubscription?
  _ringingEventsSubscription; // Subscription for ringing events (CallKit/push)
  StreamSubscription<callkit_entities.CallEvent?>?
  _callKitSubscription; // Direct CallKit listener
  OnCallAcceptedCallback?
  _onCallAcceptedCallback; // Callback for navigation after call is accepted
  String?
  _pendingCallKitAcceptId; // Store call ID that was accepted via CallKit before client was initialized
  String?
  _pendingCallKitDeclineId; // Store call ID that was declined via CallKit before client was initialized
  StreamSubscription<CallState>?
  _activeCallStateSubscription; // Listener to detect when active call ends remotely
  StreamSubscription<CoordinatorEvent>?
  _coordinatorEventsSubscription; // Listener for coordinator events (call rejected by initiator)
  static const _platform = MethodChannel(
    'com.launchgo/video_call',
  ); // MethodChannel for Android Intent handling

  StreamVideo? get client => _client;
  Call? get activeCall => _activeCall;
  bool get hasActiveCall => _activeCall != null;
  Call? get incomingCall => _incomingCall;
  String? get incomingCallId => _incomingCallId;
  String? get incomingCallerName => _incomingCallerName;
  bool get isInitialized => _isInitialized;

  /// Set callback for when a call is accepted (call is already joined) - for navigation
  void setOnCallAcceptedCallback(OnCallAcceptedCallback? callback) {
    _onCallAcceptedCallback = callback;
  }

  /// Initialize the video client for the authenticated user
  Future<void> initialize(UserModel user) async {
    debugPrint(
      '📞 [INIT] StreamVideoService.initialize() called for user: ${user.id}',
    );
    debugPrint('📞 [INIT] User role: ${user.role}');

    // Skip if already initialized AND client exists
    if (_isInitialized && _client != null) {
      debugPrint('⚠️ StreamVideoService already initialized, skipping');
      return;
    }

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
              final expTime = DateTime.fromMillisecondsSinceEpoch(
                jsonData['exp'] * 1000,
              );
              final now = DateTime.now();
              final isExpired = now.isAfter(expTime);
              final timeLeft = expTime.difference(now);

              debugPrint('📞 Token expires at: $expTime');
              debugPrint('📞 Current time: $now');
              debugPrint('📞 Token expired: $isExpired');
              if (!isExpired) {
                debugPrint(
                  '📞 Time until expiration: ${timeLeft.inMinutes} minutes',
                );
              }

              if (isExpired) {
                debugPrint(
                  '❌ [INIT] Stream Video token has EXPIRED! Token expired at: $expTime, Current time: $now',
                );
                debugPrint(
                  '❌ [INIT] No valid token available. User needs to re-authenticate.',
                );
                _isInitialized =
                    false; // Reset so initialization can be retried
                return;
              }
            }
          }
        } catch (e) {
          debugPrint('⚠️ Could not parse token expiration: $e');
        }
      }

      // Reset any existing StreamVideo singleton state before creating new instance
      // This is required for proper re-initialization after logout/login
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
          keepConnectionsAliveWhenInBackground:
              true, // Keep WebSocket alive in background
        ),
        pushNotificationManagerProvider:
            StreamVideoPushNotificationManager.create(
              iosPushProvider: const StreamVideoPushProvider.apn(
                name: 'voip_apns',
              ),
              androidPushProvider: const StreamVideoPushProvider.firebase(
                name: 'firebase',
              ),
            ),
      );

      // Connect to establish WebSocket for receiving incoming call events
      debugPrint('📞 Connecting Stream Video client...');
      await _client!.connect();
      debugPrint('✅ Stream Video client connected');

      await _logVoIPToken();

      // Listen for incoming calls (for students)
      if (user.role == UserRole.student) {
        debugPrint('📞 User is a student, setting up incoming call listener');
        _listenForIncomingCalls();
        _listenForCoordinatorEvents(); // Listen for call rejected by initiator
        _observeRingingEvents(); // Stream's official CallKit handling - call is ALREADY JOINED in callback
        _setupCallKitListener(); // Backup: direct CallKit listener for edge cases
        _setupAndroidIntentHandler(); // Listen for Android Intent with call ID when app launches from accept
      } else {
        debugPrint('📞 User is a mentor, skipping incoming call listener');
      }

      notifyListeners();
      debugPrint(
        '✅ [INIT] StreamVideoService initialized for user: ${user.id} (role: ${user.role})',
      );

      // Process pending CallKit accept if app was terminated and call was accepted before init
      if (_pendingCallKitAcceptId != null) {
        final pendingId = _pendingCallKitAcceptId;
        _pendingCallKitAcceptId = null; // Clear before processing
        debugPrint(
          '📞 [INIT] Processing pending CallKit accept for call: $pendingId',
        );
        Future.microtask(() => _handleCallKitAccept(pendingId!));
      }

      // Process pending CallKit decline if app was terminated and user declined before init
      if (_pendingCallKitDeclineId != null) {
        final pendingId = _pendingCallKitDeclineId;
        _pendingCallKitDeclineId = null; // Clear before processing
        debugPrint(
          '📞 [INIT] Processing pending CallKit decline for call: $pendingId',
        );
        Future.microtask(() => _handleCallKitDecline(pendingId!));
      }
    } catch (e) {
      debugPrint('❌ [INIT] Error initializing StreamVideoService: $e');
      debugPrint('❌ [INIT] Stack trace: ${StackTrace.current}');
      // Reset the flag so initialization can be retried
      _isInitialized = false;
    }
  }

  /// Retrieve and log VoIP device token from flutter_callkit_incoming
  Future<void> _logVoIPToken() async {
    try {
      const platform = MethodChannel('flutter_callkit_incoming');
      final String voipToken = await platform.invokeMethod(
        'getDevicePushTokenVoIP',
      );
      debugPrint('📞 VoIP Device Token: $voipToken');
    } catch (e) {
      debugPrint('Error retrieving VoIP token: $e');
    }
  }

  /// Setup Android Intent handler to receive call ID when app is launched from CallKit accept action
  /// This solves the race condition where accept happens before Flutter listener is ready
  void _setupAndroidIntentHandler() {
    debugPrint('📞 [Android Intent] Setting up MethodChannel handler');

    _platform.setMethodCallHandler((call) async {
      debugPrint('📞 [Android Intent] Received method call: ${call.method}');

      if (call.method == 'onCallAcceptedFromIntent') {
        final callId = call.arguments['callId'] as String?;
        if (callId != null) {
          debugPrint(
            '📞 [Android Intent] ========================================',
          );
          debugPrint('📞 [Android Intent] Call accepted via Intent: $callId');
          debugPrint(
            '📞 [Android Intent] ========================================',
          );

          // Process the call immediately
          await _handleCallKitAccept(callId);
        } else {
          debugPrint('❌ [Android Intent] No call ID in arguments');
        }
      }
    });

    // Also check if there's a pending call ID from MainActivity
    Future.microtask(() async {
      try {
        final pendingCallId = await _platform.invokeMethod('getPendingCallId');
        if (pendingCallId != null && pendingCallId is String) {
          debugPrint(
            '📞 [Android Intent] Found pending call ID from MainActivity: $pendingCallId',
          );
          await _handleCallKitAccept(pendingCallId);
        } else {
          debugPrint('📞 [Android Intent] No pending call ID');
        }
      } catch (e) {
        debugPrint('⚠️ [Android Intent] Error getting pending call ID: $e');
      }
    });

    debugPrint('✅ [Android Intent] MethodChannel handler setup complete');
  }

  /// Observe ringing events using Stream's official pattern
  /// This handles CallKit accept/decline on iOS and push notifications on Android
  /// The call is ALREADY JOINED when onCallAccepted is called
  void _observeRingingEvents() {
    debugPrint(
      '📞 Setting up ringing events observer (Stream official pattern)',
    );

    // Cancel existing subscription
    _ringingEventsSubscription?.cancel();

    // Use Stream's observeCoreCallKitEvents which handles:
    // - CallKit accept/decline on iOS
    // - Push notification handling
    // - Automatic call joining
    // Note: In stream_video 1.0.0+, this was renamed to observeCoreRingingEvents
    _ringingEventsSubscription = _client?.observeCoreCallKitEvents(
      onCallAccepted: (callToJoin) {
        debugPrint('📞 [RingingEvents] Call accepted (CallKit/ringing events)');
        debugPrint('📞 [RingingEvents] Call ID: ${callToJoin.id}');

        // Update state and navigate. Note: depending on platform/version, the SDK may
        // not have fully joined the call yet when this callback fires, so we run a
        // safety "ensure connected" pass in the background.
        _activeCall = callToJoin;
        _setupActiveCallStateListener(callToJoin);
        // Clear incoming call state since call is now active
        _incomingCall = null;
        _incomingCallId = null;
        _incomingCallerName = null;
        _lastProcessedCallId = null;
        notifyListeners();

        // Ensure the client/call are actually connected (resume-from-CallKit case)
        Future.microtask(() async {
          await ensureActiveCallConnected(
            reason: 'ringing_events_onCallAccepted',
          );
        });

        // Invoke callback for navigation
        if (_onCallAcceptedCallback != null) {
          debugPrint('📞 [RingingEvents] Invoking callback for navigation');
          _onCallAcceptedCallback!(callToJoin);
        }
      },
    );

    debugPrint('✅ Ringing events observer setup complete');
  }

  /// Ensure the Stream client is connected and (if needed) accept/join the active call.
  ///
  /// This is primarily to handle the "user accepts via CallKit, app resumes" flow on iOS,
  /// where the SDK may deliver the accept event before the call is fully joined.
  Future<void> ensureActiveCallConnected({String? reason}) async {
    final call = _activeCall;
    final client = _client;
    if (client == null || call == null) return;

    try {
      debugPrint(
        '📞 [EnsureConnected] Ensuring connection (reason: ${reason ?? 'unknown'}) for call: ${call.id}',
      );

      // Ensure WebSocket is connected
      await client.connect();

      final state = call.state.value;
      final status = state.status;
      debugPrint('📞 [EnsureConnected] Current call status: $status');

      // If already connected/reconnecting, do nothing.
      if (status.isConnected || status.isReconnecting) return;

      // Try accept() first (safe no-op if already accepted)
      try {
        await call.accept();
        debugPrint('📞 [EnsureConnected] accept() ok');
      } catch (e) {
        debugPrint(
          '📞 [EnsureConnected] accept() skipped/failed (likely already accepted): $e',
        );
      }

      // Then join()
      await call.join();
      debugPrint('📞 [EnsureConnected] join() ok');
    } catch (e) {
      debugPrint(
        '❌ [EnsureConnected] Failed to ensure active call connected: $e',
      );
    }
  }

  /// Extract Stream call ID from CallKit data (used by both event listener and active calls check)
  /// CallKit stores the Stream call ID in extra['callCid'] (format: "default:callId") or extra['call_id']
  String? _extractStreamCallIdFromCallKitData(Map<dynamic, dynamic> data) {
    String? callId;

    final extra = data['extra'] as Map<dynamic, dynamic>?;
    if (extra != null) {
      // First try call_id directly (clean ID without prefix)
      callId = extra['call_id'] as String?;
      if (callId != null) {
        debugPrint(
          '📞 [CallKit] Extracted call_id from extra.call_id: $callId',
        );
        return callId;
      }

      // Try extracting from callCid/call_cid (has "default:" prefix)
      final callCid =
          (extra['callCid'] as String?) ?? (extra['call_cid'] as String?);
      if (callCid != null && callCid.contains(':')) {
        callId = callCid.split(':').last;
        debugPrint(
          '📞 [CallKit] Extracted call_id from extra.callCid: $callId',
        );
        return callId;
      }
    }

    return null;
  }

  /// Setup direct CallKit event listener using FlutterCallkitIncoming
  /// This handles accept/decline when user interacts with native iOS CallKit UI
  /// Works even when app was terminated and wakes up from CallKit
  void _setupCallKitListener() {
    debugPrint('📞 Setting up direct CallKit event listener');

    // Cancel existing subscription
    _callKitSubscription?.cancel();

    // Check for active calls that may have been accepted before listener was set up (race condition fix)
    // When app is terminated/locked and user swipes to accept, the accept happens before we set up the listener
    Future.microtask(() async {
      try {
        final activeCalls = await FlutterCallkitIncoming.activeCalls();
        debugPrint(
          '📞 [CallKit] Checking for active calls on startup: ${activeCalls.length} found',
        );

        if (activeCalls.isNotEmpty) {
          for (var call in activeCalls) {
            debugPrint('📞 [CallKit] Active call found: ${call['id']}');
            debugPrint('📞 [CallKit] Active call extra: ${call['extra']}');

            // Extract Stream call ID from the active call data
            // Use the same extraction logic as the event listener
            final callId = _extractStreamCallIdFromCallKitData(call);
            if (callId != null) {
              debugPrint(
                '📞 [CallKit] Processing active call that was accepted before listener (locked screen): $callId',
              );
              _handleCallKitAccept(callId);
            } else {
              debugPrint(
                '⚠️ [CallKit] Could not extract Stream callId from active call',
              );
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ [CallKit] Error checking active calls: $e');
      }
    });

    _callKitSubscription = FlutterCallkitIncoming.onEvent.listen((
      callkit_entities.CallEvent? event,
    ) {
      if (event == null) return;

      debugPrint('📞 [CallKit] Event received: ${event.event}');
      debugPrint('📞 [CallKit] Event body: ${event.body}');

      // Extract Stream call ID from event body using shared helper
      final body = event.body;
      if (body is! Map) {
        debugPrint('⚠️ [CallKit] Event body is not a Map, ignoring');
        return;
      }

      final callId = _extractStreamCallIdFromCallKitData(body);
      if (callId == null) {
        debugPrint(
          '⚠️ [CallKit] Could not extract Stream callId from event. Ignoring.',
        );
        return;
      }

      debugPrint('📞 [CallKit] Stream Call ID: $callId');

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

  /// Handle CallKit accept action - user accepted via native iOS call UI
  /// NOTE: This is a backup handler. Primary handling is done by observeCoreCallKitEvents
  /// which automatically accepts/joins the call and fires onCallAccepted callback.
  Future<void> _handleCallKitAccept(String callId) async {
    debugPrint('📞 [CallKit-Backup] Handling accept for call: $callId');

    // Check if call is already active (observeCoreCallKitEvents might have handled it)
    if (_activeCall != null && _activeCall!.id == callId) {
      debugPrint(
        '📞 [CallKit-Backup] Call already active - skipping (handled by observeCoreCallKitEvents)',
      );
      // Still invoke navigation callback if it hasn't been done
      if (_onCallAcceptedCallback != null) {
        debugPrint(
          '📞 [CallKit-Backup] Invoking navigation callback for already active call',
        );
        _onCallAcceptedCallback!(_activeCall!);
      }
      return;
    }

    // If client isn't ready yet, store the call ID to process after initialization
    if (_client == null) {
      debugPrint(
        '⚠️ [CallKit-Backup] Client not ready - storing call ID for processing after init: $callId',
      );
      _pendingCallKitAcceptId = callId;
      return;
    }

    try {
      // Request camera and microphone permissions (required for video call)
      debugPrint(
        '📞 [CallKit-Backup] Requesting camera and microphone permissions...',
      );
      final Map<Permission, PermissionStatus> statuses = await [
        Permission.camera,
        Permission.microphone,
      ].request();

      debugPrint('📞 [CallKit-Backup] Permission results:');
      debugPrint('   Camera: ${statuses[Permission.camera]}');
      debugPrint('   Microphone: ${statuses[Permission.microphone]}');

      // Check if all permissions are granted
      final allGranted = statuses.values.every((status) => status.isGranted);
      if (!allGranted) {
        debugPrint(
          '⚠️ [CallKit-Backup] Not all permissions granted - continuing anyway',
        );
        // On iOS with CallKit, we should still try to join even without permissions
        // The system will show permission dialogs when needed
      }

      // Accept and get the call
      final call = await acceptIncomingCall(callId: callId);
      if (call != null) {
        debugPrint('✅ [CallKit-Backup] Call accepted successfully: $callId');
        // Invoke callback for navigation
        if (_onCallAcceptedCallback != null) {
          debugPrint('📞 [CallKit-Backup] Invoking navigation callback');
          _onCallAcceptedCallback!(call);
        }
      } else {
        debugPrint('❌ [CallKit-Backup] Failed to accept call: $callId');
      }
    } catch (e) {
      debugPrint('❌ [CallKit-Backup] Error accepting call: $e');
    }
  }

  /// Handle CallKit decline action - user declined via native iOS call UI
  Future<void> _handleCallKitDecline(String callId) async {
    debugPrint('📞 [CallKit] Handling decline for call: $callId');

    // Clear incoming call state regardless of whether reject succeeds
    // This ensures UI updates even if the API call fails
    _clearIncomingCall();

    if (_client == null) {
      debugPrint(
        '⚠️ [CallKit] Client not ready for decline - storing call ID for processing after init: $callId',
      );
      _pendingCallKitDeclineId = callId;
      return;
    }

    try {
      // Ensure WebSocket is connected so the reject reaches the coordinator.
      await _client!.connect();

      final call = _client!.makeCall(
        callType: StreamCallType.defaultType(),
        id: callId,
      );
      await call.getOrCreate();
      await call.reject();
      debugPrint('✅ [CallKit] Call declined: $callId');
      _dismissCallKitIfAny(reason: 'callkit_declined');
    } catch (e) {
      debugPrint('❌ [CallKit] Error declining call: $e');
    }
  }

  /// Clear incoming call state, dismiss CallKit, and notify listeners
  void _clearIncomingCall() {
    if (_incomingCall == null && _incomingCallId == null) return;
    debugPrint('📞 Clearing incoming call state');
    _incomingCall = null;
    _incomingCallId = null;
    _incomingCallerName = null;
    _lastProcessedCallId = null;
    // Dismiss CallKit UI when incoming call is cleared (e.g., initiator cancelled or declined)
    _dismissCallKitIfAny(reason: 'incoming_call_cleared');
    notifyListeners();
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
          debugPrint(
            '📞 Already processed this call, ignoring duplicate event: $callId',
          );
          return;
        }

        _lastProcessedCallId = callId;
        _incomingCall = call; // Store the actual Call object
        _incomingCallId = callId; // Also store ID for display

        // On iOS: CallKit handles the incoming call UI (triggered by VoIP push)
        // On Android: main.dart listener navigates to IncomingCallScreen

        // Get caller name from callParticipants (the mentor who initiated the call)
        final participants = call.state.value.callParticipants;
        if (participants.isNotEmpty && participants.first.name.isNotEmpty) {
          _incomingCallerName = participants.first.name;
          debugPrint(
            '📞 Caller name from callParticipants: $_incomingCallerName',
          );
        } else {
          _incomingCallerName = 'Mentor'; // Fallback
          debugPrint('📞 Using fallback caller name: $_incomingCallerName');
        }

        // Notify immediately so the incoming call screen appears
        notifyListeners();
        debugPrint(
          '📞 Notified listeners of incoming call - incomingCallId: $_incomingCallId',
        );
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

  /// Listen to coordinator events to detect when call is rejected by initiator
  void _listenForCoordinatorEvents() {
    _coordinatorEventsSubscription?.cancel();
    _coordinatorEventsSubscription = _client?.events.listen(
      (event) {
        // Handle call rejected event - this is the key event when initiator cancels
        if (event is CoordinatorCallRejectedEvent) {
          final rejectorId = event.rejectedByUserId;
          final callOwnerId = event.metadata.details.createdBy.id;
          final callCid = event.callCid.value;

          debugPrint(
            '📞 [CoordinatorEvents] Call rejected: $callCid, rejectedBy: $rejectorId, owner: $callOwnerId',
          );

          // If the call owner (initiator) rejected, clear the incoming call on the receiver
          if (rejectorId == callOwnerId && _incomingCallId != null) {
            // Check if this is for our incoming call
            final incomingCid = 'default:$_incomingCallId';
            if (callCid == incomingCid) {
              debugPrint(
                '📞 [CoordinatorEvents] Initiator cancelled our incoming call - clearing state',
              );
              _clearIncomingCall();
            }
          }
        }
      },
      onError: (error) {
        debugPrint('❌ [CoordinatorEvents] Error: $error');
      },
    );

    debugPrint('✅ Coordinator events listener setup complete');
  }

  /// Create and initiate a call (mentor only)
  /// callId should be the student's ID for consistency
  Future<Call?> createCall({
    required String callId,
    required String recipientId,
    required String recipientName,
  }) async {
    debugPrint(
      '📞 createCall called - callId: $callId, recipientId: $recipientId, recipientName: $recipientName',
    );

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

      debugPrint(
        '📞 Call object created, calling getOrCreate with ringing: true',
      );

      await call.getOrCreate(
        memberIds: [recipientId],
        ringing: true, // VoIP Push → CallKit UI (native call screen)
        notify:
            false, // Standard APN Push → text banner (fallback if VoIP fails)
      );

      debugPrint('📞 getOrCreate completed - setting activeCall for UI');

      // Set activeCall IMMEDIATELY so mentor sees "calling" UI right away
      _activeCall = call;
      _setupActiveCallStateListener(call);
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
    debugPrint('📞 ========================================');
    debugPrint('📞 acceptIncomingCall called with callId: $callId');
    debugPrint('📞 _incomingCall exists: ${_incomingCall != null}');
    debugPrint('📞 _incomingCallId: $_incomingCallId');
    debugPrint('📞 ========================================');

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
          debugPrint(
            '⚠️ callId ($callId) doesn\'t match cached ($cachedCallId) - fetching fresh',
          );
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
        debugPrint(
          '📞 Creating call with makeCall(callType: default, id: $callId)',
        );

        call = _client!.makeCall(
          callType: StreamCallType.defaultType(),
          id: callId,
        );

        debugPrint('📞 Calling getOrCreate() for call: ${call.id}');
        await call.getOrCreate();
        debugPrint(
          '📞 Fresh call fetched successfully - call.id: ${call.id}, call.callCid: ${call.callCid}',
        );
      } else {
        debugPrint(
          '❌ Cannot accept call: no incoming call and no callId provided',
        );
        return null;
      }

      debugPrint('📞 ========================================');
      debugPrint('📞 About to accept and join call with:');
      debugPrint('📞   call.id: ${call.id}');
      debugPrint('📞   call.callCid: ${call.callCid}');
      debugPrint('📞   callId parameter: $callId');
      debugPrint('📞 ========================================');

      // For incoming ringing calls, we must call accept() FIRST to:
      // 1. Signal to GetStream that the call was answered
      // 2. Notify the caller that the callee accepted
      // Then call join() to actually connect to the call
      debugPrint('📞 Calling accept() to notify caller...');
      await call.accept();
      debugPrint('✅ Call accepted - caller notified');

      debugPrint('📞 Calling join() to connect to call...');
      await call.join();
      debugPrint('✅ Call joined successfully');

      _activeCall = call;
      _setupActiveCallStateListener(call);
      // Clear incoming call state since call is now active
      _incomingCall = null;
      _incomingCallId = null;
      _incomingCallerName = null;
      _lastProcessedCallId = null;
      notifyListeners();

      debugPrint('✅ Call accepted and joined - ready for VideoCallScreen');
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

      // Clear incoming call state
      _incomingCall = null;
      _incomingCallId = null;
      _incomingCallerName = null;
      _lastProcessedCallId = null; // Clear so next call can be processed
      notifyListeners();

      debugPrint('Call declined successfully');
    } catch (e) {
      debugPrint('Error declining call: $e');
    }
  }

  /// Join an existing call
  Future<void> joinCall(Call call) async {
    try {
      await call.join();
      _activeCall = call;
      _setupActiveCallStateListener(call);
      notifyListeners();
      debugPrint('Joined call successfully');
    } catch (e) {
      debugPrint('Error joining call: $e');
    }
  }

  /// Set up a listener on the active call's state to detect when it ends remotely
  void _setupActiveCallStateListener(Call call) {
    // Cancel any existing subscription
    _activeCallStateSubscription?.cancel();

    debugPrint(
      '📞 [CallStateListener] Setting up listener for call: ${call.id}',
    );

    // Track if we've seen a connected state - only clear after being connected
    bool wasConnected = false;

    _activeCallStateSubscription = call.state.asStream().listen(
      (callState) {
        final status = callState.status;

        debugPrint(
          '📞 [CallStateListener] State update - status: $status, wasConnected: $wasConnected',
        );

        // Always clear if the call is disconnected/ended (even if it never reached Connected).
        // This is critical for "callee declined" / "caller cancelled" flows.
        if (status.isDisconnected || callState.endedAt != null) {
          debugPrint(
            '📞 [CallStateListener] Call ended/disconnected - status: $status, endedAt: ${callState.endedAt}',
          );
          _dismissCallKitIfAny(reason: 'call_state_disconnected');
          _clearActiveCall();
          return;
        }

        // Mark as connected when we reach connected state
        if (status.isConnected) {
          wasConnected = true;
          debugPrint('📞 [CallStateListener] Call is now connected');
        }

        // Only check for end conditions if we were previously connected
        // This prevents false positives during initial connection
        if (!wasConnected) {
          debugPrint(
            '📞 [CallStateListener] Skipping end check - not yet connected',
          );
          return;
        }

        // Also check if we're alone in the call (other party left)
        final participantCount = callState.callParticipants.length;
        if (participantCount <= 1 &&
            status.isConnected &&
            _activeCall != null) {
          debugPrint(
            '📞 [CallStateListener] Alone in call (participants: $participantCount) - ending',
          );
          _dismissCallKitIfAny(reason: 'call_state_alone');
          _clearActiveCall();
        }
      },
      onError: (error) {
        debugPrint('❌ [CallStateListener] Error: $error');
      },
    );
  }

  void _dismissCallKitIfAny({required String reason}) {
    // Only meaningful on iOS; safe no-op elsewhere.
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    Future.microtask(() async {
      try {
        debugPrint('📞 [CallKit] Dismissing CallKit UI (reason: $reason)');
        await FlutterCallkitIncoming.endAllCalls();
      } catch (e) {
        debugPrint('⚠️ [CallKit] Failed to dismiss CallKit UI: $e');
      }
    });
  }

  /// Clear the active call and notify listeners
  void _clearActiveCall() {
    if (_activeCall == null) return;

    debugPrint('📞 [CallStateListener] Clearing active call');
    _activeCallStateSubscription?.cancel();
    _activeCallStateSubscription = null;
    _activeCall = null;
    _lastProcessedCallId = null;
    notifyListeners();
  }

  /// End the active call for all participants
  Future<void> endCall() async {
    if (_activeCall == null) {
      debugPrint('No active call to end');
      return;
    }

    try {
      final callId = _activeCall!.id;
      debugPrint('📞 Ending call for all participants: $callId');

      // Cancel state listener first to avoid duplicate notifications
      _activeCallStateSubscription?.cancel();
      _activeCallStateSubscription = null;

      // Use end() instead of leave() to terminate the call for ALL participants
      // leave() only removes you from the call, others can stay
      // end() terminates the entire call session
      await _activeCall!.end();
      _activeCall = null;
      _lastProcessedCallId = null; // Clear to allow next call with same ID
      notifyListeners();
      debugPrint('Call ended successfully for all participants');

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
    _activeCallStateSubscription?.cancel();
    _activeCallStateSubscription = null;
    await _coordinatorEventsSubscription?.cancel();
    _coordinatorEventsSubscription = null;
    await _client?.disconnect();
    _client = null;
    _incomingCall = null;
    _incomingCallId = null;
    _incomingCallerName = null;
    _lastProcessedCallId = null;
    _pendingCallKitAcceptId = null; // Clear pending accept
    _pendingCallKitDeclineId = null; // Clear pending decline
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
