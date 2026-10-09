import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import '../../../widgets/skeletons.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/toast.dart';

class BookingViewSheet extends StatefulWidget {
  final int bookingId;
  final VoidCallback? onSaved;
  const BookingViewSheet({super.key, required this.bookingId, this.onSaved});

  @override
  State<BookingViewSheet> createState() => _BookingViewSheetState();
}

class _BookingViewSheetState extends State<BookingViewSheet> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _status;
  String? _attendance;
  String _color = '#DD1847';
  bool _confirmedByClient = false;
  int _breakAfter = 0;
  final _commentCtrl = TextEditingController();
  List<int> _selectedServiceIds = [];
  List<String> _selectedReminders = [];
  String _selectedReview = 'none';
  bool _confirmRequired = false;

  static const _colors = ['#DD1847', '#E91E63', '#9C27B0', '#2196F3', '#4CAF50', '#FF9800', '#607D8B'];

  static const _reminderOptions = [
    {'value': 'none', 'label': 'Нет'},
    {'value': '1h', 'label': 'За час'},
    {'value': '3h', 'label': 'За 3 часа'},
    {'value': '6h', 'label': 'За 6 часов'},
    {'value': '12h', 'label': 'За 12 часов'},
    {'value': '1d', 'label': 'За день'},
    {'value': '3d', 'label': 'За 3 дня'},
  ];

  static const _reviewOptions = [
    {'value': 'none', 'label': 'Нет'},
    {'value': '1h', 'label': 'Через час'},
    {'value': '3h', 'label': 'Через 3 часа'},
    {'value': '6h', 'label': 'Через 6 часов'},
    {'value': '12h', 'label': 'Через 12 часов'},
    {'value': '1d', 'label': 'Через день'},
    {'value': '2d', 'label': 'Через 2 дня'},
    {'value': '3d', 'label': 'Через 3 дня'},
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  void _load() async {
  try {
    final result = await ApiService.get('/api/booking/get?booking_id=${widget.bookingId}');
    if (result['success'] == true && mounted) {
      final d = result['data'];
      
      List<Map<String, dynamic>> services = [];
      
      if (d['services'] is List && (d['services'] as List).isNotEmpty) {
        services = List<Map<String, dynamic>>.from(d['services']);
      } else {
        final serviceIdsStr = d['service_ids']?.toString() ?? '';
        final serviceNamesStr = d['service_names']?.toString() ?? '';
        
        if (serviceIdsStr.isNotEmpty && serviceNamesStr.isNotEmpty) {
          final ids = serviceIdsStr.split(',').map((s) => int.tryParse(s.trim()) ?? 0).toList();
          final names = serviceNamesStr.split(',').map((s) => s.trim()).toList();
          
          for (int i = 0; i < ids.length && i < names.length; i++) {
            services.add({
              'id': ids[i],
              'name': names[i],
              'price': d['total_price'] ?? 0,
              'duration': d['total_duration'] ?? 0,
            });
          }
        }
      }
      
      setState(() {
        _data = d;
        _data!['services'] = services;
        _status = d['status'];
        _attendance = d['attendance'];
        _color = d['color'] ?? '#DD1847';
        _confirmedByClient = d['confirmed_by_client'] == true || d['confirmed_by_client'] == 1;
        _breakAfter = int.tryParse(d['break_after']?.toString() ?? '0') ?? 0;
        _commentCtrl.text = d['comment'] ?? '';
        _selectedServiceIds = services.map((s) => s['id'] as int).toList();
        _selectedReminders = (d['reminders'] as List?)?.cast<String>() ?? [];
        _selectedReview = d['review_request'] ?? 'none';
        _confirmRequired = d['confirm_required'] == true || d['confirm_required'] == 1;
        _loading = false;
      });
    }
  } catch (e) {
    debugPrint('Ошибка загрузки записи: $e');
    if (mounted) setState(() => _loading = false);
  }
}

  void _save() async {
  if (_data == null) return;
  try {
    final result = await ApiService.updateBooking(
      bookingId: widget.bookingId,
      projectId: _data!['project_id'] ?? 0,
      status: _status,
      attendance: _attendance,
      color: _color,
      comment: _commentCtrl.text,
      breakAfter: _breakAfter,
      confirmedByClient: _confirmedByClient,
      reminders: _selectedReminders,
      reviewRequest: _selectedReview,
      confirmRequired: _confirmRequired,
      serviceIds: _selectedServiceIds,
    );
    if (result['success'] == true && mounted) {
      Navigator.pop(context);
      widget.onSaved?.call();
      showToast(context, 'Сохранено!');
    }
  } catch (e) {
    debugPrint('Ошибка сохранения: $e');
    if (mounted) showToast(context, 'Ошибка сохранения', isError: true);
  }
}

  void _cancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Отменить запись?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Нет')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Да, отменить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true || _data == null) return;
    try {
      await ApiService.deleteBooking(widget.bookingId, _data!['project_id'] ?? 0);
      if (mounted) {
        widget.onSaved?.call();
        Navigator.pop(context);
        showToast(context, 'Запись отменена');
      }
    } catch (_) {
      if (mounted) showToast(context, 'Ошибка отмены', isError: true);
    }
  }

  void _openDatetimeModal() {
    final empId = _data!['master_id'] as int;
    final date = DateTime.tryParse(_data!['date'] ?? '') ?? DateTime.now();
    final time = (_data!['start_time'] as String).substring(0, 5);
    
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _DatetimePickerPage(
          projectId: _data!['project_id'] ?? 0,
          selectedDate: date,
          selectedEmployeeId: empId,
          selectedTime: time,
          serviceIds: _selectedServiceIds,
          onSelected: (newDate, newEmpId, newTime) {
            setState(() {
              _data!['date'] = DateFormat('yyyy-MM-dd').format(newDate);
              _data!['start_time'] = '$newTime:00';
              _data!['master_id'] = newEmpId;
            });
          },
        ),
      ),
    );
  }

  void _openServicesModal() async {
    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ServicesPicker(
        projectId: _data!['project_id'] ?? 0,
        selectedIds: _selectedServiceIds.toSet(),
      ),
    );
    
    if (result != null && result.isNotEmpty) {
      final servicesResult = await ApiService.get('/api/service/list?project_id=${_data!['project_id'] ?? 0}');
      if (servicesResult['success'] == true) {
        final allServices = List<Map<String, dynamic>>.from(servicesResult['data'] ?? []);
        final selectedServices = allServices.where((s) => result.contains(s['id'])).toList();
        
        setState(() {
          _data!['services'] = selectedServices;
          _selectedServiceIds = result.toList();
        });
      }
    }
  }

  void _openReminderModal() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ReminderPicker(
        selectedReminders: _selectedReminders,
        confirmRequired: _confirmRequired,
      ),
    );
    
    if (result != null) {
      setState(() {
        _selectedReminders = (result['reminders'] as List<String>?) ?? [];
        _confirmRequired = result['confirm_required'] ?? false;
      });
    }
  }

  void _openReviewModal() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ReviewPicker(selectedReview: _selectedReview),
    );
    
    if (result != null) {
      setState(() => _selectedReview = result);
    }
  }

  String _getReminderLabel() {
    if (_selectedReminders.isEmpty) return 'Нет';
    final labels = {'1h': 'За час', '3h': 'За 3 часа', '6h': 'За 6 часов', '12h': 'За 12 часов', '1d': 'За день', '3d': 'За 3 дня'};
    return _selectedReminders.map((t) => labels[t] ?? t).join(', ');
  }

  String _getReviewLabel() {
    final option = _reviewOptions.firstWhere((o) => o['value'] == _selectedReview, orElse: () => _reviewOptions[0]);
    return option['label'] ?? 'Нет';
  }

  @override
