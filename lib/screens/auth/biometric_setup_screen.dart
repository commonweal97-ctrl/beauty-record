// lib/screens/auth/biometric_setup_screen.dart
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'package:local_auth/local_auth.dart';
import '../../widgets/toast.dart';
import '../select_role_screen.dart';

class BiometricSetupScreen extends StatefulWidget {
  final int userId;

  const BiometricSetupScreen({super.key, required this.userId});

  @override
  State<BiometricSetupScreen> createState() => _BiometricSetupScreenState();
}

class _BiometricSetupScreenState extends State<BiometricSetupScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  List<BiometricType> _availableBiometrics = [];

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final types = await AuthService.getBiometricTypes();
      setState(() {
        _availableBiometrics = types;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка проверки биометрии';
      });
    }
  }

  Future<void> _setupBiometric() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final bool authenticated = await AuthService.authenticateWithBiometrics(
        'Подтвердите вход по биометрии для настройки'
      );

      if (mounted) {
        if (authenticated) {
          await AuthService.saveLogin(widget.userId, hasPin: true);
          if (!mounted) return;
          
          showToast(context, 'Вход по биометрии успешно настроен!');
          
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => SelectRoleScreen()),
            (route) => false,
          );
        } else {
          setState(() {
            _errorMessage = 'Не удалось подтвердить биометрию';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getBiometricName(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return 'Face ID';
      case BiometricType.fingerprint:
        return 'Touch ID';
      case BiometricType.iris:
        return 'Радужная оболочка глаза';
      default:
        return 'Биометрия';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Вход по биометрии'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _availableBiometrics.contains(BiometricType.face) 
                    ? Icons.face 
                    : Icons.fingerprint,
                size: 80,
                color: const Color(0xFFDD1847),
              ),
              const SizedBox(height: 24),
              Text(
                'Настройка входа по биометрии',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[900],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                _availableBiometrics.isNotEmpty
                    ? 'Используйте ${_getBiometricName(_availableBiometrics.first)} для быстрого входа'
                    : 'Биометрия недоступна на этом устройстве',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (_availableBiometrics.isNotEmpty && !_isLoading) 
                      ? _setupBiometric 
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDD1847),
                    disabledBackgroundColor: const Color(0xFFDD1847),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Настройка...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          'Настроить',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => SelectRoleScreen()),
                    (route) => false,
                  );
                },
                child: Text(
                  'Не сейчас',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}