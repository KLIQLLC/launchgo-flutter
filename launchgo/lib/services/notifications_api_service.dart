import 'package:flutter/foundation.dart';
import 'package:launchgo/models/notification_model.dart';
import 'package:launchgo/services/api_service.dart';

class NotificationsApiService extends ChangeNotifier {
  final ApiService _apiService;
  
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _error;
  
  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  NotificationsApiService({required ApiService apiService}) 
      : _apiService = apiService;

  /// Fetch notifications from the API
  Future<void> fetchNotifications() async {
    _isLoading = true;
    _error = null;
    _safeNotifyListeners();

    try {
      final response = await _apiService.get('/users/me/notifications');
      
      List<NotificationModel> fetchedNotifications = [];
      
      // Handle different response formats
      if (response is Map<String, dynamic>) {
        // If response has a 'data' field with array
        if (response['data'] != null && response['data'] is List) {
          fetchedNotifications = (response['data'] as List)
              .map((json) => NotificationModel.fromJson(json))
              .toList();
        }
        // If response has 'notifications' field
        else if (response['notifications'] != null && response['notifications'] is List) {
          fetchedNotifications = (response['notifications'] as List)
              .map((json) => NotificationModel.fromJson(json))
              .toList();
        }
        // Single notification response, wrap in array
        else {
          fetchedNotifications = [NotificationModel.fromJson(response)];
        }
      } else if (response is List) {
        // Direct array response
        fetchedNotifications = response
            .map((json) => NotificationModel.fromJson(json))
            .toList();
      }
      
      // Sort notifications by creation date (newest first)
      fetchedNotifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      _notifications = fetchedNotifications;
      _error = null;
    } catch (e) {
      _error = e.toString();
      _notifications = [];
      debugPrint('Error fetching notifications: $e');
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      // Make API call to mark all as read
      await _apiService.put('/users/me/notifications/all/read', {});
      
      // Update local state
      _notifications = _notifications
          .map((notification) => notification.copyWith(isRead: true))
          .toList();
      
      _safeNotifyListeners();
    } catch (e) {
      debugPrint('Error marking notifications as read: $e');
      rethrow;
    }
  }

  /// Mark a specific notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      // Make API call to mark specific notification as read
      await _apiService.put('/users/me/notifications/$notificationId/read', {});
      
      // Update local state
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
        _safeNotifyListeners();
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      rethrow;
    }
  }

  /// Clear all notifications (local only)
  void clearNotifications() {
    _notifications = [];
    _error = null;
    _safeNotifyListeners();
  }

  /// Refresh notifications (alias for fetchNotifications)
  Future<void> refresh() => fetchNotifications();

  /// Safely notify listeners to avoid framework lock issues
  void _safeNotifyListeners() {
    if (!hasListeners) return;
    
    try {
      notifyListeners();
    } catch (e) {
      // If notifyListeners fails due to framework lock, schedule it for next microtask
      Future.microtask(() {
        if (hasListeners) {
          notifyListeners();
        }
      });
    }
  }
}