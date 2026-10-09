// lib/core/connectivity_service.dart
//
// Мониторинг сети для Б-Записи.
//
// Отслеживает изменения подключения (Wi-Fi, Mobile, Ethernet, None).
// При потере сети показывает красный баннер сверху через Overlay.
//
// ВАЖНО: не делаем HTTP-проверку — connectivity_plus достаточно.
// Если пользователь в метро (Mobile без интернета) — покажет "нет сети".

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import 'app_logger.dart';

class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  OverlayEntry? _overlayEntry;
  bool _isOffline = false;

  /// Инициализация — вызывается один раз из main() после runApp.
  void init() {
    _subscription =
        _connectivity.onConnectivityChanged.listen(_onChanged);
    _checkInitial();
  }

  void _onChanged(List<ConnectivityResult> results) {
    final offline = _isOfflineResult(results);
    if (offline && !_isOffline) {
      _isOffline = true;
      AppLogger.debug('📵 Нет сети');
    } else if (!offline && _isOffline) {
      _isOffline = false;
      AppLogger.debug('📶 Сеть восстановлена');
      _hide();
    }
  }

  Future<void> _checkInitial() async {
    final results = await _connectivity.checkConnectivity();
    if (_isOfflineResult(results)) {
      _isOffline = true;
      AppLogger.debug('📵 Стартовое состояние: нет сети');
    }
  }

  bool _isOfflineResult(List<ConnectivityResult> results) {
    // offline = пусто ИЛИ [none] ИЛИ [vpn] без других
    if (results.isEmpty) return true;
    if (results.length == 1 && results.first == ConnectivityResult.none) {
      return true;
    }
    return false;
  }

  bool get isOffline => _isOffline;

  /// Показать offline-баннер (вызывается из builder MaterialApp).
  Widget buildBanner(BuildContext context, Widget child) {
    return Stack(
      children: [
        child,
        if (_isOffline)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Material(
              color: Colors.transparent,
              child: SafeArea(
                bottom: false,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: const Color(0xFFD32F2F),
                  child: const Row(
                    children: [
                      Icon(Icons.wifi_off, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Нет подключения к интернету',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void dispose() {
    _subscription?.cancel();
    _hide();
  }
}
