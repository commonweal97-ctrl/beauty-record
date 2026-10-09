// lib/core/app_logger.dart
//
// Единая точка логирования.
// В dev — print, в prod — Crashlytics.
//
// Правила:
//   • debug   — только в debug-сборке (в release отбрасывается).
//   • info    — только в debug-сборке.
//   • warning — rate-limit 1 в 10 сек на тэг + Crashlytics.
//   • error   — Crashlytics с stackTrace.
//   • fatal   — Crashlytics с fatal=true (выделяется в отчёте).

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart' as pkg_logger;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class AppLogger {
  AppLogger._();

  /// Формат debug-сообщений
  static final pkg_logger.Logger _logger = pkg_logger.Logger(
    filter: pkg_logger.DevelopmentFilter(),
    printer: pkg_logger.PrettyPrinter(methodCount: 0, colors: false),
  );

  /// Rate-limit для warning: не чаще 1 в 10 сек на тэг.
  static const _warningThrottleSeconds = 10;
  static final Map<String, DateTime> _lastWarningAt = {};

  static bool _crashlyticsAvailable = true;

  static bool _shouldSendWarning(String tag) {
    final now = DateTime.now();
    final last = _lastWarningAt[tag];
    if (last != null &&
        now.difference(last).inSeconds < _warningThrottleSeconds) {
      return false;
    }
    _lastWarningAt[tag] = now;

    // Защита от утечки памяти
    if (_lastWarningAt.length > 100) {
      _lastWarningAt.clear();
    }
    return true;
  }

  static void _safeCrashlytics(void Function() fn) {
    if (!_crashlyticsAvailable) return;
    try {
      fn();
    } catch (_) {
      _crashlyticsAvailable = false;
    }
  }

  /// Debug — только в debug-сборке.
  static void debug(String message, [dynamic data]) {
    if (kDebugMode) {
      _logger.d(data != null ? '$message | $data' : message);
    }
  }

  /// Info — только в debug-сборке.
  static void info(String message, [dynamic data]) {
    if (kDebugMode) {
      _logger.i(data != null ? '$message | $data' : message);
    }
  }

  /// Warning — в debug print, в prod Crashlytics (с rate-limit).
  static void warning(String message, [dynamic error]) {
    if (kDebugMode) {
      _logger.w(error != null ? '$message | $error' : message);
      return;
    }

    if (_shouldSendWarning(message)) {
      _safeCrashlytics(() {
        FirebaseCrashlytics.instance.log(
          '⚠️ $message${error != null ? ' | $error' : ''}',
        );
      });
    }
  }

  /// Error — Crashlytics с stackTrace.
  static void error(
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    if (kDebugMode) {
      _logger.e(message, error: error, stackTrace: stackTrace);
      return;
    }

    if (error != null) {
      _safeCrashlytics(() {
        FirebaseCrashlytics.instance.recordError(
          error,
          stackTrace ?? StackTrace.current,
          reason: message,
          fatal: false,
        );
      });
    } else {
      _safeCrashlytics(() {
        FirebaseCrashlytics.instance.log('🔴 $message');
      });
    }
  }

  /// Fatal — всегда Crashlytics с fatal=true.
  static void fatal(
    String message,
    Object error,
    StackTrace stackTrace,
  ) {
    if (kDebugMode) {
      _logger.f(message, error: error, stackTrace: stackTrace);
      return;
    }

    _safeCrashlytics(() {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: message,
        fatal: true,
      );
    });
  }

  /// Алиас для log = debug (обратная совместимость)
  static void log(String message, [dynamic data]) => debug(message, data);
}
