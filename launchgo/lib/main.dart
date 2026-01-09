// main.dart
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
import 'package:launchgo/services/video_call/voip_pushkit_service.dart';
import 'package:launchgo/utils/call_debug_logger.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import 'package:launchgo/widgets/splash_screen.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart' as callkit;
import 'package:launchgo/features/recaps/presentation/bloc/recap_bloc.dart';
import 'package:launchgo/features/recaps/data/recap_repository.dart';
import 'package:provider/provider.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// MethodChannel for receiving video call intents from Android native code
const _videoCallChannel = MethodChannel('com.launchgo/video_call');

/// iOS MethodChannel for force ending CallKit (uses reliable saveEndCall)
const _iosCallKitChannel = MethodChannel('com.launchgo.app/callkit');

/// iOS MethodChannel for receiving video toggle events from native CallKit
/// When user taps Video button in CallKit UI, native code notifies Flutter via this channel
const _iosVideoToggleChannel = MethodChannel('com.launchgo.app/video_toggle');

/// Force end all CallKit calls on iOS using the reliable native method.
/// This uses saveEndCall() which bypasses the plugin's internal call list check.
/// Call this after FlutterCallkitIncoming.endAllCalls() as a fallback.
Future<void> forceEndCallKitIOS() async {
  if (!Platform.isIOS) return;
  
  try {
    // First try the plugin's method
    await FlutterCallkitIncoming.endAllCalls();
    
    // Then call native fallback which uses saveEndCall()
    await _iosCallKitChannel.invokeMethod('forceEndAllCalls');
    debugPrint('[iOS] forceEndCallKitIOS: completed');
  } catch (e) {
    debugPrint('[iOS] forceEndCallKitIOS error: $e');
  }
}

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
    if (error.toString().contains(
      'close code must be 1000 or in the range 3000-4999',
    )) {
      debugPrint(
        '🟡 WebSocket close code error handled gracefully (from Stream Chat SDK)',
      );
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
          create: (context) =>
              ApiServiceRetrofit(authService: context.read<AuthService>()),
        ),
        Provider(
          create: (context) =>
              ApiService(authService: context.read<AuthService>()),
        ),
        ChangeNotifierProxyProvider<ApiService, NotificationsApiService>(
          create: (context) =>
              NotificationsApiService(apiService: context.read<ApiService>()),
          update: (context, apiService, notificationsService) =>
              notificationsService ??
              NotificationsApiService(apiService: apiService),
        ),
        ProxyProvider<ApiServiceRetrofit, RecapRepository>(
          update: (context, apiService, _) => RecapRepositoryImpl(apiService),
        ),
        ProxyProvider2<RecapRepository, AuthService, RecapBloc>(
          update: (context, repository, authService, _) =>
              RecapBloc(repository: repository, authService: authService),
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
  bool _videoInitInProgress = false;
  String?
  _lastNavigatedCallId; // Track last call we navigated to (video call screen)
  String?
  _lastIncomingCallId; // Track last incoming call to prevent duplicate screens
  
  /// iOS audio-only call accepted via CallKit on lock screen
  /// When user taps Video button, we navigate to video chat with this call
  String? _pendingAudioCallId;
  Call? _pendingAudioCall;

  /// iOS method channel for call validity timer
  static const _iosTimerChannel = MethodChannel(
    'com.launchgo.app/call_validity',
  );

  @override
  void initState() {
    super.initState();
    _authService = context.read<AuthService>();
    _streamChatService = context.read<StreamChatService>();
    _streamVideoService = context.read<StreamVideoService>();
    _notificationsService = context.read<NotificationsApiService>();
    _appRouter = AppRouter(_authService);

    // React to auth finishing (userInfo loaded) after cold start.
    // Without this, Stream Video may never initialize if userInfo wasn't ready at initState.
    _authService.addListener(_handleAuthChanged);

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
    PushNotificationService.instance.setNotificationsService(
      _notificationsService,
    );

    // Set router and auth service for AndroidNotificationDisplayService for tap navigation (Android only)
    if (Platform.isAndroid) {
      AndroidNotificationDisplayService.instance.setRouter(_appRouter.router);
      AndroidNotificationDisplayService.instance.setAuthService(_authService);
    }

    // Initialize NotificationNavigationService for local notification tap handling
    NotificationNavigationService.instance.initialize(
      _appRouter.router,
      _authService,
    );

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

    // Set up iOS CallKit event listener for lock screen accepts
    // On iOS, we also need to listen to CallKit events because the SDK might not
    // properly trigger observeCoreRingingEvents when app launches from terminated state
    if (Platform.isIOS) {
      _setupiOSCallKitEventListener();
      _setupIOSCallValidityHandler();
      _setupIOSVideoToggleHandler();
    }

    // Set up ringing events callback for navigation when call is accepted
    // Based on official pattern: observeCoreRingingEvents
    // The call is ALREADY JOINED when this callback fires
    _streamVideoService.setOnCallAcceptedCallback((call) {
      debugPrint(
        '[VC] 📞 [MyApp:onCallAcceptedCallback] Call accepted via CallKit/push',
      );
      debugPrint('[VC] 📞 [MyApp:onCallAcceptedCallback] Call ID: ${call.id}');

      // Prevent duplicate navigation
      if (_lastNavigatedCallId == call.id) {
        debugPrint(
          '[VC] 📞 [MyApp:onCallAcceptedCallback] Already navigated to this call, skipping',
        );
        return;
      }

      // iOS: Check if we're in the background/lock screen audio-only mode
      // If so, store as pending call and don't navigate yet
      // Navigation will happen when user taps Video button or app comes to foreground
      if (Platform.isIOS) {
        // Check app lifecycle state - if not resumed, we're likely on lock screen
        final lifecycleState = WidgetsBinding.instance.lifecycleState;
        debugPrint('[VC] 📞 [MyApp:onCallAcceptedCallback] iOS lifecycle state: $lifecycleState');
        
        if (lifecycleState != AppLifecycleState.resumed) {
          debugPrint('[VC] 📞 [MyApp:onCallAcceptedCallback] iOS: App not in foreground, storing as pending audio call');
          _pendingAudioCallId = call.id;
          _pendingAudioCall = call;
          // Don't navigate - wait for Video button tap or app resume
          return;
        }
      }

      debugPrint('[VC] 📞 [MyApp:onCallAcceptedCallback] Navigating to video chat');
      _lastNavigatedCallId = call.id;
      _appRouter.router.pushNamed(
        'student-video-chat',
        pathParameters: {'callId': call.id},
        queryParameters: {
          'callerName': 'Mentor',
          'autoAccept': 'true', // Call already accepted via CallKit
        },
      );
    });

    // Listen for incoming video calls (foreground - Android only)
    // On iOS, CallKit handles the incoming call UI natively via observeCoreRingingEvents
    // We only need to navigate on Android where we show a custom incoming call UI
    _streamVideoService.addListener(() {
      final userRole = _authService.userInfo?.role.toString() ?? 'unknown';
      debugPrint(
        '[VC] 📞 [MyApp:videoServiceListener] Service listener triggered',
      );
      debugPrint('[VC] 📞 [MyApp:videoServiceListener] User role: $userRole');
      debugPrint(
        '[VC] 📞 [MyApp:videoServiceListener] Incoming call ID: ${_streamVideoService.incomingCallId}',
      );
      debugPrint(
        '[VC] 📞 [MyApp:videoServiceListener] Incoming caller: ${_streamVideoService.incomingCallerName}',
      );

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
          debugPrint(
            '[VC] 📞 [MyApp:videoServiceListener] New incoming call detected (Android)',
          );
          debugPrint(
            '[VC] 📞 [MyApp:videoServiceListener] App state: foreground',
          );
          debugPrint(
            '[VC] 📞 [MyApp:videoServiceListener] Navigating to student-video-chat screen',
          );

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
      // CRITICAL: Skip if signing out
      if (_authService.isSigningOut) {
        return;
      }
      
      final authUser = _authService.userInfo;
      final authUserId = authUser?.id;
      if (authUser != null &&
          authUser.chatGetStreamToken != null &&
          _authService.isAuthenticated) {
        // Only auto-connect students - mentors connect selectively
        if (authUser.isStudent) {
          await _streamChatService.autoConnectUser(
            userId: authUser.id,
            token: authUser.chatGetStreamToken,
            userName: authUser.name,
            userImage: authUser.avatarUrl,
          );
        }

        // If auth changed while we were awaiting chat connect, don't continue.
        if (_authService.isSigningOut ||
            !_authService.isAuthenticated ||
            _authService.userInfo?.id != authUserId) {
          return;
        }

        // Initialize Stream Video for video calls
        if (_authService.userInfo?.callGetStreamToken != null) {
          // Ensure PushKit is enabled while authenticated (iOS).
          // Persisted on native side so it stays enabled across restarts until logout.
          await VoipPushKitService.enable();

          // If auth changed while we were awaiting PushKit enable, don't continue.
          if (_authService.isSigningOut ||
              !_authService.isAuthenticated ||
              _authService.userInfo?.id != authUserId) {
            return;
          }

          try {
            await _streamVideoService.initialize(_authService.userInfo!);
            debugPrint(
              '[VC] 📞 [MyApp:authListener] Stream Video initialized for user: ${_authService.userInfo!.id}',
            );
          } catch (e, st) {
            debugPrint(
              '[VC] ❌ [MyApp:authListener] Stream Video init failed: $e\n$st',
            );
            return;
          }

          // Consume active call from terminated state (for students)
          // This handles calls accepted via CallKit while app was terminated
          if (_authService.userInfo!.isStudent && Platform.isAndroid) {
            debugPrint(
              '[VC] 📞 [MyApp:authListener] Checking for active call from terminated state (Android only)',
            );

            // Use post frame callback to ensure UI is ready
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              // Try consuming active call with retries
              // The SDK might need time to process the CallKit accept
              for (int attempt = 0; attempt < 3; attempt++) {
                debugPrint(
                  '[VC] 📞 [MyApp:authListener] consumeAndAcceptActiveCall attempt ${attempt + 1}',
                );

                bool callConsumed = false;
                _streamVideoService.consumeAndAcceptActiveCall((callToJoin) {
                  debugPrint(
                    '[VC] 📞 [MyApp:authListener] Active call consumed from terminated state',
                  );
                  debugPrint(
                    '[VC] 📞 [MyApp:authListener] Call ID: ${callToJoin.id}',
                  );

                  // Prevent duplicate navigation
                  if (_lastNavigatedCallId == callToJoin.id) {
                    debugPrint(
                      '[VC] 📞 [MyApp:authListener] Already navigated to this call, skipping',
                    );
                    return;
                  }

                  _lastNavigatedCallId = callToJoin.id;
                  callConsumed = true;
                  _appRouter.router.pushNamed(
                    'student-video-chat',
                    pathParameters: {'callId': callToJoin.id},
                    queryParameters: {
                      'callerName': 'Mentor',
                      'autoAccept':
                          'true', // Call already accepted from terminated state
                    },
                  );
                });

                // Wait a bit and check if call was consumed
                await Future.delayed(const Duration(milliseconds: 300));

                // If we already navigated (either from this or iOS CallKit handler), stop retrying
                if (_lastNavigatedCallId != null || callConsumed) {
                  debugPrint(
                    '[VC] 📞 [MyApp:authListener] Call handling complete, stopping retries',
                  );
                  break;
                }
              }
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

        // For returning users (auto-login), also check push permission status.
        // If it's still notDetermined, the user will be prompted again.
        // PushNotificationService is single-flight so this won't duplicate requests.
        if (_authService.isAuthenticated) {
          Future.microtask(() async {
            // Check and request push permissions if not yet determined
            await PushNotificationService.instance.requestPermissionsAndSetupToken(
              caller: 'MyApp.authListener.returningUser',
            );

            // Load notifications
            _notificationsService.fetchNotifications();

            // Initialize and schedule weekly notifications for authenticated users
            if (_authService.userInfo != null) {
              await WeeklyNotificationService.instance.initialize();
              await WeeklyNotificationService.instance
                  .scheduleWeeklyRecapNotification(_authService.userInfo);
            }
          });
        }
      }
    });

    // Try to connect immediately if already authenticated (students only)
    if (_authService.userInfo != null &&
        _authService.userInfo!.chatGetStreamToken != null &&
        _authService.userInfo!.isStudent &&
        _authService.isAuthenticated &&
        !_authService.isSigningOut) {
      _streamChatService.autoConnectUser(
        userId: _authService.userInfo!.id,
        token: _authService.userInfo!.chatGetStreamToken,
        userName: _authService.userInfo!.name,
        userImage: _authService.userInfo!.avatarUrl,
      );
    }

    // Initialize Stream Video immediately if already authenticated
    if (_authService.userInfo != null &&
        _authService.userInfo!.callGetStreamToken != null) {
      final startupUserId = _authService.userInfo!.id;
      Future.microtask(() async {
        // Double-check user is still authenticated
        if (_authService.userInfo != null &&
            _authService.isAuthenticated &&
            !_authService.isSigningOut &&
            _authService.userInfo!.id == startupUserId) {
          // For returning users on app startup: check push permission status.
          // If notDetermined, prompt user. Single-flight mechanism prevents duplicates.
          await PushNotificationService.instance.requestPermissionsAndSetupToken(
            caller: 'MyApp.initState.alreadyAuthenticated',
          );

          // Auth might have changed while awaiting the permission flow.
          if (_authService.userInfo == null ||
              !_authService.isAuthenticated ||
              _authService.isSigningOut ||
              _authService.userInfo!.id != startupUserId) {
            return;
          }

          try {
            await _streamVideoService.initialize(_authService.userInfo!);
            debugPrint('[VC] 📞 [MyApp:initState] Stream Video initialized on startup');
          } catch (e, st) {
            debugPrint('[VC] ❌ [MyApp:initState] Stream Video init failed: $e\n$st');
            return;
          }

          // Consume active call from terminated state (Android)
          // Based on official pattern from GetStream tutorial
          if (_authService.userInfo!.isStudent && Platform.isAndroid) {
            debugPrint(
              '[VC] 📞 [MyApp:initState] Attempting to consume active call from terminated state (Android only)',
            );
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _streamVideoService.consumeAndAcceptActiveCall((
                callToJoin,
              ) async {
                debugPrint(
                  '[VC] 📞 [MyApp:initState] Active call consumed from terminated state',
                );
                debugPrint(
                  '[VC] 📞 [MyApp:initState] Call ID: ${callToJoin.id}',
                );
                debugPrint(
                  '[VC] 📞 [MyApp:initState] App state: terminated -> foreground',
                );

                // Wait for splash screen to finish before navigating
                while (_showSplash) {
                  await Future.delayed(const Duration(milliseconds: 100));
                }
                await Future.delayed(const Duration(milliseconds: 300));

                _appRouter.router.pushNamed(
                  'student-video-chat',
                  pathParameters: {'callId': callToJoin.id},
                  queryParameters: {
                    'callerName': 'Mentor',
                    'autoAccept':
                        'true', // Call already accepted from terminated state
                  },
                );
              });
            });
          }
        }
      });
    }

    // NOTE: FCM / notification permissions are requested centrally (AuthService).

    // Show splash screen for 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showSplash = false;
        });
      }
    });
  }

  void _handleAuthChanged() {
    final user = _authService.userInfo;
    if (user == null) return;
    if (_authService.isSigningOut || !_authService.isAuthenticated) return;
    final userId = user.id;

    // Ensure Stream Video initializes as soon as we have userInfo (needed for CallKit accept flows).
    if (user.callGetStreamToken != null &&
        !_streamVideoService.isInitialized &&
        !_videoInitInProgress) {
      _videoInitInProgress = true;
      Future.microtask(() async {
        try {
          // Guard against stale queued microtasks: logout/auth changes can happen before this runs.
          if (!mounted ||
              _authService.isSigningOut ||
              !_authService.isAuthenticated ||
              _authService.userInfo?.id != userId) {
            debugPrint(
              '[VC] 📞 [MyApp:_handleAuthChanged] Skipping Stream Video init (auth changed or signing out)',
            );
            return;
          }
          await _streamVideoService.initialize(_authService.userInfo!);
          debugPrint('[VC] 📞 [MyApp:_handleAuthChanged] Stream Video initialized after auth');
        } catch (e) {
          debugPrint('[VC] ⚠️ [MyApp:_handleAuthChanged] Stream Video init failed: $e');
        } finally {
          _videoInitInProgress = false;
        }
      });
    }
  }

  /// Set up handler for video call intents from Android native code
  /// This handles the case where user accepts a call via CallKit while app is terminated
  void _setupAndroidCallIntentHandler() {
    debugPrint(
      '[VC] 📞 Setting up Android call intent handler via MethodChannel',
    );

    _videoCallChannel.setMethodCallHandler((call) async {
      debugPrint('[VC] 📞 MethodChannel received: ${call.method}');
      debugPrint('[VC] 📞 MethodChannel arguments: ${call.arguments}');

      if (call.method == 'onCallAcceptedFromIntent') {
        final args = call.arguments as Map<dynamic, dynamic>?;
        final callId = args?['callId'] as String?;

        debugPrint(
          '[VC] 📞 ========== CALL ACCEPTED FROM ANDROID INTENT ==========',
        );
        debugPrint('[VC] 📞 Call ID: $callId');

        if (callId != null) {
          // Wait for splash screen to finish before navigating
          while (_showSplash) {
            await Future.delayed(const Duration(milliseconds: 100));
          }

          // Wait for auth to be ready (max 5 seconds)
          var authWaitCount = 0;
          while (_authService.userInfo == null && authWaitCount < 50) {
            await Future.delayed(const Duration(milliseconds: 100));
            authWaitCount++;
          }
          await Future.delayed(const Duration(milliseconds: 300));

          // Ensure video service is initialized
          if (_authService.userInfo != null &&
              !_streamVideoService.isInitialized) {
            debugPrint(
              '[VC] 📞 Video service not initialized, initializing now...',
            );
            await _streamVideoService.initialize(_authService.userInfo!);
          }

          // Navigate to video chat screen
          // User already accepted from notification - auto-accept the call
          debugPrint(
            '[VC] 📞 Navigating to student-video-chat screen with autoAccept=true',
          );
          _lastNavigatedCallId = callId;
          _appRouter.router.pushNamed(
            'student-video-chat',
            pathParameters: {'callId': callId},
            queryParameters: {
              'callerName': 'Mentor',
              'autoAccept':
                  'true', // User already tapped Answer on notification
            },
          );
          debugPrint('[VC] 📞 Navigation initiated');
        } else {
          debugPrint('[VC] ❌ Call ID is null, cannot navigate');
        }
        debugPrint(
          '[VC] 📞 ========== END CALL ACCEPTED FROM ANDROID INTENT ==========',
        );
      } else if (call.method == 'onCallDeclinedFromIntent') {
        final args = call.arguments as Map<dynamic, dynamic>?;
        final callId = args?['callId'] as String?;

        debugPrint(
          '[VC] 📞 ========== CALL DECLINED FROM ANDROID INTENT ==========',
        );
        debugPrint('[VC] 📞 Call ID: $callId');

        if (callId != null) {
          // Wait a bit for auth and video service to be ready
          await Future.delayed(const Duration(milliseconds: 300));

          // Ensure video service is initialized
          if (_authService.userInfo != null &&
              !_streamVideoService.isInitialized) {
            debugPrint(
              '[VC] 📞 Video service not initialized, initializing now...',
            );
            await _streamVideoService.initialize(_authService.userInfo!);
          }

          // Reject the call via SDK
          await _streamVideoService.rejectIncomingCall(callId);
          debugPrint('[VC] 📞 Call rejected via SDK');
        } else {
          debugPrint('[VC] ❌ Call ID is null, cannot reject');
        }
        debugPrint(
          '[VC] 📞 ========== END CALL DECLINED FROM ANDROID INTENT ==========',
        );
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
      final callId = await _videoCallChannel.invokeMethod<String>(
        'getPendingCallId',
      );

      if (callId != null) {
        debugPrint('[VC] 📞 Found pending call ID from Android: $callId');

        // Wait for splash screen to finish before navigating
        while (_showSplash) {
          await Future.delayed(const Duration(milliseconds: 100));
        }

        // Wait for auth to be ready (max 5 seconds)
        var authWaitCount = 0;
        while (_authService.userInfo == null && authWaitCount < 50) {
          await Future.delayed(const Duration(milliseconds: 100));
          authWaitCount++;
        }
        await Future.delayed(const Duration(milliseconds: 300));

        if (_authService.userInfo != null) {
          // Ensure video service is initialized
          if (!_streamVideoService.isInitialized) {
            await _streamVideoService.initialize(_authService.userInfo!);
          }

          // Navigate to video chat screen
          // User already accepted from notification - auto-accept the call
          debugPrint(
            '[VC] 📞 Navigating to student-video-chat for pending call with autoAccept=true',
          );
          _lastNavigatedCallId = callId;
          _appRouter.router.pushNamed(
            'student-video-chat',
            pathParameters: {'callId': callId},
            queryParameters: {
              'callerName': 'Mentor',
              'autoAccept':
                  'true', // User already tapped Answer on notification
            },
          );
        }
        return; // Don't check for decline if we have an accept
      } else {
        debugPrint('[VC] 📞 No pending accept call from Android');
      }

      // Check for pending decline
      debugPrint('[VC] 📞 Checking for pending decline from Android...');
      final declineCallId = await _videoCallChannel.invokeMethod<String>(
        'getPendingDeclineCallId',
      );

      if (declineCallId != null) {
        debugPrint(
          '[VC] 📞 Found pending decline call ID from Android: $declineCallId',
        );

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
      debugPrint(
        '[VC] 📞 Checking for pending decline from BroadcastReceiver...',
      );
      final declineCallId = await _videoCallChannel.invokeMethod<String>(
        'getPendingDeclineCallId',
      );

      if (declineCallId != null) {
        debugPrint(
          '[VC] 📞 ========== FOUND PENDING DECLINE FROM BACKGROUND ==========',
        );
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
    debugPrint(
      '[VC] 📞 Setting up CallKit event listener for decline handling',
    );
    debugPrint('[VC] 📞 ====================================================');

    FlutterCallkitIncoming.onEvent.listen((callkit.CallEvent? event) async {
      debugPrint(
        '[VC] 📞 ****************************************************',
      );
      debugPrint('[VC] 📞 CALLKIT EVENT RECEIVED');
      debugPrint(
        '[VC] 📞 ****************************************************',
      );

      if (event == null) {
        debugPrint('[VC] 📞 Event is NULL, ignoring');
        return;
      }

      debugPrint('[VC] 📞 Event type: ${event.event}');
      debugPrint('[VC] 📞 Event name: ${event.event.name}');
      debugPrint('[VC] 📞 Event body type: ${event.body.runtimeType}');
      debugPrint('[VC] 📞 Event body: ${event.body}');

      // Log all body contents if it's a map
      final body = event.body;
      if (body is Map) {
        debugPrint('[VC] 📞 Body keys: ${body.keys.toList()}');
        for (final key in body.keys) {
          debugPrint(
            '[VC] 📞   body[$key] = ${body[key]} (${body[key].runtimeType})',
          );
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
        debugPrint(
          '[VC] 📞 ========== CALL DECLINED VIA CALLKIT EVENT ==========',
        );

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
          debugPrint(
            '[VC] 📞 Video service initialized: ${_streamVideoService.isInitialized}',
          );

          // Ensure video service is initialized
          if (_authService.userInfo != null) {
            if (!_streamVideoService.isInitialized) {
              debugPrint(
                '[VC] 📞 Video service not initialized, initializing...',
              );
              await _streamVideoService.initialize(_authService.userInfo!);
              debugPrint(
                '[VC] 📞 Video service initialized: ${_streamVideoService.isInitialized}',
              );
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

        debugPrint(
          '[VC] 📞 ========== END CALL DECLINED VIA CALLKIT EVENT ==========',
        );
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

      debugPrint(
        '[VC] 📞 ****************************************************',
      );
    });

    debugPrint('[VC] 📞 CallKit event listener configured and active');
  }

  /// Set up iOS-specific CallKit event listener
  /// This handles accept events when app launches from terminated/lock screen state
  /// The Stream Video SDK's observeCoreRingingEvents might not fire in time
  void _setupiOSCallKitEventListener() {
    debugPrint('[VC] 📞 ====================================================');
    debugPrint('[VC] 📞 Setting up iOS CallKit event listener');
    debugPrint('[VC] 📞 ====================================================');

    FlutterCallkitIncoming.onEvent.listen((callkit.CallEvent? event) async {
      debugPrint(
        '[VC] 📞 [iOS] ****************************************************',
      );
      debugPrint('[VC] 📞 [iOS] CALLKIT EVENT RECEIVED');
      debugPrint(
        '[VC] 📞 [iOS] ****************************************************',
      );

      if (event == null) {
        debugPrint('[VC] 📞 [iOS] Event is NULL, ignoring');
        return;
      }

      debugPrint('[VC] 📞 [iOS] Event type: ${event.event}');
      debugPrint('[VC] 📞 [iOS] Event body: ${event.body}');

      if (event.event == callkit.Event.actionCallAccept) {
        debugPrint('[VC] 📞 [iOS] ========== CALL ACCEPT EVENT ==========');

        // Extract call ID from event body
        String? callId;
        final body = event.body;
        if (body is Map) {
          final extra = body['extra'];
          if (extra is Map) {
            callId = extra['call_id'] as String?;
            if (callId == null) {
              // Try extracting from call_cid
              final callCid = extra['call_cid'] as String?;
              if (callCid != null && callCid.contains(':')) {
                callId = callCid.split(':').last;
              }
            }
          }
          callId ??= body['call_id'] as String? ?? body['id'] as String?;
        }

        debugPrint('[VC] 📞 [iOS] Extracted call ID: $callId');

        if (callId != null) {
          // Check if we already navigated to this call
          if (_lastNavigatedCallId == callId) {
            debugPrint(
              '[VC] 📞 [iOS] Already navigated to this call, skipping',
            );
            return;
          }

          debugPrint('[VC] 📞 [iOS] Ensuring auth + StreamVideo are ready...');
          final acceptStart = DateTime.now();

          // Ensure auth exists and this is a student device.
          if (_authService.userInfo == null || !_authService.userInfo!.isStudent) {
            debugPrint('[VC] ⚠️ [iOS] Cannot accept: user not ready or not a student');
            await CallDebugLogger.log('[IOS_ACCEPT] ABORT: user not ready or not student');
            return;
          }

          // Cold start case: initialize Stream Video if needed (don't just wait).
          if (!_streamVideoService.isInitialized) {
            try {
              debugPrint('[VC] 📞 [iOS] StreamVideo not initialized, initializing now...');
              await _streamVideoService.initialize(_authService.userInfo!);
              debugPrint('[VC] 📞 [iOS] StreamVideo initialized: ${_streamVideoService.isInitialized}');
            } catch (e) {
              debugPrint('[VC] ❌ [iOS] Failed to initialize StreamVideo: $e');
              await CallDebugLogger.log('[IOS_ACCEPT] ERROR initializing StreamVideo: $e');
            }
          }

          // Wait up to 30s total for service to become ready.
          for (int i = 0; i < 300; i++) {
            if (_streamVideoService.isInitialized && _streamVideoService.client != null) {
              final waited = DateTime.now().difference(acceptStart).inMilliseconds;
              debugPrint('[VC] 📞 [iOS] Services ready after ${waited}ms');
              break;
            }
            await Future.delayed(const Duration(milliseconds: 100));
          }

          if (!_streamVideoService.isInitialized || _streamVideoService.client == null) {
            debugPrint('[VC] ⚠️ [iOS] Services not ready after 30s; call may be marked missed by server');
            await CallDebugLogger.log('[IOS_ACCEPT] ABORT: StreamVideo not ready after 30s');
            return;
          }

          // CRITICAL FIX: Explicitly accept the call via Stream SDK
          // This ensures the mentor is notified that the student answered.
          //
          // IMPORTANT: Call.accept() only succeeds when call.status is Incoming.
          // On cold start, makeCall().getOrCreate() often yields Idle, so accept is rejected.
          //
          // We cannot use consumeAndAcceptActiveCall() here because it depends on the SDK-managed
          // CallKit activeCalls list (uuid/callCid), which can be null in our custom CallKit flow.
          // Instead, we consume using the CallKit event payload (uuid + call_cid) and then accept.
          try {
            final client = _streamVideoService.client;
            if (client == null) {
              debugPrint('[VC] ⚠️ [iOS] Cannot accept: StreamVideo client is null');
              await CallDebugLogger.log('[IOS_ACCEPT] ABORT: StreamVideo client is null');
              return;
            }

            // Extract CallKit UUID + call_cid from the event payload
            String? uuid;
            String? callCid;
            if (body is Map) {
              uuid = body['id'] as String? ?? body['uuid'] as String?;
              final extra = body['extra'];
              if (extra is Map) {
                callCid = extra['call_cid'] as String? ?? extra['stream_call_cid'] as String?;
              }
            }

            if (uuid == null || uuid.isEmpty || callCid == null || callCid.isEmpty) {
              await CallDebugLogger.log('[IOS_ACCEPT] ABORT: missing uuid or callCid in CallKit event payload');
              debugPrint('[VC] ⚠️ [iOS] Missing uuid/callCid in CallKit event payload');
              return;
            }

            debugPrint('[VC] 📞 [iOS] consumeIncomingCall(uuid=$uuid, cid=$callCid)...');
            final consumeResult = await client.consumeIncomingCall(uuid: uuid, cid: callCid);
            Call? acceptedCall;
            consumeResult.fold(
              success: (result) {
                acceptedCall = result.data;
              },
              failure: (error) async {
                await CallDebugLogger.log('[IOS_ACCEPT] consumeIncomingCall FAILED: $error');
              },
            );

            if (acceptedCall == null) {
              await CallDebugLogger.log('[IOS_ACCEPT] ABORT: consumeIncomingCall returned no call');
              return;
            }

            final acceptResult = await acceptedCall!.accept();
            // Log only if accept fails (reduce noise)
            if (acceptResult.isFailure) {
              await CallDebugLogger.log('[IOS_ACCEPT] accept() FAILED: $acceptResult');
            }

            _streamVideoService.setActiveCall(acceptedCall!);
            
            // IMPORTANT: On iOS lock screen, we DON'T navigate to video chat immediately.
            // The call is accepted as audio-only via CallKit.
            // User must tap the Video button in CallKit UI to open the app and enable video.
            // Store the pending call so we can navigate when video toggle is received.
            _pendingAudioCallId = acceptedCall!.id;
            _pendingAudioCall = acceptedCall;
            debugPrint('[VC] 📞 [iOS] Call accepted as audio-only. Waiting for video toggle to navigate.');
            debugPrint('[VC] 📞 [iOS] Pending audio call: $_pendingAudioCallId');
            
            // Note: Navigation will happen when:
            // 1. User taps Video button -> native sends video_toggle event -> we navigate
            // 2. App comes to foreground with pending call -> we navigate
          } catch (e) {
            debugPrint('[VC] ❌ [iOS] Error accepting via consumeIncomingCall: $e');
            await CallDebugLogger.log('[IOS_ACCEPT] ERROR consumeIncomingCall/accept: $e');
          }
        } else {
          debugPrint('[VC] ⚠️ [iOS] Could not extract call ID from event');
          await CallDebugLogger.log('[IOS_ACCEPT] ABORT: could not extract callId from CallKit event');
        }

        debugPrint('[VC] 📞 [iOS] ========== END CALL ACCEPT EVENT ==========');
      } else if (event.event == callkit.Event.actionCallDecline) {
        debugPrint('[VC] 📞 [iOS] Call DECLINE event');
        // Handle decline similar to Android
        String? callId;
        final body = event.body;
        if (body is Map) {
          final extra = body['extra'];
          if (extra is Map) {
            callId = extra['call_id'] as String?;
            if (callId == null) {
              final callCid = extra['call_cid'] as String?;
              if (callCid != null && callCid.contains(':')) {
                callId = callCid.split(':').last;
              }
            }
          }
          callId ??= body['call_id'] as String? ?? body['id'] as String?;
        }

        if (callId != null && _authService.userInfo != null) {
          if (!_streamVideoService.isInitialized) {
            await _streamVideoService.initialize(_authService.userInfo!);
          }
          await _streamVideoService.rejectIncomingCall(callId);
        }
      }

      debugPrint(
        '[VC] 📞 [iOS] ****************************************************',
      );
    });

    debugPrint('[VC] 📞 [iOS] CallKit event listener configured');
  }

  /// Set up iOS call validity handler
  /// Native iOS timer calls this to check if incoming call is still valid
  void _setupIOSCallValidityHandler() {
    debugPrint('[VC] 📞 [iOS] Setting up call validity handler');

    _iosTimerChannel.setMethodCallHandler((call) async {
      if (call.method == 'checkCallValidity') {
        final args = call.arguments as Map<dynamic, dynamic>?;
        final cid = args?['cid'] as String?;

        if (cid == null) {
          debugPrint('[VC] ⚠️ [iOS] checkCallValidity: no cid');
          return false;
        }

        debugPrint('[VC] 📞 [iOS] Checking validity for: $cid');

        // Extract call ID from cid (format: "default:callId")
        final requestedCallId = cid.split(':').length > 1 ? cid.split(':')[1] : cid;

        // If call was accepted (activeCall exists), check if it's THE SAME call
        if (_streamVideoService.hasActiveCall) {
          final activeCallId = _streamVideoService.activeCall?.id;
          if (activeCallId == requestedCallId) {
            debugPrint('[VC] 📞 [iOS] Active call matches requested cid -> valid');
            return true;
          } else {
            // Different call is active - the requested call is no longer valid
            debugPrint('[VC] 📞 [iOS] Active call ($activeCallId) != requested ($requestedCallId) -> invalid');
            return false;
          }
        }

        // If incoming call exists, check if it matches and check with server
        if (_streamVideoService.incomingCallId != null) {
          final incomingId = _streamVideoService.incomingCallId;
          if (incomingId != requestedCallId) {
            // Different incoming call - requested call is stale
            debugPrint('[VC] 📞 [iOS] Incoming call ($incomingId) != requested ($requestedCallId) -> invalid');
            return false;
          }
          
          debugPrint('[VC] 📞 [iOS] Incoming call matches, checking server...');
          try {
            final isValid = await _checkCallStillValid(cid);
            debugPrint('[VC] 📞 [iOS] Server says: $isValid');
            return isValid;
          } catch (e) {
            debugPrint('[VC] ⚠️ [iOS] Error checking server: $e');
            // On error, assume valid to avoid premature dismissal
            return true;
          }
        }

        // No incoming call and no active call -> cancelled
        debugPrint('[VC] 📞 [iOS] No call -> invalid');
        return false;
      } else if (call.method == 'isUserAuthenticated') {
        // Check if user is authenticated for VoIP push filtering
        final isAuthenticated = _authService.isAuthenticated;
        debugPrint('[VC] 📞 [iOS] isUserAuthenticated check: $isAuthenticated');
        return isAuthenticated;
      }
      return null;
    });

    debugPrint('[VC] 📞 [iOS] Call validity handler configured');
  }

  /// Set up iOS video toggle handler
  /// When user taps Video button in CallKit UI, native code notifies Flutter to open app
  void _setupIOSVideoToggleHandler() {
    debugPrint('[VC] 📞 [iOS] Setting up video toggle handler');

    _iosVideoToggleChannel.setMethodCallHandler((call) async {
      if (call.method == 'videoToggled') {
        debugPrint('[VC] 📞 [iOS] ========== VIDEO TOGGLE EVENT ==========');
        final args = call.arguments as Map<dynamic, dynamic>?;
        final callId = args?['call_id'] as String?;
        final callCid = args?['call_cid'] as String?;
        
        debugPrint('[VC] 📞 [iOS] Video toggled for call: $callId, cid: $callCid');
        
        // Navigate to video chat with the pending audio call
        if (_pendingAudioCall != null && _pendingAudioCallId != null) {
          debugPrint('[VC] 📞 [iOS] Navigating to video chat with pending call: $_pendingAudioCallId');
          
          // Prevent duplicate navigation
          if (_lastNavigatedCallId == _pendingAudioCallId) {
            debugPrint('[VC] 📞 [iOS] Already navigated to this call, skipping');
            return true;
          }
          
          _lastNavigatedCallId = _pendingAudioCallId;
          _appRouter.router.pushNamed(
            'student-video-chat',
            pathParameters: {'callId': _pendingAudioCallId!},
            queryParameters: {'callerName': 'Mentor', 'autoAccept': 'true'},
          );
          
          // Clear pending call after navigation
          _pendingAudioCallId = null;
          _pendingAudioCall = null;
        } else if (callId != null) {
          // Fallback: use callId from the event
          debugPrint('[VC] 📞 [iOS] No pending call, using callId from event: $callId');
          
          if (_lastNavigatedCallId == callId) {
            debugPrint('[VC] 📞 [iOS] Already navigated to this call, skipping');
            return true;
          }
          
          _lastNavigatedCallId = callId;
          _appRouter.router.pushNamed(
            'student-video-chat',
            pathParameters: {'callId': callId},
            queryParameters: {'callerName': 'Mentor', 'autoAccept': 'true'},
          );
        } else {
          debugPrint('[VC] ⚠️ [iOS] No pending call and no callId in event');
        }
        
        debugPrint('[VC] 📞 [iOS] ========== END VIDEO TOGGLE EVENT ==========');
        return true;
      }
      return null;
    });

    debugPrint('[VC] 📞 [iOS] Video toggle handler configured');
  }

  /// Check if call is still valid by querying Stream server
  Future<bool> _checkCallStillValid(String callCid) async {
    if (!_streamVideoService.isInitialized ||
        _streamVideoService.client == null) {
      return false;
    }

    try {
      final parts = callCid.split(':');
      final callId = parts.length > 1 ? parts[1] : callCid;

      final call = _streamVideoService.client!.makeCall(
        callType: StreamCallType.defaultType(),
        id: callId,
      );

      await call.getOrCreate();
      final state = call.state.value;
      final isValid = state.endedAt == null;

      debugPrint(
        '[VC] 📞 [iOS] Call $callId - endedAt: ${state.endedAt}, valid: $isValid',
      );
      return isValid;
    } catch (e) {
      debugPrint('[VC] ⚠️ [iOS] Error querying call: $e');
      return false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authService.removeListener(_handleAuthChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    debugPrint('🔄 App Lifecycle State: $state');

    // Stream Chat automatically manages presence based on WebSocket connection
    // When app resumes, ensure connection is active for presence
    if (state == AppLifecycleState.resumed) {
      // If secure storage was temporarily unavailable during a lock-screen wakeup,
      // retry restoring auth now that the device is unlocked/foregrounded.
      if (!_authService.isAuthenticated) {
        Future.microtask(() => _authService.refreshFromStorageIfPossible());
      }
      
      // iOS: Check if there's a pending audio call that was accepted on lock screen
      // When app comes to foreground (e.g., user taps Video button), navigate to video chat
      if (Platform.isIOS && _pendingAudioCall != null && _pendingAudioCallId != null) {
        debugPrint('[VC] 📞 [iOS] App resumed with pending audio call: $_pendingAudioCallId');
        
        if (_lastNavigatedCallId != _pendingAudioCallId) {
          debugPrint('[VC] 📞 [iOS] Navigating to video chat from app resume');
          _lastNavigatedCallId = _pendingAudioCallId;
          _appRouter.router.pushNamed(
            'student-video-chat',
            pathParameters: {'callId': _pendingAudioCallId!},
            queryParameters: {'callerName': 'Mentor', 'autoAccept': 'true'},
          );
        }
        
        // Clear pending call after navigation
        _pendingAudioCallId = null;
        _pendingAudioCall = null;
      }

      // CRITICAL: Skip if signing out
      if (_authService.isSigningOut) {
      } else if (_authService.userInfo != null &&
          _authService.userInfo!.chatGetStreamToken != null &&
          _authService.isAuthenticated) {
        // Only auto-reconnect students - mentors will reconnect when they select students
        if (_authService.userInfo!.isStudent) {
          _streamChatService.autoConnectUser(
            userId: _authService.userInfo!.id,
            token: _authService.userInfo!.chatGetStreamToken,
            userName: _authService.userInfo!.name,
            userImage: _authService.userInfo!.avatarUrl,
          );
        } else {
        }
      } else {
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
        debugPrint(
          '[VC] 📞 App resumed - checking for pending decline from background',
        );
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
        builder: (context, child) =>
            StreamChat(client: streamChatService.client, child: child!),
      );
    }

    return MaterialApp.router(
      title: 'launchgo',
      theme: themeService.themeData,
      routerConfig: _appRouter.router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) =>
          StreamChat(client: streamChatService.client, child: child!),
    );
  }
}
