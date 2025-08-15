import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import '../../api/api_service.dart';
import '../../api/dio_client.dart';
import '../../services/auth_service.dart';
import '../../services/secure_storage_service.dart';

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
  
  // Network
  getIt.registerLazySingleton<Dio>(
    () => DioClient.createDio(),
  );
  
  getIt.registerLazySingleton<ApiService>(
    () => ApiService(getIt<Dio>()),
  );
  
  // Services - AuthService needs ApiService injected
  getIt.registerLazySingleton<AuthService>(
    () => AuthService()..setApiService(getIt<ApiService>()),
  );
  
  // Initialize services that need it
  await getIt<AuthService>().initialize();
}

/// Extension to make GetIt available through BuildContext
/// This allows hybrid usage with Provider if needed
extension GetItExtension on dynamic {
  T get<T extends Object>() => getIt<T>();
}