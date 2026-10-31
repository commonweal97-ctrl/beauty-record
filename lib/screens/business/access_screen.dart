import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import '../../../widgets/skeletons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../widgets/toast.dart';
import '../../../widgets/common/phone_input.dart';
import '../../../widgets/common/avatar_initials.dart';
import '../../../utils/phone_display.dart';

class AccessScreen extends StatefulWidget {
  final int projectId;
  const AccessScreen({super.key, required this.projectId});

  @override
  State<AccessScreen> createState() => _AccessScreenState();
}

class _AccessScreenState extends State<AccessScreen> {
  List<Map<String, dynamic>> _accessList = [];
  bool _loading = true;

  static const _roleLabels = {
    'creator': 'Создатель',
    'admin': 'Администратор',
    'admin_limited': 'Администратор (огр.)',
    'employee_view': 'Сотрудник (просмотр)',
    'employee_edit': 'Сотрудник (ред.)',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await ApiService.get('/api/access/list?project_id=${widget.projectId}');
      if (result['success'] == true && mounted) {
        setState(() {
          _accessList = List<Map<String, dynamic>>.from(result['data'] ?? []);
          _loading = false;
        });
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatLastVisit(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Нет визитов';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      
      if (diff.inMinutes < 1) return 'Только что';
      if (diff.inMinutes < 60) return '${diff.inMinutes} мин назад';
      if (diff.inHours < 24) return 'Сегодня в ${DateFormat('HH:mm').format(date)}';
      if (diff.inHours < 48) return 'Вчера в ${DateFormat('HH:mm').format(date)}';
      return DateFormat('dd.MM.yy HH:mm').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  String _getDeviceIcon(String? type) {
    switch (type) {
      case 'ios': return 'assets/apple.svg';
      case 'android': return 'assets/android.svg';
      case 'desktop': return 'assets/device-desktop.svg';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: _loading
          ? _buildSkeleton()
          : _accessList.isEmpty
              ? _buildEmpty()
              : _buildList(),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: 4,
      itemBuilder: (_, i) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF0F0F0)),
        ),
        child: Row(children: [
          const SkeletonCircle(size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SkeletonBox(height: 15, width: 150),
              const SizedBox(height: 6),
              const SkeletonBox(height: 13, width: 100),
              const SizedBox(height: 6),
              const SkeletonBox(height: 12, width: 180),
              const SizedBox(height: 4),
              const SkeletonBox(height: 11, width: 120),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.lock_outline, size: 64, color: Colors.grey[300]),
        const SizedBox(height: 16),
        const Text('Нет пользователей с доступом', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text('Добавьте людей, которые будут иметь доступ к проекту', style: TextStyle(color: Color(0xFF888888))),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => _openAccessModal(),
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Добавить доступ', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDD1847),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ]),
    );
  }

  Widget _buildList() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Row(children: [
          const Expanded(child: Text('Доступ к проекту', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600))),
          GestureDetector(
            onTap: () => _openAccessModal(),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFDD1847), Color(0xFFC1163D)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
          ),
        ]),
      ),
      Expanded(
        child: RefreshIndicator(
          color: const Color(0xFFDD1847),
          onRefresh: () async { await _load(); },
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _accessList.length,
            itemBuilder: (_, i) => _buildAccessCard(_accessList[i]),
          ),
        ),
      ),
    ]);
  }

  Widget _buildAccessCard(Map<String, dynamic> a) {
    final name = '${a['first_name'] ?? ''} ${a['last_name'] ?? ''}'.trim();
    final role = _roleLabels[a['access_role']] ?? 'Сотрудник (ред.)';
    final phone = a['phone']?.toString() ?? '';
    final email = a['email']?.toString() ?? '';
    final avatar = a['avatar']?.toString();
    final deviceType = a['device_type']?.toString();
    final lastVisit = a['last_visit']?.toString();

    return GestureDetector(
      onTap: () => _openAccessForUser(a),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF0F0F0)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          (avatar != null && avatar.isNotEmpty)
              ? ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: 'https://xn--80ane1al0e.xn--80abvyjk6cts.xn--p1ai$avatar',
                    width: 48, height: 48, fit: BoxFit.cover,
                    placeholder: (_, _) => const SkeletonCircle(size: 48),
                    errorWidget: (_, _, _) => AvatarInitials(name: name, size: 48, textColor: const Color(0xFF666666)),
                  ),
                )
              : AvatarInitials(name: name, size: 48, textColor: const Color(0xFF666666)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(role, style: const TextStyle(fontSize: 13, color: Color(0xFF888888))),
              const SizedBox(height: 4),
              if (phone.isNotEmpty || email.isNotEmpty)
                Wrap(spacing: 14, runSpacing: 2, children: [
                  if (phone.isNotEmpty)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.phone, size: 12, color: Color(0xFF999999)),
                      const SizedBox(width: 4),
                      Text(formatPhoneDisplay(phone), style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
                    ]),
                  if (email.isNotEmpty)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.email_outlined, size: 12, color: Color(0xFF999999)),
                      const SizedBox(width: 4),
                      Flexible(child: Text(email, style: const TextStyle(fontSize: 12, color: Color(0xFF999999)), overflow: TextOverflow.ellipsis)),
                    ]),
                ]),
              const SizedBox(height: 4),
              Row(children: [
                if (deviceType != null && _getDeviceIcon(deviceType).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: SvgPicture.asset(_getDeviceIcon(deviceType), width: 12, height: 12, colorFilter: const ColorFilter.mode(Color(0xFF22B100), BlendMode.srcIn)),
                  ),
                Text(
                  _formatLastVisit(lastVisit),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF22B100)),
                ),
              ]),
            ]),
          ),
          const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC)),
        ]),
      ),
    );
  }

  void _openAccessModal({Map<String, dynamic>? accessData}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => AccessFormSheet(
        projectId: widget.projectId,
        accessData: accessData,
        onSaved: _load,
      ),
    );
  }

  void _openAccessForUser(Map<String, dynamic> a) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AccessLoader(
        accessId: a['id'],
        projectId: widget.projectId,
        onSaved: _load,
      ),
    );
  }
}

