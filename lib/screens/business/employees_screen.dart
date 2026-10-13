import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../../services/api_service.dart';
import '../../../widgets/skeletons.dart';
import '../../../widgets/toast.dart';
import 'fixed_time_settings_sheet.dart';
import 'access_screen.dart';
import 'employee_schedule_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_logger.dart';
import '../../widgets/common/phone_input.dart';
import '../../utils/phone_display.dart';

// ==================== ОТДЕЛЬНЫЙ ВИДЖЕТ ДЛЯ ПОЛЯ ЦЕНЫ ====================
class _PriceField extends StatefulWidget {
  final String initialValue;
  final bool enabled;
  final ValueChanged<String> onChanged;
  
  const _PriceField({
    required this.initialValue,
    required this.enabled,
    required this.onChanged,
  });

  @override
  State<_PriceField> createState() => _PriceFieldState();
}

class _PriceFieldState extends State<_PriceField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(_PriceField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Обновляем текст только если он изменился извне и поле не в фокусе
    if (oldWidget.initialValue != widget.initialValue && !_controller.selection.isValid) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 65, 
      height: 32,
      child: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        enabled: widget.enabled,
        onChanged: widget.onChanged,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          filled: true, 
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8), 
            borderSide: const BorderSide(color: Color(0xFFE8E8E8))
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), 
          isDense: true,
        ),
      ),
    );
  }
}

class EmployeesScreen extends StatefulWidget {
  final int projectId;
  const EmployeesScreen({super.key, required this.projectId});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  List<Map<String, dynamic>> _employees = [];
  bool _loading = true;

  static const String _baseUrl = 'https://xn--80ane1al0e.xn--80abvyjk6cts.xn--p1ai';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await ApiService.get('/api/employee/list?project_id=${widget.projectId}');
      if (result['success'] == true && mounted) {
        setState(() {
          _employees = List<Map<String, dynamic>>.from(result['data'] ?? []);
          _loading = false;
        });
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('Ошибка загрузки сотрудников: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  String _getPosition(Map<String, dynamic> e) {
    if (e['position'] != null && e['position'].toString().isNotEmpty) return e['position'].toString();
    if (e['category'] != null && e['category'].toString().isNotEmpty) return e['category'].toString();
    if (e['project_role'] == 'admin') return 'Администратор';
    return 'Мастер';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: _loading
          ? _buildSkeleton()
          : _employees.isEmpty
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
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF0F0F0))),
        child: Row(children: [
          const SkeletonCircle(size: 56),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SkeletonBox(height: 16, width: 150),
            const SizedBox(height: 8),
            const SkeletonBox(height: 12, width: 100),
            const SizedBox(height: 8),
            Row(children: const [SkeletonBox(height: 12, width: 80), SizedBox(width: 16), SkeletonBox(height: 12, width: 120)]),
          ])),
        ]),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
        const SizedBox(height: 16),
        const Text('Нет сотрудников', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        const Text('Добавьте сотрудников, чтобы они могли работать с записями', style: TextStyle(color: Color(0xFF888888)), textAlign: TextAlign.center),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: () => _openEmployeeModal(),
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Добавить сотрудника', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDD1847), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
      ]),
    );
  }

  Widget _buildList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Row(children: [
            const Expanded(child: Text('Сотрудники', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600))),
            GestureDetector(
              onTap: () => _openEmployeeModal(),
              child: Container(width: 40, height: 40, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFDD1847), Color(0xFFC1163D)]), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.add, color: Colors.white, size: 20)),
            ),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _employees.length,
            itemBuilder: (_, i) => _buildEmployeeCard(_employees[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildEmployeeCard(Map<String, dynamic> e) {
    final name = '${e['first_name'] ?? ''} ${e['last_name'] ?? ''}'.trim();
    final position = _getPosition(e);
    final phone = e['phone']?.toString() ?? '';
    final email = e['email']?.toString() ?? '';
    final avatar = e['avatar']?.toString();
    return GestureDetector(
      onTap: () => _openEmployeeModal(employee: e),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF0F0F0)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))]),
        child: Row(children: [
          Container(
            width: 56, height: 56,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF8F8F8)),
            clipBehavior: Clip.antiAlias,
            child: avatar != null && avatar.isNotEmpty
                ? CachedNetworkImage(imageUrl: '$_baseUrl$avatar', fit: BoxFit.cover)
                : Padding(padding: const EdgeInsets.all(12), child: SvgPicture.asset('assets/user.svg', colorFilter: const ColorFilter.mode(Color(0xFF999999), BlendMode.srcIn))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(20)), child: Text(position, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF666666)))),
              const SizedBox(height: 8),
              Wrap(spacing: 16, runSpacing: 4, children: [
                if (phone.isNotEmpty) Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.phone, size: 14, color: Color(0xFF999999)), const SizedBox(width: 4), Text(formatPhoneDisplay(phone), style: const TextStyle(fontSize: 13, color: Color(0xFF666666)))]),
                if (email.isNotEmpty) Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.email_outlined, size: 14, color: Color(0xFF999999)), const SizedBox(width: 4), Flexible(child: Text(email, style: const TextStyle(fontSize: 13, color: Color(0xFF666666)), overflow: TextOverflow.ellipsis))]),
              ]),
            ]),
          ),
          const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC)),
        ]),
      ),
    );
  }

  void _openEmployeeModal({Map<String, dynamic>? employee}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _EmployeeFormSheet(
        projectId: widget.projectId,
        employee: employee,
        onSaved: _load,
      ),
    ).then((_) => _load());
  }
}

// ==================== ФОРМА СОТРУДНИКА ====================
class _EmployeeFormSheet extends StatefulWidget {
  final int projectId;
  final Map<String, dynamic>? employee;
  final VoidCallback onSaved;
  const _EmployeeFormSheet({required this.projectId, this.employee, required this.onSaved});
  @override
  State<_EmployeeFormSheet> createState() => _EmployeeFormSheetState();
}

