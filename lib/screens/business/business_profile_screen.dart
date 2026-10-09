import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../../services/api_service.dart';
import '../../../widgets/skeletons.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/toast.dart';
import '../auth/login_screen.dart';

class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({super.key});

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  String? _avatar;
  bool _loading = true;
  final String _countryDial = '+7';
  final String _countryFlag = '🇷🇺';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() async {
    try {
      final result = await ApiService.get('/api/profile');
      if (result['success'] == true && mounted) {
        final data = result['data'];
        setState(() {
          _firstNameCtrl.text = data['first_name'] ?? '';
          _lastNameCtrl.text = data['last_name'] ?? '';
          _emailCtrl.text = data['email'] ?? '';
          _phoneCtrl.text = _formatPhone(data['phone'] ?? '');
          _avatar = data['avatar'];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length == 11 && digits.startsWith('7')) {
      return '${digits.substring(1, 4)} ${digits.substring(4, 7)} ${digits.substring(7, 9)} ${digits.substring(9, 11)}';
    }
    return phone;
  }

  void _save() async {
    if (_newPassCtrl.text.isNotEmpty && _newPassCtrl.text != _confirmPassCtrl.text) {
      showToast(context, 'Пароли не совпадают', isError: true);
      return;
    }
    try {
      final result = await ApiService.updateProfile(
        _firstNameCtrl.text.trim(),
        _lastNameCtrl.text.trim(),
        _emailCtrl.text.trim(),
        newPassword: _newPassCtrl.text.isNotEmpty ? _newPassCtrl.text : null,
      );
      if (result['success'] == true && mounted) {
        showToast(context, 'Профиль обновлён');
      }
    } catch (_) {
      if (mounted) showToast(context, 'Ошибка сохранения', isError: true);
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        title: const Text('Мой профиль', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w600)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.grey), onPressed: () => Navigator.pop(context)),
      ),
      body: _loading
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                const Center(child: SkeletonCircle(size: 100)),
                const SizedBox(height: 24),
                const SkeletonBox(height: 14, width: 120),
                const SizedBox(height: 8),
                Row(children: [
                  const Expanded(child: SkeletonBox(height: 48, radius: 12)),
                  const SizedBox(width: 12),
                  const Expanded(child: SkeletonBox(height: 48, radius: 12)),
                ]),
                const SizedBox(height: 16),
                const SkeletonBox(height: 14, width: 80),
                const SizedBox(height: 8),
                const SkeletonBox(height: 48, radius: 12),
                const SizedBox(height: 16),
                const SkeletonBox(height: 14, width: 140),
                const SizedBox(height: 8),
                const SkeletonBox(height: 48, radius: 12),
                const SizedBox(height: 16),
                const SkeletonBox(height: 14, width: 120),
                const SizedBox(height: 8),
                const SkeletonBox(height: 48, radius: 12),
                const SizedBox(height: 12),
                const SkeletonBox(height: 48, radius: 12),
              ]),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                GestureDetector(
                  onTap: () {},
                  child: CachedAvatar(url: _avatar, size: 100, radius: 50),
                ),
                const SizedBox(height: 24),
                _sectionTitle('Имя и фамилия'),
                const SizedBox(height: 8),
                Row(children: [Expanded(child: _field(_firstNameCtrl, 'Имя')), const SizedBox(width: 12), Expanded(child: _field(_lastNameCtrl, 'Фамилия'))]),
                const SizedBox(height: 16),
                _sectionTitle('Телефон'),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE0E0E0))),
                  child: Row(children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16), decoration: const BoxDecoration(border: Border(right: BorderSide(color: Color(0x1A000000)))), child: Row(children: [Text(_countryFlag, style: const TextStyle(fontSize: 20)), const SizedBox(width: 4), Text(_countryDial, style: const TextStyle(fontSize: 14, color: Color(0xFF666666)))])),
                    Expanded(child: TextField(controller: _phoneCtrl, enabled: false, style: const TextStyle(fontSize: 16, color: Colors.black54), decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16)))),
                  ]),
                ),
                const SizedBox(height: 4),
                const Align(alignment: Alignment.centerLeft, child: Text('Телефон можно изменить только через администратора', style: TextStyle(fontSize: 12, color: Color(0xFF999999)))),
                const SizedBox(height: 16),
                _sectionTitle('Электронная почта'),
                const SizedBox(height: 8),
                _field(_emailCtrl, 'example@mail.ru', keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 16),
                _sectionTitle('Смена пароля'),
                const SizedBox(height: 8),
                _field(_newPassCtrl, 'Новый пароль', obscure: true),
                const SizedBox(height: 12),
                _field(_confirmPassCtrl, 'Повторите пароль', obscure: true),
                const SizedBox(height: 24),
                SizedBox(width: double.infinity, height: 52, child: ElevatedButton(onPressed: _save, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDD1847), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Сохранить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)))),
                const SizedBox(height: 24),
                // Переключатель Клиент / Бизнес
                Container(
                  decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(15)), padding: const EdgeInsets.all(6),
                  child: Row(children: [
                    Expanded(child: GestureDetector(onTap: () => Navigator.pushReplacementNamed(context, '/home'), child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(12)), child: const Text('Клиент', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF666666)))))),
                    Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)]), child: const Text('Бизнес', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFDD1847))))),
                  ]),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () async { 
    await ApiService.clearSession();
    if (!context.mounted) return;
    await context.read<UserProvider>().logout(); 
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => LoginScreen()), (_) => false); 
},
                  child: const Text('Выйти из аккаунта', style: TextStyle(color: Color(0xFF999999))),
                ),
              ]),
            ),
    );
  }

  Widget _sectionTitle(String t) => Align(alignment: Alignment.centerLeft, child: Text(t, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))));
  
  Widget _field(TextEditingController c, String hint, {TextInputType? keyboardType, bool obscure = false}) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE0E0E0))),
      child: TextField(controller: c, keyboardType: keyboardType, obscureText: obscure, style: const TextStyle(fontSize: 16), decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Colors.grey, fontSize: 16), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16))),
    );
  }
}