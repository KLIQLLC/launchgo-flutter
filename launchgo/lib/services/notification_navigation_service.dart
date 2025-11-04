import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'auth_service.dart';

/// Service for handling complex navigation scenarios from push notifications
class NotificationNavigationService {
  static NotificationNavigationService? _instance;
  static NotificationNavigationService get instance => _instance ??= NotificationNavigationService._();
  
  NotificationNavigationService._();

  GoRouter? _router;
  AuthService? _authService;

  /// Initialize with router and auth service
  void initialize(GoRouter router, AuthService authService) {
    _router = router;
    _authService = authService;
    debugPrint('🔔 NotificationNavigationService initialized');
  }

  /// Handle update-document notification
  /// 1. Switch to specified semester globally
  /// 2. Navigate to documents screen  
  /// 3. Scroll to specific document
  Future<void> handleUpdateDocument({
    String? semesterId,
    String? documentId,
  }) async {
    debugPrint('🔔 Handling update-document notification');
    debugPrint('🔔 SemesterId: $semesterId, DocumentId: $documentId');

    try {
      // Step 1: Switch semester globally if provided
      if (semesterId != null && _authService != null) {
        debugPrint('🔔 Switching to semester: $semesterId');
        await _authService!.selectSemester(semesterId);
        debugPrint('✅ Semester switched successfully');
        
        // Small delay to allow semester change to propagate
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // Step 2: Navigate to documents screen with scroll target
      if (_router != null) {
        final extra = <String, dynamic>{};
        if (documentId != null) {
          extra['scrollToDocumentId'] = documentId;
        }
        
        debugPrint('🔔 Navigating to documents with extra: $extra');
        if (extra.isNotEmpty) {
          _router!.go('/documents', extra: extra);
        } else {
          _router!.go('/documents');
        }
        debugPrint('✅ Navigation completed');
      } else {
        debugPrint('❌ Router not available for navigation');
      }
    } catch (e) {
      debugPrint('❌ Error handling update-document notification: $e');
    }
  }

  /// Handle update-event notification
  /// 1. Switch to specified semester globally if provided
  /// 2. Navigate to schedule screen (weekly schedule tab)
  /// 3. Scroll to specific event
  Future<void> handleUpdateEvent({
    String? semesterId,
    String? eventId,
  }) async {
    debugPrint('🔔 [TERMINATED] Handling update-event notification');
    debugPrint('🔔 [TERMINATED] SemesterId: $semesterId, EventId: $eventId');
    debugPrint('🔔 [TERMINATED] Router available: ${_router != null}');
    debugPrint('🔔 [TERMINATED] AuthService available: ${_authService != null}');

    try {
      // Wait longer for app to fully initialize when coming from terminated state
      debugPrint('🔔 [TERMINATED] Waiting for app initialization...');
      await Future.delayed(const Duration(milliseconds: 1500));
      
      // Check if services are ready
      if (_router == null || _authService == null) {
        debugPrint('❌ [TERMINATED] Services not ready, retrying...');
        await Future.delayed(const Duration(milliseconds: 1000));
      }

      // Step 1: Switch semester globally if provided
      if (semesterId != null && _authService != null) {
        debugPrint('🔔 [TERMINATED] Switching to semester: $semesterId');
        await _authService!.selectSemester(semesterId);
        debugPrint('✅ [TERMINATED] Semester switched successfully');
        
        // Small delay to allow semester change to propagate
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Step 2: Navigate to schedule screen with scroll target
      if (_router != null) {
        try {
          final currentLocation = _router!.routerDelegate.currentConfiguration.last.matchedLocation;
          debugPrint('🔔 [TERMINATED] Current route: $currentLocation');
          
          if (currentLocation == '/schedule') {
            // Already on schedule screen - need to force navigation with different approach
            debugPrint('🔔 [TERMINATED] Already on schedule screen, using replacement navigation');
            if (eventId != null) {
              // First navigate away briefly, then back with the extra data
              _router!.go('/courses'); // Navigate away
              await Future.delayed(const Duration(milliseconds: 200));
              _router!.go('/schedule', extra: {'scrollToEventId': eventId});
            }
          } else {
            // Not on schedule screen - normal navigation
            final extra = <String, dynamic>{};
            if (eventId != null) {
              extra['scrollToEventId'] = eventId;
            }
            
            debugPrint('🔔 [TERMINATED] Navigating to schedule with extra: $extra');
            if (extra.isNotEmpty) {
              _router!.go('/schedule', extra: extra);
            } else {
              _router!.go('/schedule');
            }
          }
          debugPrint('✅ [TERMINATED] Navigation completed');
        } catch (e) {
          debugPrint('❌ [TERMINATED] Router error: $e, falling back to simple navigation');
          // Fallback to simple navigation if router state is not ready
          _router!.go('/schedule', extra: eventId != null ? {'scrollToEventId': eventId} : null);
        }
      } else {
        debugPrint('❌ [TERMINATED] Router not available for navigation');
      }
    } catch (e) {
      debugPrint('❌ [TERMINATED] Error handling update-event notification: $e');
    }
  }

  /// Handle chat notification (Stream Chat)
  /// 1. Switch to the correct student based on channel_id (student ID)
  /// 2. Navigate to chat screen with channel info
  /// 
  /// Note: For Stream Chat, receiver_id is the mentor ID, channel_id is the student ID
  Future<void> handleChatNotification({
    String? receiverId,
    String? channelId,
    String? channelType,
  }) async {
    debugPrint('🔔 [CHAT] ReceiverId (mentor): $receiverId, ChannelId (student): $channelId');

    try {
      // Wait for app to fully initialize when coming from terminated state
      debugPrint('🔔 [CHAT] Waiting for app initialization...');
      await Future.delayed(const Duration(milliseconds: 1500));
      
      // Check if services are ready
      if (_router == null || _authService == null) {
        debugPrint('❌ [CHAT] Services not ready, retrying...');
        await Future.delayed(const Duration(milliseconds: 1000));
      }

      // Step 1: Switch to the correct student if channelId is provided
      // For Stream Chat, channel_id contains the student ID who sent the message
      if (channelId != null && _authService != null) {
        debugPrint('🔔 [CHAT] Switching to student with ID: $channelId');
        await _authService!.selectStudent(channelId);
        debugPrint('✅ [CHAT] Student switched successfully');
        
        // Small delay to allow student change to propagate
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Step 2: Navigate to chat screen with channel info
      if (_router != null) {
        final extra = <String, dynamic>{};
        if (channelId != null) {
          extra['channelId'] = channelId;
          extra['channelType'] = channelType ?? 'messaging';
        }
        
        debugPrint('🔔 [CHAT] Navigating to chat with extra: $extra');
        try {
          if (extra.isNotEmpty) {
            _router!.go('/chat', extra: extra);
          } else {
            _router!.go('/chat');
          }
        } catch (e) {
          // Fallback to simple navigation if router state is not ready
          _router!.go('/chat');
        }
      } else {
        debugPrint('❌ [CHAT] Router not available for navigation');
      }
    } catch (e) {
      debugPrint('❌ [CHAT] Error handling chat notification: $e');
    }
  }

  /// Handle other notification types (expandable)
  Future<void> handleNotification({
    required String eventType,
    required Map<String, dynamic> data,
  }) async {
    debugPrint('🔔 Handling notification type: $eventType');
    
    switch (eventType) {
      case 'update-document':
        await handleUpdateDocument(
          semesterId: data['semesterId'],
          documentId: data['documentId'],
        );
        break;
      
      case 'update-event':
        await handleUpdateEvent(
          semesterId: data['semesterId'],
          eventId: data['eventId'],
        );
        break;
      
      case 'create-document':
        // Use same navigation as update-document (semester switching + documents screen)
        await handleUpdateDocument(
          semesterId: data['semesterId'],
          documentId: data['documentId'],
        );
        break;
        
      case 'update-assignment':
      case 'create-assignment':
        // Navigate to specific course assignments
        if (data['courseId'] != null) {
          _router?.go('/course/${data['courseId']}/assignments');
        }
        break;
        
      case 'upload-attachment':
        // Navigate to course assignments and scroll to specific assignment
        if (data['assignmentId'] != null && data['courseId'] != null) {
          // Switch context if needed
          if (data['semesterId'] != null || data['studentId'] != null) {
            await _switchContextIfNeeded(data['semesterId'], data['studentId']);
          }
          
          // Build URL with query parameters for scroll-to-assignment
          String url = '/course/${data['courseId']}/assignments?scrollToAssignmentId=${data['assignmentId']}';
          List<String> queryParams = ['scrollToAssignmentId=${data['assignmentId']}'];
          
          // Add cell/line/section parameters if available
          if (data['cellId'] != null) {
            queryParams.add('cellId=${data['cellId']}');
          }
          if (data['lineNumber'] != null) {
            queryParams.add('line=${data['lineNumber']}');
          }
          if (data['sectionId'] != null) {
            queryParams.add('section=${data['sectionId']}');
          }
          
          url = '/course/${data['courseId']}/assignments?${queryParams.join('&')}';
          _router?.go(url);
        } else {
          // Fallback to courses if no specific assignment/course data
          _router?.go('/courses');
        }
        break;
        
      case 'create-course':
        // Navigate to courses screen
        _router?.go('/courses');
        break;
        
      case 'create-event':
        // Navigate to schedule screen
        _router?.go('/schedule');
        break;
        
      default:
        debugPrint('🔔 Unknown notification type: $eventType');
    }
  }

  /// Switch semester and student context if needed before navigation
  Future<void> _switchContextIfNeeded(String? semesterId, String? studentId) async {
    if (_authService == null) return;
    
    bool contextChanged = false;
    
    try {
      // Switch student if needed (for mentors)
      if (studentId != null && 
          _authService!.isMentor && 
          _authService!.selectedStudentId != studentId) {
        debugPrint('🔄 Switching to student: $studentId');
        await _authService!.selectStudent(studentId);
        contextChanged = true;
      }
      
      // Switch semester if needed
      if (semesterId != null && 
          _authService!.selectedSemesterId != semesterId) {
        debugPrint('🔄 Switching to semester: $semesterId');
        await _authService!.selectSemester(semesterId);
        contextChanged = true;
      }
      
      // Wait for auth service state to propagate if context changed
      if (contextChanged) {
        debugPrint('📍 Context switched, waiting for state propagation...');
        // Wait for the next frame to ensure notifyListeners() has been processed
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Verify the context has actually changed
        bool contextApplied = true;
        if (studentId != null && _authService!.isMentor) {
          contextApplied = contextApplied && _authService!.selectedStudentId == studentId;
        }
        if (semesterId != null) {
          contextApplied = contextApplied && _authService!.selectedSemesterId == semesterId;
        }
        
        if (!contextApplied) {
          debugPrint('⚠️ Context change not fully applied, waiting longer...');
          // Fallback: wait a bit longer if state hasn't propagated
          await Future.delayed(const Duration(milliseconds: 200));
        }
        
        debugPrint('✅ Context switching complete');
      }
    } catch (e) {
      debugPrint('❌ Error switching context: $e');
      // Continue with navigation even if context switch fails
    }
  }
}