class _EmployeeFormSheetState extends State<_EmployeeFormSheet> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _aboutCtrl = TextEditingController();
  final _positionCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  final GlobalKey<PhoneInputState> _phoneKey = GlobalKey<PhoneInputState>();
  String _category = 'Не выбрано';
  bool _providesServices = true;
  String _bookingColor = '#DD1847';
  String _avatarUrl = '';
  File? _avatarFile;
  bool _loading = false;
  bool _saving = false;

  bool _notifyNewBooking = true;
  bool _notifyBookingChange = true;
  bool _notifyBookingCancel = true;
  Map<String, bool> _notifications = {'new_booking': true, 'booking_change': true, 'booking_cancel': true};

  bool _onlineEnabled = true;
  bool _optimalTimeEnabled = true;
  bool _fixedTimeEnabled = false;
  Map<String, dynamic> _minBookingTime = {'enabled': false, 'value': 1, 'unit': 'hours'};

  List<Map<String, dynamic>> _photos = [];

  String _accessStatus = 'Настроить';
  String _scheduleStatus = 'Настроить';

  Set<int> _employeeServiceIds = {};
  List<Map<String, dynamic>> _allServices = [];
  List<Map<String, dynamic>> _filteredServices = [];
  final TextEditingController _serviceSearchCtrl = TextEditingController();
  
  // Персональные настройки для каждой услуги сотрудника
  Map<int, Map<String, dynamic>> _employeeServicePrices = {};

  static const _colors = ['#DD1847', '#E91E63', '#9C27B0', '#2196F3', '#4CAF50', '#FF9800', '#607D8B'];
  static const String _baseUrl = 'https://xn--80ane1al0e.xn--80abvyjk6cts.xn--p1ai';
  static const _categories = ['Администратор', 'Бровист', 'Визажист', 'Врач', 'Косметолог', 'Массажист', 'Мастер', 'Мастер ногтевого сервиса', 'Мастер пирсинга', 'Мастер по наращиванию ресниц', 'Парикмахер', 'Преподаватель', 'Специалист', 'Специалист по эстетике тела', 'Татуировщик', 'Тренер', 'Прочее'];
  static const _roleLabels = {
    'creator': 'Создатель', 'admin': 'Администратор', 'admin_limited': 'Администратор (огр.)',
    'employee_view': 'Сотрудник (просмотр)', 'employee_edit': 'Сотрудник (ред.)',
  };

  bool get _isEdit => widget.employee != null;

  @override
  void initState() {
    super.initState();
    _serviceSearchCtrl.addListener(_filterServices);
    if (_isEdit) _loadEmployeeData();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose(); _lastNameCtrl.dispose(); _aboutCtrl.dispose();
    _positionCtrl.dispose(); _phoneCtrl.dispose(); _emailCtrl.dispose();
    _serviceSearchCtrl.dispose();
    super.dispose();
  }

  void _filterServices() {
    final query = _serviceSearchCtrl.text.toLowerCase();
    setState(() {
      _filteredServices = query.isEmpty ? List.from(_allServices) : _allServices.where((s) {
        final name = (s['name'] ?? '').toString().toLowerCase();
        final category = (s['category'] ?? '').toString().toLowerCase();
        return name.contains(query) || category.contains(query);
      }).toList();
    });
  }

  Future<void> _loadEmployeeData() async {
    setState(() => _loading = true);
    try {
      final result = await ApiService.get('/api/employee/get?id=${widget.employee!['id']}&project_id=${widget.projectId}');
      if (result['success'] == true && mounted) {
        final d = result['data'];
        
        String phone = d['phone'] ?? '';
        String dial = '+7';
        String number = '';
        if (phone.isNotEmpty) {
          if (phone.startsWith('+375')) { dial = '+375'; number = phone.substring(4); }
          else if (phone.startsWith('+380')) { dial = '+380'; number = phone.substring(4); }
          else if (phone.startsWith('+7')) { dial = '+7'; number = phone.substring(2); }
          else if (phone.startsWith('8')) { dial = '+7'; number = phone.substring(1); }
          else { number = phone; }
          if (dial == '+7' && number.length == 10) {
            number = '${number.substring(0,3)} ${number.substring(3,6)} ${number.substring(6,8)} ${number.substring(8,10)}';
          } else if ((dial == '+375' || dial == '+380') && number.length >= 2) number = '${number.substring(0,2)} ${number.substring(2)}';
        }
        if (d['notifications'] != null) {
          _notifications = Map<String, bool>.from(d['notifications']);
          _notifyNewBooking = _notifications['new_booking'] ?? true;
          _notifyBookingChange = _notifications['booking_change'] ?? true;
          _notifyBookingCancel = _notifications['booking_cancel'] ?? true;
        }
        
        _employeeServiceIds = {};
        if (d['service_ids'] != null && d['service_ids'] is List) {
          for (var id in d['service_ids']) {
            if (id is int) { 
              _employeeServiceIds.add(id); 
            } else if (id is String) { 
              final parsed = int.tryParse(id); 
              if (parsed != null && parsed > 0) _employeeServiceIds.add(parsed); 
            } else {
              final parsed = int.tryParse(id.toString()); 
              if (parsed != null && parsed > 0) _employeeServiceIds.add(parsed);
            }
          }
        }
        
        // Загружаем персональные цены услуг для сотрудника
        _employeeServicePrices = {};
        if (d['employee_service_prices'] != null && d['employee_service_prices'] is Map) {
          (d['employee_service_prices'] as Map).forEach((k, v) {
            _employeeServicePrices[int.parse(k.toString())] = Map<String, dynamic>.from(v);
          });
        }
        
        setState(() {
          _firstNameCtrl.text = d['first_name'] ?? '';
          _lastNameCtrl.text = d['last_name'] ?? '';
          _aboutCtrl.text = d['about'] ?? '';
          _positionCtrl.text = d['position'] ?? '';
          _phoneCtrl.text = number;
          _emailCtrl.text = d['email'] ?? '';
          _category = d['category'] ?? 'Не выбрано';
          _providesServices = d['provides_services'] != false;
          _bookingColor = d['booking_color'] ?? '#DD1847';
          _avatarUrl = d['avatar'] ?? '';
          _loading = false;
        });
        _loadPhotos();
        _loadOnlineSettings();
        _loadAccessStatus();
        _loadScheduleStatus();
        _loadEmployeeServices();
      }
    } catch (e) {
      AppLogger.debug('❌ Load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadEmployeeServices() async {
    try {
      final r = await ApiService.get('/api/service/list?project_id=${widget.projectId}');
      if (r['success'] == true && mounted) {
        setState(() {
          _allServices = List<Map<String, dynamic>>.from(r['data'] ?? []);
          _filteredServices = List.from(_allServices);
        });
      }
    } catch (_) {}
  }

  Future<void> _loadPhotos() async {
    try {
      final result = await ApiService.get('/api/employee-photo/list?employee_id=${widget.employee!['id']}&project_id=${widget.projectId}');
      if (result['success'] == true && mounted) {
        setState(() => _photos = List<Map<String, dynamic>>.from(result['data'] ?? []));
      }
    } catch (_) {}
  }

  Future<void> _loadOnlineSettings() async {
    try {
      final results = await Future.wait([
        ApiService.get('/api/employee/get?id=${widget.employee!['id']}&project_id=${widget.projectId}'),
        ApiService.get('/api/employee/get-fixed-time?employee_id=${widget.employee!['id']}&project_id=${widget.projectId}'),
        ApiService.get('/api/project-profile/get-online-settings?project_id=${widget.projectId}'),
      ]);
      if (results[0]['success'] == true) {
        final emp = results[0]['data'];
        setState(() {
          _onlineEnabled = emp['is_active'] != false;
          _optimalTimeEnabled = emp['optimal_time_enabled'] != false;
        });
      }
      if (results[1]['success'] == true) {
        setState(() => _fixedTimeEnabled = results[1]['data']['enabled'] == true);
      }
      if (results[2]['success'] == true) {
        final settings = results[2]['data'];
        final allMbt = settings['min_booking_time'] as Map<String, dynamic>? ?? {};
        if (allMbt.containsKey(widget.employee!['id'].toString())) {
          setState(() => _minBookingTime = Map<String, dynamic>.from(allMbt[widget.employee!['id'].toString()]));
        }
      }
      if (_optimalTimeEnabled) _loadOptimalIntervals();
    } catch (_) {}
  }

  Future<void> _loadAccessStatus() async {
    try {
      final result = await ApiService.get('/api/access/list?project_id=${widget.projectId}');
      if (result['success'] == true && mounted) {
        final list = List<Map<String, dynamic>>.from(result['data'] ?? []);
        final userId = widget.employee!['id'];
        final access = list.firstWhere(
          (a) => a['user_id'] == userId,
          orElse: () => {},
        );
        if (access.isNotEmpty) {
          setState(() {
            _accessStatus = _roleLabels[access['access_role']] ?? 'Настроен';
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadScheduleStatus() async {
    try {
      final result = await ApiService.get('/api/employee/schedule/get?employee_id=${widget.employee!['id']}&project_id=${widget.projectId}&year=${DateTime.now().year}&month=${DateTime.now().month}');
      if (result['success'] == true && mounted) {
        final data = result['data'] as Map? ?? {};
        if (data.isNotEmpty) {
          String? lastDate;
          for (final key in data.keys) {
            lastDate = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${key.toString().padLeft(2, '0')}';
          }
          if (lastDate != null) {
            final d = DateTime.tryParse(lastDate);
            if (d != null) {
              final months = ['янв', 'фев', 'мар', 'апр', 'мая', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
              setState(() {
                _scheduleStatus = 'заполнен до ${d.day} ${months[d.month - 1]} ${d.year}';
              });
              return;
            }
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _loadOptimalIntervals() async {
    try {
      final result = await ApiService.get('/api/calculate-optimal-intervals?employee_id=${widget.employee!['id']}&project_id=${widget.projectId}');
      if (result['success'] == true) {
        setState(() {
        });
      }
    } catch (_) {}
  }

  String _getFullPhone() => _phoneKey.currentState?.fullPhone ?? '';

  String get _initials {
    final first = _firstNameCtrl.text.trim();
    final last = _lastNameCtrl.text.trim();
    if (first.isEmpty && last.isEmpty) return '?';
    final f = first.isNotEmpty ? first[0].toUpperCase() : '';
    final l = last.isNotEmpty ? last[0].toUpperCase() : '';
    return '$f$l';
  }
  
  String _getNotificationsStatus() {
    final enabled = [_notifyNewBooking, _notifyBookingChange, _notifyBookingCancel].where((v) => v).length;
    return enabled == 3 ? 'Все' : '$enabled/3';
  }

  // ========== МЕТОДЫ ДЛЯ ПЕРСОНАЛЬНЫХ НАСТРОЕК УСЛУГ ==========
  
  void _updateServicePrice(int serviceId, String value) {
    _employeeServicePrices[serviceId] ??= {};
    _employeeServicePrices[serviceId]!['price'] = value;
    // Не вызываем setState здесь - обновление происходит локально в контроллере
  }

  void _updateServiceFree(int serviceId, bool value) {
    _employeeServicePrices[serviceId] ??= {};
    _employeeServicePrices[serviceId]!['is_free'] = value;
    if (value) {
      _employeeServicePrices[serviceId]!['price'] = '';
      _employeeServicePrices[serviceId]!['price_from'] = false;
    }
    setState(() {});
  }

  void _updateServicePriceFrom(int serviceId, bool value) {
    _employeeServicePrices[serviceId] ??= {};
    _employeeServicePrices[serviceId]!['price_from'] = value;
    setState(() {});
  }

  void _updateServiceDuration(int serviceId, int value) {
    _employeeServicePrices[serviceId] ??= {};
    _employeeServicePrices[serviceId]!['duration'] = value;
    setState(() {});
  }

  void _updateServiceOnlineBooking(int serviceId, bool value) {
    _employeeServicePrices[serviceId] ??= {};
    _employeeServicePrices[serviceId]!['online_booking'] = value;
    setState(() {});
  }

  void _pickServiceDuration(int serviceId) async {
    final service = _allServices.firstWhere((s) => s['id'] == serviceId, orElse: () => {});
    final defaultDuration = service['duration'] as int? ?? 60;
    final dur = _employeeServicePrices[serviceId]?['duration'];
    final currentDuration = dur != null ? int.tryParse(dur.toString()) ?? defaultDuration : defaultDuration;
    
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _TimeWheelPicker(
        initialMinutes: currentDuration,
        title: 'Длительность услуги',
        onSelected: (m) => Navigator.pop(ctx, m),
      ),
    );
    
    if (result != null && mounted) {
      _updateServiceDuration(serviceId, result);
      setState(() {});
    }
  }

  String _formatDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '$h ч $m мин';
    if (h > 0) return '$h ч';
    if (m > 0) return '$m мин';
    return '0 мин';
  }

  // ========== СОХРАНЕНИЕ ==========
  Future<void> _save() async {
    if (_firstNameCtrl.text.trim().isEmpty) {
      showToast(context, 'Введите имя', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final servicePricesToSend = <String, Map<String, dynamic>>{};
      for (final entry in _employeeServicePrices.entries) {
        final p = entry.value;
        if (p['price'] != null || p['is_free'] == true || p['duration'] != null || p['online_booking'] != null) {
          servicePricesToSend[entry.key.toString()] = {
            'price': (p['price'] ?? '').toString(),
            'is_free': p['is_free'] ?? false,
            'price_from': p['price_from'] ?? false,
            'duration': p['duration']?.toString(),
            'online_booking': p['online_booking'] ?? true,
          };
        }
      }

      final body = {
        'project_id': widget.projectId,
        'employee_id': widget.employee?['id'],
        'first_name': _firstNameCtrl.text.trim(),
        'last_name': _lastNameCtrl.text.trim(),
        'about': _aboutCtrl.text.trim(),
        'position': _positionCtrl.text.trim(),
        'phone': _getFullPhone(),
        'email': _emailCtrl.text.trim(),
        'category': _category == 'Не выбрано' ? '' : _category,
        'provides_services': _providesServices,
        'booking_color': _bookingColor,
        'notifications': _notifications,
        'service_ids': _employeeServiceIds.toList(),
        'employee_service_prices': servicePricesToSend,
      };
      
      final result = await ApiService.post('/api/employee/save', body);
      
      if (result['success'] == true && mounted) {
        final empId = result['employee_id'] ?? widget.employee?['id'];
        if (_avatarFile != null && empId != null) await _uploadAvatar(empId);
        if (!mounted) return;
        Navigator.pop(context);
        widget.onSaved();
        showToast(context, _isEdit ? 'Сотрудник обновлён' : 'Сотрудник добавлен');
      } else if (mounted) {
        final msg = result['message'] ?? 'Ошибка сохранения';
        showToast(context, msg, isError: true);
      }
    } catch (e) {
      if (mounted) showToast(context, 'Ошибка сохранения', isError: true);
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _uploadAvatar(int empId) async {
    final formData = http.MultipartRequest('POST', Uri.parse('$_baseUrl/api/employee-avatar/upload'));
    final prefs = await SharedPreferences.getInstance();
    final cookies = prefs.getString('saved_cookies');
    if (cookies != null) formData.headers['Cookie'] = cookies;
    formData.fields['employee_id'] = empId.toString();
    formData.fields['project_id'] = widget.projectId.toString();
    formData.files.add(await http.MultipartFile.fromPath('avatar', _avatarFile!.path));
    await formData.send();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800);
    if (picked != null) {
      setState(() { _avatarFile = File(picked.path); _avatarUrl = ''; });
    }
  }

  Future<void> _deleteAvatar() async {
    if (_isEdit && _avatarUrl.isNotEmpty) {
      await ApiService.post('/api/employee-avatar/delete', {'employee_id': widget.employee!['id'], 'project_id': widget.projectId});
    }
    setState(() { _avatarFile = null; _avatarUrl = ''; });
  }



  void _openNotificationsSettings() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (context, setModalState) {
        return SizedBox(height: MediaQuery.of(context).size.height * 0.6, child: Column(children: [
          Container(padding: const EdgeInsets.all(20), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))), child: Row(children: [
            GestureDetector(onTap: () => Navigator.pop(ctx), child: const Icon(Icons.arrow_back)),
            const Spacer(), const Text('Оповещения', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const Spacer(), GestureDetector(onTap: () => Navigator.pop(ctx), child: const Icon(Icons.close)),
          ])),
          Expanded(child: ListView(padding: const EdgeInsets.all(20), children: [
            const Text('Выберите, какие уведомления получать на email', style: TextStyle(fontSize: 14, color: Color(0xFF666666))),
            const SizedBox(height: 20),
            _buildNotifItem('Новая онлайн-запись', 'Уведомление при создании новой записи через онлайн', _notifyNewBooking, (v) => setModalState(() => _notifyNewBooking = v)),
            const SizedBox(height: 8),
            _buildNotifItem('Изменение записи клиентом', 'Клиент перенёс или изменил запись', _notifyBookingChange, (v) => setModalState(() => _notifyBookingChange = v)),
            const SizedBox(height: 8),
            _buildNotifItem('Отмена записи клиентом', 'Клиент отменил запись', _notifyBookingCancel, (v) => setModalState(() => _notifyBookingCancel = v)),
          ])),
          Container(padding: const EdgeInsets.all(20), decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF0F0F0)))), child: SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
            onPressed: () { setState(() { _notifications = {'new_booking': _notifyNewBooking, 'booking_change': _notifyBookingChange, 'booking_cancel': _notifyBookingCancel}; }); Navigator.pop(ctx); },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDD1847), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Сохранить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
          ))),
        ]));
      }),
    );
  }

  Widget _buildNotifItem(String title, String desc, bool value, ValueChanged<bool> onChanged) {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(16)), child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)), const SizedBox(height: 4), Text(desc, style: const TextStyle(fontSize: 13, color: Color(0xFF888888)))])),
      Switch(value: value, onChanged: onChanged, activeThumbColor: const Color(0xFFDD1847)),
    ]));
  }

  void _showOnlineSettings() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModalState) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.8, child: Column(children: [
          Container(padding: const EdgeInsets.all(16), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))), child: Row(children: [
            GestureDetector(onTap: () => Navigator.pop(ctx), child: const Icon(Icons.arrow_back)), const Spacer(),
            Column(children: [const Text('Онлайн-запись', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)), Text('${_firstNameCtrl.text} ${_lastNameCtrl.text}'.trim(), style: const TextStyle(fontSize: 12, color: Color(0xFF999999)))]),
            const Spacer(), GestureDetector(onTap: () => Navigator.pop(ctx), child: const Icon(Icons.close)),
          ])),
          Expanded(child: ListView(padding: const EdgeInsets.all(20), children: [
            _buildOnlineToggle('Онлайн-запись', 'Сотрудник участвует в онлайн-записи', _onlineEnabled, (v) => setModalState(() => _onlineEnabled = v)),
            const SizedBox(height: 24),
            _buildOnlineToggle('Минимальное время для записи', 'За сколько времени можно записаться', _minBookingTime['enabled'] == true, (v) => setModalState(() => _minBookingTime['enabled'] = v)),
            if (_minBookingTime['enabled'] == true) ...[
              const SizedBox(height: 8), Text('Нельзя записаться раньше чем за:', style: TextStyle(fontSize: 13, color: Colors.grey[600])), const SizedBox(height: 8),
              Row(children: [
                SizedBox(width: 70, child: TextField(controller: TextEditingController(text: _minBookingTime['value']?.toString() ?? '1'), keyboardType: TextInputType.number, textAlign: TextAlign.center, onChanged: (v) => _minBookingTime['value'] = int.tryParse(v) ?? 1, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(vertical: 10), isDense: true))),
                const SizedBox(width: 8),
                DropdownButton<String>(value: _minBookingTime['unit'] ?? 'hours', items: const [DropdownMenuItem(value: 'minutes', child: Text('Минут')), DropdownMenuItem(value: 'hours', child: Text('Часов')), DropdownMenuItem(value: 'days', child: Text('Дней'))], onChanged: (v) => setModalState(() => _minBookingTime['unit'] = v)),
              ]),
              const SizedBox(height: 8), _buildMbtPreview(),
            ],
            const SizedBox(height: 24),
            _buildOnlineToggle('Оптимальное время', 'Автоматически формирует интервалы времени для онлайн-записи на основе средней продолжительности популярных услуг', _optimalTimeEnabled, (v) { setModalState(() => _optimalTimeEnabled = v); if (v) _loadOptimalIntervals(); }),
            const SizedBox(height: 24),
            _buildOnlineToggle('Фиксированное время', _fixedTimeEnabled ? 'Включено' : 'Не настроено', _fixedTimeEnabled, (v) async {
              setModalState(() => _fixedTimeEnabled = v);
              try { await ApiService.post('/api/employee/save-fixed-time', {'employee_id': widget.employee!['id'], 'project_id': widget.projectId, 'enabled': v}); } catch (_) {}
            }, showSettings: true, onSettingsTap: () { Navigator.pop(ctx); _openFixedTimeSettings(); }),
          ])),
          Container(padding: const EdgeInsets.all(20), decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF0F0F0)))), child: SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
            onPressed: () => _saveOnlineSettings(ctx), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDD1847), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Сохранить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
          ))),
        ]),
      )),
    );
  }

  Widget _buildOnlineToggle(String title, String subtitle, bool value, ValueChanged<bool> onChanged, {bool showSettings = false, VoidCallback? onSettingsTap}) {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12)), child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)), const SizedBox(height: 2), Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF999999)))])),
      if (showSettings && onSettingsTap != null) TextButton(onPressed: onSettingsTap, child: Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.calendar_today, size: 14, color: Color(0xFFDD1847)), SizedBox(width: 4), Text('Настроить', style: TextStyle(color: Color(0xFFDD1847)))])),
      Switch(value: value, onChanged: onChanged, activeThumbColor: const Color(0xFFDD1847)),
    ]));
  }

  Widget _buildMbtPreview() {
    final value = _minBookingTime['value'] ?? 1;
    final unit = _minBookingTime['unit'] ?? 'hours';
    final now = DateTime.now();
    DateTime future = now;
    if (unit == 'minutes') {
      future = now.add(Duration(minutes: value));
    } else if (unit == 'hours') future = now.add(Duration(hours: value));
    else if (unit == 'days') future = now.add(Duration(days: value));
    final nowStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final futureStr = '${future.hour.toString().padLeft(2, '0')}:${future.minute.toString().padLeft(2, '0')}';
    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(10)), child: Text('Пример: если сейчас $nowStr, записаться можно с $futureStr', style: const TextStyle(fontSize: 13, color: Color(0xFF666666))));
  }

  void _openFixedTimeSettings() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => FixedTimeSettingsSheet(
        employeeId: widget.employee!['id'], projectId: widget.projectId,
        onSaved: () => setState(() => _fixedTimeEnabled = true),
      ),
    );
  }

  Future<void> _saveOnlineSettings(BuildContext ctx) async {
    try {
      await ApiService.post('/api/employee/save', {'employee_id': widget.employee!['id'], 'project_id': widget.projectId, 'first_name': _firstNameCtrl.text, 'last_name': _lastNameCtrl.text, 'is_active': _onlineEnabled});
      final settingsRes = await ApiService.get('/api/project-profile/get-online-settings?project_id=${widget.projectId}');
      Map<String, dynamic> allMbt = {};
      if (settingsRes['success'] == true) allMbt = Map<String, dynamic>.from(settingsRes['data']['min_booking_time'] ?? {});
      allMbt[widget.employee!['id'].toString()] = _minBookingTime;
      await ApiService.post('/api/project-profile/save-online-setting', {'project_id': widget.projectId, 'min_booking_time': allMbt});
      await ApiService.post('/api/employee/toggle-optimal-time', {'employee_id': widget.employee!['id'], 'project_id': widget.projectId, 'enabled': _optimalTimeEnabled});
      if (!mounted) return;
      setState(() {});
      Navigator.pop(context);
      showToast(context, 'Настройки сохранены');
    } catch (_) {}
  }

  void _openAccessSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => AccessFormSheet(
        projectId: widget.projectId,
        accessData: {
          'user_id': widget.employee!['id'],
          'first_name': _firstNameCtrl.text,
          'last_name': _lastNameCtrl.text,
          'phone': _getFullPhone(),
          'email': _emailCtrl.text,
        },
        onSaved: () {
          _loadAccessStatus();
        },
      ),
    );
  }

  void _openSchedule() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EmployeeScheduleScreen(
        employeeId: widget.employee!['id'],
        projectId: widget.projectId,
        employeeName: '${_firstNameCtrl.text} ${_lastNameCtrl.text}'.trim(),
      ),
    ));
  }

  // ========== ПИКЕР УСЛУГ С НАСТРОЙКАМИ ==========
  void _showServicePicker() async {
    if (_allServices.isEmpty) {
      final r = await ApiService.get('/api/service/list?project_id=${widget.projectId}');
      if (r['success'] == true) {
        _allServices = List<Map<String, dynamic>>.from(r['data'] ?? []);
        _filteredServices = List.from(_allServices);
      }
    }
    if (!mounted) return;
    
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => GestureDetector(
          onTap: () => FocusScope.of(ctx).unfocus(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.8,
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))),
                child: Column(children: [
                  Row(children: [
                    const Expanded(child: Text('Услуги сотрудника', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ]),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(10)),
                    child: TextField(
                      controller: _serviceSearchCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Поиск услуг...',
                        prefixIcon: Icon(Icons.search, size: 20, color: Color(0xFF999999)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: (val) {
                        _serviceSearchCtrl.text = val;
                        _filterServices();
                        setModalState(() {});
                      },
                    ),
                  ),
                ]),
              ),
              Expanded(
                child: _filteredServices.isEmpty
                    ? const Center(child: Text('Услуги не найдены', style: TextStyle(color: Color(0xFF999999))))
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: _filteredServices.map((s) {
                          final id = s['id'] is int ? s['id'] as int : int.tryParse(s['id']?.toString() ?? '') ?? 0;
                          final sel = _employeeServiceIds.contains(id);
                          final photo = s['photo_url']?.toString();
                          final price = double.tryParse(s['price']?.toString() ?? '0') ?? 0;
                          final duration = s['duration'] as int? ?? 0;
                          final prices = _employeeServicePrices[id] ?? {};
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: sel ? const Color(0xFFFDF2F5) : const Color(0xFFF8F8F8),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: sel ? const Color(0xFFDD1847) : const Color(0xFFE8E8E8), width: sel ? 2 : 1),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Основная строка с чекбоксом
                                InkWell(
                                  onTap: () => setModalState(() {
                                    if (sel) {
                                      _employeeServiceIds.remove(id);
                                      _employeeServicePrices.remove(id);
                                    } else {
                                      _employeeServiceIds.add(id);
                                    }
                                  }),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(children: [
                                      Container(
                                        width: 48, height: 48,
                                        decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)),
                                        clipBehavior: Clip.antiAlias,
                                        child: photo != null && photo.isNotEmpty
                                            ? CachedNetworkImage(imageUrl: '$_baseUrl$photo', fit: BoxFit.cover)
                                            : const Icon(Icons.spa, size: 20, color: Color(0xFF999999)),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          Text(s['name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 2),
                                          Text('${price > 0 ? '${price.toStringAsFixed(0)} руб' : 'Бесплатно'} · ${_formatDuration(duration)}', style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
                                        ]),
                                      ),
                                      Container(
                                        width: 24, height: 24,
                                        decoration: BoxDecoration(
                                          color: sel ? const Color(0xFFDD1847) : Colors.transparent,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: sel ? const Color(0xFFDD1847) : const Color(0xFFCCCCCC), width: 2),
                                        ),
                                        child: sel ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                                      ),
                                    ]),
                                  ),
                                ),
                                // Настройки (только если услуга выбрана)
                                if (sel) ...[
                                  const Divider(height: 1, color: Color(0xFFF0F0F0)),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      // Цена
                                      const Text('ЦЕНА', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF999999), letterSpacing: 0.5)),
                                      const SizedBox(height: 4),
                                      Row(children: [
                                        GestureDetector(
                                          onTap: () {
                                            _updateServicePriceFrom(id, !(prices['price_from'] ?? false));
                                            setModalState(() {});
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: (prices['price_from'] ?? false) ? const Color(0xFFDD1847) : Colors.white,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: (prices['price_from'] ?? false) ? const Color(0xFFDD1847) : const Color(0xFFE0E0E0)),
                                            ),
                                            child: Text('от', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: (prices['price_from'] ?? false) ? Colors.white : const Color(0xFF999999))),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        _PriceField(
                                          initialValue: (prices['price'] ?? '').toString(),
                                          enabled: !(prices['is_free'] ?? false),
                                          onChanged: (v) {
                                            _updateServicePrice(id, v);
                                          },
                                        ),
                                        const SizedBox(width: 4),
                                        const Text('руб', style: TextStyle(fontSize: 11, color: Color(0xFF999999))),
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () {
                                            _updateServiceFree(id, !(prices['is_free'] ?? false));
                                            setModalState(() {});
                                          },
                                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                                            Icon((prices['is_free'] ?? false) ? Icons.check_box : Icons.check_box_outline_blank, size: 16, color: const Color(0xFFDD1847)),
                                            const SizedBox(width: 3),
                                            const Text('Бесплатно', style: TextStyle(fontSize: 11, color: Color(0xFF666666))),
                                          ]),
                                        ),
                                      ]),
                                      
                                      // Длительность
                                      const SizedBox(height: 10),
                                      const Text('ДЛИТЕЛЬНОСТЬ', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF999999), letterSpacing: 0.5)),
                                      const SizedBox(height: 4),
                                      GestureDetector(
                                        onTap: () {
                                          _pickServiceDuration(id);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE8E8E8))),
                                          child: Row(children: [
                                            const Icon(Icons.access_time, size: 16, color: Color(0xFF999999)),
                                            const SizedBox(width: 6),
                                            Expanded(child: Text(prices['duration'] != null ? _formatDuration(int.tryParse(prices['duration'].toString()) ?? duration) : 'Общая: ${_formatDuration(duration)}', style: const TextStyle(fontSize: 12, color: Color(0xFF333333)))),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE0E0E0)), borderRadius: BorderRadius.circular(6)),
                                              child: Text(prices['duration'] != null ? 'Изменить' : 'Установить', style: const TextStyle(fontSize: 10, color: Color(0xFF666666))),
                                            ),
                                          ]),
                                        ),
                                      ),
                                      
                                      // Онлайн-запись
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE8E8E8))),
                                        child: Row(children: [
                                          const Text('Онлайн-запись', style: TextStyle(fontSize: 12, color: Color(0xFF666666))),
                                          const Spacer(),
                                          Switch(
                                            value: prices['online_booking'] ?? true,
                                            onChanged: (v) {
                                              _updateServiceOnlineBooking(id, v);
                                              setModalState(() {});
                                            },
                                            activeThumbColor: const Color(0xFFDD1847),
                                          ),
                                        ]),
                                      ),
                                    ]),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF0F0F0)))),
                child: SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {});
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDD1847), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('Сохранить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _pickWorkPhoto() async {
    if (!_isEdit) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final uri = Uri.parse('$_baseUrl/api/employee-photo/upload');
      final request = http.MultipartRequest('POST', uri);
      
      final cookies = await SharedPreferences.getInstance().then((prefs) => prefs.getString('saved_cookies'));
      if (cookies != null) {
        request.headers['Cookie'] = cookies;
      }
      
      request.fields['employee_id'] = widget.employee!['id'].toString();
      request.fields['project_id'] = widget.projectId.toString();
      request.files.add(await http.MultipartFile.fromPath('photo', picked.path));
      final res = await request.send();
      final body = await res.stream.bytesToString();
      final result = jsonDecode(body);
      if (result['success'] == true) {
        _photos.add({'id': result['data']['id'], 'photo_url': result['data']['photo_url']});
        setState(() {});
      } else {
        if (mounted) {
          showToast(context, result['message'] ?? 'Ошибка загрузки', isError: true);
        }
      }
    }
  }

  Future<void> _deletePhoto(Map<String, dynamic> photo) async {
    final photoId = photo['id'];
    final result = await ApiService.post('/api/employee-photo/delete', {
      'photo_id': photoId,
      'project_id': widget.projectId,
    });
    if (result['success'] == true) {
      setState(() => _photos.remove(photo));
    }
  }

  Widget _buildColorPicker() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Цвет записей', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)), const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: _colors.map((c) => GestureDetector(
        onTap: () => setState(() => _bookingColor = c),
        child: Container(width: 36, height: 36, decoration: BoxDecoration(color: Color(int.parse('FF${c.substring(1)}', radix: 16)), borderRadius: BorderRadius.circular(10), border: Border.all(color: _bookingColor == c ? Colors.black : Colors.transparent, width: 2.5), boxShadow: [BoxShadow(color: _bookingColor == c ? Color(int.parse('FF${c.substring(1)}', radix: 16)).withValues(alpha: 0.4) : Colors.transparent, blurRadius: 8, spreadRadius: 1)]), child: _bookingColor == c ? const Center(child: Icon(Icons.check, color: Colors.white, size: 16)) : null),
      )).toList()),
    ]);
  }

  void _showCategoryPicker() {
    showModalBottomSheet(context: context, backgroundColor: Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (ctx) => SizedBox(height: MediaQuery.of(context).size.height * 0.5, child: Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: Row(children: [const Expanded(child: Text('Выберите категорию', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx))])),
      Expanded(child: ListView(children: _categories.map((cat) => ListTile(title: Text(cat), trailing: _category == cat ? const Icon(Icons.check, color: Color(0xFFDD1847)) : null, onTap: () { setState(() => _category = cat); Navigator.pop(ctx); })).toList())),
    ])));
  }

  Widget _buildSelectRow(String label, String value, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12)), child: Row(children: [Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)), const Spacer(), Text(value, style: const TextStyle(fontSize: 14, color: Color(0xFF888888))), const SizedBox(width: 8), const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC), size: 20)])));
  }

  Widget _buildToggleRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12)), child: Row(children: [Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)), const Spacer(), Switch(value: value, onChanged: onChanged, activeThumbColor: const Color(0xFFDD1847))]));
  }

  Widget _buildDeleteButton() {
    return SizedBox(width: double.infinity, child: OutlinedButton.icon(
      onPressed: () async {
        final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Удалить сотрудника?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить', style: TextStyle(color: Colors.red)))]));
        if (confirm == true) {
          final result = await ApiService.post('/api/employee/delete', {
            'employee_id': widget.employee!['id'], 
            'project_id': widget.projectId
          });
          if (mounted && result['success'] == true) {
            Navigator.pop(context);
            widget.onSaved();
            showToast(context, 'Сотрудник удалён');
          } else if (mounted) {
            showToast(context, result['message'] ?? 'Ошибка удаления', isError: true);
          }
        }
      },
      icon: const Icon(Icons.delete_outline, size: 18), label: const Text('Удалить сотрудника'),
      style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFF44336), side: const BorderSide(color: Color(0xFFF44336)), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    ));
  }

  Widget _field(TextEditingController ctrl, String hint, {TextInputType? keyboardType, int maxLines = 1}) {
    return TextField(controller: ctrl, keyboardType: keyboardType, maxLines: maxLines, decoration: InputDecoration(hintText: hint, filled: true, fillColor: const Color(0xFFF8F8F8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE0E0E0))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE0E0E0))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDD1847))), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)));
  }

  Widget _buildPhotosSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Фото работ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), const SizedBox(height: 10),
      Wrap(spacing: 10, runSpacing: 10, children: [
        ..._photos.map((p) => ClipRRect(borderRadius: BorderRadius.circular(16), child: Container(width: 100, height: 100, decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE0E0E0), width: 1), borderRadius: BorderRadius.circular(16)), child: Stack(fit: StackFit.expand, children: [
          ClipRRect(borderRadius: BorderRadius.circular(15), child: CachedNetworkImage(imageUrl: '$_baseUrl${p['photo_url'] ?? p['url']}', fit: BoxFit.cover)),
          Positioned(top: 6, right: 6, child: GestureDetector(onTap: () => _deletePhoto(p), child: Container(width: 24, height: 24, decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 14)))),
        ])))),
        if (_photos.length < 6) GestureDetector(onTap: _pickWorkPhoto, child: Container(width: 100, height: 100, decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE0E0E0), width: 2), borderRadius: BorderRadius.circular(16), color: const Color(0xFFF8F8F8)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add, size: 24, color: Colors.grey[400]), const SizedBox(height: 4), Text('Добавить\nфото', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey[500]))]))),
      ]),
    ]);
  }

  Widget _buildPhoneField() {
    return PhoneInput(
      key: _phoneKey,
      controller: _phoneCtrl,
      onPhoneChanged: (_) => setState(() {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return SizedBox(height: MediaQuery.of(context).size.height * 0.85, child: const Center(child: CircularProgressIndicator()));
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SizedBox(height: MediaQuery.of(context).size.height * 0.9, child: Column(children: [
        Container(padding: const EdgeInsets.all(16), decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20)), border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))), child: Row(children: [
          GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.arrow_back)), const Spacer(),
          const Text('Профиль сотрудника', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)), const Spacer(),
          GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close)),
        ])),
        Expanded(
          child: ListView(padding: const EdgeInsets.all(20), children: [
            Row(children: [
              GestureDetector(onTap: _pickAvatar, child: Stack(clipBehavior: Clip.none, children: [
                Container(width: 80, height: 80, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFF0F0F0), border: Border.all(color: Colors.white, width: 3), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12)]), child: ClipOval(child: _avatarFile != null ? Image.file(_avatarFile!, fit: BoxFit.cover) : _avatarUrl.isNotEmpty ? CachedNetworkImage(imageUrl: '$_baseUrl$_avatarUrl', fit: BoxFit.cover) : Center(child: Text(_initials, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: Color(0xFFDD1847)))))),
                if (_avatarFile != null || _avatarUrl.isNotEmpty) Positioned(bottom: -5, right: -5, child: GestureDetector(onTap: _deleteAvatar, child: Container(width: 28, height: 28, decoration: BoxDecoration(color: const Color(0xFFF44336), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)), child: const Icon(Icons.close, color: Colors.white, size: 14)))),
              ])),
              const SizedBox(width: 16),
              Expanded(child: Column(children: [_field(_firstNameCtrl, 'Имя'), const SizedBox(height: 8), _field(_lastNameCtrl, 'Фамилия')])),
            ]),
            const SizedBox(height: 20), _field(_aboutCtrl, 'Расскажите о сотруднике...', maxLines: 3), const SizedBox(height: 20),
            _buildPhotosSection(), const SizedBox(height: 20),
            _buildSelectRow('Категория', _category, _showCategoryPicker), const SizedBox(height: 20),
            _field(_positionCtrl, 'Должность'), const SizedBox(height: 20),
            _buildPhoneField(), const SizedBox(height: 20),
            _field(_emailCtrl, 'Email', keyboardType: TextInputType.emailAddress), const SizedBox(height: 20),
            if (_isEdit) ...[
              _buildSelectRow('Доступ', _accessStatus, _openAccessSettings),
              const SizedBox(height: 20),
              _buildSelectRow('График', _scheduleStatus, _openSchedule),
              const SizedBox(height: 20),
              _buildSelectRow('Онлайн-запись', _onlineEnabled ? 'Включена' : 'Выключена', _showOnlineSettings),
              const SizedBox(height: 20),
            ],
            _buildSelectRow('Оповещения', _getNotificationsStatus(), _openNotificationsSettings), const SizedBox(height: 20),
            _buildToggleRow('Оказывает услуги', _providesServices, (v) => setState(() => _providesServices = v)), const SizedBox(height: 20),
            if (_isEdit)
              _buildSelectRow('Услуги', _employeeServiceIds.isEmpty ? 'Не выбрано' : 'Выбрано: ${_employeeServiceIds.length}', _showServicePicker),
            const SizedBox(height: 20),
            _buildColorPicker(), const SizedBox(height: 20),
            if (_isEdit) _buildDeleteButton(),
          ]),
        ),
        Container(padding: const EdgeInsets.all(20), decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFF0F0F0)))), child: SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
          onPressed: _saving ? null : _save, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDD1847), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(_isEdit ? 'Сохранить' : 'Добавить сотрудника', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
        ))),
      ])),
    );
  }
}

