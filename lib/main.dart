// lib/main.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/api_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/select_role_screen.dart';
import 'screens/client/client_dashboard_screen.dart';
import 'screens/business/business_dashboard_screen.dart';
import 'screens/auth/pin_setup_screen.dart';
import 'screens/auth/biometric_setup_screen.dart';
import 'services/push_notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/app_logger.dart';
import 'core/app_colors.dart';
import 'core/app_typography.dart';
import 'core/crashlytics_service.dart';
import 'core/analytics_service.dart';
import 'providers/user_provider.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initializeDateFormatting('ru');
  
  FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
  
  try {
    await Firebase.initializeApp(
      name: 'BeautyRecordApp',
      options: const FirebaseOptions(
        apiKey: "AIzaSyDH9r7X92mEIY5ZyUbYrTzemcL44q5Vaao",
        authDomain: "beauty-rosha.firebaseapp.com",
        databaseURL: "https://beauty-rosha-default-rtdb.firebaseio.com",
        projectId: "beauty-rosha",
        storageBucket: "beauty-rosha.firebasestorage.app",
        messagingSenderId: "105056061241",
        appId: "1:105056061241:ios:765803191900f34b790ae8",
        measurementId: "G-Z2N51YVMLH",
      ),
    );

    // ========== CRASHLYTICS ==========
    // 1. Перехват ошибок Flutter framework
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      // Логируем в Crashlytics (в release)
      CrashlyticsService.recordError(
        details.exception,
        details.stack ?? StackTrace.current,
        reason: 'FlutterError: ${details.context}',
        fatal: true,
      );
    };

    // 2. Перехват асинхронных ошибок (вне Flutter zone)
    PlatformDispatcher.instance.onError = (error, stack) {
      CrashlyticsService.recordError(
        error,
        stack,
        reason: 'PlatformDispatcher.onError',
        fatal: true,
      );
      return true;
    };

    AppLogger.info('Crashlytics подключён');

    // ========== ANALYTICS ==========
    await AnalyticsService.logAppOpen();
    AppLogger.info('Analytics подключён');
  } catch (e) {
    AppLogger.debug('Firebase error: $e');
  }

  final pushService = PushNotificationService();
  pushService.initialize();
  pushService.onNotificationTap = (projectId, count) {
    AppLogger.debug('Push tap: project=$projectId, count=$count');
  };
  await ApiService.init();
  runApp(
    ChangeNotifierProvider(
      create: (_) => UserProvider()..load(),
      child: const BeautyRecordApp(),
    ),
  );
}

class BeautyRecordApp extends StatelessWidget {
  const BeautyRecordApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Б-Запись',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ru'),
      supportedLocales: const [
        Locale('ru'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        fontFamily: 'Inter',
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFDD1847),
          secondary: Color(0xFFDD1847),
          surface: Colors.white,
        ),
        extensions: const [
          AppColors.light,
        ],
        textTheme: const TextTheme(
          // Заголовки
          displayLarge: AppTypography.h0,
          displayMedium: AppTypography.h1,
          displaySmall: AppTypography.h2,
          headlineMedium: AppTypography.h3,
          headlineSmall: AppTypography.h4,
          // Тело
          bodyLarge: AppTypography.bodyLarge,
          bodyMedium: AppTypography.bodyMedium,
          bodySmall: AppTypography.bodySmall,
          // Подписи
          labelLarge: AppTypography.buttonMedium,
          labelMedium: AppTypography.caption,
          labelSmall: AppTypography.label,
        ),
        useMaterial3: false,
      ),
      // Глобальное скрытие клавиатуры при тапе по свободному месту.
      // HitTestBehavior.translucent — тап проходит к детям (кнопки, поля),
      // но onTap всё равно срабатывает: если тап был НЕ по интерактивному
      // элементу — клавиатура закрывается. Работает на ВСЕХ экранах,
      // включая будущие, без правок в отдельных виджетах.
      builder: (context, child) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: child ?? const SizedBox.shrink(),
        );
      },
      initialRoute: '/',
      routes: {
        '/': (_) => const LoginScreen(),
        '/home': (_) => SelectRoleScreen(),
        '/client': (_) => const ClientDashboardScreen(),
        '/business': (_) => const BusinessDashboardScreen(),
        '/pin-setup': (_) => PinSetupScreen(userId: 0),
        '/biometric-setup': (_) => BiometricSetupScreen(userId: 0),
      },
    );
  }
}