// ==================== ЗАГРУЗЧИК ДАННЫХ ДОСТУПА ====================
class _AccessLoader extends StatefulWidget {
  final int accessId;
  final int projectId;
  final VoidCallback onSaved;
  const _AccessLoader({required this.accessId, required this.projectId, required this.onSaved});
  @override
  State<_AccessLoader> createState() => _AccessLoaderState();
}

class _AccessLoaderState extends State<_AccessLoader> {
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ApiService.get('/api/access/get?id=${widget.accessId}&project_id=${widget.projectId}');
      if (r['success'] == true && mounted) setState(() => _data = r['data']);
    } on ApiException catch (e) { if (mounted) showToast(context, e.message, isError: true); }
  }

  @override
  Widget build(BuildContext context) {
    if (_data == null) {
      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SkeletonCircle(size: 48),
              SizedBox(height: 16),
              SkeletonBox(height: 14, width: 160),
            ],
          ),
        ),
      );
    }
    return AccessFormSheet(projectId: widget.projectId, accessData: _data, onSaved: widget.onSaved);
  }
}

// ==================== ФОРМА ДОСТУПА ====================
class AccessFormSheet extends StatefulWidget {
  final int projectId;
  final Map<String, dynamic>? accessData;
  final VoidCallback onSaved;

  const AccessFormSheet({super.key, required this.projectId, this.accessData, required this.onSaved});

  @override
  State<AccessFormSheet> createState() => _AccessFormSheetState();
}

