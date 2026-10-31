import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../core/app_typography.dart';
import '../../core/app_logger.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../services/api_service.dart';
import 'consents_screen.dart';
import 'discounts_screen.dart';
import '../auth/quick_setup_screen.dart';
import 'reviews_screen.dart';
import '../../../widgets/skeletons.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/toast.dart';
import '../../../widgets/common/phone_input.dart';
import '../../utils/phone_display.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final GlobalKey<PhoneInputState> _phoneKey = GlobalKey<PhoneInputState>();
  String? _avatar;
  String? _birthDate;
  bool _loading = true;
  bool _hasChanges = false;
  bool _initializing = false;
  String _originalFirstName = '';
  String _originalLastName = '';


  @override
  void initState() {
    super.initState();
    _loadProfile();
    _firstNameCtrl.addListener(_onNameChanged);
    _lastNameCtrl.addListener(_onNameChanged);
  }

  void _onNameChanged() {
    if (_initializing) return;
    final changed = _firstNameCtrl.text != _originalFirstName ||
        _lastNameCtrl.text != _originalLastName;
    if (changed != _hasChanges) {
      setState(() => _hasChanges = changed);
    }
  }

  void _loadProfile() async {
    try {
      final result = await ApiService.get('/api/profile');
      if (result['success'] == true && mounted) {
        final data = result['data'];
        setState(() {
          _initializing = true;
          _originalFirstName = data['first_name'] ?? '';
          _originalLastName = data['last_name'] ?? '';
          _firstNameCtrl.text = _originalFirstName;
          _lastNameCtrl.text = _originalLastName;
          _emailCtrl.text = data['email'] ?? '';
          _phoneCtrl.text = data['phone'] ?? '';
          _avatar = data['avatar'];
          _birthDate = data['birth_date'];
          _loading = false;
        });
        _initializing = false;
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<int> _getUserId() async {
    final result = await ApiService.get('/api/profile');
    return result['data']?['id'] ?? 0;
  }



  @override
  void dispose() {
    _firstNameCtrl.removeListener(_onNameChanged);
    _lastNameCtrl.removeListener(_onNameChanged);
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  String _formatBirthDate(String? date) {
    if (date == null) return 'Не указана';
    final d = DateTime.tryParse(date);
    if (d == null) return 'Не указана';
    const months = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _pickBirthDate() async {
    final result = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _CustomDatePicker(
        initialDate: _birthDate != null ? DateTime.tryParse(_birthDate!) : null,
      ),
    );
    
    if (result != null && mounted) {
      setState(() {
        _birthDate = result.toIso8601String().split('T')[0];
      });
    }
  }

  // ============================================================
  // СМЕНА EMAIL
  // ============================================================
  void _showEmailDialog() {
    final emailCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    String? error;
    bool codeSent = false;
    bool loading = false;
    final currentEmail = context.read<UserProvider>().email;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Изменение email',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Текущий: $currentEmail',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
              const SizedBox(height: 24),
              if (!codeSent)
                const Text(
                  'Введите новый email',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !codeSent,
                  style: AppTypography.input.copyWith(color: const Color(0xFF1A1A1A)),
                  decoration: const InputDecoration(
                    hintText: 'new@email.ru',
                    hintStyle: AppTypography.inputHint,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
              ),
              if (codeSent) ...[
                const SizedBox(height: 20),
                const Text(
                  'Введите код подтверждения',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F8F8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                  ),
                  child: TextField(
                    controller: codeCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 8),
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      hintText: '000000',
                      hintStyle: AppTypography.inputHint,
                      border: InputBorder.none,
                      counterText: '',
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Color(0xFF856404)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Код отправлен на указанный email',
                          style: TextStyle(fontSize: 13, color: Color(0xFF856404)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: loading ? null : () async {
                    final newEmail = emailCtrl.text.trim();
                    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(newEmail)) {
                      setSheetState(() => error = 'Введите корректный email');
                      return;
                    }
                    if (newEmail == currentEmail) {
                      setSheetState(() => error = 'Это ваш текущий email');
                      return;
                    }
                    setSheetState(() { loading = true; error = null; });
                    try {
                      if (!codeSent) {
                        final result = await ApiService.saveEmail(newEmail);
                        if (result['success'] != true) {
                          setSheetState(() {
                            error = result['message'] ?? 'Ошибка. Попробуйте позже';
                            loading = false;
                          });
                          return;
                        }
                        setSheetState(() { codeSent = true; loading = false; });
                      } else {
                        final code = codeCtrl.text.trim();
                        if (code.length != 6) {
                          setSheetState(() { error = 'Введите 6-значный код'; loading = false; });
                          return;
                        }
                        final result = await ApiService.verifyEmail(code);
                        if (result['success'] != true) {
                          setSheetState(() {
                            error = result['message'] ?? 'Неверный код';
                            loading = false;
                          });
                          return;
                        }
                        if (mounted) {
                          await context.read<UserProvider>().updateEmail(newEmail);
                          setState(() => _emailCtrl.text = newEmail);
                          if (mounted) showToast(context, 'Email изменён');
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      }
                    } catch (e) {
                      AppLogger.warning('ProfileScreen: change email failed: $e');
                      setSheetState(() { error = 'Ошибка соединения'; loading = false; });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDD1847),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    loading ? '...' : (codeSent ? 'Подтвердить' : 'Отправить код'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // СМЕНА ТЕЛЕФОНА
  // ============================================================
  void _showPhoneDialog() {
    final phoneKey = GlobalKey<PhoneInputState>();
    final phoneCtrl = TextEditingController();
    String? error;
    bool codeSent = false;
    bool loading = false;
    String newPhone = '';
    bool polling = false;
    final currentPhone = context.read<UserProvider>().phone;

    Future<void> startPolling() async {
      if (polling) return;
      polling = true;
      for (int i = 0; i < 100; i++) {
        await Future.delayed(const Duration(seconds: 3));
        if (!mounted) break;
        try {
          final result = await ApiService.changePhoneConfirm(newPhone);
          if (result['success'] == true) {
            if (mounted) {
              await context.read<UserProvider>().updatePhone(newPhone);
              setState(() => _phoneCtrl.text = newPhone);
              if (mounted) showToast(context, 'Телефон изменён');
            }
            if (mounted) Navigator.pop(context);
            break;
          }
        } on ApiException catch (e) { if (mounted) showToast(context, e.message, isError: true); }
      }
      polling = false;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Изменение телефона',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Текущий: $currentPhone',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
              const SizedBox(height: 24),
              if (!codeSent) ...[
                const Text(
                  'Введите новый номер телефона',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                PhoneInput(
                  key: phoneKey,
                  controller: phoneCtrl,
                  onPhoneChanged: (_) => setSheetState(() {}),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF2F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.phone_in_talk, size: 40, color: Color(0xFFDD1847)),
                      const SizedBox(height: 12),
                      const Text(
                        'Позвоните с нового номера',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        newPhone,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFDD1847),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Звонок сбросится — номер подтвердится автоматически',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 12),
                      const SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Ожидание звонка...',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: (loading || codeSent) ? null : () async {
                    final state = phoneKey.currentState;
                    if (state == null || !state.isValid) {
                      setSheetState(() => error = 'Введите корректный номер');
                      return;
                    }
                    final phone = state.fullPhone;
                    if (phone == currentPhone) {
                      setSheetState(() => error = 'Это ваш текущий номер');
                      return;
                    }
                    setSheetState(() { loading = true; error = null; });
                    try {
                      final result = await ApiService.changePhoneRequest(phone);
                      if (result['success'] != true) {
                        setSheetState(() {
                          error = result['message'] ?? 'Ошибка';
                          loading = false;
                        });
                        return;
                      }
                      newPhone = phone;
                      setSheetState(() { codeSent = true; loading = false; });
                      startPolling();
                    } catch (e) {
                      AppLogger.warning('ProfileScreen: change phone failed: $e');
                      setSheetState(() { error = 'Ошибка соединения'; loading = false; });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDD1847),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    loading ? '...' : 'Продолжить',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _saveProfile() async {
    try {
      final result = await ApiService.post('/api/profile/update', {
        'first_name': _firstNameCtrl.text,
        'last_name': _lastNameCtrl.text,
        'email': _emailCtrl.text,
        'phone': _phoneKey.currentState?.fullPhone ?? '',
        'birth_date': _birthDate,
      });
      
      if (result['success'] == true && mounted) {
        _originalFirstName = _firstNameCtrl.text;
        _originalLastName = _lastNameCtrl.text;
        setState(() => _hasChanges = false);
        showToast(context, 'Профиль сохранён');
      }
    } catch (e) {
      if (mounted) {
        showToast(context, 'Ошибка сохранения: $e', isError: true);
      }
    }
  }

  Widget _avatarPlaceholder({double size = 100}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.25),
        child: SvgPicture.asset('assets/photo-none.svg'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
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
            const SizedBox(height: 24),
            ...List.generate(5, (_) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: const SkeletonBox(height: 48, radius: 12),
            )),
          ],
        ),
      );
    }

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Аватар
          GestureDetector(
            onTap: () {},
            child: _avatar != null && _avatar!.isNotEmpty
                ? CachedAvatar(url: _avatar, size: 100, radius: 50)
                : _avatarPlaceholder(),
          ),
          const SizedBox(height: 24),

          // Имя
          _buildSectionTitle('Имя и фамилия'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _buildField(_firstNameCtrl, 'Имя')),
            const SizedBox(width: 12),
            Expanded(child: _buildField(_lastNameCtrl, 'Фамилия')),
          ]),
          const SizedBox(height: 16),

          // Телефон (readonly + тап → смена)
          _buildSectionTitle('Телефон'),
          const SizedBox(height: 8),
          _buildReadonlyField(
            value: _phoneCtrl.text.isNotEmpty ? formatPhoneDisplay(_phoneCtrl.text) : 'Не указан',
            onTap: _showPhoneDialog,
          ),
          const SizedBox(height: 16),

          // Email (readonly + тап → смена)
          _buildSectionTitle('Электронная почта'),
          const SizedBox(height: 8),
          _buildReadonlyField(
            value: _emailCtrl.text.isNotEmpty ? _emailCtrl.text : 'Не указан',
            onTap: _showEmailDialog,
          ),
          const SizedBox(height: 16),

          // Дата рождения
          _buildSettingsRow('Дата рождения', _formatBirthDate(_birthDate), () => _pickBirthDate()),
          const SizedBox(height: 4),
          const Padding(padding: EdgeInsets.only(bottom: 12), child: Text('Данные о дате рождения будут предоставлены бизнес-проектам, которым вы дали согласие на обработку ПД.', style: TextStyle(fontSize: 11, color: Color(0xFF999999)))),
          const SizedBox(height: 8),

          // Ссылки на соцсети
          _buildSettingsRow('Ссылки на соц. сети', 'Не указаны', () {}),
          const SizedBox(height: 8),

          // Мои согласия
          _buildSettingsRow('Мои согласия', '', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ConsentsScreen()));
          }),
          const SizedBox(height: 8),

          // Скидки и сертификаты
          _buildSettingsRow('Скидки и сертификаты', '', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const DiscountsScreen()));
          }),
          const SizedBox(height: 8),

          // Отзывы
          _buildSettingsRow('Отзывы', '', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ReviewsScreen()));
          }),
          const SizedBox(height: 8),

          // Быстрый вход
          _buildSettingsRow('Быстрый вход', '', () {
            _getUserId().then((id) {
              if (!context.mounted) return;
              Navigator.push(context, MaterialPageRoute(builder: (_) => QuickSetupScreen(userId: id)));
            });
          }, trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            _buildStatusDot(true),
            const SizedBox(width: 8),
            _buildStatusDot(false),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ])),
          const SizedBox(height: 24),

          TextButton(
    onPressed: () async {
      await ApiService.clearSession();
      if (!context.mounted) return;
      await context.read<UserProvider>().logout();
      if (context.mounted) Navigator.pushReplacementNamed(context, '/');
    },
    child: const Text('Выйти из аккаунта', style: TextStyle(color: Color(0xFF999999))),
),
            ],
          ),
        ),
        // Плавающая кнопка "Сохранить"
        if (_hasChanges)
          Positioned(
            left: 20,
            right: 20,
            bottom: 10,
            child: ElevatedButton(
              onPressed: _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDD1847),
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 8,
                shadowColor: const Color(0xFFDD1847).withValues(alpha: 0.3),
              ),
              child: const Text(
                'Сохранить',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(alignment: Alignment.centerLeft, child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))));
  }

  Widget _buildField(TextEditingController ctrl, String hint, {TextInputType? keyboardType}) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE0E0E0))),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: AppTypography.input.copyWith(color: const Color(0xFF1A1A1A)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTypography.inputHint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildReadonlyField({required String value, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: AppTypography.input.copyWith(
                  color: value == 'Не указан' ? const Color(0xFF999999) : const Color(0xFF1A1A1A),
                ),
              ),
            ),
            const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF999999)),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsRow(String label, String value, VoidCallback onTap, {Widget? trailing}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE0E0E0))),
        child: Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
          if (value.isNotEmpty) Padding(padding: const EdgeInsets.only(right: 8), child: Text(value, style: const TextStyle(fontSize: 14, color: Color(0xFF888888)))),
          trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
        ]),
      ),
    );
  }

  Widget _buildStatusDot(bool active) {
    return Container(
      width: 12, height: 12,
      decoration: BoxDecoration(shape: BoxShape.circle, color: active ? const Color(0xFF4CAF50) : const Color(0xFFF44336), border: Border.all(color: Colors.white, width: 2)),
    );
  }

}

