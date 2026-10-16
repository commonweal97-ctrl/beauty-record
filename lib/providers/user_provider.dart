// lib/providers/user_provider.dart
//
// Единое состояние пользователя в приложении.
//
// Использование:
//   final user = context.watch<UserProvider>().user;
//   await context.read<UserProvider>().setUser(id: 5, email: 'a@b.c');
//
// Под капотом синхронизируется с AuthService (SharedPreferences).

import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../services/auth_service.dart';
import '../core/app_logger.dart';

class UserProvider extends ChangeNotifier {
  User? _user;
  int? _lastProjectId;
  bool _isLoading = false;
  bool _isInitialized = false;

  // ========== ГЕТТЕРЫ ==========

  User? get user => _user;
  int? get lastProjectId => _lastProjectId;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;

  bool get isAuthenticated => _user != null;
  bool get isClient => _user?.role == 'client';
  bool get isBusiness => _user?.role == 'salon_owner';

  int get id => _user?.id ?? 0;
  String get email => _user?.email ?? '';
  String get phone => _user?.phone ?? '';

  // ========== ЗАГРУЗКА ==========

  /// Загружает состояние из SharedPreferences.
  /// Вызывается один раз при старте приложения.
  Future<void> load() async {
    _isLoading = true;
    notifyListeners();

    try {
      final saved = await AuthService.getSavedLogin();
      if (saved != null) {
        _user = User(
          id: saved['user_id'] as int,
          email: (saved['user_email'] ?? '') as String,
          phone: (saved['user_phone'] ?? '') as String,
          hasPin: (saved['has_pin'] ?? false) as bool,
          role: await AuthService.getLastRole(),
        );
        _lastProjectId = await AuthService.getLastProjectId();
      }
      _isInitialized = true;
      AppLogger.debug('UserProvider.load: user=$_user, projectId=$_lastProjectId');
    } catch (e) {
      AppLogger.error('UserProvider.load failed', e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ========== ОБНОВЛЕНИЕ ==========

  /// Установить пользователя (после логина / регистрации).
  Future<void> setUser({
    required int id,
    String email = '',
    bool hasPin = false,
    String? role,
    String phone = '',
  }) async {
    await AuthService.saveLogin(
      id,
      hasPin: hasPin,
      userEmail: email,
      userPhone: phone,
    );
    _user = User(id: id, email: email, phone: phone, hasPin: hasPin, role: role ?? _user?.role);
    AppLogger.debug('UserProvider.setUser: $_user');
    notifyListeners();
  }

  /// Обновить роль ('client' | 'salon_owner').
  Future<void> setRole(String role) async {
    await AuthService.saveLastRole(role);
    if (_user != null) {
      _user = _user!.copyWith(role: role);
    } else {
      _user = User(id: 0, role: role);
    }
    AppLogger.debug('UserProvider.setRole: $role');
    notifyListeners();
  }

  /// Обновить hasPin (после установки PIN).
  void setHasPin(bool hasPin) {
    if (_user != null) {
      _user = _user!.copyWith(hasPin: hasPin);
      notifyListeners();
    }
  }

  /// Обновить email (после подтверждения через OTP).
  Future<void> updateEmail(String newEmail) async {
    if (_user == null) return;
    // Сохраняем в SharedPreferences (для auto-login)
    await AuthService.saveLogin(
      _user!.id,
      hasPin: _user!.hasPin,
      userEmail: newEmail,
      userPhone: _user!.phone,
    );
    _user = _user!.copyWith(email: newEmail);
    AppLogger.debug('UserProvider.updateEmail: $newEmail');
    notifyListeners();
  }

  /// Обновить телефон (после подтверждения звонком).
  Future<void> updatePhone(String newPhone) async {
    if (_user == null) return;
    await AuthService.saveLogin(
      _user!.id,
      hasPin: _user!.hasPin,
      userEmail: _user!.email,
      userPhone: newPhone,
    );
    _user = _user!.copyWith(phone: newPhone);
    AppLogger.debug('UserProvider.updatePhone: $newPhone');
    notifyListeners();
  }

  /// Установить последний проект (для бизнеса).
  Future<void> setProjectId(int projectId) async {
    await AuthService.saveLastProjectId(projectId);
    // Дублируем в last_screen — для правильной навигации при авто-входе.
    await AuthService.saveLastScreen('business_project', projectId: projectId);
    _lastProjectId = projectId;
    AppLogger.debug('UserProvider.setProjectId: $projectId');
    notifyListeners();
  }

  // ========== ВЫХОД ==========

  /// Полный выход из аккаунта.
  Future<void> logout() async {
    await AuthService.fullLogout();
    _user = null;
    _lastProjectId = null;
    AppLogger.debug('UserProvider.logout');
    notifyListeners();
  }

  /// Очистить только данные юзера (для тестов / отладки).
  void clear() {
    _user = null;
    _lastProjectId = null;
    notifyListeners();
  }
}