Widget build(BuildContext context) {
  if (_loading) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SkeletonCircle(size: 48),
            SizedBox(height: 16),
            SkeletonBox(height: 14, width: 120),
          ],
        ),
      ),
    );
  }
    final d = _data!;
    final services = d['services'] as List? ?? [];
    final avatar = d['master_avatar'];

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [const Spacer(), const Text('Запись', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)), const Spacer(), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))]),
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.symmetric(horizontal: 20), children: [
            // 1. Клиент
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFF9F9F9), borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                Row(children: [
                  CircleAvatar(radius: 22, backgroundColor: const Color(0xFFFDF2F5), child: Text(_initials(d['client_name'] ?? '?'), style: const TextStyle(color: Color(0xFFDD1847), fontWeight: FontWeight.w700))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(d['client_name'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)), Text(d['client_phone'] ?? '', style: const TextStyle(fontSize: 13, color: Color(0xFF888888)))])),
                  PopupMenuButton(
                    icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                    itemBuilder: (_) => [
                      PopupMenuItem(child: Row(children: [Icon(Icons.phone, size: 18, color: Colors.grey[700]), const SizedBox(width: 8), const Text('Позвонить')]), onTap: () {}),
                      PopupMenuItem(child: Row(children: [Icon(Icons.sms, size: 18, color: Colors.grey[700]), const SizedBox(width: 8), const Text('SMS')]), onTap: () {}),
                    ],
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  _statusBtn('✓ Подтвердил', _confirmedByClient, () => setState(() => _confirmedByClient = !_confirmedByClient)),
                  const SizedBox(width: 6),
                  _statusBtn('Пришёл', _attendance == 'arrived', () => setState(() => _attendance = _attendance == 'arrived' ? null : 'arrived')),
                  const SizedBox(width: 6),
                  _statusBtn('Не пришёл', _attendance == 'no_show', () => setState(() => _attendance = _attendance == 'no_show' ? null : 'no_show'), isRed: true),
                ]),
              ]),
            ),
            const SizedBox(height: 16),
            
            // 2. Сотрудник
            _sectionTitle('Сотрудник'),
            GestureDetector(
              onTap: _openDatetimeModal,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF0F0F0))),
                child: Row(children: [
                  CachedAvatar(url: avatar, size: 48, radius: 24),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(d['master_name'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)), if (d['master_position'] != null) Text(d['master_position'], style: const TextStyle(fontSize: 12, color: Color(0xFF888888)))])),
                  const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC)),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            
            // 3. Время
            _sectionTitle('Время'),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF0F0F0))),
              child: Column(children: [
                ListTile(
                  title: const Text('Дата и время', style: TextStyle(fontSize: 14, color: Color(0xFF666666))),
                  trailing: Text('${d['date']} ${(d['start_time'] as String).substring(0, 5)} – ${(d['end_time'] as String).substring(0, 5)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  onTap: _openDatetimeModal,
                ),
                ListTile(
                  title: const Text('Перерыв после записи', style: TextStyle(fontSize: 14, color: Color(0xFF666666))),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(_breakAfter > 0 ? '$_breakAfter мин' : 'Нет', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, size: 20, color: Color(0xFFCCCCCC)),
                  ]),
                  onTap: () => _showBreakPicker(),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            
            // 4. Услуги
            Row(children: [
              _sectionTitle('Услуги'),
              const Spacer(),
              TextButton.icon(
                onPressed: _openServicesModal,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Добавить услугу'),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFFDD1847)),
              ),
            ]),
            ...services.map((s) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.grey[200]),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedAvatar(url: s['photo_url'], size: 40, radius: 8),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s['name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  Text('${s['price'] ?? 0} ₽ · ${_formatDuration(s['duration'] ?? 0)}', style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
                ])),
              ]),
            )),
            const SizedBox(height: 16),
            
            // 5. Уведомления
            _sectionTitle('Уведомления'),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF0F0F0))),
              child: Column(children: [
                InkWell(
                  onTap: _openReminderModal,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(children: [
                      const Expanded(child: Text('Напоминание', style: TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)))),
                      Text(_getReminderLabel(), style: const TextStyle(fontSize: 14, color: Color(0xFF888888))),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, size: 20, color: Color(0xFFCCCCCC)),
                    ]),
                  ),
                ),
                const Divider(height: 1),
                InkWell(
                  onTap: _openReviewModal,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(children: [
                      const Expanded(child: Text('Запрос отзыва', style: TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)))),
                      Text(_getReviewLabel(), style: const TextStyle(fontSize: 14, color: Color(0xFF888888))),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, size: 20, color: Color(0xFFCCCCCC)),
                    ]),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            
            // 6. Цвет
            _sectionTitle('Цвет закраски'),
            Wrap(spacing: 8, children: _colors.map((c) => GestureDetector(
              onTap: () => setState(() => _color = c),
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: Color(int.parse('FF${c.substring(1)}', radix: 16)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _color == c ? Colors.black : Colors.transparent, width: 2.5),
                ),
                child: _color == c ? const Center(child: Icon(Icons.check, color: Colors.white, size: 16)) : null,
              ),
            )).toList()),
            const SizedBox(height: 16),
            
            // 7. Примечание
