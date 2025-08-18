import 'package:flutter/material.dart';
import 'package:launchgo/router/app_router.dart';
import 'package:launchgo/services/auth_service.dart';
import 'package:launchgo/widgets/splash_screen.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthService()..initialize(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppRouter _appRouter;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    final authService = context.read<AuthService>();
    _appRouter = AppRouter(authService);
    
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
  Widget build(BuildContext context) {
    if (_showSplash) {
      return MaterialApp(
        title: 'LaunchGo',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF5757)),
          useMaterial3: true,
        ),
        home: const SplashScreen(),
        debugShowCheckedModeBanner: false,
      );
    }

    return MaterialApp.router(
      title: 'LaunchGo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF5757)),
        useMaterial3: true,
      ),
      routerConfig: _appRouter.router,
      debugShowCheckedModeBanner: false,
    );
  }
}

