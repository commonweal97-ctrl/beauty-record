// lib/services/push_notification_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';
import '../core/app_logger.dart';

@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  AppLogger.debug('🔔 BACKGROUND HANDLER CALLED!');
  AppLogger.debug('🔔 DATA: ${message.data}');
  AppLogger.debug('🔔 NOTIFICATION: ${message.notification?.title}');

  final data = message.data;
  final title = data['title'] ?? message.notification?.title ?? 'Уведомление';
  final body = data['body'] ?? message.notification?.body ?? '';

  final localNotifications = FlutterLocalNotificationsPlugin();

  const androidInit = AndroidInitializationSettings('ic_notification');
  const iosInit = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  await localNotifications.initialize(
    settings: const InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    ),
  );

  final androidDetails = AndroidNotificationDetails(
    'manual_notifications',
    'Уведомления для отправки',
    channelDescription: 'Уведомления о необходимости ручной отправки сообщений',
    importance: Importance.high,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
    largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
    styleInformation: const BigPictureStyleInformation(
      DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
    ),
  );

  const iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  await localNotifications.show(
    id: DateTime.now().millisecondsSinceEpoch % 100000,
    title: title,
    body: body,
    notificationDetails: NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    ),
    payload: jsonEncode(data),
  );

  AppLogger.debug('🔔 BACKGROUND NOTIFICATION SHOWN');
}

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._();
  factory PushNotificationService() => _instance;
  PushNotificationService._();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  Function(int projectId, int count)? onNotificationTap;
  String? _cachedToken;

  Future<void> initialize() async {
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    const androidSettings = AndroidInitializationSettings('ic_notification');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: (response) {
        _handleNotificationTap(response.payload);
      },
    );

    String? token;
    try {
      token = await _firebaseMessaging.getToken();
      _cachedToken = token;
      AppLogger.debug('🔑 FCM TOKEN: $token');
    } catch (e) {
      AppLogger.debug('FCM token error: $e');
    }

    _firebaseMessaging.onTokenRefresh.listen(_saveFcmToken);
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleNotificationTap(message.data.toString());
    });

    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage.data.toString());
    }
  }

  Future<void> registerTokenAfterLogin() async {
    if (_cachedToken != null) {
      await _saveFcmToken(_cachedToken!);
    }
  }

  Future<void> _saveFcmToken(String token) async {
    AppLogger.debug('📤 Sending FCM token to server...');
    try {
      final result = await ApiService.post('/api/notification/register-device', {
        'token': token,
        'platform': 'android',
      });
      AppLogger.debug('📤 Server response: $result');
      if (result['success'] == true) {
        AppLogger.debug('✅ FCM token saved to server');
      } else {
        AppLogger.debug('❌ Server rejected token: ${result['message']}');
      }
    } catch (e) {
      AppLogger.debug('❌ Failed to save FCM token: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] ?? '';
    final title = data['title'] ?? message.notification?.title ?? 'Уведомление';
    final body = data['body'] ?? message.notification?.body ?? '';
    final projectId = int.tryParse(data['project_id'] ?? '0') ?? 0;
    final bookingId = int.tryParse(data['booking_id'] ?? '0') ?? 0;

    // Для client_notification показываем локальное уведомление
    if (type == 'client_notification') {
      _showLocalNotification(
        id: DateTime.now().millisecondsSinceEpoch % 100000,
        title: title,
        body: body,
        payload: jsonEncode({
          'type': type,
          'project_id': projectId,
          'booking_id': bookingId,
        }),
      );
      return;
    }

    // Остальные типы
    _showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      title: title,
      body: body,
      payload: jsonEncode({
        'type': type,
        'project_id': projectId,
        'booking_id': bookingId,
      }),
    );
  }

  void _handleNotificationTap(String? payload) {
    if (payload == null) return;
    try {
      final data = jsonDecode(payload);
      final type = data['type'] ?? '';
      final projectId = data['project_id'] ?? 0;
      final count = data['count'] ?? 0;

      if (type == 'manual_notifications') {
        onNotificationTap?.call(projectId, count);
      }
    } catch (_) {}
  }

  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'manual_notifications',
      'Уведомления для отправки',
      channelDescription: 'Уведомления о необходимости ручной отправки сообщений',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_notification',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _localNotifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: payload,
    );
  }
}