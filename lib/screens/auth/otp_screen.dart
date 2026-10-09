// lib/screens/auth/otp_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../select_role_screen.dart';
import '../auth/pin_setup_screen.dart';
import '../auth/register_screen.dart';
import 'call_verification_screen.dart';

class OtpScreen extends StatefulWidget {
  final int userId;
  final String email;
  final bool isRegistration;
  final String firstName;
  final String lastName;
  final String phone;
  
  const OtpScreen({
    super.key,
    required this.userId,
    this.email = '',
    this.isRegistration = false,
    this.firstName = '',
    this.lastName = '',
    this.phone = '',
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  String? _error;
  int _timerSeconds = 59;
  bool _canResend = false;
  String _phone = '';

  @override
  void initState() {
    super.initState();
    _startTimer();
    _loadPhone();
  }

  Future<void> _loadPhone() async {
    if (widget.phone.isNotEmpty) {
      setState(() => _phone = widget.phone);
      return;
    }
    
    try {
      final result = await ApiService.get('/api/auth/check-session');
      if (result['success'] == true && result['user_phone'] != null) {
        setState(() => _phone = result['user_phone'] ?? '');
        return;
      }
      
      if (widget.userId > 0) {
        final userData = await ApiService.checkUser(widget.userId.toString(), 'user_id');
        if (userData['success'] == true) {
          setState(() => _phone = userData['data']['user_phone'] ?? '');
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    for (var c in _controllers) { c.dispose(); }
    for (var f in _focusNodes) { f.dispose(); }
    super.dispose();
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      if (_timerSeconds > 0) {
        setState(() => _timerSeconds--);
        _startTimer();
      } else {
        setState(() => _canResend = true);
      }
    });
  }

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 3) return '${name[0]}***@$domain';
    return '${name.substring(0, 3)}***${name.substring(name.length - 1)}@$domain';
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _onChanged(String value, int index) {
    if (value.length == 1 && index < 5) _focusNodes[index + 1].requestFocus();
    setState(() => _error = null);
  }

  void _verify() async {
    final code = _code;
    if (code.length != 6) return;

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.verifyOtp(widget.userId, code);

      if (!mounted) return;

      if (result['success'] == true) {
        if (widget.isRegistration) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => PinSetupScreen(userId: result['data']['user_id'] ?? widget.userId)),
            (route) => false,
          );
        } else {
          final methods = result['data']['methods'] ?? {};
          if (methods['pin'] == true) {
            await AuthService.saveLogin(widget.userId, hasPin: true, userEmail: widget.email);
            if (!mounted) return;
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => SelectRoleScreen()),
              (route) => false,
            );
          } else {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => PinSetupScreen(userId: widget.userId)),
              (route) => false,
            );
          }
        }
      } else {
        setState(() { _error = 'Неверный код'; _isLoading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Ошибка соединения'; _isLoading = false; });
    }
  }

  void _verifyByCall() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallVerificationScreen(
          phone: _phone,
          userId: widget.userId,
          email: widget.email,
          isRegistration: widget.isRegistration,
          firstName: widget.firstName,
          lastName: widget.lastName,
        ),
      ),
    ).then((verified) {
      if (verified == true && mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  void _resend() async {
    setState(() { _canResend = false; _timerSeconds = 59; });
    
    if (widget.isRegistration) {
      try {
        await ApiService.register(
          firstName: widget.firstName,
          lastName: widget.lastName,
          email: widget.email,
          phone: widget.phone,
          subscribe: true,
          termsAccepted: true,
        );
      } catch (_) {}
    } else {
      try {
        await ApiService.sendOtp(widget.userId, widget.email, 'email');
      } catch (_) {}
    }
    
    _startTimer();
  }

  void _changeEmail() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => RegisterScreen(
          identifier: widget.phone.isNotEmpty ? widget.phone : widget.email,
          type: widget.phone.isNotEmpty ? 'phone' : 'email',
          prefillData: {
            'first_name': widget.firstName,
            'last_name': widget.lastName,
            'email': widget.email,
            'phone': widget.phone,
          },
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Введите код', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.grey[900])),
                const SizedBox(height: 8),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                    children: [
                      const TextSpan(text: 'Код отправлен на '),
                      TextSpan(text: widget.email.isNotEmpty ? _maskEmail(widget.email) : '', style: const TextStyle(color: Color(0xFFDD1847), fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (index) {
                    return Container(
                      width: 48, height: 56,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: TextField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'\d'))],
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true, fillColor: Colors.grey[50],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _error != null ? Colors.red : Colors.grey[200]!)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _error != null ? Colors.red : Colors.grey[200]!)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDD1847), width: 2)),
                        ),
                        onChanged: (v) => _onChanged(v, index),
                      ),
                    );
                  }),
                ),
                if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _canResend ? _resend : null,
                  child: Text(
                    _canResend ? 'Отправить код повторно' : 'Отправить код повторно через ${(_timerSeconds ~/ 60).toString().padLeft(2, '0')}:${(_timerSeconds % 60).toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 14, fontWeight: _canResend ? FontWeight.w600 : FontWeight.w400, color: _canResend ? const Color(0xFFDD1847) : Colors.grey[500]),
                  ),
                ),
                if (widget.isRegistration) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _changeEmail,
                    child: Text(
                      'Изменить email',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[500], decoration: TextDecoration.underline),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: (_code.length == 6 && !_isLoading) ? _verify : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDD1847),
                      disabledBackgroundColor: const Color(0xFFDD1847),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                                'Проверка...',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          )
                        : const Text('Подтвердить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Кнопка "Подтвердить по звонку"
                SizedBox(
                  width: double.infinity, height: 52,
                  child: OutlinedButton(
                    onPressed: _phone.isNotEmpty ? _verifyByCall : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDD1847),
                      side: const BorderSide(color: Color(0xFFDD1847), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Подтвердить по звонку',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.grey[600], side: BorderSide(color: Colors.grey[300]!), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('Назад', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}