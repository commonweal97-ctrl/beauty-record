// lib/core/analytics_service.dart
//
// Аналитика для Б-Записи (Firebase Analytics).
//
// Принцип: все методы — static, безопасные (не падают, если Firebase не готов).
// В debug-режиме события НЕ отправляются — только логируются.

import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'app_logger.dart';

class AnalyticsService {
  AnalyticsService._();

  /// Ленивый доступ к FirebaseAnalytics (безопасно, если Firebase не готов).
  static FirebaseAnalytics? get _analytics {
    if (kDebugMode) return null; // в debug не отправляем
    try {
      return FirebaseAnalytics.instance;
    } catch (_) {
      return null;
    }
  }

  static void _log(String event, [Map<String, Object>? params]) {
    if (kDebugMode) {
      AppLogger.debug('📊 [analytics] $event${params != null ? ' $params' : ''}');
    }
  }

  // ========== ПРИВЯЗКА К ЮЗЕРУ ==========

  /// Установить user_id (для сегментации).
  static Future<void> setUserId(int userId) async {
    _log('setUserId', {'user_id': userId});
    await _analytics?.setUserId(id: userId.toString());
  }

  /// Очистить user_id (при logout).
  static Future<void> clearUserId() async {
    _log('clearUserId');
    await _analytics?.setUserId(id: null);
  }

  // ========== ЭКРАНЫ ==========

  /// Просмотр экрана.
  static Future<void> logScreen(String screenName) async {
    _log('screen_view', {'screen': screenName});
    await _analytics?.logScreenView(screenName: screenName);
  }

  // ========== АВТОРИЗАЦИЯ ==========

  /// Вход (method: 'otp', 'pin', 'biometric', 'call', 'password').
  static Future<void> logLogin(String method) async {
    _log('login', {'method': method});
    await _analytics?.logLogin(loginMethod: method);
  }

  /// Регистрация.
  static Future<void> logRegistration(String method) async {
    _log('sign_up', {'method': method});
    await _analytics?.logSignUp(signUpMethod: method);
  }

  // ========== ЗАПИСИ (BOOKING) ==========

  /// Создана запись.
  static Future<void> logBookingCreated({
    required int bookingId,
    required int projectId,
    int? employeeId,
    int? serviceId,
    required String source, // 'online' | 'manual'
  }) async {
    _log('booking_created', {
      'booking_id': bookingId,
      'project_id': projectId,
      'source': source,
    });
    await _analytics?.logEvent(
      name: 'booking_created',
      parameters: {
        'booking_id': bookingId,
        'project_id': projectId,
        'employee_id': ?employeeId,
        'service_id': ?serviceId,
        'source': source,
      },
    );
  }

  /// Отмена записи.
  static Future<void> logBookingCancelled({
    required int bookingId,
    required int projectId,
    String? reason,
  }) async {
    _log('booking_cancelled', {'booking_id': bookingId});
    await _analytics?.logEvent(
      name: 'booking_cancelled',
      parameters: {
        'booking_id': bookingId,
        'project_id': projectId,
        'reason': ?reason,
      },
    );
  }

  /// Перенос записи.
  static Future<void> logBookingRescheduled({
    required int bookingId,
    required int projectId,
  }) async {
    _log('booking_rescheduled', {'booking_id': bookingId});
    await _analytics?.logEvent(
      name: 'booking_rescheduled',
      parameters: {
        'booking_id': bookingId,
        'project_id': projectId,
      },
    );
  }

  // ========== ОНЛАЙН-ЗАПИСЬ ==========

  /// Начало онлайн-записи (открыл форму).
  static Future<void> logOnlineBookingStart({required int projectId}) async {
    _log('online_booking_start', {'project_id': projectId});
    await _analytics?.logEvent(
      name: 'online_booking_start',
      parameters: {'project_id': projectId},
    );
  }

  /// Завершение онлайн-записи.
  static Future<void> logOnlineBookingComplete({
    required int projectId,
    required int bookingId,
  }) async {
    _log('online_booking_complete', {'booking_id': bookingId});
    await _analytics?.logEvent(
      name: 'online_booking_complete',
      parameters: {
        'project_id': projectId,
        'booking_id': bookingId,
      },
    );
  }

  // ========== ПРОСМОТРЫ ==========

  /// Просмотр услуги.
  static Future<void> logServiceView({
    required int serviceId,
    required String serviceName,
  }) async {
    _log('service_view', {'service_id': serviceId});
    await _analytics?.logEvent(
      name: 'service_view',
      parameters: {
        'service_id': serviceId,
        'service_name': serviceName,
      },
    );
  }

  /// Просмотр мастера.
  static Future<void> logEmployeeView({
    required int employeeId,
    required String employeeName,
  }) async {
    _log('employee_view', {'employee_id': employeeId});
    await _analytics?.logEvent(
      name: 'employee_view',
      parameters: {
        'employee_id': employeeId,
        'employee_name': employeeName,
      },
    );
  }

  // ========== ПРОЧЕЕ ==========

  /// Открытие приложения.
  static Future<void> logAppOpen() async {
    _log('app_open');
    await _analytics?.logAppOpen();
  }

  /// Поделиться (запись, услуга, мастер).
  static Future<void> logShare(
    String contentType,
    int contentId, [
    String method = 'link',
  ]) async {
    _log('share', {'type': contentType, 'id': contentId, 'method': method});
    await _analytics?.logShare(
      contentType: contentType,
      itemId: contentId.toString(),
      method: method,
    );
  }

  /// Кастомное событие.
  static Future<void> logCustom(
    String name, [
    Map<String, Object>? params,
  ]) async {
    _log(name, params);
    await _analytics?.logEvent(name: name, parameters: params);
  }
}
