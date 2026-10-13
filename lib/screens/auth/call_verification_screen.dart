// lib/screens/auth/call_verification_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../select_role_screen.dart';
import '../auth/pin_setup_screen.dart';

class CallVerificationScreen extends StatefulWidget {
  final String phone;
  final int userId;
  final String email;
  final bool isRegistration;
  final String firstName;
  final String lastName;

  const CallVerificationScreen({
    super.key,
    required this.phone,
    required this.userId,
    this.email = '',
    this.isRegistration = false,
    this.firstName = '',
    this.lastName = '',
  });

  @override
  State<CallVerificationScreen> createState() => _CallVerificationScreenState();
}

class _CallVerificationScreenState extends State<CallVerificationScreen> {
  Timer? _checkTimer;
  Timer? _countdownTimer;
  Timer? _verifyCountdownTimer;
  bool _isWaiting = false;
  bool _isChecking = false;
  bool _isConfirmed = false;
  bool _isVerifying = false;
  String? _error;
  int _secondsLeft = 300;
  int _verifySecondsLeft = 30;

  @override
  void initState() {
    super.initState();
    
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startChecking();
      _startCountdown();
    });
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    _countdownTimer?.cancel();
    _verifyCountdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _secondsLeft = 300;
    
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          timer.cancel();
          _isWaiting = false;
        }
      });
    });
  }

  void _startChecking() {
    setState(() {
      _isWaiting = true;
      _error = null;
    });

    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      await _checkVerification();
    });
  }

  String get _verifyTimerText {
    final s = _verifySecondsLeft.toString().padLeft(2, '0');
    return '00:$s';
  }

  String get _timerText {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _checkVerification() async {
    if (_isChecking || _isConfirmed) return;
    _isChecking = true;

    try {
      final result = await ApiService.get(
        '/api/auth/check-call-verification?phone=${Uri.encodeComponent(widget.phone)}',
        forceRefresh: true,
      );

      if (result['success'] == true && result['verified'] == true && mounted) {
        _checkTimer?.cancel();
        _countdownTimer?.cancel();
        _verifyCountdownTimer?.cancel();
        setState(() {
          _isWaiting = false;
          _isConfirmed = true;
        });

        // Даём overlay показаться (UX как в Б-Роща)
        await Future.delayed(const Duration(milliseconds: 1200));

        await _performLogin();
      }
    } catch (_) {
    } finally {
      _isChecking = false;
    }
  }

  Future<void> _performLogin() async {
    debugPrint('CV: _performLogin START');
    try {
      if (widget.isRegistration) {
        await _registerByCall();
        return;
      }

      // Существующий пользователь
      debugPrint('CV: POST /api/auth/login-by-call user_id=${widget.userId}');
      final result = await ApiService.post(
        '/api/auth/login-by-call',
        {'user_id': widget.userId},
      );
      debugPrint('CV: login-by-call result = $result');
      final token = result['remember_token'] ?? '';

      if (token.isNotEmpty) {
        if (!mounted) return;
      await context.read<UserProvider>().setUser(
        id: widget.userId,
        hasPin: true,
        email: widget.email,
      );
      }

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => SelectRoleScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Ошибка входа');
      }
    }
  }

  Future<void> _registerByCall() async {
    try {
      final result = await ApiService.post('/api/auth/register-by-call', {
        'phone': widget.phone,
        'email': widget.email,
        'first_name': widget.firstName,
        'last_name': widget.lastName,
      });

      if (result['success'] == true) {
        final userId = result['data']['user_id'] ?? 0;
        final token = result['remember_token'] ?? '';

        if (token.isNotEmpty) {
          if (!mounted) return;
      await context.read<UserProvider>().setUser(
        id: userId,
        hasPin: false,
        email: widget.email,
      );
        }

        if (mounted && userId > 0) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => PinSetupScreen(userId: userId)),
            (route) => false,
          );
        }
      } else {
        if (mounted) {
          setState(() => _error = result['message'] ?? 'Ошибка регистрации');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Ошибка соединения');
      }
    }
  }

  Future<void> _callNumber() async {
    // UX как в Б-Роща: overlay "Проверяем ваш номер" + таймер 30 сек
    setState(() {
      _isVerifying = true;
      _isWaiting = false;
      _verifySecondsLeft = 30;
    });

    _verifyCountdownTimer?.cancel();
    _verifyCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        if (_verifySecondsLeft > 0) {
          _verifySecondsLeft--;
        } else {
          timer.cancel();
          _isVerifying = false;
        }
      });
    });

    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      await _checkVerification();
    });

    final uri = Uri.parse('tel:+79803043674');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
            const Spacer(),
            
            // Иконка
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _isConfirmed ? const Color(0xFFE8F5E9) : const Color(0xFFFDF2F5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isConfirmed ? Icons.check_circle : Icons.phone_callback,
                size: 40,
                color: _isConfirmed ? const Color(0xFF2E7D32) : const Color(0xFFDD1847),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Заголовок
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: Text(
                _isConfirmed ? 'Номер подтвержден' : 'Позвоните по номеру',
                key: ValueKey(_isConfirmed),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _isConfirmed ? const Color(0xFF2E7D32) : const Color(0xFF1A1A1A),
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Подзаголовок
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: Text(
                _isConfirmed ? 'Вход выполняется...' : 'Звонок будет сброшен автоматически\nи вход выполнится',
                key: ValueKey(_isConfirmed),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: _isConfirmed ? const Color(0xFF2E7D32) : const Color(0xFF666666),
                  height: 1.4,
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Номер телефона
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              decoration: BoxDecoration(
                color: _isConfirmed ? const Color(0xFFE8F5E9) : const Color(0xFFFDF2F5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '+7 (980) 304-36-74',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _isConfirmed ? const Color(0xFF2E7D32) : const Color(0xFFDD1847),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Статус
            if (_isWaiting) ...[
              Text(
                'Ожидание звонка: $_timerText',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF666666),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ),
            
            const Spacer(),
            
            // Кнопка "Позвонить"
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _callNumber,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDD1847),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Позвонить',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Кнопка "Назад"
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Назад',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
            
                const SizedBox(height: 24),
              ],
            ),
            // Overlay "Проверяем ваш номер" — UX как в Б-Роща
            if (_isVerifying || _isConfirmed)
              Positioned.fill(
                child: Container(
                  color: Colors.white,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: Stack(
                          children: [
                            const Positioned.fill(
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Color(0xFFDD1847),
                              ),
                            ),
                            const Center(
                              child: Icon(
                                Icons.phone_in_talk,
                                size: 32,
                                color: Color(0xFFDD1847),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'Проверяем ваш номер',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.phone,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF666666),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _verifyTimerText,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFDD1847),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Ожидайте подтверждения звонка',
                        style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}