// Кастомный виджет выбора даты с быстрым выбором года
class _CustomDatePicker extends StatefulWidget {
  final DateTime? initialDate;
  
  const _CustomDatePicker({this.initialDate});
  
  @override
  State<_CustomDatePicker> createState() => _CustomDatePickerState();
}

class _CustomDatePickerState extends State<_CustomDatePicker> {
  late int _selectedDay;
  late int _selectedMonth;
  late int _selectedYear;
  late PageController _monthController;
  bool _isYearPickerOpen = false;
  
  final List<String> _months = [
    'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
    'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
  ];
  
  @override
  void initState() {
    super.initState();
    final now = widget.initialDate ?? DateTime(2000);
    _selectedDay = now.day;
    _selectedMonth = now.month;
    _selectedYear = now.year;
    _monthController = PageController(initialPage: (_selectedYear - 1900) * 12 + _selectedMonth - 1);
  }
  
  @override
  void dispose() {
    _monthController.dispose();
    super.dispose();
  }
  
  int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }
  
  void _onMonthChanged(int index) {
    setState(() {
      _selectedYear = 1900 + index ~/ 12;
      _selectedMonth = (index % 12) + 1;
      final maxDay = _daysInMonth(_selectedYear, _selectedMonth);
      if (_selectedDay > maxDay) _selectedDay = maxDay;
    });
  }

  void _jumpToYear(int year) {
    setState(() {
      _selectedYear = year;
      _isYearPickerOpen = false;
      final pageIndex = (year - 1900) * 12 + _selectedMonth - 1;
      _monthController.jumpToPage(pageIndex);
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Полоска сверху
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          
          // Заголовок
          const Text(
            'Выберите дату рождения',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 24),
          
          // Навигация по месяцам
          Row(
            children: [
              IconButton(
                onPressed: () {
                  _monthController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                icon: const Icon(Icons.chevron_left, size: 28),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isYearPickerOpen = !_isYearPickerOpen;
                    });
                  },
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _months[_selectedMonth - 1],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$_selectedYear',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFDD1847),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _isYearPickerOpen ? Icons.expand_less : Icons.expand_more,
                            size: 20,
                            color: const Color(0xFFDD1847),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  final maxMonth = today.year * 12 + today.month - 1;
                  final currentMonth = (_selectedYear - 1900) * 12 + _selectedMonth - 1;
                  if (currentMonth < maxMonth) {
                    _monthController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                icon: const Icon(Icons.chevron_right, size: 28),
              ),
            ],
          ),
          
          // Выбор года
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: _isYearPickerOpen ? 80 : 0,
            child: _isYearPickerOpen
                ? Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F8F8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: today.year - 1930 + 1,
                          itemBuilder: (context, index) {
                            final year = 1930 + index;
                            final isSelected = year == _selectedYear;
                            
                            return GestureDetector(
                              onTap: () => _jumpToYear(year),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFFDD1847) : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: isSelected ? null : Border.all(color: const Color(0xFFE0E0E0)),
                                ),
                                child: Center(
                                  child: Text(
                                    '$year',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? Colors.white : Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          
          const SizedBox(height: 8),
          
          // Дни недели
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс']
                .map((day) => SizedBox(
                      width: 40,
                      child: Text(
                        day,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          
          // Сетка дней
          SizedBox(
            height: 280,
            child: PageView.builder(
              controller: _monthController,
              onPageChanged: _onMonthChanged,
              itemCount: (today.year - 1900 + 1) * 12,
              itemBuilder: (context, index) {
                final year = 1900 + index ~/ 12;
                final month = (index % 12) + 1;
                final daysInCurrentMonth = _daysInMonth(year, month);
                final firstDay = DateTime(year, month, 1).weekday % 7;
                final isCurrentMonth = year == _selectedYear && month == _selectedMonth;
                
                return GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 1,
                  ),
                  itemCount: 42,
                  itemBuilder: (context, dayIndex) {
                    final day = dayIndex - firstDay + 1;
                    if (day < 1 || day > daysInCurrentMonth) {
                      return const SizedBox.shrink();
                    }
                    
                    final date = DateTime(year, month, day);
                    final isSelected = isCurrentMonth && day == _selectedDay;
                    final isToday = date.year == today.year && 
                                   date.month == today.month && 
                                   date.day == today.day;
                    final isFuture = date.isAfter(today);
                    
                    return GestureDetector(
                      onTap: isFuture ? null : () {
                        setState(() {
                          _selectedDay = day;
                          _selectedMonth = month;
                          _selectedYear = year;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? const Color(0xFFDD1847) 
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            '$day',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                              color: isSelected 
                                  ? Colors.white 
                                  : isFuture 
                                      ? Colors.grey[300] 
                                      : Colors.black,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          
          // Кнопка "Выбрать"
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context, DateTime(_selectedYear, _selectedMonth, _selectedDay));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDD1847),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Выбрать',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          
          // Кнопка "Отмена"
          SizedBox(
            width: double.infinity,
            height: 52,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Отмена',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF999999),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}