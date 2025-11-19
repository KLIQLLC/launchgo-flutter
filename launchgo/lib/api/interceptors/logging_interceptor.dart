import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      final requestLog = StringBuffer();
      requestLog.writeln('╔══════════════════════════════════════════════════════════════');
      requestLog.writeln('║ 🚀 REQUEST');
      requestLog.writeln('╟──────────────────────────────────────────────────────────────');
      requestLog.writeln('║ ${options.method} ${options.uri}');
      requestLog.writeln('╟──────────────────────────────────────────────────────────────');
      requestLog.writeln('║ Headers:');
      options.headers.forEach((key, value) {
        if (key != 'Authorization' || !value.toString().contains('Bearer')) {
          requestLog.writeln('║   $key: $value');
        } else {
          // Mask the token for security
          requestLog.writeln('║   $key: Bearer [MASKED]');
        }
      });
      
      if (options.data != null) {
        requestLog.writeln('╟──────────────────────────────────────────────────────────────');
        requestLog.writeln('║ Body:');
        try {
          final formatted = const JsonEncoder.withIndent('  ').convert(options.data);
          formatted.split('\n').forEach((line) {
            requestLog.writeln('║ $line');
          });
        } catch (e) {
          requestLog.writeln('║ ${options.data}');
        }
      }
      
      requestLog.writeln('╚══════════════════════════════════════════════════════════════');
      debugPrint(requestLog.toString());
    }
    
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      final responseLog = StringBuffer();
      responseLog.writeln('╔══════════════════════════════════════════════════════════════');
      responseLog.writeln('║ ✅ RESPONSE');
      responseLog.writeln('╟──────────────────────────────────────────────────────────────');
      responseLog.writeln('║ Status: ${response.statusCode} ${response.statusMessage}');
      responseLog.writeln('║ ${response.requestOptions.method} ${response.requestOptions.uri}');
      
      if (response.data != null) {
        responseLog.writeln('╟──────────────────────────────────────────────────────────────');
        responseLog.writeln('║ Data:');
        try {
          final formatted = const JsonEncoder.withIndent('  ').convert(response.data);
          formatted.split('\n').forEach((line) {
            responseLog.writeln('║ $line');
          });
        } catch (e) {
          responseLog.writeln('║ ${response.data}');
        }
      }
      
      responseLog.writeln('╚══════════════════════════════════════════════════════════════');
      debugPrint(responseLog.toString());
    }
    
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      final errorLog = StringBuffer();
      errorLog.writeln('╔══════════════════════════════════════════════════════════════');
      errorLog.writeln('║ ❌ ERROR');
      errorLog.writeln('╟──────────────────────────────────────────────────────────────');
      errorLog.writeln('║ Status: ${err.response?.statusCode}');
      errorLog.writeln('║ ${err.requestOptions.method} ${err.requestOptions.uri}');
      errorLog.writeln('║ Message: ${err.message}');
      
      if (err.response?.data != null) {
        errorLog.writeln('╟──────────────────────────────────────────────────────────────');
        errorLog.writeln('║ Response:');
        try {
          final formatted = const JsonEncoder.withIndent('  ').convert(err.response?.data);
          formatted.split('\n').forEach((line) {
            errorLog.writeln('║ $line');
          });
        } catch (e) {
          errorLog.writeln('║ ${err.response?.data}');
        }
      }
      
      errorLog.writeln('╚══════════════════════════════════════════════════════════════');
      debugPrint(errorLog.toString());
    }
    
    super.onError(err, handler);
  }
}