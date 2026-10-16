import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'main_screen.dart';
import 'bookings_screen.dart';
import 'profile_screen.dart';
import '../business/business_dashboard_screen.dart';
import '../../../services/api_service.dart';
import 'package:provider/provider.dart';
import '../../../providers/user_provider.dart';
import 'client_chat_screen.dart';
import '../../../services/push_notification_service.dart';
import '../../../services/auth_service.dart';

class ClientDashboardScreen extends StatefulWidget {
  const ClientDashboardScreen({super.key});

  @override
  State<ClientDashboardScreen> createState() => _ClientDashboardScreenState();
}

class _ClientDashboardScreenState extends State<ClientDashboardScreen> {
  int _currentIndex = 0;
  int _unreadChats = 0;
  Timer? _unreadTimer;

  final List<Widget> _screens = [
    MainScreen(),
    BookingsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    AuthService.saveLastScreen('client');
    _loadUnreadCount();
    _unreadTimer = Timer.periodic(const Duration(seconds: 15), (_) => _loadUnreadCount());
    
    // Обработка нажатия на push-уведомление
    PushNotificationService().onNotificationTap = (projectId, count) {
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ClientChatScreen()));
      }
    };
  }

  @override
  void dispose() {
    _unreadTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUnreadCount() async {
    try {
      int total = 0;
      
      final supportResult = await ApiService.get('/api/chat/list?project_id=0&type=support');
      if (supportResult['success'] == true) {
        for (final chat in supportResult['data'] ?? []) {
          total += (chat['unread'] ?? 0) as int;
        }
      }
      
      final orgResult = await ApiService.get('/api/chat/client-list');
      if (orgResult['success'] == true) {
        for (final chat in orgResult['data'] ?? []) {
          total += (chat['unread'] ?? 0) as int;
        }
      }
      
      if (mounted) setState(() => _unreadChats = total);
    } catch (_) {}
  }

  Future<void> _switchToBusiness() async {
    await context.read<UserProvider>().setRole('salon_owner');
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const BusinessDashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(88),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Container(
              height: 88,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF0F0F0)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 20),
                  SvgPicture.asset('assets/LogoZapis.svg', height: 48),
                  const Spacer(),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(15),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ClientChatScreen()));
                      },
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 50, height: 50,
                            decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(15)),
                            child: Center(child: SvgPicture.asset('assets/chat.svg', width: 22, height: 22, colorFilter: const ColorFilter.mode(Color(0xFF666666), BlendMode.srcIn))),
                          ),
                          if (_unreadChats > 0)
                            Positioned(
                              right: -2,
                              top: -2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFFDD1847), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white, width: 2)),
                                child: Text('${_unreadChats > 99 ? '99+' : _unreadChats}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildRoleToggle(),
          Expanded(child: _screens[_currentIndex]),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF0F0F0)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 2))],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _buildNavItem(0, 'assets/home.svg', 'Главная'),
                _buildNavItem(1, 'assets/calendar.svg', 'Мои записи'),
                _buildNavItem(2, 'assets/user.svg', 'Кабинет'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {}, // уже клиент — ничего не делаем
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Клиент',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFDD1847),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: _switchToBusiness,
              child: Container(
                alignment: Alignment.center,
                child: const Text(
                  'Бизнес',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF666666),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, String iconPath, String label) {
    final isActive = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: isActive ? const Color(0xFFFDF2F5) : Colors.transparent, borderRadius: BorderRadius.circular(14)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SvgPicture.asset(iconPath, width: 24, height: 24, colorFilter: ColorFilter.mode(isActive ? const Color(0xFFDD1847) : const Color(0xFF666666), BlendMode.srcIn)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: isActive ? FontWeight.w600 : FontWeight.w500, color: isActive ? const Color(0xFFDD1847) : const Color(0xFF666666))),
          ]),
        ),
      ),
    );
  }
}