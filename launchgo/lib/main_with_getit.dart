import 'package:flutter/material.dart';
import 'package:launchgo/core/di/service_locator.dart';
import 'package:launchgo/router/app_router.dart';
import 'package:launchgo/services/auth_service.dart';
import 'package:provider/provider.dart';

/// Alternative main file using GetIt for dependency injection
/// This demonstrates how to use GetIt alongside Provider for a hybrid approach
/// 
/// To use this instead of the default main.dart:
/// 1. Rename this file to main.dart
/// 2. Rename the current main.dart to main_provider_only.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize GetIt service locator
  await setupServiceLocator();
  
  runApp(
    // We still use Provider for UI state management
    // but services are now managed by GetIt
    ChangeNotifierProvider.value(
      value: getIt<AuthService>(),
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

  @override
  void initState() {
    super.initState();
    // Get AuthService from GetIt instead of Provider
    final authService = getIt<AuthService>();
    _appRouter = AppRouter(authService);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'launchgo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      routerConfig: _appRouter.router,
    );
  }
}