// ========== ВИДЖЕТ КОЛЁСИКА ВРЕМЕНИ ==========
class _TimeWheelPicker extends StatefulWidget {
  final int initialMinutes;
  final String title;
  final ValueChanged<int> onSelected;
  
  const _TimeWheelPicker({
    required this.initialMinutes,
    required this.title,
    required this.onSelected,
  });

  @override
  State<_TimeWheelPicker> createState() => _TimeWheelPickerState();
}

class _TimeWheelPickerState extends State<_TimeWheelPicker> {
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  int _selectedHour = 0;
  int _selectedMinute = 0;

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.initialMinutes ~/ 60;
    _selectedMinute = widget.initialMinutes % 60;
    _hourController = FixedExtentScrollController(initialItem: _selectedHour);
    _minuteController = FixedExtentScrollController(initialItem: _selectedMinute ~/ 5);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        height: 340,
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Row(children: [
            Expanded(child: Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
          ]),
          const SizedBox(height: 20),
          Expanded(
            child: Row(children: [
              Expanded(child: Column(children: [
                const Text('Часы', style: TextStyle(fontSize: 14, color: Color(0xFF999999))),
                const SizedBox(height: 8),
                Expanded(
                  child: ListWheelScrollView.useDelegate(
                    controller: _hourController,
                    itemExtent: 40,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: (v) => setState(() => _selectedHour = v),
                    childDelegate: ListWheelChildBuilderDelegate(
                      builder: (context, index) => Center(child: Text('$index', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: _selectedHour == index ? const Color(0xFFDD1847) : const Color(0xFF333333)))),
                      childCount: 13,
                    ),
                  ),
                ),
              ])),
              const SizedBox(width: 16),
              Expanded(child: Column(children: [
                const Text('Минуты', style: TextStyle(fontSize: 14, color: Color(0xFF999999))),
                const SizedBox(height: 8),
                Expanded(
                  child: ListWheelScrollView.useDelegate(
                    controller: _minuteController,
                    itemExtent: 40,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: (v) => setState(() => _selectedMinute = v * 5),
                    childDelegate: ListWheelChildBuilderDelegate(
                      builder: (context, index) => Center(child: Text((index * 5).toString().padLeft(2, '0'), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: _selectedMinute == index * 5 ? const Color(0xFFDD1847) : const Color(0xFF333333)))),
                      childCount: 12,
                    ),
                  ),
                ),
              ])),
            ]),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: () => widget.onSelected(_selectedHour * 60 + _selectedMinute),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDD1847), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Сохранить', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }
}