_sectionTitle('Примечание'),
TextField(
  controller: _commentCtrl,
  maxLines: 3,
  style: const TextStyle(
    fontSize: 14,
    color: Color(0xFF1A1A1A),
  ),
  decoration: InputDecoration(
    hintText: 'Примечание...',
    hintStyle: const TextStyle(
      color: Color(0xFF999999),
      fontSize: 14,
    ),
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFDD1847)),
    ),
    contentPadding: const EdgeInsets.all(14),
  ),
),
            const SizedBox(height: 16),
            
            // Отменить
            SizedBox(width: double.infinity, child: OutlinedButton(
              onPressed: _cancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Отменить запись'),
            )),
          ]),
        ),
        Padding(padding: const EdgeInsets.all(20), child: SizedBox(width: double.infinity, height: 52, child: ElevatedButton(onPressed: _save, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDD1847), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Сохранить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white))))),
      ]),
    );
  }

  String _initials(String name) => name.split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join().toUpperCase();

  Widget _sectionTitle(String title) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF888888))));

  String _formatDuration(int minutes) {
    if (minutes == 0) return '0 мин';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '$h ч $m мин';
    if (h > 0) return '$h ч';
    return '$m мин';
  }

  Widget _statusBtn(String label, bool active, VoidCallback onTap, {bool isRed = false}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? (isRed ? const Color(0xFFFCE4E4) : const Color(0xFFD4EDDA)) : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: active ? (isRed ? const Color(0xFFF44336) : const Color(0xFF4CAF50)) : const Color(0xFFE0E0E0)),
          ),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: active ? (isRed ? const Color(0xFFC62828) : const Color(0xFF2E7D32)) : Colors.black)),
        ),
      ),
    );
  }

  void _showBreakPicker() {
    final options = [0, 5, 10, 15, 20, 30, 45, 60, 90, 120];
    showModalBottomSheet(
      context: context, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Перерыв после записи', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Wrap(spacing: 8, children: options.map((m) => GestureDetector(
            onTap: () { setState(() => _breakAfter = m); Navigator.pop(context); },
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(color: _breakAfter == m ? const Color(0xFFFDF2F5) : const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12), border: Border.all(color: _breakAfter == m ? const Color(0xFFDD1847) : Colors.transparent)), child: Text(m == 0 ? 'Нет' : '$m мин')),
          )).toList()),
        ]),
      ),
    );
  }
}

