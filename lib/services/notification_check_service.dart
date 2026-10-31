// lib/services/notification_check_service.dart
import 'dart:async';
import 'api_service.dart';
import '../screens/business/manual_notification_sheet.dart';
import 'package:flutter/material.dart';

class NotificationCheckService {
  static final NotificationCheckService _instance = NotificationCheckService._();
  factory NotificationCheckService() => _instance;
  NotificationCheckService._();

  Timer? _checkTimer;
  bool _isChecking = false;
  bool _isSheetOpen = false;

  BuildContext? _context;
  int? _currentProjectId;

  void updateContext(BuildContext context, int projectId) {
    _context = context;
    _currentProjectId = projectId;
  }

  void startPeriodicCheck({Duration interval = const Duration(seconds: 30)}) {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(interval, (_) => checkForNewNotifications());
    checkForNewNotifications();
  }

  void stopPeriodicCheck() {
    _checkTimer?.cancel();
  }

  void onSheetClosed() {
    _isSheetOpen = false;
  }

  Future<bool> checkForNewNotifications() async {
    if (_isChecking || _context == null || _currentProjectId == null) return false;
    if (_isSheetOpen) return false;
    
    _isChecking = true;

    try {
      final r = await ApiService.get(
        '/api/notification/list?project_id=$_currentProjectId',
      );

      if (r['success'] == true && _context != null && _context!.mounted) {
        final items = List<Map<String, dynamic>>.from(r['data'] ?? []);
        if (items.isNotEmpty) {
          _isSheetOpen = true;
          showModalBottomSheet(
            context: _context!,
            isScrollControlled: true,
            useSafeArea: true,
            isDismissible: false,
            enableDrag: false,
            backgroundColor: Colors.transparent,
            builder: (_) => ManualNotificationSheet(
              projectId: _currentProjectId!,
              onComplete: () {
                _isSheetOpen = false;
                Future.delayed(const Duration(milliseconds: 500), () {
                  checkForNewNotifications();
                });
              },
            ),
          ).then((_) {
            _isSheetOpen = false;
            Future.delayed(const Duration(milliseconds: 500), () {
              checkForNewNotifications();
            });
          });
          _isChecking = false;
          return true;
        }
      }
    } catch (e) { debugPrint('API error: $e'); }

    _isChecking = false;
    return false;
  }
}