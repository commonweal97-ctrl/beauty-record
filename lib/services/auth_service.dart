// lib/services/auth_service.dart
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static final LocalAuthentication _localAuth = LocalAuthentication();

  // Биометрия
  static Future<bool> authenticateWithBiometrics(String reason) async {
    try {
      final bool canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      
      if (!canAuthenticateWithBiometrics) {
        throw 'Биометрия недоступна на этом устройстве';
      }

      final List<BiometricType> availableBiometrics = 
          await _localAuth.getAvailableBiometrics();
      
      if (availableBiometrics.isEmpty) {
        throw 'Биометрические данные не настроены';
      }

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason,
      );

      return didAuthenticate;
    } on PlatformException catch (e) {
      throw 'Ошибка биометрии: ${e.message}';
    }
  }

  static Future<bool> hasBiometrics() async {
    try {
      final bool canCheck = await _localAuth.canCheckBiometrics;
      final List<BiometricType> availableBiometrics = 
          await _localAuth.getAvailableBiometrics();
      return canCheck && availableBiometrics.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  static Future<List<BiometricType>> getBiometricTypes() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveLogin(
    int userId, {
    bool hasPin = false,
    String userEmail = '',
    String userPhone = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_id', userId);
    await prefs.setBool('has_pin', hasPin);
    await prefs.setString('user_email', userEmail);
    await prefs.setString('user_phone', userPhone);
    // Сбрасываем флаг выхода при новом входе
    await prefs.setBool('logged_out', false);
  }

  static Future<Map<String, dynamic>?> getSavedLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId == null) return null;
    
    return {
      'user_id': userId,
      'has_pin': prefs.getBool('has_pin') ?? false,
      'user_email': prefs.getString('user_email') ?? '',
      'user_phone': prefs.getString('user_phone') ?? '',
    };
  }

  // Сохранение remember_token
  static Future<void> saveRememberToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('remember_token', token);
    // Не сбрасываем logged_out здесь, так как это может быть автологин
  }

  // Получение remember_token
  static Future<String?> getRememberToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('remember_token');
  }

  // Проверка, был ли пользователь вышел намеренно
  static Future<bool> wasLoggedOut() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('logged_out') ?? false;
  }

  // Очистка состояния входа
  static Future<void> clearLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('has_pin');
    await prefs.remove('user_email');
    await prefs.remove('user_phone');
    await prefs.remove('remember_token');
    await prefs.remove('saved_cookies');
    // Устанавливаем флаг, что пользователь вышел намеренно
    await prefs.setBool('logged_out', true);
  }
  
  // Полная очистка всех данных авторизации
  static Future<void> fullLogout() async {
    await clearLogin();
    // Дополнительно очищаем все возможные данные
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('biometric_enabled');
    await prefs.remove('biometric_user_id');
    // Навигационное состояние — чтобы при следующем входе не перекинуло
    // на удалённый проект или старую роль (баг: заходило в project_id,
    // которого уже нет).
    await prefs.remove('last_role');
    await prefs.remove('last_project_id');
    await prefs.remove('last_screen');
    await prefs.remove('last_screen_project_id');
  }

  // Сохранение последнего выбранного режима
  static Future<void> saveLastRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_role', role);
  }

  // Получение последнего выбранного режима
  static Future<String?> getLastRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_role');
  }

  // Сохранение последнего выбранного проекта
  static Future<void> saveLastProjectId(int projectId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_project_id', projectId);
  }

  // Получение последнего выбранного проекта
  static Future<int?> getLastProjectId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('last_project_id');
  }

  // ========== ПОСЛЕДНИЙ ЭКРАН ==========
  //
  // last_screen = 'select_role' | 'client' | 'business' | 'business_project'
  // last_screen_project_id = int (только для business_project)

  /// Сохранить последний экран, на котором был пользователь.
  /// Используется при авто-входе, чтобы вернуть пользователя туда же.
  static Future<void> saveLastScreen(String screen, {int? projectId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_screen', screen);
    if (projectId != null) {
      await prefs.setInt('last_screen_project_id', projectId);
    } else {
      await prefs.remove('last_screen_project_id');
    }
  }

  static Future<String?> getLastScreen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_screen');
  }

  static Future<int?> getLastScreenProjectId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('last_screen_project_id');
  }
}