// ==================== СТРАНИЦА ВЫБОРА ДАТЫ/ВРЕМЕНИ ====================
class _DatetimePickerPage extends StatefulWidget {
  final int projectId;
  final DateTime selectedDate;
  final int selectedEmployeeId;
  final String selectedTime;
  final List<int> serviceIds;
  final Function(DateTime, int, String) onSelected;

  const _DatetimePickerPage({
    required this.projectId,
    required this.selectedDate,
    required this.selectedEmployeeId,
    required this.selectedTime,
    required this.serviceIds,
    required this.onSelected,
  });

  @override
  State<_DatetimePickerPage> createState() => _DatetimePickerPageState();
}

class _DatetimePickerPageState extends State<_DatetimePickerPage> {
  late DateTime _date;
  late int _empId;
  late String _time;
  List<Map<String, dynamic>> _employees = [];
  Map<int, List<Map<String, dynamic>>> _occupiedByEmployee = {};
  bool _loadingEmployees = true;
  final _datesScrollController = ScrollController();
  final List<DateTime> _dates = [];
  int _totalServiceDuration = 0;

  @override
  void initState() {
    super.initState();
    _date = widget.selectedDate;
    _empId = widget.selectedEmployeeId;
    _time = widget.selectedTime;
    _generateDates();
    _loadEmployees();
    
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelectedDate());
  }

  void _generateDates() {
    _dates.clear();
    final start = DateTime(_date.year, _date.month, _date.day - 7);
    for (int i = 0; i < 30; i++) {
      _dates.add(DateTime(start.year, start.month, start.day + i));
    }
  }

  void _scrollToSelectedDate() {
    final index = _dates.indexWhere((d) => 
      d.year == _date.year && d.month == _date.month && d.day == _date.day);
    if (index >= 0 && _datesScrollController.hasClients) {
      final viewportWidth = _datesScrollController.position.viewportDimension;
      final targetOffset = (index * 64.0) - (viewportWidth / 2) + 32;
      _datesScrollController.jumpTo(targetOffset.clamp(0.0, _datesScrollController.position.maxScrollExtent));
    }
  }

  void _loadEmployees() async {
    setState(() => _loadingEmployees = true);
    
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_date);
      final scheduleResult = await ApiService.get(
        '/api/employee/schedule/list-for-date?project_id=${widget.projectId}&date=$dateStr');
      
      List<Map<String, dynamic>> emps = [];
      if (scheduleResult['success'] == true) {
        emps = List<Map<String, dynamic>>.from(scheduleResult['data'] ?? []);
      }
      
      final occupiedFutures = emps.map((e) async {
        final result = await ApiService.get(
          '/api/occupied-time/list?project_id=${widget.projectId}&date=$dateStr&employee_id=${e['id']}');
        return {
          'empId': e['id'],
          'occupied': result['success'] == true 
            ? List<Map<String, dynamic>>.from(result['data'] ?? [])
            : [],
        };
      }).toList();
      
      final occupiedResults = await Future.wait(occupiedFutures);
      final occupiedMap = <int, List<Map<String, dynamic>>>{};
      for (final r in occupiedResults) {
        occupiedMap[r['empId'] as int] = r['occupied'] as List<Map<String, dynamic>>;
      }
      
      int totalDuration = 0;
      if (widget.serviceIds.isNotEmpty) {
        final servicesResult = await ApiService.get('/api/service/list?project_id=${widget.projectId}');
        if (servicesResult['success'] == true) {
          final allServices = List<Map<String, dynamic>>.from(servicesResult['data'] ?? []);
          for (final s in allServices) {
            if (widget.serviceIds.contains(s['id'])) {
              totalDuration += (s['duration'] as int?) ?? 0;
            }
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _employees = emps;
          _occupiedByEmployee = occupiedMap;
          _totalServiceDuration = totalDuration;
          _loadingEmployees = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingEmployees = false);
    }
  }

  bool _hasWorkingEmployees() {
    return _employees.any((e) => e['is_working'] != false);
  }

  bool _isSlotOccupied(int empId, String time) {
    final occupied = _occupiedByEmployee[empId] ?? [];
    final timeMin = _timeToMin(time);
    final duration = _totalServiceDuration > 0 ? _totalServiceDuration : 30;
    final timeEnd = timeMin + duration;
    
    for (final o in occupied) {
      final startMin = _timeToMin((o['start_time'] as String).substring(0, 5));
      final endMin = _timeToMin((o['end_time'] as String).substring(0, 5));
      if (timeMin < endMin && timeEnd > startMin) return true;
    }
    
    if (timeMin + duration > 21 * 60) return true;
    
    return false;
  }

  int _timeToMin(String time) {
    final parts = time.split(':');
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  String _minToTime(int min) {
    return '${(min ~/ 60).toString().padLeft(2, '0')}:${(min % 60).toString().padLeft(2, '0')}';
  }

  void _selectTime(int empId, String time) {
    _empId = empId;
    _time = time;
    widget.onSelected(_date, _empId, _time);
    Navigator.pop(context);
  }

  void _openCalendarPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CalendarPicker(
        selectedDate: _date,
        onDateSelected: (date) {
          Navigator.pop(context);
          setState(() {
            _date = date;
            _loadingEmployees = true;
          });
          _loadEmployees();
        },
      ),
    );
  }

  Widget _buildNoOneWorks() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📅', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            const Text(
              'Никто не работает',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Выберите другой день или измените график работы.',
              style: TextStyle(fontSize: 14, color: Color(0xFF888888), height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDD1847),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Изменить график работы', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _datesScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final months = ['', 'янв.', 'фев.', 'мар.', 'апр.', 'мая', 'июн.', 'июл.', 'авг.', 'сен.', 'окт.', 'ноя.', 'дек.'];
    final days = ['', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
        title: const Text('Дата и время', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [IconButton(icon: const Icon(Icons.close, color: Colors.black), onPressed: () => Navigator.pop(context))],
      ),
      body: Column(children: [
        SizedBox(
          height: 72,
          child: Row(children: [
            IconButton(icon: const Icon(Icons.calendar_today, size: 20, color: Color(0xFF666666)), onPressed: () => _openCalendarPicker()),
            Expanded(
              child: ListView.builder(
                controller: _datesScrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(right: 16),
                itemCount: _dates.length,
                itemBuilder: (_, i) {
                  final d = _dates[i];
                  final sel = d.year == _date.year && d.month == _date.month && d.day == _date.day;
                  final isWeekend = d.weekday == 6 || d.weekday == 7;
                  return GestureDetector(
                    onTap: () { setState(() { _date = d; _loadingEmployees = true; }); _loadEmployees(); },
                    child: Container(
                      width: 60, margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(color: sel ? const Color(0xFFDD1847) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('${d.day} ${days[d.weekday]}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: sel ? Colors.white : (isWeekend ? const Color(0xFFDD1847) : Colors.black))),
                        Text(months[d.month], style: TextStyle(fontSize: 11, color: sel ? Colors.white70 : Colors.grey)),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(DateFormat('d MMMM yyyy', 'ru').format(_date), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: _loadingEmployees
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SkeletonCircle(size: 40),
                      SizedBox(height: 12),
                      SkeletonBox(height: 14, width: 140),
                    ],
                  ),
                )
              : _employees.isEmpty
                  ? _buildNoOneWorks()
                  : !_hasWorkingEmployees()
                      ? _buildNoOneWorks()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _employees.length,
                          itemBuilder: (_, i) {
                            final e = _employees[i];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12)),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  CachedAvatar(url: e['avatar'], size: 36, radius: 18),
                                  const SizedBox(width: 10),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(e['name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                    if (e['position'] != null) Text(e['position'], style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
                                  ])),
                                ]),
                                const SizedBox(height: 10),
                                Wrap(spacing: 6, runSpacing: 6, children: List.generate(14, (h) {
                                  final time = '${(8 + h).toString().padLeft(2, '0')}:00';
                                  final isSelected = _empId == e['id'] && _time == time;
                                  final isOccupied = _isSlotOccupied(e['id'] as int, time);
                                  return GestureDetector(
                                    onTap: isOccupied ? null : () => _selectTime(e['id'] as int, time),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFFDD1847) : (isOccupied ? Colors.grey[300] : Colors.white),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: isSelected ? const Color(0xFFDD1847) : (isOccupied ? Colors.transparent : const Color(0xFFE0E0E0))),
                                      ),
                                      child: Text(
                                        time + (_totalServiceDuration > 0 ? '–${_minToTime(_timeToMin(time) + _totalServiceDuration)}' : ''),
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isSelected ? Colors.white : (isOccupied ? Colors.grey : Colors.black), decoration: isOccupied ? TextDecoration.lineThrough : null),
                                      ),
                                    ),
                                  );
                                })),
                              ]),
                            );
                          },
                        ),
        ),
      ]),
    );
  }
}

