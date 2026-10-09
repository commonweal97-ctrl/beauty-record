// lib/utils/app_logger.dart
//
// Единая точка логирования для приложения Б-Запись.
// Заменяет прямые print() вызовы.
//
// В release-сборке debug/info не выводятся — только warning/error.
// Позже можно добавить отправку error в Sentry.

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

class AppLogger {
  AppLogger._();

  static final Logger _logger = Logger(
    filter: _AppLogFilter(),
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 120,
      colors: false,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  /// Debug-сообщения: видны только в debug-сборке
  static void debug(String message, [dynamic data]) {
    _logger.d(message, error: data);
  }

  /// Info: значимые события (запуск, переходы)
  static void info(String message, [dynamic data]) {
    _logger.i(message, error: data);
  }

  /// Warning: что-то не так, но не критично
  static void warning(String message, [dynamic data]) {
    _logger.w(message, error: data);
  }

  /// Error: исключения, сбои
  static void error(
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// Заменяет print() — короткая форма для debug
  static void log(String message, [dynamic data]) {
    debug(message, data);
  }
}

/// Фильтр: в release — только warning и error
class _AppLogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    if (kReleaseMode) {
      return event.level.index >= Level.warning.index;
    }
    return true;
  }
}