class _AccessFormSheetState extends State<AccessFormSheet> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final GlobalKey<PhoneInputState> _phoneKey = GlobalKey<PhoneInputState>();
  final _emailCtrl = TextEditingController();

  String _selectedRole = 'employee_edit';
  bool _saving = false;

  Map<String, String> _settings = {
    'clientsVisibility': 'all',
    'phonesVisibility': 'everywhere',
    'bookingsVisibility': 'all',
    'addEditBookings': 'own',
    'cancelBookings': 'own',
    'occupyTime': 'own',
  };
  bool _showClientLastNames = true;

  static const _roles = [
    {'value': 'admin', 'title': 'Администратор', 'desc': 'Полные права, кроме управления создателями'},
    {'value': 'admin_limited', 'title': 'Администратор (огр.)', 'desc': 'Полные права, кроме управления доступом'},
    {'value': 'employee_view', 'title': 'Сотрудник (просмотр)', 'desc': 'Только просмотр своих записей и графика'},
    {'value': 'employee_edit', 'title': 'Сотрудник (ред.)', 'desc': 'Просмотр и редактирование своих записей'},
  ];

  bool get _isEdit => widget.accessData != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final d = widget.accessData!;
      _firstNameCtrl.text = d['first_name'] ?? '';
      _lastNameCtrl.text = d['last_name'] ?? '';
      _phoneCtrl.text = d['phone'] ?? '';
      _emailCtrl.text = d['email'] ?? '';
      _selectedRole = d['access_role'] ?? 'employee_edit';
      _settings = {
        'clientsVisibility': d['clients_visibility'] ?? 'all',
        'phonesVisibility': d['phones_visibility'] ?? 'everywhere',
        'bookingsVisibility': d['bookings_visibility'] ?? 'all',
        'addEditBookings': d['add_edit_bookings'] ?? 'own',
        'cancelBookings': d['cancel_bookings'] ?? 'own',
        'occupyTime': d['occupy_time'] ?? 'own',
      };
      _showClientLastNames = d['show_client_last_names'] != false;
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose(); _lastNameCtrl.dispose();
    _phoneCtrl.dispose(); _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_firstNameCtrl.text.trim().isEmpty) {
      showToast(context, 'Введите имя', isError: true);  // Вместо SnackBar
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiService.post('/api/access/save', {
        'project_id': widget.projectId,
        'user_id': widget.accessData?['user_id'],
        'first_name': _firstNameCtrl.text.trim(),
        'last_name': _lastNameCtrl.text.trim(),
        'phone': _phoneKey.currentState?.fullPhone ?? '',
        'email': _emailCtrl.text.trim(),
        'access_role': _selectedRole,
        'settings': {..._settings, 'showClientLastNames': _showClientLastNames},
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
        showToast(context, 'Доступ сохранён');  // Вместо SnackBar
      }
    } catch (_) {
      if (!mounted) return;
      showToast(context, 'Ошибка сохранения', isError: true);  // Добавлено
    }
    if (mounted) setState(() => _saving = false);
  }

  String _settingLabel(String key) {
    const labels = {
      'clientsVisibility': {'all': 'Всех', 'own': 'Своих'},
      'phonesVisibility': {'everywhere': 'Везде', 'except_list': 'Везде кроме списка', 'hide': 'Не показывать'},
      'bookingsVisibility': {'all': 'Все', 'own': 'Свои'},
      'addEditBookings': {'forbidden': 'Запрещено', 'own': 'Только свои', 'all': 'Всех'},
      'cancelBookings': {'forbidden': 'Запрещено', 'own': 'Только свои', 'all': 'Всех'},
      'occupyTime': {'forbidden': 'Запрещено', 'own': 'Только себе'},
    };
    return labels[key]?[_settings[key]] ?? _settings[key] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.9,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20)), border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))),
          child: Row(children: [
            GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.arrow_back)),
            const Spacer(),
            const Text('Настройка доступа', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const Spacer(),
            GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close)),
          ]),
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.all(20), children: [
            Row(children: [
              Expanded(child: _field(_firstNameCtrl, 'Имя')),
              const SizedBox(width: 12),
              Expanded(child: _field(_lastNameCtrl, 'Фамилия')),
            ]),
            const SizedBox(height: 20),
            PhoneInput(
              key: _phoneKey,
              controller: _phoneCtrl,
              onPhoneChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            _field(_emailCtrl, 'Email для входа', keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 24),
            const Text('Роль', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            _buildRoleSelector(),
            const SizedBox(height: 24),
            const Text('Дополнительные настройки', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _buildSettingsGroup('Клиенты', [
              _buildSettingRow('Показывать клиентов', _settingLabel('clientsVisibility'), () => _showPicker('clientsVisibility', {'all': 'Всех', 'own': 'Своих'})),
              _buildToggleRow('Показывать фамилии клиентов', _showClientLastNames, (v) => setState(() => _showClientLastNames = v)),
              _buildSettingRow('Показывать телефоны клиентов', _settingLabel('phonesVisibility'), () => _showPicker('phonesVisibility', {'everywhere': 'Везде', 'except_list': 'Везде кроме списка', 'hide': 'Не показывать'})),
            ]),
            _buildSettingsGroup('Запись', [
              _buildSettingRow('Показывать записи', _settingLabel('bookingsVisibility'), () => _showPicker('bookingsVisibility', {'all': 'Все', 'own': 'Свои'})),
              _buildSettingRow('Редактировать записи', _settingLabel('addEditBookings'), () => _showPicker('addEditBookings', {'forbidden': 'Запрещено', 'own': 'Только свои', 'all': 'Всех'})),
              _buildSettingRow('Отменять записи', _settingLabel('cancelBookings'), () => _showPicker('cancelBookings', {'forbidden': 'Запрещено', 'own': 'Только свои', 'all': 'Всех'})),
              _buildSettingRow('Занимать время', _settingLabel('occupyTime'), () => _showPicker('occupyTime', {'forbidden': 'Запрещено', 'own': 'Только себе'})),
            ]),
          ]),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFF0F0F0)))),
          child: SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDD1847),
              disabledBackgroundColor: const Color(0xFFDD1847),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _saving
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
                      SizedBox(width: 12),
                      Text('Сохранение...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                    ],
                  )
                : const Text('Сохранить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
          )),
        ),
      ]),
    );
  }

  Widget _buildRoleSelector() {
    return GestureDetector(
      onTap: () => _showRolePicker(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE0E0E0))),
        child: Row(children: [
          Expanded(child: Text(_roles.firstWhere((r) => r['value'] == _selectedRole, orElse: () => _roles.last)['title']!, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
          const Icon(Icons.arrow_drop_down, color: Color(0xFFCCCCCC)),
        ]),
      ),
    );
  }

  void _showRolePicker() {
    showModalBottomSheet(context: context, backgroundColor: Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (ctx) => Container(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('Выберите роль', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)), const SizedBox(height: 16),
      ..._roles.map((r) => ListTile(title: Text(r['title']!, style: const TextStyle(fontWeight: FontWeight.w500)), subtitle: Text(r['desc']!, style: const TextStyle(fontSize: 13, color: Color(0xFF888888))), trailing: _selectedRole == r['value'] ? const Icon(Icons.check, color: Color(0xFFDD1847)) : null, onTap: () { setState(() => _selectedRole = r['value']!); Navigator.pop(ctx); })),
    ])));
  }

  Widget _buildSettingsGroup(String title, List<Widget> items) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title.toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF999999))), const SizedBox(height: 10), ...items,
      ]),
    );
  }

  Widget _buildSettingRow(String label, String value, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE)))), child: Row(children: [Expanded(child: Text(label, style: const TextStyle(fontSize: 14))), Text(value, style: const TextStyle(fontSize: 14, color: Color(0xFF888888))), const SizedBox(width: 8), const Icon(Icons.chevron_right, size: 16, color: Color(0xFF999999))])));
  }

  Widget _buildToggleRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE)))), child: Row(children: [Expanded(child: Text(label, style: const TextStyle(fontSize: 14))), Switch(value: value, onChanged: onChanged, activeThumbColor: const Color(0xFFDD1847))]));
  }

  void _showPicker(String key, Map<String, String> options) {
    showModalBottomSheet(context: context, backgroundColor: Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (ctx) => Container(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('Выберите', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)), const SizedBox(height: 16),
      ...options.entries.map((e) => ListTile(title: Text(e.value), trailing: _settings[key] == e.key ? const Icon(Icons.check, color: Color(0xFFDD1847)) : null, onTap: () { setState(() => _settings[key] = e.key); Navigator.pop(ctx); })),
    ])));
  }

  Widget _field(TextEditingController ctrl, String hint, {TextInputType? keyboardType}) {
    return TextField(controller: ctrl, keyboardType: keyboardType, decoration: InputDecoration(hintText: hint, filled: true, fillColor: const Color(0xFFF8F8F8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE0E0E0))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE0E0E0))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDD1847))), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)));
  }
}