// ==================== ПИКЕР УСЛУГ ====================
class _ServicesPicker extends StatefulWidget {
  final int projectId;
  final Set<int> selectedIds;
  const _ServicesPicker({required this.projectId, required this.selectedIds});

  @override
  State<_ServicesPicker> createState() => _ServicesPickerState();
}

class _ServicesPickerState extends State<_ServicesPicker> {
  List<Map<String, dynamic>> _services = [];
  bool _loading = true;
  late Set<int> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.selectedIds);
    _load();
  }

  void _load() async {
    final result = await ApiService.get('/api/service/list?project_id=${widget.projectId}');
    if (result['success'] == true && mounted) setState(() { _services = List<Map<String, dynamic>>.from(result['data'] ?? []); _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 400,
      child: Column(children: [
        Padding(padding: const EdgeInsets.all(20), child: Row(children: [const Spacer(), const Text('Выберите услуги', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)), const Spacer(), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))])),
        Expanded(
          child: _loading
              ? ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: 5,
                  itemBuilder: (_, _) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      const SkeletonBox(width: 40, height: 40, radius: 8),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const SkeletonBox(height: 14, width: 150),
                        const SizedBox(height: 4),
                        const SkeletonBox(height: 12, width: 100),
                      ])),
                    ]),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _services.length,
                  itemBuilder: (_, i) {
                    final s = _services[i];
                    final sel = _selected.contains(s['id']);
                    return CheckboxListTile(
                      value: sel,
                      onChanged: (v) => setState(() { v == true ? _selected.add(s['id']) : _selected.remove(s['id']); }),
                      title: Text(s['name'] ?? '', style: const TextStyle(fontSize: 14)),
                      subtitle: Text('${s['price'] ?? 0} ₽ · ${_formatDuration(s['duration'] ?? 0)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      activeColor: const Color(0xFFDD1847),
                    );
                  },
                ),
        ),
        Padding(padding: const EdgeInsets.all(20), child: SizedBox(width: double.infinity, height: 52, child: ElevatedButton(onPressed: () => Navigator.pop(context, _selected), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDD1847), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Готово', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white))))),
      ]),
    );
  }

  String _formatDuration(int minutes) {
    if (minutes == 0) return '0 мин';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '$h ч $m мин';
    if (h > 0) return '$h ч';
    return '$m мин';
  }
}

