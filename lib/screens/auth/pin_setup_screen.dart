// lib/screens/auth/pin_setup_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../auth/biometric_setup_screen.dart';

class PinSetupScreen extends StatefulWidget {
  final int userId;
  const PinSetupScreen({super.key, required this.userId});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String _pin = '';
  String _firstPin = '';
  bool _isConfirming = false;
  String? _error;
  String? _pressedKey;

  void _onKeyPressed(String key) {
    HapticFeedback.lightImpact();
    if (_pin.length >= 4) return;
    setState(() {
      _pin += key;
      _error = null;
      _pressedKey = key;
    });
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _pressedKey = null);
    });
    if (_pin.length == 4) {
      Future.delayed(const Duration(milliseconds: 200), () => _processPin());
    }
  }

  void _onBackspace() {
    HapticFeedback.lightImpact();
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  void _processPin() {
    if (!_isConfirming) {
      setState(() {
        _firstPin = _pin;
        _pin = '';
        _isConfirming = true;
        _error = null;
      });
    } else {
      if (_pin == _firstPin) {
        _savePin();
      } else {
        setState(() {
          _error = 'PIN-коды не совпадают';
          _pin = '';
        });
        HapticFeedback.heavyImpact();
      }
    }
  }

  void _savePin() async {
    try {
      await ApiService.savePin(widget.userId, _pin);
      if (!mounted) return;
      await context.read<UserProvider>().setUser(
        id: widget.userId,
        hasPin: true,
      );
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => BiometricSetupScreen(userId: widget.userId),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() => _error = 'Ошибка сохранения');
    }
  }

  void _skip() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => BiometricSetupScreen(userId: widget.userId),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Text(
                    _isConfirming ? 'Повторите PIN-код' : 'Придумайте PIN-код',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isConfirming ? 'Введите PIN-код ещё раз' : '4 цифры для быстрого входа',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF666666),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final isFilled = i < _pin.length;
                  final hasError = _error != null;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasError
                          ? const Color(0xFFF44336)
                          : isFilled
                              ? const Color(0xFFDD1847)
                              : const Color(0xFFE0E0E0),
                      boxShadow: isFilled && !hasError
                          ? [
                              BoxShadow(
                                color: const Color(0xFFDD1847).withValues(alpha: 0.3),
                                blurRadius: 6,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                    transform: isFilled ? Matrix4.identity().scaledByDouble(1.1, 1.1, 1.1, 1.0) : Matrix4.identity(),
                  );
                }),
              ),
            ),

            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: _error != null ? 36 : 0,
              margin: EdgeInsets.only(top: _error != null ? 12 : 0),
              child: _error != null
                  ? Text(
                      _error!,
                      style: const TextStyle(
                        color: Color(0xFFF44336),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  : null,
            ),

            const SizedBox(height: 60),

            if (_isConfirming)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Повторите PIN-код для подтверждения',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: ['1', '2', '3'].map((k) => _buildKey(k)).toList(),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: ['4', '5', '6'].map((k) => _buildKey(k)).toList(),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: ['7', '8', '9'].map((k) => _buildKey(k)).toList(),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildSkipKey(),
                      _buildKey('0'),
                      _buildBackspaceKey(),
                    ],
                  ),
                ],
              ),
            ),

            const Spacer(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildKey(String label) {
    final isPressed = _pressedKey == label;
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _pressedKey = label);
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) {
        _onKeyPressed(label);
      },
      onTapCancel: () {
        setState(() => _pressedKey = null);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: isPressed ? const Color(0xFFDD1847) : const Color(0xFFF8F9FA),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w500,
            color: isPressed ? Colors.white : const Color(0xFF1A1A1A),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceKey() {
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        setState(() => _pressedKey = 'backspace');
      },
      onTapUp: (_) {
        _onBackspace();
        setState(() => _pressedKey = null);
      },
      onTapCancel: () => setState(() => _pressedKey = null),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: _pressedKey == 'backspace'
              ? const Color(0xFFDD1847)
              : const Color(0xFFF8F9FA),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.backspace_outlined,
          size: 28,
          color: _pressedKey == 'backspace'
              ? Colors.white
              : const Color(0xFF1A1A1A),
        ),
      ),
    );
  }

  Widget _buildSkipKey() {
    return GestureDetector(
      onTap: _skip,
      child: SizedBox(
        width: 72,
        height: 72,
        child: Center(
          child: Text(
            'В другой\nраз',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF666666),
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}