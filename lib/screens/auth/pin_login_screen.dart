// lib/screens/auth/pin_login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../select_role_screen.dart';
import '../../main.dart';
import '../../services/push_notification_service.dart';
import '../../widgets/toast.dart';
import 'login_screen.dart';
import 'otp_screen.dart';

class PinLoginScreen extends StatefulWidget {
  final int userId;
  final String userEmail;
  const PinLoginScreen({super.key, required this.userId, this.userEmail = ''});

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  String _pin = '';
  String? _error;
  String? _pressedKey;
  int _attempts = 0;
  final _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    print('🔐 PinLoginScreen initState');
    print('🔐 userId: ${widget.userId}');
    print('🔐 userEmail: ${widget.userEmail}');
    _tryBiometric();
  }

  Future<void> _tryBiometric() async {
    print('🔐 _tryBiometric called');
    try {
      final bool canCheck = await _localAuth.canCheckBiometrics;
      print('🔐 canCheckBiometrics: $canCheck');
      
      if (!canCheck) return;
      
      final List<BiometricType> availableBiometrics = 
          await _localAuth.getAvailableBiometrics();
      print('🔐 availableBiometrics: $availableBiometrics');
      
      if (availableBiometrics.isEmpty) return;
      
      final bool authenticated = await _localAuth.authenticate(
        localizedReason: 'Войдите в приложение по биометрии',
      );
      print('🔐 biometric authenticated: $authenticated');
      
      if (authenticated && mounted) {
        print('🔐 Sending biometric-login request');
        final result = await ApiService.post('/api/auth/biometric-login', {'user_id': widget.userId});
        print('🔐 biometric-login result: $result');
        
        await AuthService.saveLogin(widget.userId, hasPin: true, userEmail: widget.userEmail);
        
        PushNotificationService().registerTokenAfterLogin();
        
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => SelectRoleScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      print('🔐 Biometric error: $e');
    }
  }

  void _onKeyPressed(String key) {
    HapticFeedback.lightImpact();
    if (_pin.length >= 4) return;
    
    print('🔐 Key pressed: $key');
    print('🔐 Current pin length before: ${_pin.length}');
    
    setState(() { 
      _pin += key; 
      _error = null; 
      _pressedKey = key; 
    });
    
    print('🔐 Current pin length after: ${_pin.length}');
    
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _pressedKey = null);
    });
    
    if (_pin.length == 4) {
      print('🔐 PIN entered: $_pin');
      Future.delayed(const Duration(milliseconds: 200), () => _verifyPin());
    }
  }

  void _onBackspace() {
    HapticFeedback.lightImpact();
    if (_pin.isEmpty) return;
    
    print('🔐 Backspace pressed');
    print('🔐 Current pin before: $_pin');
    
    setState(() { 
      _pin = _pin.substring(0, _pin.length - 1); 
      _error = null; 
    });
    
    print('🔐 Current pin after: $_pin');
  }

  Future<void> _verifyPin() async {
    print('🔐 _verifyPin called');
    print('🔐 userId: ${widget.userId}');
    print('🔐 PIN to verify: $_pin');
    
    try {
      print('🔐 Sending verify-pin request...');
      final result = await ApiService.verifyPin(widget.userId, _pin);
      print('🔐 verify-pin result: $result');
      
      if (!mounted) {
        print('🔐 Widget not mounted after verify');
        return;
      }
      
      if (result['success'] == true) {
        print('🔐 PIN verified successfully');
        await AuthService.saveLogin(widget.userId, hasPin: true, userEmail: widget.userEmail);
        
        PushNotificationService().registerTokenAfterLogin();
        
        if (mounted) {
          print('🔐 Navigating to SelectRoleScreen');
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => SelectRoleScreen()),
            (route) => false,
          );
        }
      } else {
        print('🔐 PIN verification failed');
        print('🔐 Error message: ${result['message']}');
        
        _attempts++;
        if (_attempts >= 3) {
          print('🔐 Too many attempts, returning to login');
          if (mounted) {
            showToast(context, 'Превышено количество попыток', isError: true);
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => LoginScreen()),
              (route) => false,
            );
          }
        } else {
          print('🔐 Attempt $_attempts of 3');
          setState(() { 
            _error = 'Неверный PIN-код. Осталось ${3 - _attempts} попытки'; 
            _pin = ''; 
          });
        }
      }
    } catch (e) {
      print('🔐 Error in _verifyPin: $e');
      print('🔐 Error type: ${e.runtimeType}');
      if (mounted) {
        setState(() { 
          _error = 'Ошибка соединения'; 
          _pin = ''; 
        });
      }
    }
  }

  void _forgotPin() async {
    print('🔐 _forgotPin called');
    try {
      await ApiService.sendOtp(widget.userId, widget.userEmail, 'email');
    } catch (e) {
      print('🔐 Error sending OTP: $e');
    }
    
    if (!mounted) return;
    
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => OtpScreen(
          userId: widget.userId,
          email: widget.userEmail,
          phone: '',
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            const Text('Введите PIN-код', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
            const SizedBox(height: 8),
            const Text('Для входа в аккаунт', style: TextStyle(fontSize: 16, color: Color(0xFF666666))),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 14, height: 14, 
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _pin.length ? (_error != null ? Colors.red : const Color(0xFFDD1847)) : const Color(0xFFE0E0E0),
                ),
              )),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 20, 
              child: _error != null ? Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 14), textAlign: TextAlign.center) : null
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: ['1','2','3'].map((k) => _buildKey(k)).toList()),
                  const SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: ['4','5','6'].map((k) => _buildKey(k)).toList()),
                  const SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: ['7','8','9'].map((k) => _buildKey(k)).toList()),
                  const SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [_buildForgotKey(), _buildKey('0'), _buildBackspaceKey()]),
                ],
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildKey(String label) {
    final isPressed = _pressedKey == label;
    
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressedKey = label),
      onTapUp: (_) => _onKeyPressed(label),
      onTapCancel: () => setState(() => _pressedKey = null),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 72, 
        height: 72,
        decoration: BoxDecoration(
          color: isPressed ? const Color(0xFFDD1847) : const Color(0xFFF8F9FA), 
          shape: BoxShape.circle
        ),
        alignment: Alignment.center,
        child: Text(
          label, 
          style: TextStyle(
            fontSize: 32, 
            fontWeight: FontWeight.w500, 
            color: isPressed ? Colors.white : const Color(0xFF1A1A1A)
          )
        ),
      ),
    );
  }

  Widget _buildBackspaceKey() {
    return GestureDetector(
      onTap: _onBackspace,
      child: Container(
        width: 72, 
        height: 72, 
        decoration: const BoxDecoration(
          color: Color(0xFFF8F9FA), 
          shape: BoxShape.circle
        ), 
        alignment: Alignment.center, 
        child: const Icon(
          Icons.backspace_outlined, 
          size: 28, 
          color: Color(0xFF1A1A1A)
        )
      ),
    );
  }

  Widget _buildForgotKey() {
    return GestureDetector(
      onTap: _forgotPin,
      child: const SizedBox(
        width: 72, 
        height: 72, 
        child: Center(
          child: Text(
            'Не помню\nпин-код', 
            style: TextStyle(
              fontSize: 11, 
              color: Color(0xFF666666)
            ), 
            textAlign: TextAlign.center
          )
        )
      ),
    );
  }
}