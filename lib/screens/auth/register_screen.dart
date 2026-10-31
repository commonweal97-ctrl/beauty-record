import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/common/phone_input.dart';
import 'otp_screen.dart';

class RegisterScreen extends StatefulWidget {
  final String identifier;
  final String type;
  final Map<String, String>? prefillData;
  
  const RegisterScreen({
    super.key,
    required this.identifier,
    required this.type,
    this.prefillData,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final GlobalKey<PhoneInputState> _phoneKey = GlobalKey<PhoneInputState>();
  bool _termsAccepted = false;
  bool _newsletterAccepted = true;
  bool _isLoading = false;
  String? _error;






  @override
  void initState() {
    super.initState();
    
    // Заполняем сохранённые данные
    if (widget.prefillData != null) {
      _firstNameController.text = widget.prefillData!['first_name'] ?? '';
      _lastNameController.text = widget.prefillData!['last_name'] ?? '';
      _emailController.text = widget.prefillData!['email'] ?? '';
      
      if (widget.prefillData!['phone']?.isNotEmpty ?? false) {
        String phone = widget.prefillData!['phone']!.replaceAll(RegExp(r'\D'), '');
        if (phone.startsWith('7') && phone.length > 10) phone = phone.substring(1);
        if (phone.startsWith('375')) phone = phone.substring(3);
        _phoneController.text = phone;
      }
    }
    
    if (widget.type == 'phone' && widget.prefillData == null) {
      String phone = widget.identifier.replaceAll(RegExp(r'\D'), '');
      if (phone.startsWith('7') && phone.length > 10) phone = phone.substring(1);
      _phoneController.text = phone;
    } else if (widget.type == 'email' && widget.prefillData == null) {
      _emailController.text = widget.identifier;
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  bool get _isValid {
    final isPhone = widget.type == 'phone';
    return _firstNameController.text.trim().length >= 2 &&
        _lastNameController.text.trim().length >= 2 &&
        _termsAccepted &&
        (isPhone ? _isEmailValid() : _isPhoneValid());
  }

  bool _isEmailValid() => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_emailController.text.trim());
  bool _isPhoneValid() => _phoneKey.currentState?.isValid ?? false;

  String _cleanPhone() => _phoneKey.currentState?.fullPhone ?? '';

  void _register() async {
    if (_firstNameController.text.trim().length < 2) {
      setState(() => _error = 'Введите имя (минимум 2 символа)');
      return;
    }
    if (_lastNameController.text.trim().length < 2) {
      setState(() => _error = 'Введите фамилию (минимум 2 символа)');
      return;
    }
    if (!_isEmailValid()) {
      setState(() => _error = 'Введите корректный email');
      return;
    }
    if (!_isPhoneValid()) {
      setState(() => _error = 'Введите номер телефона полностью');
      return;
    }
    if (!_termsAccepted) {
      setState(() => _error = 'Примите условия обработки данных');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    try {
      final phone = _cleanPhone();
      final email = _emailController.text.trim();

      // Проверяем телефон
      final checkPhone = await ApiService.checkUser(phone, 'phone');
      if (checkPhone['success'] == true && checkPhone['data']?['exists'] == true) {
        if (mounted) {
          setState(() {
            _error = 'Пользователь с таким телефоном уже существует';
            _isLoading = false;
          });
        }
        return;
      }

      // Проверяем email
      final checkEmail = await ApiService.checkUser(email, 'email');
      if (checkEmail['success'] == true && checkEmail['data']?['exists'] == true) {
        if (mounted) {
          setState(() {
            _error = 'Пользователь с таким email уже существует';
            _isLoading = false;
          });
        }
        return;
      }

      // Регистрация — создаёт юзера + отправляет OTP.
      // register() возвращает user_id в data.user_id — передаём его в OtpScreen,
      // чтобы CallVerificationScreen знал, что юзер уже создан, и вызвал
      // login-by-call (а не register-by-call).
      final result = await ApiService.register(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: email,
        phone: phone,
        subscribe: _newsletterAccepted,
        termsAccepted: _termsAccepted,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final userId = result['data']?['user_id'] ?? 0;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OtpScreen(
              userId: userId,
              email: email,
              isRegistration: true,
              firstName: _firstNameController.text.trim(),
              lastName: _lastNameController.text.trim(),
              phone: phone,
            ),
          ),
        );
      } else {
        setState(() => _error = result['message'] ?? 'Ошибка регистрации');
      }
    } catch (e) {
      setState(() => _error = 'Ошибка соединения');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Регистрация', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.grey[900]), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text('Заполните данные для создания аккаунта', style: TextStyle(fontSize: 14, color: Colors.grey[600]), textAlign: TextAlign.center),
                const SizedBox(height: 28),
                _buildField(_firstNameController, 'Имя'),
                const SizedBox(height: 12),
                _buildField(_lastNameController, 'Фамилия'),
                const SizedBox(height: 12),
                _buildField(_emailController, 'Email', keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                _buildPhoneField(),
                const SizedBox(height: 20),
                _buildConsentCheckbox(),
                const SizedBox(height: 12),
                _buildNewsletterCheckbox(),
                if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13), textAlign: TextAlign.center)),
                const SizedBox(height: 24),
                SizedBox(height: 52, child: ElevatedButton(
                  onPressed: (_isValid && !_isLoading) ? _register : null,
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
                              'Отправка кода...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        )
                      : const Text('Зарегистрироваться', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                )),
                const SizedBox(height: 12),
                SizedBox(height: 52, child: OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(foregroundColor: Colors.grey[600], side: BorderSide(color: Colors.grey[300]!), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Назад к входу', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController c, String hint, {TextInputType? keyboardType}) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE0E0E0))),
      child: TextField(controller: c, keyboardType: keyboardType, onChanged: (_) => setState(() {}), style: const TextStyle(fontSize: 16), decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Colors.grey, fontSize: 16), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16))),
    );
  }

  Widget _buildPhoneField() {
    return PhoneInput(
      key: _phoneKey,
      controller: _phoneController,
      hasError: _error != null,
      onPhoneChanged: (_) => setState(() {}),
    );
  }

  Widget _buildConsentCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24, height: 24,
          child: Checkbox(value: _termsAccepted, onChanged: (v) => setState(() => _termsAccepted = v ?? false), activeColor: const Color(0xFFDD1847)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _termsAccepted = !_termsAccepted),
            child: Text.rich(
              TextSpan(
                style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4),
                children: [
                  const TextSpan(text: 'Я принимаю '),
                  TextSpan(
                    text: 'условия обработки данных',
                    style: const TextStyle(color: Color(0xFFDD1847), decoration: TextDecoration.underline),
                    recognizer: TapGestureRecognizer()..onTap = () async {
                      final uri = Uri.parse('https://запись.бьютироща.рф/privacy');
                      try {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      } catch (_) { /* silent: launchUrl(privacy) не критичен */ }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNewsletterCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 24, height: 24, child: Checkbox(value: _newsletterAccepted, onChanged: (v) => setState(() => _newsletterAccepted = v ?? false), activeColor: const Color(0xFFDD1847))),
        const SizedBox(width: 10),
        Expanded(child: Text('Согласен(а) получать информационную и рекламную рассылку', style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4))),
      ],
    );
  }

}