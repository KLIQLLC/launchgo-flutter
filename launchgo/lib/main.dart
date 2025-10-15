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
import 'package:launchgo/services/theme_service.dart';
import 'package:launchgo/services/chat/stream_chat_service.dart';
import 'package:launchgo/services/notification_service.dart';
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
  
  // Initialize push notifications lazily (won't block app startup)
  NotificationService.instance.initialize().catchError((e) {
    debugPrint('❌ Notification service initialization failed: $e');
  });
  
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
        ChangeNotifierProvider.value(value: NotificationService.instance),
        Provider(
          create: (context) => ApiServiceRetrofit(
            authService: context.read<AuthService>(),
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

  @override
  void initState() {
    super.initState();
    _authService = context.read<AuthService>();
    _streamChatService = context.read<StreamChatService>();
    _appRouter = AppRouter(_authService);
    
    // Set StreamChatService reference in AuthService for presence management
    _authService.setStreamChatService(_streamChatService);
    
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

