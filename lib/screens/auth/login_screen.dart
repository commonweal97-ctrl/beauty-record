// lib/screens/auth/login_screen.dart
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/analytics_service.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/toast.dart';
import '../../widgets/common/phone_input.dart';
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
  final GlobalKey<PhoneInputState> _phoneKey = GlobalKey<PhoneInputState>();
  final _emailController = TextEditingController();
  bool _isPhone = true;
  bool _isLoading = false;
  bool _isAutoLoginChecking = true;

  String? _phoneError;
  String? _emailError;




  bool get _isFormValid {
    if (_isPhone) {
      return _phoneKey.currentState?.isValid ?? false;
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
        // Источник истины — сервер: актуальная роль + список проектов.
        // Не доверяем SharedPreferences (last_role/last_project_id могут устареть —
        // проект удалён, роль изменилась). Баг: перекидывало на project_id,
        // которого уже нет.
        final state = await ApiService.get('/api/auth/my-state');
        if (!mounted) return;

        final data = state['data'] as Map<String, dynamic>?;
        final role = data?['role'] as String?;
        final projects = (data?['projects'] as List?)?.cast<Map<String, dynamic>>() ?? [];

        final lastScreen = await AuthService.getLastScreen();
        final lastScreenProjectId = await AuthService.getLastScreenProjectId();
        if (!mounted) return;

        // 1. Клиент → ЛК клиента
        if (role == 'client') {
          await AuthService.saveLastScreen('client');
          if (!mounted) return;
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

        // 2. Бизнес — проверяем проекты
        if (role == 'salon_owner') {
          if (projects.isEmpty) {
            // Проектов нет — на выбор роли
            await AuthService.saveLastScreen('select_role');
            if (!mounted) return;
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

          // Если last_screen=select_role — уважаем выбор пользователя
          if (lastScreen == 'select_role') {
            await AuthService.saveLastScreen('select_role');
            if (!mounted) return;
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

          // Определяем projectId: last_screen_project_id, если он в списке
          int? targetProjectId;
          if (lastScreen == 'business_project' && lastScreenProjectId != null) {
            final exists = projects.any((p) => p['id'] == lastScreenProjectId);
            if (exists) targetProjectId = lastScreenProjectId;
          }

          // Если бизнес и проект не выбран явно — берём первый проект
          if (targetProjectId == null && projects.length == 1) {
            targetProjectId = projects[0]['id'] as int?;
          }

          // Если несколько проектов и last_screen=business — список
          if (targetProjectId == null && projects.length > 1) {
            await AuthService.saveLastScreen('business');
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                transitionDuration: const Duration(milliseconds: 200),
                pageBuilder: (_, _, _) => BusinessDashboardScreen(),
                transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
              ),
            );
            return;
          }

          // Иначе — конкретный проект
          if (targetProjectId != null) {
            await AuthService.saveLastScreen('business_project', projectId: targetProjectId);
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                transitionDuration: const Duration(milliseconds: 200),
                pageBuilder: (_, _, _) => BusinessDashboardScreen(initialProjectId: targetProjectId),
                transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
              ),
            );
            return;
          }
        }

        // 3. Роль не определена / нестандартная — на выбор роли
        await AuthService.saveLastScreen('select_role');
        if (!mounted) return;
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
          pageBuilder: (_, _, _) => PinLoginScreen(
            userId: saved['user_id'] ?? 0,
            userEmail: saved['user_email'] ?? '',
            phone: saved['user_phone'] ?? '',
          ),
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

  String _cleanPhone() => _phoneKey.currentState?.fullPhone ?? '';

  void _validateAndContinue() {
    setState(() {
      if (_isPhone) {
        final valid = _phoneKey.currentState?.isValid ?? false;
        if (_phoneController.text.isEmpty) {
          _phoneError = 'Введите номер телефона';
        } else if (!valid) {
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
        // Email пользователя: из API, либо из формы (если вход по email).
        // API может не вернуть user_email — тогда подставляем введённый.
        final userEmail =
            (result['data']['user_email'] as String?)?.isNotEmpty == true
                ? result['data']['user_email'] as String
                : (_isPhone ? '' : _emailController.text.trim());
        
        if (!mounted) return;
        await context.read<UserProvider>().setUser(
          id: userId,
          email: userEmail,
          hasPin: hasPin,
          phone: _isPhone ? _cleanPhone() : '',
        );
        await AnalyticsService.logLogin(hasPin ? 'pin' : 'otp');
        await AnalyticsService.setUserId(userId);
        if (!mounted) return;
        
        if (hasPin) {
          Navigator.push(context, PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 250),
            pageBuilder: (_, _, _) => PinLoginScreen(
              userId: userId,
              userEmail: userEmail,
              phone: _isPhone ? _cleanPhone() : '',
            ),
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
                      PhoneInput(
                        key: _phoneKey,
                        controller: _phoneController,
                        hasError: _phoneError != null,
                        onPhoneChanged: (_) {
                          if (_phoneError != null) {
                            setState(() => _phoneError = null);
                          } else {
                            setState(() {});
                          }
                        },
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