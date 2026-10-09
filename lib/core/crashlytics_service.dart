// lib/core/crashlytics_service.dart
//
// Единая точка для Crashlytics.
// В debug-режиме логирует в консоль, в prod — отправляет в Firebase.

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class CrashlyticsService {
  CrashlyticsService._();

  /// Логирование события (видно в Crashlytics Logs)
  static Future<void> log(String message) async {
    if (kDebugMode) {
      debugPrint('📝 ${DateTime.now().toIso8601String()} | $message');
      return;
    }
    await FirebaseCrashlytics.instance.log(message);
  }

  /// Логирование не-фатальной ошибки
  static Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    String? reason,
    bool fatal = false,
  }) async {
    if (kDebugMode) {
      debugPrint('🔴 ${reason ?? "Error"}: $error');
      return;
    }
    await FirebaseCrashlytics.instance.recordError(
      error,
      stackTrace,
      reason: reason,
      fatal: fatal,
    );
  }

  /// ID пользователя (привязка крашей к юзеру)
  static Future<void> setUserIdentifier(String userId) async {
    if (kDebugMode) return;
    await FirebaseCrashlytics.instance.setUserIdentifier(userId);
  }

  /// Кастомный ключ для фильтрации
  static Future<void> setCustomKey(String key, String value) async {
    if (kDebugMode) return;
    await FirebaseCrashlytics.instance.setCustomKey(key, value);
  }
}
