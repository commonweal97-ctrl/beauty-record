// lib/screens/auth/login_screen.dart
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/analytics_service.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/toast.dart';
import '../../utils/phone_formatter.dart';
import 'otp_screen.dart';
import 'register_screen.dart';
import 'pin_login_screen.dart';
import '../select_role_screen.dart';
import '../client/client_dashboard_screen.dart';
import '../business/business_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isPhone = true;
  bool _isLoading = false;
  bool _isAutoLoginChecking = true;
  String _countryCode = '7';
  String _countryDial = '+7';
  String _countryFlag = '🇷🇺';
  String? _phoneError;
  String? _emailError;

  final List<Map<String, dynamic>> _countries = [
    {'code': 'ru', 'dial_code': '7', 'flag': '🇷🇺', 'name': 'Россия', 'max_digits': 10},
    {'code': 'by', 'dial_code': '375', 'flag': '🇧🇾', 'name': 'Беларусь', 'max_digits': 9},
    {'code': 'kz', 'dial_code': '7', 'flag': '🇰🇿', 'name': 'Казахстан', 'max_digits': 10},
    {'code': 'ua', 'dial_code': '380', 'flag': '🇺🇦', 'name': 'Украина', 'max_digits': 9},
    {'code': 'de', 'dial_code': '49', 'flag': '🇩🇪', 'name': 'Германия', 'max_digits': 11},
    {'code': 'us', 'dial_code': '1', 'flag': '🇺🇸', 'name': 'США', 'max_digits': 10},
  ];

  int get _maxDigits {
    final country = _countries.firstWhere((c) => c['dial_code'] == _countryCode, orElse: () => _countries.first);
    return country['max_digits'] as int;
  }

  bool get _isFormValid {
    if (_isPhone) {
      return PhoneFormatter.isValid(_phoneController.text, _maxDigits);
    } else {
      final email = _emailController.text.trim();
      return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
    }
  }

  @override
  void initState() {
    super.initState();
    _autoLoginIfPossible();
  }

  Future<void> _autoLoginIfPossible() async {
    final wasLoggedOut = await AuthService.wasLoggedOut();
    if (wasLoggedOut) {
      setState(() => _isAutoLoginChecking = false);
      return;
    }
    
    try {
      final check = await ApiService.get('/api/auth/check-session');
      if (check['success'] == true && mounted) {
        // Пользователь в сессии — проверяем последний выбор
        final lastRole = await AuthService.getLastRole();
        if (!mounted) return;
        
        if (lastRole == 'client') {
          // Сразу в ЛК клиента
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 200),
              pageBuilder: (_, _, _) => ClientDashboardScreen(),
              transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
            ),
          );
          return;
        }
        
        if (lastRole == 'salon_owner') {
          final lastProjectId = await AuthService.getLastProjectId();
          if (!mounted) return;
          
          if (lastProjectId != null && lastProjectId > 0) {
            // Сразу в журнал проекта
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                transitionDuration: const Duration(milliseconds: 200),
                pageBuilder: (_, _, _) => BusinessDashboardScreen(initialProjectId: lastProjectId),
                transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
              ),
            );
          } else {
            // Список проектов
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                transitionDuration: const Duration(milliseconds: 200),
                pageBuilder: (_, _, _) => BusinessDashboardScreen(),
                transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
              ),
            );
          }
          return;
        }
        
        // Нет сохраненного выбора — показываем выбор
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 200),
            pageBuilder: (_, _, _) => SelectRoleScreen(),
            transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
          ),
        );
        return;
      }
    } catch (_) {}
    
    // Если сессии нет — проверяем сохраненные данные
    final saved = await AuthService.getSavedLogin();
    if (!mounted) return;
    
    if (saved == null) {
      setState(() => _isAutoLoginChecking = false);
      return;
    }
    
    if (saved['has_pin'] == true) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 200),
          pageBuilder: (_, _, _) => PinLoginScreen(userId: saved['user_id'] ?? 0, userEmail: saved['user_email'] ?? ''),
          transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
        ),
      );
    } else {
      // Если сессии нет, но есть remember_token — пробуем восстановить
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 200),
          pageBuilder: (_, _, _) => SelectRoleScreen(),
          transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
        ),
      );
    }
    
    setState(() => _isAutoLoginChecking = false);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String _cleanPhone() {
    return PhoneFormatter.normalizeForApi(_phoneController.text, '+$_countryCode');
  }

  void _onPhoneChanged(String value) {
    String digits = PhoneFormatter.clean(value);
    if (digits.length > _maxDigits) digits = digits.substring(0, _maxDigits);
    String formatted = PhoneFormatter.formatRu(digits);
    _phoneController.value = TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
    setState(() => _phoneError = null);
  }

  void _validateAndContinue() {
    setState(() {
      if (_isPhone) {
        final digits = PhoneFormatter.clean(_phoneController.text);
        if (digits.isEmpty) {
          _phoneError = 'Введите номер телефона';
        } else if (digits.length != _maxDigits) {
          _phoneError = 'Введите номер полностью';
        } else {
          _phoneError = null;
        }
      } else {
        final email = _emailController.text.trim();
        if (email.isEmpty) {
          _emailError = 'Введите email';
        } else if (!_isEmailValid()) {
          _emailError = 'Введите корректный email';
        } else {
          _emailError = null;
        }
      }
    });

    if ((_isPhone && _phoneError != null) || (!_isPhone && _emailError != null)) return;
    _continue();
  }

  bool _isEmailValid() {
    final email = _emailController.text.trim();
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
  }

  void _continue() async {
    final identifier = _isPhone ? _cleanPhone() : _emailController.text.trim();
    if (identifier.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final type = _isPhone ? 'phone' : 'email';
      final result = await ApiService.checkUser(identifier, type);

      if (!mounted) return;

      if (result['success'] == true && result['data']['exists'] == true) {
        final userId = result['data']['user_id'];
        final methods = result['data']['methods'] ?? {};
        final hasPin = methods['pin'] == true;
        final userEmail = result['data']['user_email'] ?? '';
        
        if (!mounted) return;
        await context.read<UserProvider>().setUser(
          id: userId,
          email: userEmail,
          hasPin: hasPin,
        );
        await AnalyticsService.logLogin(hasPin ? 'pin' : 'otp');
        await AnalyticsService.setUserId(userId);
        if (!mounted) return;
        
        if (hasPin) {
          Navigator.push(context, PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 250),
            pageBuilder: (_, _, _) => PinLoginScreen(userId: userId, userEmail: userEmail),
            transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
          ));
        } else {
          await ApiService.sendOtp(userId, identifier, type);
          if (!mounted) return;
          Navigator.push(context, PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 250),
            pageBuilder: (_, _, _) => OtpScreen(
              userId: userId, 
              email: userEmail,
              phone: _isPhone ? _cleanPhone() : '',
            ),
            transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut), child: child),
          ));
        }
      } else {
        Navigator.push(context, PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 250),
          pageBuilder: (_, _, _) => RegisterScreen(identifier: identifier, type: type),
          transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
        ));
      }
    } catch (e) {
      if (mounted) showToast(context, 'Ошибка соединения', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.white, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Align(alignment: Alignment.centerLeft, child: Text('Выберите страну', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.grey[900]))),
        const SizedBox(height: 16),
        Flexible(child: ListView.builder(shrinkWrap: true, itemCount: _countries.length, itemBuilder: (_, i) {
          final c = _countries[i];
          return ListTile(
            leading: Text(c['flag'] as String, style: const TextStyle(fontSize: 28)),
            title: Text(c['name'] as String, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            trailing: Text('+${c['dial_code']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF666666))),
            onTap: () { setState(() { _countryCode = c['dial_code'] as String; _countryDial = '+${c['dial_code']}'; _countryFlag = c['flag'] as String; _phoneController.clear(); _phoneError = null; }); Navigator.pop(ctx); },
          );
        })),
      ]))),
    );
  }

  void _openSupport() async {
    try {
      await launchUrl(Uri.parse('https://vk.ru/im?sel=-211300534'), mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        await launchUrl(Uri.parse('https://vk.ru/im?sel=-211300534'), mode: LaunchMode.platformDefault);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAutoLoginChecking) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: context.colors.brand),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  SvgPicture.asset('assets/LogoZapis.svg', height: 85),
                  const SizedBox(height: 20),
                  Text('Войдите в аккаунт', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.grey[900]), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text('Используйте телефон или почту', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey[600]), textAlign: TextAlign.center),
                  const SizedBox(height: 28),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.all(4),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final tabWidth = (constraints.maxWidth) / 2;
                        return Stack(
                          children: [
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                              left: _isPhone ? 0 : tabWidth,
                              top: 0,
                              bottom: 0,
                              width: tabWidth,
                              child: Container(
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))]),
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() {
                                      _isPhone = true;
                                      _phoneError = null;
                                      _emailError = null;
                                    }),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      child: Center(child: Text('Телефон', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _isPhone ? Colors.black : const Color(0xFF666666)))),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() {
                                      _isPhone = false;
                                      _phoneError = null;
                                      _emailError = null;
                                    }),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      child: Center(child: Text('Почта', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: !_isPhone ? Colors.black : const Color(0xFF666666)))),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_isPhone)
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12), border: Border.all(color: _phoneError != null ? Colors.red : const Color(0xFFE0E0E0))),
                        child: Row(children: [
                          GestureDetector(
                            onTap: _showCountryPicker,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                              decoration: const BoxDecoration(border: Border(right: BorderSide(color: Color(0x1A000000), width: 1))),
                              child: Row(children: [Text(_countryFlag, style: const TextStyle(fontSize: 22)), const SizedBox(width: 4), Text(_countryDial, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF333333)))]),
                            ),
                          ),
                          Expanded(child: TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\s]'))],
                            onChanged: _onPhoneChanged,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                            decoration: const InputDecoration(hintText: '987 654 32 10', hintStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFFCCCCCC)), border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
                          )),
                        ]),
                      ),
                      if (_phoneError != null) Padding(padding: const EdgeInsets.only(top: 8, left: 4), child: Text(_phoneError!, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500))),
                    ])
                  else
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12), border: Border.all(color: _emailError != null ? Colors.red : const Color(0xFFE0E0E0))),
                        child: TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (_) => setState(() => _emailError = null),
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                          decoration: const InputDecoration(hintText: 'Email', hintStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFFCCCCCC)), border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
                        ),
                      ),
                      if (_emailError != null) Padding(padding: const EdgeInsets.only(top: 8, left: 4), child: Text(_emailError!, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500))),
                    ]),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: (_isFormValid && !_isLoading) ? _validateAndContinue : null,
                      style: ElevatedButton.styleFrom(backgroundColor: context.colors.brand, disabledBackgroundColor: context.colors.brand, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                      child: _isLoading
                          ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)), SizedBox(width: 12), Text('Проверка...', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white))])
                          : const Text('Продолжить', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _openSupport,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      child: Text(
                        'Поддержка',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}