// ==================== ПИКЕР НАПОМИНАНИЙ ====================
class _ReminderPicker extends StatefulWidget {
  final List<String> selectedReminders;
  final bool confirmRequired;
  const _ReminderPicker({required this.selectedReminders, required this.confirmRequired});

  @override
  State<_ReminderPicker> createState() => _ReminderPickerState();
}

class _ReminderPickerState extends State<_ReminderPicker> {
  late List<String> _selected;
  late bool _confirmRequired;

  static const _options = [
    {'value': 'none', 'label': 'Нет'},
    {'value': '1h', 'label': 'За час'},
    {'value': '3h', 'label': 'За 3 часа'},
    {'value': '6h', 'label': 'За 6 часов'},
    {'value': '12h', 'label': 'За 12 часов'},
    {'value': '1d', 'label': 'За день'},
    {'value': '3d', 'label': 'За 3 дня'},
  ];

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selectedReminders);
    _confirmRequired = widget.confirmRequired;
  }

  void _toggle(String value) {
    setState(() {
      if (_selected.contains(value)) {
        _selected.remove(value);
      } else if (_selected.length < 2) {
        _selected.add(value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(children: [
                const Expanded(child: Text('Напоминание', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ]),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text('Можно выбрать не более 2-х напоминаний', style: TextStyle(fontSize: 13, color: Color(0xFF888888))),
            ),
            ..._options.map((o) => InkWell(
              onTap: () => _toggle(o['value']!),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))),
                child: Row(children: [
                  Expanded(child: Text(o['label']!, style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)))),
                  Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _selected.contains(o['value']) ? const Color(0xFFDD1847) : const Color(0xFFCCCCCC), width: 2),
                      color: _selected.contains(o['value']) ? const Color(0xFFDD1847) : Colors.transparent,
                    ),
                    child: _selected.contains(o['value']) ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
                  ),
                ]),
              ),
            )),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(children: [
                const Expanded(child: Text('Запрашивать подтверждение', style: TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)))),
                Switch(
                  value: _confirmRequired,
                  onChanged: (v) => setState(() => _confirmRequired = v),
                  activeThumbColor: const Color(0xFFDD1847),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, {'reminders': _selected, 'confirm_required': _confirmRequired}),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDD1847), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Готово', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== ПИКЕР ЗАПРОСА ОТЗЫВА ====================
