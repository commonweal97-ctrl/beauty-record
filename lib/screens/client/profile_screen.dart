import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../services/api_service.dart';
import '../../../services/auth_service.dart';
import 'consents_screen.dart';
import 'discounts_screen.dart';
import '../auth/quick_setup_screen.dart';
import 'reviews_screen.dart';
import '../../../widgets/skeletons.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/toast.dart'; // Add this import

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
  String? _avatar;
  String? _birthDate;
  String _countryCode = '7';
  String _countryDial = '+7';
  String _countryFlag = '🇷🇺';
  bool _loading = true;

  final List<Map<String, dynamic>> _countries = [
    {'code': 'ru', 'dial_code': '7', 'flag': '🇷🇺', 'name': 'Россия', 'max_digits': 10},
    {'code': 'by', 'dial_code': '375', 'flag': '🇧🇾', 'name': 'Беларусь', 'max_digits': 9},
    {'code': 'kz', 'dial_code': '7', 'flag': '🇰🇿', 'name': 'Казахстан', 'max_digits': 10},
    {'code': 'ua', 'dial_code': '380', 'flag': '🇺🇦', 'name': 'Украина', 'max_digits': 9},
  ];

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
          _phoneCtrl.text = _formatPhoneForDisplay(data['phone'] ?? '');
          _avatar = data['avatar'];
          _birthDate = data['birth_date'];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<int> _getUserId() async {
    final result = await ApiService.get('/api/profile');
    return result['data']?['id'] ?? 0;
  }

  String _formatPhoneForDisplay(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length == 11 && digits.startsWith('7')) {
      return '${digits.substring(1, 4)} ${digits.substring(4, 7)} ${digits.substring(7, 9)} ${digits.substring(9, 11)}';
    }
    return phone;
  }

  @override
  void dispose() {
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

  void _saveProfile() async {
    try {
      final result = await ApiService.post('/api/profile/update', {
        'first_name': _firstNameCtrl.text,
        'last_name': _lastNameCtrl.text,
        'email': _emailCtrl.text,
        'phone': _phoneCtrl.text,
        'birth_date': _birthDate,
      });
      
      if (result['success'] == true && mounted) {
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

    return SingleChildScrollView(
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

          // Телефон
          _buildSectionTitle('Телефон'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE0E0E0))),
            child: Row(children: [
              GestureDetector(
                onTap: () => _showCountryPicker(),
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16), decoration: const BoxDecoration(border: Border(right: BorderSide(color: Color(0x1A000000), width: 1))), child: Row(children: [Text(_countryFlag, style: const TextStyle(fontSize: 20)), const SizedBox(width: 4), Text(_countryDial, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF666666)))])),
              ),
              Expanded(child: TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, style: const TextStyle(fontSize: 16), decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16)))),
            ]),
          ),
          const SizedBox(height: 16),

          // Email
          _buildSectionTitle('Электронная почта'),
          const SizedBox(height: 8),
          _buildField(_emailCtrl, 'example@mail.ru', keyboardType: TextInputType.emailAddress),
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

          // Кнопка сохранить
          SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
            onPressed: _saveProfile,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDD1847), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Сохранить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
          )),
          const SizedBox(height: 24),

          // Переключатель Клиент / Бизнес
          Container(
            decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(15)),
            padding: const EdgeInsets.all(6),
            child: Row(children: [
              Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)]), child: const Text('Клиент', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFDD1847))))),
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pushReplacementNamed(context, '/business'),
                child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(12)), child: const Text('Бизнес', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF666666)))),
              )),
            ]),
          ),
          const SizedBox(height: 16),

          TextButton(
    onPressed: () async {
      await ApiService.clearSession();
      await AuthService.clearLogin();
      if (mounted) Navigator.pushReplacementNamed(context, '/');
    },
    child: const Text('Выйти из аккаунта', style: TextStyle(color: Color(0xFF999999))),
),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(alignment: Alignment.centerLeft, child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))));
  }

  Widget _buildField(TextEditingController ctrl, String hint, {TextInputType? keyboardType}) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE0E0E0))),
      child: TextField(controller: ctrl, keyboardType: keyboardType, style: const TextStyle(fontSize: 16), decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Colors.grey, fontSize: 16), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16))),
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

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Text('Выберите страну', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.grey[900])),
        const SizedBox(height: 16),
        ..._countries.map((c) => ListTile(
          leading: Text(c['flag'] as String, style: const TextStyle(fontSize: 28)),
          title: Text(c['name'] as String, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          trailing: Text('+${c['dial_code']}', style: const TextStyle(fontSize: 16, color: Color(0xFF666666))),
          onTap: () { setState(() { _countryCode = c['dial_code'] as String; _countryDial = '+${c['dial_code']}'; _countryFlag = c['flag'] as String; }); Navigator.pop(ctx); },
        )),
      ]))),
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
    final daysInMonth = _daysInMonth(_selectedYear, _selectedMonth);
    final firstDayOfWeek = DateTime(_selectedYear, _selectedMonth, 1).weekday % 7;
    
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