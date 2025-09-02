import 'package:flutter/material.dart';

class NotificationProvider extends ChangeNotifier {
  final List<AppNotification> _notifications = [];
  bool _stockAlertsEnabled = true;
  bool _debtRemindersEnabled = true;

  List<AppNotification> get notifications => _notifications;
  bool get stockAlertsEnabled => _stockAlertsEnabled;
  bool get debtRemindersEnabled => _debtRemindersEnabled;

  void addNotification(AppNotification notification) {
    _notifications.insert(0, notification);
    notifyListeners();
  }

  void markAsRead(String notificationId) {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      notifyListeners();
    }
  }

  void removeNotification(String notificationId) {
    _notifications.removeWhere((n) => n.id == notificationId);
    notifyListeners();
  }

  void clearAllNotifications() {
    _notifications.clear();
    notifyListeners();
  }

  void markAllAsRead() {
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
    notifyListeners();
  }

  void setStockAlertsEnabled(bool enabled) {
    _stockAlertsEnabled = enabled;
    notifyListeners();
  }

  void setDebtRemindersEnabled(bool enabled) {
    _debtRemindersEnabled = enabled;
    notifyListeners();
  }

  int get unreadCount => _notifications.where((n) => !n.isRead).length;
}

class AppNotification {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime createdAt;
  final bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.isRead = false,
  });

  AppNotification copyWith({
    String? id,
    String? title,
    String? message,
    NotificationType? type,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }

  bool get isStockNotification => type == NotificationType.lowStock;
}

enum NotificationType {
  lowStock,
  debt,
  general,
}