class _ReviewPicker extends StatefulWidget {
  final String selectedReview;
  const _ReviewPicker({required this.selectedReview});

  @override
  State<_ReviewPicker> createState() => _ReviewPickerState();
}

class _ReviewPickerState extends State<_ReviewPicker> {
  late String _selected;

  static const _options = [
    {'value': 'none', 'label': 'Нет'},
    {'value': '1h', 'label': 'Через час'},
    {'value': '3h', 'label': 'Через 3 часа'},
    {'value': '6h', 'label': 'Через 6 часов'},
    {'value': '12h', 'label': 'Через 12 часов'},
    {'value': '1d', 'label': 'Через день'},
    {'value': '2d', 'label': 'Через 2 дня'},
    {'value': '3d', 'label': 'Через 3 дня'},
  ];

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedReview;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(children: [
                const Expanded(child: Text('Запрос отзыва', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ]),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text('Выберите через какое время клиенту будет отправлено уведомление с запросом отзыва', style: TextStyle(fontSize: 13, color: Color(0xFF888888))),
            ),
            ..._options.map((o) => InkWell(
              onTap: () => setState(() => _selected = o['value']!),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))),
                child: Row(children: [
                  Expanded(child: Text(o['label']!, style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)))),
                  Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _selected == o['value'] ? const Color(0xFFDD1847) : const Color(0xFFCCCCCC), width: 2),
                      color: _selected == o['value'] ? const Color(0xFFDD1847) : Colors.transparent,
                    ),
                    child: _selected == o['value'] ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
                  ),
                ]),
              ),
            )),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, _selected),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDD1847), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Готово', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== КАЛЕНДАРЬ ====================
