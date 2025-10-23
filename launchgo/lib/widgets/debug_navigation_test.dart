import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/pending_navigation_service.dart';

/// Debug widget to test navigation without push notifications
/// Remove this in production
class DebugNavigationTest extends StatelessWidget {
  const DebugNavigationTest({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        border: Border.all(color: Colors.orange),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'DEBUG: Test Navigation',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Simulator doesn\'t support push notifications.\nUse these buttons to test navigation:',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTestButton('Documents', '/documents'),
              _buildTestButton('Courses', '/courses'),
              _buildTestButton('Chat', '/chat'),
              _buildTestButton('Recaps', '/recaps'),
              _buildTestButton('Notifications', '/notifications'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTestButton(String label, String route) {
    return Builder(
      builder: (context) => ElevatedButton(
        onPressed: () {
          debugPrint('🧪 [V3] Direct navigation to: $route');
          // Test direct navigation without pending service
          context.go(route);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }
}