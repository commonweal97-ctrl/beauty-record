// lib/screens/select_role_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'client/client_dashboard_screen.dart';
import 'business/business_dashboard_screen.dart';
import 'auth/login_screen.dart';
import '../core/app_logger.dart';

class SelectRoleScreen extends StatefulWidget {
  const SelectRoleScreen({super.key});

  @override
  State<SelectRoleScreen> createState() => _SelectRoleScreenState();
}

class _SelectRoleScreenState extends State<SelectRoleScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigate(Widget page) {
    _controller.reverse().then((_) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 400),
            pageBuilder: (_, _, _) => page,
            transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
          ),
        );
      }
    });
  }

  Future<void> _goToClient() async {
    await AuthService.saveLastRole('client');
    _navigate(ClientDashboardScreen());
  }

  Future<void> _goToBusiness() async {
    await AuthService.saveLastRole('business');
    _navigate(BusinessDashboardScreen());
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    
    setState(() => _isLoggingOut = true);
    
    try {
      // 1. Очищаем серверную сессию
      try {
        await ApiService.logout();
      } catch (_) {}
      
      // 2. Очищаем локальные куки
      await ApiService.clearSession();
      
      // 3. Полная очистка данных авторизации
      await AuthService.fullLogout();
      
      // 4. Переходим на экран входа
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      AppLogger.debug('Logout error: $e');
      if (mounted) {
        setState(() => _isLoggingOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fadeIn,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset('assets/LogoZapis.svg', height: 85),
                  const SizedBox(height: 16),
                  Text('Добро пожаловать!', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                  const SizedBox(height: 4),
                  Text('Выберите как хотите продолжить', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                  const SizedBox(height: 32),
                  _RoleCard(
                    svgAsset: 'assets/user.svg',
                    title: 'Кабинет клиента',
                    subtitle: 'Запись на услуги, мои записи',
                    onTap: _goToClient,
                  ),
                  const SizedBox(height: 14),
                  _RoleCard(
                    svgAsset: 'assets/layers.svg',
                    title: 'Бизнес кабинет',
                    subtitle: 'Управление проектами, журнал записи',
                    onTap: _goToBusiness,
                  ),
                  const SizedBox(height: 32),
                  _isLoggingOut
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : TextButton(
                          onPressed: _logout,
                          child: Text('Выйти', style: TextStyle(color: Colors.grey[500])),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String svgAsset;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RoleCard({required this.svgAsset, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          border: Border.all(color: const Color(0xFFE0E0E0), width: 2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            SvgPicture.asset(svgAsset, width: 48, height: 48),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}