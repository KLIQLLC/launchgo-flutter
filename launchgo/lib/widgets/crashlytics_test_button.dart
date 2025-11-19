import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';

class CrashlyticsTestButton extends StatelessWidget {
  const CrashlyticsTestButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        // Test Crashlytics by throwing a test exception
        FirebaseCrashlytics.instance.log("Test crash button pressed");
        FirebaseCrashlytics.instance.setCustomKey("test_key", "test_value");
        FirebaseCrashlytics.instance.setUserIdentifier("test_user_123");
        
        // Uncomment to test a crash (will crash the app!)
        // throw Exception('Test Crashlytics crash');
        
        // Record a non-fatal error for testing
        FirebaseCrashlytics.instance.recordError(
          Exception('Test non-fatal error'),
          StackTrace.current,
          reason: 'Testing Crashlytics integration',
          fatal: false,
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test error sent to Crashlytics'),
          ),
        );
      },
      child: const Text('Test Crashlytics'),
    );
  }
}