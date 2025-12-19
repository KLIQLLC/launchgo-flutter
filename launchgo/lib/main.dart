import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launchgo/config/environment.dart';
import 'package:launchgo/router/app_router.dart';
import 'package:launchgo/services/api_service_retrofit.dart';
import 'package:launchgo/services/auth_service.dart';
import 'package:launchgo/services/api_service.dart';
import 'package:launchgo/services/theme_service.dart';
import 'package:launchgo/services/chat/stream_chat_service.dart';
import 'package:launchgo/services/push_notification_service.dart';
import 'package:launchgo/services/android_notification_display_service.dart';
import 'package:launchgo/services/pending_navigation_service.dart';
import 'package:launchgo/services/notifications_api_service.dart';
import 'package:launchgo/services/notification_navigation_service.dart';
import 'package:launchgo/services/weekly_notification_service.dart';
import 'package:launchgo/services/video_call/stream_video_service.dart';
import 'package:launchgo/services/video_call/video_call_push_handler.dart';
import 'package:launchgo/widgets/splash_screen.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart' as callkit;
import 'package:launchgo/features/recaps/presentation/bloc/recap_bloc.dart';
import 'package:launchgo/features/recaps/data/recap_repository.dart';
import 'package:provider/provider.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// MethodChannel for receiving video call intents from Android native code
const _videoCallChannel = MethodChannel('com.launchgo/video_call');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize environment configuration
  EnvironmentConfig.init();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Don't initialize push notifications here - will be done after router is ready
  
  // Set up Crashlytics
  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };
  
  // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    // Filter out known WebSocket close code errors from Stream Chat
    if (error.toString().contains('close code must be 1000 or in the range 3000-4999')) {
      debugPrint('🟡 WebSocket close code error handled gracefully (from Stream Chat SDK)');
      return true; // Don't crash the app
    }
    
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  
  // Lock orientation to portrait only
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()..initialize()),
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => StreamChatService()),
        ChangeNotifierProvider(create: (_) => StreamVideoService()),
        ChangeNotifierProvider.value(value: PushNotificationService.instance),
        ChangeNotifierProvider.value(value: PendingNavigationService.instance),
        Provider(
          create: (context) => ApiServiceRetrofit(
            authService: context.read<AuthService>(),
          ),
        ),
        Provider(
          create: (context) => ApiService(
            authService: context.read<AuthService>(),
          ),
        ),
        ChangeNotifierProxyProvider<ApiService, NotificationsApiService>(
          create: (context) => NotificationsApiService(
            apiService: context.read<ApiService>(),
          ),
          update: (context, apiService, notificationsService) => notificationsService ?? NotificationsApiService(
            apiService: apiService,
          ),
        ),
        ProxyProvider<ApiServiceRetrofit, RecapRepository>(
          update: (context, apiService, _) => RecapRepositoryImpl(apiService),
        ),
        ProxyProvider2<RecapRepository, AuthService, RecapBloc>(
          update: (context, repository, authService, _) => RecapBloc(
            repository: repository,
            authService: authService,
          ),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<RecapBloc>(
            create: (context) => context.read<RecapBloc>(),
          ),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final AppRouter _appRouter;
  bool _showSplash = true;
  late final AuthService _authService;
  late final StreamChatService _streamChatService;
  late final StreamVideoService _streamVideoService;
  late final NotificationsApiService _notificationsService;
  String? _lastNavigatedCallId; // Track last call we navigated to (video call screen)
  String? _lastIncomingCallId; // Track last incoming call to prevent duplicate screens

  @override
  void initState() {
    super.initState();
    _authService = context.read<AuthService>();
    _streamChatService = context.read<StreamChatService>();
    _streamVideoService = context.read<StreamVideoService>();
    _notificationsService = context.read<NotificationsApiService>();
    _appRouter = AppRouter(_authService);
    
    // Set router in navigation service
    PendingNavigationService.instance.setRouter(_appRouter.router);
    
    // Set router in push notification service for direct navigation
    PushNotificationService.instance.setRouter(_appRouter.router);
    
    // Set auth service for semester switching
    PushNotificationService.instance.setAuthService(_authService);
    
    // Now that router is ready, initialize push notifications
    PushNotificationService.instance.initialize().catchError((e) {
      debugPrint('❌ Push notification service initialization failed: $e');
    });
    
    // Set StreamChatService reference in AuthService for presence management
    _authService.setStreamChatService(_streamChatService);
    
    // Set NotificationsApiService reference in PushNotificationService for badge updates
    PushNotificationService.instance.setNotificationsService(_notificationsService);

    // Set router and auth service for AndroidNotificationDisplayService for tap navigation (Android only)
    if (Platform.isAndroid) {
      AndroidNotificationDisplayService.instance.setRouter(_appRouter.router);
      AndroidNotificationDisplayService.instance.setAuthService(_authService);
    }

    // Initialize NotificationNavigationService for local notification tap handling
    NotificationNavigationService.instance.initialize(_appRouter.router, _authService);

    // Initialize VideoCallPushHandler for handling video call push notifications
    VideoCallPushHandler.instance.initialize(
      _appRouter.router,
      _authService,
      _streamVideoService,
    );

    // Set up MethodChannel listener for Android terminated state call acceptance
    // When user accepts call via CallKit while app is terminated, MainActivity sends
    // the call_id to Flutter via this channel
    if (Platform.isAndroid) {
      _setupAndroidCallIntentHandler();
      _setupCallKitEventListener();
    }

    // Set up ringing events callback for navigation when call is accepted
    // Based on official pattern: observeCoreRingingEvents
    // The call is ALREADY JOINED when this callback fires
    _streamVideoService.setOnCallAcceptedCallback((call) {
      debugPrint('[VIDEO_CALL] Call accepted via CallKit/push - navigating');
      debugPrint('[VIDEO_CALL] Call ID: ${call.id}');
      debugPrint('[VIDEO_CALL] App state: foreground');

      _lastNavigatedCallId = call.id;
      _appRouter.router.pushNamed(
        'student-video-chat',
        pathParameters: {'callId': call.id},
        queryParameters: {
          'callerName': 'Mentor',
          'autoAccept': 'true',  // Call already accepted via CallKit
        },
      );
    });

    // Listen for incoming video calls (foreground - Android only)
    // On iOS, CallKit handles the incoming call UI natively via observeCoreRingingEvents
    // We only need to navigate on Android where we show a custom incoming call UI
    _streamVideoService.addListener(() {
      final userRole = _authService.userInfo?.role.toString() ?? 'unknown';
      debugPrint('[VIDEO_CALL] Service listener triggered');
      debugPrint('[VIDEO_CALL] User role: $userRole');
      debugPrint('[VIDEO_CALL] Incoming call ID: ${_streamVideoService.incomingCallId}');
      debugPrint('[VIDEO_CALL] Incoming caller: ${_streamVideoService.incomingCallerName}');

      // Handle incoming calls (students only, app in foreground)
      // iOS: Skip this - CallKit handles incoming UI natively, navigation happens via onCallAccepted
      // Android: Show custom incoming call UI
      if (Platform.isAndroid &&
          _streamVideoService.incomingCallId != null &&
          _streamVideoService.incomingCallerName != null &&
          _authService.userInfo != null &&
          _authService.userInfo!.isStudent) {
        final currentCallId = _streamVideoService.incomingCallId!;

        // Prevent duplicate navigation
        if (_lastIncomingCallId != currentCallId) {
          debugPrint('[VIDEO_CALL] New incoming call detected (Android)');
          debugPrint('[VIDEO_CALL] App state: foreground');
          debugPrint('[VIDEO_CALL] Navigating to student-video-chat screen');

          _lastIncomingCallId = currentCallId;

          _appRouter.router.pushNamed(
            'student-video-chat',
            pathParameters: {'callId': currentCallId},
            queryParameters: {
              'callerName': _streamVideoService.incomingCallerName!,
              // autoAccept is false by default - show Accept/Decline UI
            },
          );
        }
      } else if (_streamVideoService.incomingCallId == null) {
        _lastIncomingCallId = null;
      }

      // Reset navigation tracking when call ends
      if (!_streamVideoService.hasActiveCall) {
        _lastNavigatedCallId = null;
      }
    });

    // Add app lifecycle observer
    WidgetsBinding.instance.addObserver(this);
    
    // Auto-connect Stream Chat for unread badge when user is authenticated
    // Only for students - mentors connect when they select a student
    _authService.addListener(() async {
      if (_authService.userInfo != null && _authService.userInfo!.chatGetStreamToken != null) {
        // Only auto-connect students - mentors connect selectively
        if (_authService.userInfo!.isStudent) {
          await _streamChatService.autoConnectUser(
            userId: _authService.userInfo!.id,
            token: _authService.userInfo!.chatGetStreamToken,
            userName: _authService.userInfo!.name,
            userImage: _authService.userInfo!.avatarUrl,
          );
        }

        // Initialize Stream Video for video calls
        if (_authService.userInfo!.callGetStreamToken != null) {
          await _streamVideoService.initialize(_authService.userInfo!);
          debugPrint('✅ Stream Video initialized for user: ${_authService.userInfo!.id}');

          // Consume active call from terminated state (for students)
          if (_authService.userInfo!.isStudent) {
            debugPrint('[VIDEO_CALL] Checking for active call from terminated state');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _streamVideoService.consumeAndAcceptActiveCall((callToJoin) {
                debugPrint('[VIDEO_CALL] Active call consumed from terminated state (auth listener)');
                debugPrint('[VIDEO_CALL] Call ID: ${callToJoin.id}');

                _lastNavigatedCallId = callToJoin.id;
                _appRouter.router.pushNamed(
                  'student-video-chat',
                  pathParameters: {'callId': callToJoin.id},
                  queryParameters: {
                    'callerName': 'Mentor',
                    'autoAccept': 'true',  // Call already accepted from terminated state
                  },
                );
              });
            });
          }
        }

        // Process any pending navigation after auth is ready
        if (PendingNavigationService.instance.hasPendingNavigation) {
          debugPrint('🔄 Auth ready, processing pending navigation');
          Future.delayed(const Duration(milliseconds: 500), () {
            PendingNavigationService.instance.processPendingNavigation();
          });
        }
        
        // Request FCM permissions and setup token for push notifications
        if (_authService.isAuthenticated) {
          Future.microtask(() async {
            // Check if user is still authenticated (might have signed out)
            if (!_authService.isAuthenticated || _authService.userInfo == null) {
              debugPrint('⚠️ User signed out during async operation, skipping setup');
              return;
            }

            // Request FCM permissions and setup token
            final success = await PushNotificationService.instance.requestPermissionsAndSetupToken();
            if (success) {
              debugPrint('✅ FCM token setup successful');
              // Manually trigger Stream Chat FCM registration
              await _streamChatService.registerPushTokenManually();
            } else {
              debugPrint('❌ FCM token setup failed');
            }

            // Load notifications
            _notificationsService.fetchNotifications();

            // Initialize and schedule weekly notifications for authenticated users
            if (_authService.userInfo != null) {
              await WeeklyNotificationService.instance.initialize();
              await WeeklyNotificationService.instance.scheduleWeeklyRecapNotification(_authService.userInfo);
            }
          });
        }
      }
    });

    // Try to connect immediately if already authenticated (students only)
    if (_authService.userInfo != null &&
        _authService.userInfo!.chatGetStreamToken != null &&
        _authService.userInfo!.isStudent) {
      _streamChatService.autoConnectUser(
        userId: _authService.userInfo!.id,
        token: _authService.userInfo!.chatGetStreamToken,
        userName: _authService.userInfo!.name,
        userImage: _authService.userInfo!.avatarUrl,
      );
    }

    // Initialize Stream Video immediately if already authenticated
    if (_authService.userInfo != null && _authService.userInfo!.callGetStreamToken != null) {
      Future.microtask(() async {
        // Double-check user is still authenticated
        if (_authService.userInfo != null) {
          await _streamVideoService.initialize(_authService.userInfo!);
          debugPrint('[VIDEO_CALL] Stream Video initialized on startup');

          // Consume active call from terminated state (Android)
          // Based on official pattern from GetStream tutorial
          if (_authService.userInfo!.isStudent) {
            debugPrint('[VIDEO_CALL] Attempting to consume active call from terminated state');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _streamVideoService.consumeAndAcceptActiveCall((callToJoin) {
                debugPrint('[VIDEO_CALL] Active call consumed from terminated state');
                debugPrint('[VIDEO_CALL] Call ID: ${callToJoin.id}');
                debugPrint('[VIDEO_CALL] App state: terminated -> foreground');

                _appRouter.router.pushNamed(
                  'student-video-chat',
                  pathParameters: {'callId': callToJoin.id},
                  queryParameters: {
                    'callerName': 'Mentor',
                    'autoAccept': 'true',  // Call already accepted from terminated state
                  },
                );
              });
            });
          }
        }
      });
    }
    
    // Setup FCM token if already authenticated
    if (_authService.isAuthenticated) {
      Future.microtask(() async {
        final success = await PushNotificationService.instance.requestPermissionsAndSetupToken();
        if (success) {
          debugPrint('✅ FCM token setup successful (initial)');
          await _streamChatService.registerPushTokenManually();
        } else {
          debugPrint('❌ FCM token setup failed (initial)');
        }
        _notificationsService.fetchNotifications();
      });
    }
    
    // Show splash screen for 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showSplash = false;
        });
      }
    });
  }

  /// Set up handler for video call intents from Android native code
  /// This handles the case where user accepts a call via CallKit while app is terminated
  void _setupAndroidCallIntentHandler() {
    debugPrint('[VC] 📞 Setting up Android call intent handler via MethodChannel');

    _videoCallChannel.setMethodCallHandler((call) async {
      debugPrint('[VC] 📞 MethodChannel received: ${call.method}');
      debugPrint('[VC] 📞 MethodChannel arguments: ${call.arguments}');

      if (call.method == 'onCallAcceptedFromIntent') {
        final args = call.arguments as Map<dynamic, dynamic>?;
        final callId = args?['callId'] as String?;

        debugPrint('[VC] 📞 ========== CALL ACCEPTED FROM ANDROID INTENT ==========');
        debugPrint('[VC] 📞 Call ID: $callId');

        if (callId != null) {
          // Wait a bit for auth and video service to be ready
          await Future.delayed(const Duration(milliseconds: 500));

          // Ensure video service is initialized
          if (_authService.userInfo != null && !_streamVideoService.isInitialized) {
            debugPrint('[VC] 📞 Video service not initialized, initializing now...');
            await _streamVideoService.initialize(_authService.userInfo!);
          }

          // Navigate to video chat screen
          // User already accepted from notification - auto-accept the call
          debugPrint('[VC] 📞 Navigating to student-video-chat screen with autoAccept=true');
          _lastNavigatedCallId = callId;
          _appRouter.router.pushNamed(
            'student-video-chat',
            pathParameters: {'callId': callId},
            queryParameters: {
              'callerName': 'Mentor',
              'autoAccept': 'true',  // User already tapped Answer on notification
            },
          );
          debugPrint('[VC] 📞 Navigation initiated');
        } else {
          debugPrint('[VC] ❌ Call ID is null, cannot navigate');
        }
        debugPrint('[VC] 📞 ========== END CALL ACCEPTED FROM ANDROID INTENT ==========');
      } else if (call.method == 'onCallDeclinedFromIntent') {
        final args = call.arguments as Map<dynamic, dynamic>?;
        final callId = args?['callId'] as String?;

        debugPrint('[VC] 📞 ========== CALL DECLINED FROM ANDROID INTENT ==========');
        debugPrint('[VC] 📞 Call ID: $callId');

        if (callId != null) {
          // Wait a bit for auth and video service to be ready
          await Future.delayed(const Duration(milliseconds: 300));

          // Ensure video service is initialized
          if (_authService.userInfo != null && !_streamVideoService.isInitialized) {
            debugPrint('[VC] 📞 Video service not initialized, initializing now...');
            await _streamVideoService.initialize(_authService.userInfo!);
          }

          // Reject the call via SDK
          await _streamVideoService.rejectIncomingCall(callId);
          debugPrint('[VC] 📞 Call rejected via SDK');
        } else {
          debugPrint('[VC] ❌ Call ID is null, cannot reject');
        }
        debugPrint('[VC] 📞 ========== END CALL DECLINED FROM ANDROID INTENT ==========');
      }
    });

    // Also check for pending call ID (in case Flutter was slow to start)
    _checkPendingCallFromAndroid();
  }

  /// Check if there's a pending call ID from Android (terminated state acceptance/decline)
  Future<void> _checkPendingCallFromAndroid() async {
    try {
      // Check for pending accept
      debugPrint('[VC] 📞 Checking for pending call from Android...');
      final callId = await _videoCallChannel.invokeMethod<String>('getPendingCallId');

      if (callId != null) {
        debugPrint('[VC] 📞 Found pending call ID from Android: $callId');

        // Wait for auth to be ready
        await Future.delayed(const Duration(milliseconds: 800));

        if (_authService.userInfo != null) {
          // Ensure video service is initialized
          if (!_streamVideoService.isInitialized) {
            await _streamVideoService.initialize(_authService.userInfo!);
          }

          // Navigate to video chat screen
          // User already accepted from notification - auto-accept the call
          debugPrint('[VC] 📞 Navigating to student-video-chat for pending call with autoAccept=true');
          _lastNavigatedCallId = callId;
          _appRouter.router.pushNamed(
            'student-video-chat',
            pathParameters: {'callId': callId},
            queryParameters: {
              'callerName': 'Mentor',
              'autoAccept': 'true',  // User already tapped Answer on notification
            },
          );
        }
        return; // Don't check for decline if we have an accept
      } else {
        debugPrint('[VC] 📞 No pending accept call from Android');
      }

      // Check for pending decline
      debugPrint('[VC] 📞 Checking for pending decline from Android...');
      final declineCallId = await _videoCallChannel.invokeMethod<String>('getPendingDeclineCallId');

      if (declineCallId != null) {
        debugPrint('[VC] 📞 Found pending decline call ID from Android: $declineCallId');

        // Wait for auth to be ready
        await Future.delayed(const Duration(milliseconds: 500));

        if (_authService.userInfo != null) {
          // Ensure video service is initialized
          if (!_streamVideoService.isInitialized) {
            await _streamVideoService.initialize(_authService.userInfo!);
          }

          // Reject the call via SDK
          await _streamVideoService.rejectIncomingCall(declineCallId);
          debugPrint('[VC] 📞 Pending decline processed');
        }
      } else {
        debugPrint('[VC] 📞 No pending decline call from Android');
      }
    } catch (e) {
      debugPrint('[VC] 📞 Error checking pending call: $e');
    }
  }

  /// Check for pending decline that happened while app was in background
  Future<void> _checkPendingDeclineFromBackground() async {
    try {
      debugPrint('[VC] 📞 Checking for pending decline from BroadcastReceiver...');
      final declineCallId = await _videoCallChannel.invokeMethod<String>('getPendingDeclineCallId');

      if (declineCallId != null) {
        debugPrint('[VC] 📞 ========== FOUND PENDING DECLINE FROM BACKGROUND ==========');
        debugPrint('[VC] 📞 Call ID: $declineCallId');

        if (_authService.userInfo != null) {
          // Ensure video service is initialized
          if (!_streamVideoService.isInitialized) {
            debugPrint('[VC] 📞 Initializing video service...');
            await _streamVideoService.initialize(_authService.userInfo!);
          }

          // Reject the call via SDK
          debugPrint('[VC] 📞 Rejecting call via SDK...');
          await _streamVideoService.rejectIncomingCall(declineCallId);
          debugPrint('[VC] 📞 Call rejected successfully');
        } else {
          debugPrint('[VC] ⚠️ User not authenticated, cannot reject call');
        }

        debugPrint('[VC] 📞 ========== END PENDING DECLINE ==========');
      } else {
        debugPrint('[VC] 📞 No pending decline found');
      }
    } catch (e) {
      debugPrint('[VC] ❌ Error checking pending decline: $e');
    }
  }

  /// Set up listener for FlutterCallkitIncoming events
  /// This handles decline events when app is in foreground or background (not terminated)
  /// Note: Accept events are handled by Stream Video SDK's observeCoreRingingEvents
  void _setupCallKitEventListener() {
    debugPrint('[VC] 📞 ====================================================');
    debugPrint('[VC] 📞 Setting up CallKit event listener for decline handling');
    debugPrint('[VC] 📞 ====================================================');

    FlutterCallkitIncoming.onEvent.listen((callkit.CallEvent? event) async {
      debugPrint('[VC] 📞 ****************************************************');
      debugPrint('[VC] 📞 CALLKIT EVENT RECEIVED');
      debugPrint('[VC] 📞 ****************************************************');

      if (event == null) {
        debugPrint('[VC] 📞 Event is NULL, ignoring');
        return;
      }

      debugPrint('[VC] 📞 Event type: ${event.event}');
      debugPrint('[VC] 📞 Event name: ${event.event?.name}');
      debugPrint('[VC] 📞 Event body type: ${event.body.runtimeType}');
      debugPrint('[VC] 📞 Event body: ${event.body}');

      // Log all body contents if it's a map
      final body = event.body;
      if (body is Map) {
        debugPrint('[VC] 📞 Body keys: ${body.keys.toList()}');
        for (final key in body.keys) {
          debugPrint('[VC] 📞   body[$key] = ${body[key]} (${body[key].runtimeType})');
        }

        // Log extra if present
        final extra = body['extra'];
        if (extra != null) {
          debugPrint('[VC] 📞 Extra type: ${extra.runtimeType}');
          debugPrint('[VC] 📞 Extra value: $extra');
          if (extra is Map) {
            for (final key in extra.keys) {
              debugPrint('[VC] 📞   extra[$key] = ${extra[key]}');
            }
          }
        }
      }

      // Handle decline events - accept is handled by Stream Video SDK
      if (event.event == callkit.Event.actionCallDecline) {
        debugPrint('[VC] 📞 ========== CALL DECLINED VIA CALLKIT EVENT ==========');

        // Extract call ID from event body
        String? callId;
        if (body is Map) {
          // Try to get call_id from extra field
          final extra = body['extra'];
          if (extra is Map) {
            callId = extra['call_id'] as String?;
            debugPrint('[VC] 📞 call_id from extra: $callId');
            if (callId == null) {
              // Try extracting from call_cid
              final callCid = extra['call_cid'] as String?;
              debugPrint('[VC] 📞 call_cid from extra: $callCid');
              if (callCid != null && callCid.contains(':')) {
                callId = callCid.split(':').last;
                debugPrint('[VC] 📞 Extracted call_id from call_cid: $callId');
              }
            }
          }
          // Fallback to direct fields
          if (callId == null) {
            callId = body['call_id'] as String? ?? body['id'] as String?;
            debugPrint('[VC] 📞 call_id from body direct: $callId');
          }
        }

        debugPrint('[VC] 📞 FINAL Extracted call ID: $callId');

        if (callId != null) {
          debugPrint('[VC] 📞 Auth user: ${_authService.userInfo?.id}');
          debugPrint('[VC] 📞 Video service initialized: ${_streamVideoService.isInitialized}');

          // Ensure video service is initialized
          if (_authService.userInfo != null) {
            if (!_streamVideoService.isInitialized) {
              debugPrint('[VC] 📞 Video service not initialized, initializing...');
              await _streamVideoService.initialize(_authService.userInfo!);
              debugPrint('[VC] 📞 Video service initialized: ${_streamVideoService.isInitialized}');
            }

            // Reject the call via SDK to notify the caller
            debugPrint('[VC] 📞 Calling rejectIncomingCall($callId)...');
            await _streamVideoService.rejectIncomingCall(callId);
            debugPrint('[VC] 📞 rejectIncomingCall completed');
          } else {
            debugPrint('[VC] ⚠️ User not authenticated, cannot reject call');
          }
        } else {
          debugPrint('[VC] ⚠️ Could not extract call ID from event');
        }

        debugPrint('[VC] 📞 ========== END CALL DECLINED VIA CALLKIT EVENT ==========');
      } else if (event.event == callkit.Event.actionCallAccept) {
        debugPrint('[VC] 📞 Call ACCEPT event - handled by Stream Video SDK');
      } else if (event.event == callkit.Event.actionCallTimeout) {
        debugPrint('[VC] 📞 Call TIMEOUT event - ending all calls');
        await FlutterCallkitIncoming.endAllCalls();
      } else if (event.event == callkit.Event.actionCallEnded) {
        debugPrint('[VC] 📞 Call ENDED event');
      } else if (event.event == callkit.Event.actionCallIncoming) {
        debugPrint('[VC] 📞 Call INCOMING event');
      } else if (event.event == callkit.Event.actionCallStart) {
        debugPrint('[VC] 📞 Call START event');
      } else {
        debugPrint('[VC] 📞 Unknown event type: ${event.event}');
      }

      debugPrint('[VC] 📞 ****************************************************');
    });

    debugPrint('[VC] 📞 CallKit event listener configured and active');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    debugPrint('🔄 App Lifecycle State: $state');
    
    // Stream Chat automatically manages presence based on WebSocket connection
    // When app resumes, ensure connection is active for presence
    if (state == AppLifecycleState.resumed) {
      if (_authService.userInfo != null && _authService.userInfo!.chatGetStreamToken != null) {
        // Only auto-reconnect students - mentors will reconnect when they select students
        if (_authService.userInfo!.isStudent) {
          _streamChatService.autoConnectUser(
            userId: _authService.userInfo!.id,
            token: _authService.userInfo!.chatGetStreamToken,
            userName: _authService.userInfo!.name,
            userImage: _authService.userInfo!.avatarUrl,
          );
          debugPrint('🟢 App resumed - Student reconnected to Stream Chat');
        } else {
          debugPrint('🟡 App resumed - Mentor will connect when selecting student');
        }
      }
      
      // Only fetch notifications if user is authenticated
      if (_authService.isAuthenticated) {
        Future.microtask(() => _notificationsService.fetchNotifications());
      }
      
      // Check for pending navigation when app resumes
      if (PendingNavigationService.instance.hasPendingNavigation) {
        debugPrint('🔄 App resumed with pending navigation');
        Future.delayed(const Duration(milliseconds: 800), () {
          PendingNavigationService.instance.processPendingNavigation();
        });
      }

      // Check for pending decline from CallKit (background decline)
      if (Platform.isAndroid) {
        debugPrint('[VC] 📞 App resumed - checking for pending decline from background');
        _checkPendingDeclineFromBackground();
      }
    }
    // Note: Stream Chat automatically sets users offline when WebSocket disconnects
    // No manual offline handling needed
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final streamChatService = context.watch<StreamChatService>();
    
    if (_showSplash) {
      return MaterialApp(
        title: 'launchgo',
        theme: themeService.themeData,
        home: const SplashScreen(),
        debugShowCheckedModeBanner: false,
        builder: (context, child) => StreamChat(
          client: streamChatService.client,
          child: child!,
        ),
      );
    }

    return MaterialApp.router(
      title: 'launchgo',
      theme: themeService.themeData,
      routerConfig: _appRouter.router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => StreamChat(
        client: streamChatService.client,
        child: child!,
      ),
    );
  }
}

