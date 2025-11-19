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
import 'package:launchgo/widgets/splash_screen.dart';
import 'package:launchgo/features/recaps/presentation/bloc/recap_bloc.dart';
import 'package:launchgo/features/recaps/data/recap_repository.dart';
import 'package:provider/provider.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

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
  late final NotificationsApiService _notificationsService;

  @override
  void initState() {
    super.initState();
    _authService = context.read<AuthService>();
    _streamChatService = context.read<StreamChatService>();
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
    
    // Add app lifecycle observer
    WidgetsBinding.instance.addObserver(this);
    
    // Auto-connect Stream Chat for unread badge when user is authenticated
    // Only for students - mentors connect when they select a student
    _authService.addListener(() async {
      if (_authService.userInfo != null && _authService.userInfo!.getStreamToken != null) {
        // Only auto-connect students - mentors connect selectively
        if (_authService.userInfo!.isStudent) {
          await _streamChatService.autoConnectUser(
            userId: _authService.userInfo!.id,
            token: _authService.userInfo!.getStreamToken,
            userName: _authService.userInfo!.name,
            userImage: _authService.userInfo!.avatarUrl,
          );
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
            await WeeklyNotificationService.instance.initialize();
            await WeeklyNotificationService.instance.scheduleWeeklyRecapNotification(_authService.userInfo);
          });
        }
      }
    });
    
    // Try to connect immediately if already authenticated (students only)
    if (_authService.userInfo != null && 
        _authService.userInfo!.getStreamToken != null &&
        _authService.userInfo!.isStudent) {
      _streamChatService.autoConnectUser(
        userId: _authService.userInfo!.id,
        token: _authService.userInfo!.getStreamToken,
        userName: _authService.userInfo!.name,
        userImage: _authService.userInfo!.avatarUrl,
      );
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
      if (_authService.userInfo != null && _authService.userInfo!.getStreamToken != null) {
        // Only auto-reconnect students - mentors will reconnect when they select students
        if (_authService.userInfo!.isStudent) {
          _streamChatService.autoConnectUser(
            userId: _authService.userInfo!.id,
            token: _authService.userInfo!.getStreamToken,
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