class _CalendarPicker extends StatefulWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;

  const _CalendarPicker({required this.selectedDate, required this.onDateSelected});

  @override
  State<_CalendarPicker> createState() => _CalendarPickerState();
}

class _CalendarPickerState extends State<_CalendarPicker> {
  late DateTime _selected;
  final _scrollController = ScrollController();
  final _months = <DateTime>[];
  String _headerText = '';

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedDate;
    _generateMonths();
    _updateHeader(_selected);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelected();
      _scrollController.addListener(_onScroll);
    });
  }

  void _generateMonths() {
    _months.clear();
    final now = DateTime(_selected.year, _selected.month);
    for (int i = -6; i <= 6; i++) {
      _months.add(DateTime(now.year, now.month + i));
    }
  }

  void _scrollToSelected() {
    final index = _months.indexWhere((m) => m.year == _selected.year && m.month == _selected.month);
    if (index >= 0 && _scrollController.hasClients) {
      _scrollController.jumpTo(index * 340.0);
    }
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    final index = (offset / 340).round();
    if (index >= 0 && index < _months.length) {
      _updateHeader(_months[index]);
    }
    if (offset < 400) {
      _months.insert(0, DateTime(_months.first.year, _months.first.month - 1));
      _scrollController.jumpTo(offset + 340);
    }
    if (offset > (_months.length - 3) * 340) {
      _months.add(DateTime(_months.last.year, _months.last.month + 1));
    }
  }

  void _updateHeader(DateTime month) {
    final m = ['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'];
    setState(() => _headerText = '${m[month.month - 1]} ${month.year}');
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = ['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'];
    final today = DateTime.now();

    return SizedBox(
      height: 500,
      child: Column(children: [
        Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 8), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
        Text(_headerText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс']
              .map((d) => SizedBox(width: 36, child: Text(d, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: d == 'Сб' || d == 'Вс' ? const Color(0xFFDD1847) : Colors.grey))))
              .toList(),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: _months.length,
            itemExtent: 340,
            itemBuilder: (_, mi) {
              final mt = _months[mi];
              final dim = DateTime(mt.year, mt.month + 1, 0).day;
              final fd = DateTime(mt.year, mt.month, 1);
              final so = fd.weekday - 1;
              return Column(children: [
                Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('${m[mt.month - 1]} ${mt.year}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
                  itemCount: so + dim,
                  itemBuilder: (_, i) {
                    if (i < so) return const SizedBox.shrink();
                    final day = i - so + 1;
                    final date = DateTime(mt.year, mt.month, day);
                    final sel = date.day == _selected.day && date.month == _selected.month && date.year == _selected.year;
                    final it = date.day == today.day && date.month == today.month && date.year == today.year;
                    final we = date.weekday == 6 || date.weekday == 7;
                    return GestureDetector(
                      onTap: () { setState(() => _selected = date); widget.onDateSelected(date); },
                      child: Container(
                        margin: const EdgeInsets.all(1),
                        decoration: BoxDecoration(color: sel ? const Color(0xFFDD1847) : (it ? const Color(0xFFFDF2F5) : Colors.transparent), shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Text('$day', style: TextStyle(fontSize: 14, fontWeight: it || sel ? FontWeight.w600 : FontWeight.w400, color: sel ? Colors.white : (we ? const Color(0xFFDD1847) : Colors.black))),
                      ),
                    );
                  },
                ),
              ]);
            },
          ),
        ),
      ]),
    );
  }
}