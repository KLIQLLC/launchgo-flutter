import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

/// Service Locator using GetIt for dependency injection
/// This provides a more scalable DI solution compared to Provider alone
/// 
/// Example usage:
/// ```dart
/// final authService = getIt<AuthService>();
/// final apiService = getIt<ApiService>();
/// ```
final getIt = GetIt.instance;

/// Initialize all dependencies
/// Call this in main() before runApp()
Future<void> setupServiceLocator() async {
  // Core services
  getIt.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(),
  );
  
  // Services - AuthService first since ApiService depends on it
  getIt.registerLazySingleton<AuthService>(
    () => AuthService(),
  );
  
  // Network services depend on AuthService
  getIt.registerLazySingleton<ApiService>(
    () => ApiService(authService: getIt<AuthService>()),
  );
  
  // Initialize services that need it
  await getIt<AuthService>().initialize();
}

/// Extension to make GetIt available through BuildContext
/// This allows hybrid usage with Provider if needed
extension GetItExtension on dynamic {
  T get<T extends Object>() => getIt<T>();
}