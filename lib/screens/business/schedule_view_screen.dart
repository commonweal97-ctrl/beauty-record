import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../widgets/skeletons.dart';
import '../../../widgets/cached_image.dart';
import '../../../utils/name_utils.dart';
import '../../../widgets/common/avatar_initials.dart';
import '../../../widgets/toast.dart';
import '../../widgets/common/time_picker_sheet.dart';

class ScheduleViewScreen extends StatefulWidget {
  final int projectId;
  const ScheduleViewScreen({super.key, required this.projectId});

  @override
  State<ScheduleViewScreen> createState() => _ScheduleViewScreenState();
}

class _ScheduleViewScreenState extends State<ScheduleViewScreen> {
  List<Map<String, dynamic>> _employees = [];
  List<DateTime> _dates = [];
  DateTime _currentMonth = DateTime.now();
  bool _loading = true;
  final Set<String> _selectedCells = {};
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  Map<int, Set<int>> _employeeBookingDays = {};

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _generateDates();
    _load();
  }

  void _generateDates() {
    final dim = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    _dates = List.generate(dim, (i) => DateTime(_currentMonth.year, _currentMonth.month, i + 1));
  }

  void _load() async {
    setState(() => _loading = true);
    try {
      final projectId = widget.projectId;
      final year = _currentMonth.year;
      final month = _currentMonth.month.toString().padLeft(2, '0');
      final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
      final endDate = '$year-$month-${lastDay.toString().padLeft(2, '0')}';

      final empResult = await ApiService.get('/api/employee/list?project_id=$projectId');
      List<Map<String, dynamic>> emps = [];
      if (empResult['success'] == true) {
        emps = List<Map<String, dynamic>>.from(empResult['data'] ?? []);
      }

      // Загружаем записи для каждого сотрудника
      Map<int, Set<int>> employeeBookingDays = {};
      try {
        final bookingResult = await ApiService.get('/api/booking/list?project_id=$projectId&date=$year-$month-01&end_date=$endDate');
        if (bookingResult['success'] == true) {
          final bookings = List<Map<String, dynamic>>.from(bookingResult['data'] ?? []);
          for (final b in bookings) {
            if (b['status'] == 'cancelled') continue;
            final empId = b['employee_id'];
            final dateStr = b['date']?.toString() ?? '';
            final parts = dateStr.split('-');
            if (empId != null && parts.length == 3) {
              final day = int.tryParse(parts[2]) ?? 0;
              if (day > 0) {
                employeeBookingDays.putIfAbsent(empId, () => {});
                employeeBookingDays[empId]!.add(day);
              }
            }
          }
        }
      } on ApiException catch (e) { if (mounted) showToast(context, e.message, isError: true); }

      final futures = emps.map((e) async {
        final schedResult = await ApiService.get(
          '/api/employee/schedule/get?employee_id=${e['id']}&project_id=$projectId&year=$year&month=$month');
        
        if (schedResult['success'] == true) {
          final data = schedResult['data'];
          if (data is Map<String, dynamic>) {
            e['schedule_data'] = data;
          } else if (data is List) {
            final Map<String, dynamic> scheduleMap = {};
            for (final item in data) {
              if (item is Map<String, dynamic> && item.containsKey('day')) {
                scheduleMap[item['day'].toString()] = item;
              }
            }
            e['schedule_data'] = scheduleMap;
          }
        }
        return e;
      }).toList();

      final employees = await Future.wait(futures);
      if (mounted) {
        setState(() { 
        _employees = employees; 
        _employeeBookingDays = employeeBookingDays;
        _loading = false; 
      });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleCell(int empId, int dateIndex) {
    final key = '${empId}_$dateIndex';
    setState(() {
      _selectedCells.contains(key) ? _selectedCells.remove(key) : _selectedCells.add(key);
    });
  }

  void _clearSelection() => setState(() => _selectedCells.clear());



  bool _isOnlineClosed(Map<String, dynamic> emp, int day) {
    final scheduleData = emp['schedule_data'];
    if (scheduleData is Map<String, dynamic>) {
      final daySchedule = scheduleData[day.toString()];
      if (daySchedule is Map<String, dynamic> && daySchedule['online_booking'] == false) {
        return true;
      }
    }
    return false;
  }

  String _timeRange(Map<String, dynamic> emp, int day) {
    final scheduleData = emp['schedule_data'];
    
    if (scheduleData is Map<String, dynamic> && scheduleData.isNotEmpty) {
      final dayKey = day.toString();
      final daySchedule = scheduleData[dayKey];
      if (daySchedule != null && daySchedule is Map<String, dynamic>) {
        if (daySchedule['is_day_off'] == true) return 'Выходной';
        final startTime = daySchedule['start_time']?.toString();
        final endTime = daySchedule['end_time']?.toString();
        if (startTime != null && endTime != null) {
          return '${startTime.substring(0, 5)} – ${endTime.substring(0, 5)}';
        }
      }
      return '';
    }
    
    return '';
  }

  void _openMonthPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _MonthPickerWidget(
        selectedYear: _currentMonth.year,
        selectedMonth: _currentMonth.month - 1,
        onSelected: (y, m) {
          setState(() {
            _currentMonth = DateTime(y, m + 1);
            _generateDates();
            _clearSelection();
          });
          _load();
          Navigator.pop(context);
        },
      ),
    );
  }

  void _openScheduleSettings() {
    if (_selectedCells.isNotEmpty) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _ScheduleSettingsSheet(
          projectId: widget.projectId,
          onSaved: () {
            _selectedCells.clear();
            _load();
          },
          initialMode: 'time_config',
          selectedCells: _selectedCells.toSet(),
          dates: _dates,
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _ScheduleSettingsSheet(
          projectId: widget.projectId,
          onSaved: () => _load(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weekdays = ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'];
    final months = ['янв.', 'фев.', 'мар.', 'апр.', 'мая', 'июн.', 'июл.', 'авг.', 'сен.', 'окт.', 'ноя.', 'дек.'];
    const fixedColWidth = 100.0;
    const cellWidth = 85.0;
    const headerHeight = 60.0;
    const rowHeight = 70.0;

    return Column(children: [
      Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Expanded(child: const Text('График работы', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
          TextButton.icon(
            onPressed: _openScheduleSettings,
            icon: const Icon(Icons.settings, size: 18),
            label: const Text('Настроить график'),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDD1847)),
          ),
        ]),
      ),
      Expanded(
        child: _loading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SkeletonCircle(size: 48),
                    SizedBox(height: 16),
                    SkeletonBox(height: 14, width: 160),
                    SizedBox(height: 8),
                    SkeletonBox(height: 12, width: 120),
                  ],
                ),
              )
            : Container(
                color: Colors.white,
                child: Stack(
                  children: [
                    GestureDetector(
                      onPanUpdate: (details) {
                        _horizontalScrollController.jumpTo(
                          _horizontalScrollController.offset - details.delta.dx,
                        );
                      },
                      child: SingleChildScrollView(
                        controller: _horizontalScrollController,
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          controller: _verticalScrollController,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Заголовки дат
                              Row(children: [
                                const SizedBox(width: fixedColWidth, height: headerHeight),
                                ..._dates.map((d) {
                                  return Container(
                                    width: cellWidth, height: headerHeight,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border(
                                        right: BorderSide(color: Colors.grey[200]!),
                                        bottom: BorderSide(color: Colors.grey[200]!),
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          weekdays[d.weekday % 7],
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: d.weekday == 6 || d.weekday == 7
                                                ? const Color(0xFFDD1847)
                                                : const Color(0xFF888888),
                                          ),
                                        ),
                                        Text(
                                          '${d.day}',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          months[d.month - 1],
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFF888888),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ]),
                              // Строки сотрудников
                              ..._employees.map((e) => Row(children: [
                                const SizedBox(width: fixedColWidth, height: rowHeight),
                                ...List.generate(_dates.length, (i) {
                                  final key = '${e['id']}_$i';
                                  final sel = _selectedCells.contains(key);
                                  final range = _timeRange(e, _dates[i].day);
                                  final isWeekend = _dates[i].weekday == 6 || _dates[i].weekday == 7;
                                  final empId = e['id'] as int;
                                  final hasBookings = _employeeBookingDays[empId]?.contains(_dates[i].day) ?? false;
                                  
                                  return GestureDetector(
                                    onTap: () => _toggleCell(e['id'] as int, i),
                                    child: Container(
                                      width: cellWidth,
                                      height: rowHeight,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border(
                                          right: BorderSide(color: Colors.grey[200]!),
                                          bottom: BorderSide(color: Colors.grey[200]!),
                                        ),
                                      ),
                                      child: Center(
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            // Основная ячейка с временем
                                            Container(
                                              width: 76,
                                              height: 46,
                                              alignment: Alignment.center,
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: sel
                                                    ? const Color(0xFFDD1847)
                                                    : range.isEmpty
                                                        ? const Color(0xFFE8E8E8)
                                                        : (isWeekend ? const Color(0xFFFDF2F5) : const Color(0xFFF5F5F5)),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                range,
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: sel
                                                      ? Colors.white
                                                      : (isWeekend && range.isNotEmpty ? const Color(0xFFDD1847) : Colors.black),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            // Иконка «онлайн закрыт»
                                            if (_isOnlineClosed(e, _dates[i].day))
                                              Positioned(
                                                top: 4,
                                                right: 4,
                                                child: Icon(
                                                  Icons.public_off,
                                                  size: 14,
                                                  color: const Color(0xFFDD1847).withValues(alpha: 0.55),
                                                ),
                                              ),
                                            // Индикатор записей (точка под временем)
                                            if (hasBookings)
                                              Positioned(
                                                bottom: 6,
                                                child: Container(
                                                  width: 5,
                                                  height: 5,
                                                  decoration: BoxDecoration(
                                                    color: sel ? Colors.white : const Color(0xFFDD1847),
                                                    shape: BoxShape.circle,
                                                    boxShadow: sel ? [] : [
                                                      BoxShadow(
                                                        color: const Color(0xFFDD1847).withValues(alpha: 0.5),
                                                        blurRadius: 4,
                                                        spreadRadius: 1,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ])),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Фиксированная колонка сотрудников
                    Positioned(
                      left: 0,
                      top: 0,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x0A000000),
                              offset: Offset(2, 0),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: SingleChildScrollView(
                          controller: _verticalScrollController,
                          physics: const NeverScrollableScrollPhysics(),
                          child: Column(
                            children: [
                              Container(
                                width: fixedColWidth,
                                height: headerHeight,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border(
                                    right: BorderSide(color: Colors.grey[200]!),
                                    bottom: BorderSide(color: Colors.grey[200]!),
                                  ),
                                ),
                                child: Center(
                                  child: IconButton(
                                    icon: const Icon(Icons.calendar_today, size: 24, color: Color(0xFF666666)),
                                    onPressed: _openMonthPicker,
                                  ),
                                ),
                              ),
                              ..._employees.map((e) => Container(
                                width: fixedColWidth,
                                height: rowHeight,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border(
                                    right: BorderSide(color: Colors.grey[200]!),
                                    bottom: BorderSide(color: Colors.grey[200]!),
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    (e['avatar'] != null && e['avatar'].toString().isNotEmpty)
                                        ? CachedAvatar(url: e['avatar'], size: 36, radius: 18)
                                        : AvatarInitials(name: extractName(e), size: 36),
                                    const SizedBox(height: 4),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: Text(
                                        extractShortName(e),
                                        style: const TextStyle(fontSize: 11),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
      if (_selectedCells.isNotEmpty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, -4))],
          ),
          child: SafeArea(
            top: false,
            child: Row(children: [
              Expanded(
                child: Text('Выбрано: ${_selectedCells.length}', style: const TextStyle(color: Color(0xFF666666), fontSize: 13)),
              ),
              TextButton(
                onPressed: _clearSelection,
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
                child: const Text('Сбросить', style: TextStyle(fontSize: 13)),
              ),
              TextButton(
                onPressed: _clearSelection,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  foregroundColor: Colors.red,
                ),
                child: const Text('Очистить', style: TextStyle(fontSize: 13)),
              ),
              ElevatedButton(
                onPressed: _openScheduleSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDD1847),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Настроить', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ),
    ]);
  }
}

// ==================== МОДАЛКА НАСТРОЙКИ ГРАФИКА ====================
class _ScheduleSettingsSheet extends StatefulWidget {
  final int projectId;
  final VoidCallback onSaved;
  final String? initialMode;
  final Set<String>? selectedCells;
  final List<DateTime>? dates;
  
  const _ScheduleSettingsSheet({
    required this.projectId, 
    required this.onSaved,
    this.initialMode,
    this.selectedCells,
    this.dates,
  });

  @override
  State<_ScheduleSettingsSheet> createState() => _ScheduleSettingsSheetState();
}

class _ScheduleSettingsSheetState extends State<_ScheduleSettingsSheet> {
  int _step = 1;
  final Set<int> _selectedEmployees = {};
  List<Map<String, dynamic>> _allEmployees = [];
  String _scheduleType = '';
  
  final Set<int> _selectedWeekdays = {1, 2, 3, 4, 5};
  TimeOfDay _workStart = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _workEnd = const TimeOfDay(hour: 20, minute: 0);
  bool _allDay = false;
  bool _onlineBooking = true;
  final List<Map<String, String>> _breaks = [];
  
  DateTime? _periodStart;
  DateTime? _periodEnd;
  bool _noEndDate = true;
  
  int _workDays = 5;
  int _offDays = 2;
  // ignore: unused_field
  String _cyclicType = '';
  
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _periodStart = DateTime.now();
    _periodStart = DateTime(_periodStart!.year, _periodStart!.month, _periodStart!.day);
    _loadEmployees();
    
    if (widget.initialMode == 'time_config') {
      _step = 5;
      if (widget.selectedCells != null) {
        for (final key in widget.selectedCells!) {
          final empId = int.tryParse(key.split('_')[0]) ?? 0;
          if (empId > 0) _selectedEmployees.add(empId);
        }
      }
    }
  }

  void _loadEmployees() async {
    final result = await ApiService.get('/api/employee/list?project_id=${widget.projectId}');
    if (result['success'] == true && mounted) {
      setState(() {
        _allEmployees = List<Map<String, dynamic>>.from(result['data'] ?? []);
      });
    }
  }



  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    final months = ['янв', 'фев', 'мар', 'апр', 'мая', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _saveWeekdaysSchedule() async {
    if (_selectedEmployees.isEmpty) {
      showToast(context, 'Выберите сотрудников', isError: true);
      return;
    }

    setState(() => _loading = true);

    try {
      final startStr = _formatTime(_workStart);
      final endStr = _formatTime(_workEnd);
      
      final startDate = _periodStart ?? DateTime.now();
      final endDate = _noEndDate 
          ? DateTime(startDate.year + 1, startDate.month, startDate.day)
          : (_periodEnd ?? DateTime(startDate.year + 1, startDate.month, startDate.day));
      
      final List<Map<String, dynamic>> days = [];
      var current = DateTime(startDate.year, startDate.month, startDate.day);
      while (!current.isAfter(endDate)) {
        final dayOfWeek = current.weekday % 7;
        if (_selectedWeekdays.contains(dayOfWeek)) {
          days.add({
            'year': current.year,
            'month': current.month,
            'day': current.day,
          });
        }
        current = current.add(const Duration(days: 1));
      }

      final breakData = _breaks.map((b) => {
        'start': b['start'],
        'end': b['end'],
      }).toList();

      final futures = _selectedEmployees.map((empId) async {
        final body = <String, dynamic>{
          'employee_id': empId,
          'project_id': widget.projectId,
          'days': days,
          'start_time': startStr,
          'end_time': endStr,
          'is_all_day': _allDay,
          'online_booking': _onlineBooking,
          'breaks': breakData,
        };
        return ApiService.post('/api/employee/schedule/save', body);
      }).toList();

      final results = await Future.wait(futures);
      final allSuccess = results.every((r) => r['success'] == true);

      if (mounted) {
        setState(() => _loading = false);
        if (allSuccess) {
          Navigator.pop(context);
          widget.onSaved();
          showToast(context, 'График сохранён для ${_selectedEmployees.length} сотрудников');
        } else {
          showToast(context, 'Ошибка сохранения', isError: true);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        showToast(context, 'Ошибка соединения', isError: true);
      }
    }
  }

  Future<void> _saveCyclicSchedule() async {
    if (_selectedEmployees.isEmpty) {
      showToast(context, 'Выберите сотрудников', isError: true);
      return;
    }

    setState(() => _loading = true);

    try {
      final startStr = _formatTime(_workStart);
      final endStr = _formatTime(_workEnd);
      
      final startDate = _periodStart ?? DateTime.now();
      final endDate = _noEndDate 
          ? DateTime(startDate.year + 1, startDate.month, startDate.day)
          : (_periodEnd ?? DateTime(startDate.year + 1, startDate.month, startDate.day));
      
      final List<Map<String, dynamic>> days = [];
      var current = DateTime(startDate.year, startDate.month, startDate.day);
      int dayIndex = 0;
      final cycleLength = _workDays + _offDays;
      
      while (!current.isAfter(endDate)) {
        if (dayIndex < _workDays) {
          days.add({
            'year': current.year,
            'month': current.month,
            'day': current.day,
          });
        }
        dayIndex = (dayIndex + 1) % cycleLength;
        current = current.add(const Duration(days: 1));
      }

      final breakData = _breaks.map((b) => {
        'start': b['start'],
        'end': b['end'],
      }).toList();

      final futures = _selectedEmployees.map((empId) async {
        final body = <String, dynamic>{
          'employee_id': empId,
          'project_id': widget.projectId,
          'days': days,
          'start_time': startStr,
          'end_time': endStr,
          'is_all_day': _allDay,
          'online_booking': _onlineBooking,
          'breaks': breakData,
        };
        return ApiService.post('/api/employee/schedule/save', body);
      }).toList();

      final results = await Future.wait(futures);
      final allSuccess = results.every((r) => r['success'] == true);

      if (mounted) {
        setState(() => _loading = false);
        if (allSuccess) {
          Navigator.pop(context);
          widget.onSaved();
          showToast(context, 'График сохранён для ${_selectedEmployees.length} сотрудников');
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveTimeConfig() async {
    if (_selectedEmployees.isEmpty) {
      showToast(context, 'Выберите сотрудников', isError: true);
      return;
    }

    setState(() => _loading = true);

    try {
      final startStr = _allDay ? '00:00' : _formatTime(_workStart);
      final endStr = _allDay ? '23:59' : _formatTime(_workEnd);
      
      final breakData = _allDay 
          ? [] 
          : _breaks.map((b) => {
              'start': b['start'],
              'end': b['end'],
            }).toList();

      final Map<int, List<Map<String, dynamic>>> daysByEmployee = {};
      
      if (widget.selectedCells != null && widget.dates != null) {
        for (final cellKey in widget.selectedCells!) {
          final parts = cellKey.split('_');
          if (parts.length == 2) {
            final empId = int.tryParse(parts[0]) ?? 0;
            final dayIndex = int.tryParse(parts[1]) ?? -1;
            
            if (empId > 0 && dayIndex >= 0 && dayIndex < widget.dates!.length) {
              final date = widget.dates![dayIndex];
              daysByEmployee.putIfAbsent(empId, () => []);
              daysByEmployee[empId]!.add({
                'year': date.year,
                'month': date.month,
                'day': date.day,
              });
            }
          }
        }
      }

      final futures = _selectedEmployees.map((empId) async {
        final days = daysByEmployee[empId] ?? [];
        
        final body = <String, dynamic>{
          'employee_id': empId,
          'project_id': widget.projectId,
          'days': days,
          'start_time': startStr,
          'end_time': endStr,
          'is_all_day': _allDay,
          'online_booking': _onlineBooking,
          'breaks': breakData,
        };
        return ApiService.post('/api/employee/schedule/save', body);
      }).toList();

      final results = await Future.wait(futures);
      final allSuccess = results.every((r) => r['success'] == true);

      if (mounted) {
        setState(() => _loading = false);
        if (allSuccess) {
          Navigator.pop(context);
          widget.onSaved();
          showToast(context, 'Время настроено для ${_selectedEmployees.length} сотрудников');
        } else {
          showToast(context, 'Ошибка сохранения', isError: true);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        showToast(context, 'Ошибка соединения', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _step == 1
                    ? _buildStepEmployees()
                    : _step == 2
                        ? _buildStepType()
                        : _step == 3
                            ? _scheduleType == 'cyclic'
                                ? _buildStepCyclicOptions()
                                : _buildStepWeekdaysSettings()
                            : _step == 4
                                ? _buildStepCyclicTimeSettings()
                                : _step == 5
                                    ? _buildStepTimeConfig()
                                    : const SizedBox(),
              ),
            ],
          ),
          if (_loading)
            Container(
              color: Colors.white.withValues(alpha: 0.7),
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
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    String title = 'Выберите сотрудников';
    if (_step == 2) {
      title = 'Тип графика';
    } else if (_step == 3 && _scheduleType == 'weekdays') title = 'По дням недели';
    else if (_step == 3 && _scheduleType == 'cyclic') title = 'Циклический график';
    else if (_step == 4) title = 'Циклический график';
    else if (_step == 5) title = 'Настройка времени';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (_step == 5) {
                Navigator.pop(context);
              } else if (_step > 1) {
                setState(() => _step--);
                if (_step == 2) _scheduleType = '';
              } else {
                Navigator.pop(context);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Icon(_step == 1 || _step == 5 ? Icons.close : Icons.arrow_back, size: 24, color: const Color(0xFF666666)),
            ),
          ),
          Expanded(child: Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              child: const Icon(Icons.close, size: 24, color: Color(0xFF666666)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepEmployees() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Поиск по сотрудникам',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF999999)),
              filled: true,
              fillColor: const Color(0xFFF8F8F8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: _allEmployees.map((e) {
              final sel = _selectedEmployees.contains(e['id']);
              return ListTile(
                leading: (e['avatar'] != null && e['avatar'].toString().isNotEmpty)
                    ? CachedAvatar(url: e['avatar'], size: 44, radius: 22)
                    : AvatarInitials(name: extractName(e), size: 44),
                title: Text(extractName(e), style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(e['position'] ?? 'Мастер', style: const TextStyle(color: Color(0xFF888888))),
                trailing: Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: sel ? const Color(0xFFDD1847) : const Color(0xFFDDDDDD), width: 2),
                    color: sel ? const Color(0xFFDD1847) : Colors.transparent,
                  ),
                  child: sel ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                ),
                onTap: () {
                  setState(() {
                    sel ? _selectedEmployees.remove(e['id']) : _selectedEmployees.add(e['id']);
                  });
                },
              );
            }).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _selectedEmployees.isEmpty ? null : () => setState(() => _step = 2),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDD1847),
                disabledBackgroundColor: const Color(0xFFCCCCCC),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Далее (${_selectedEmployees.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepType() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildTypeCard(
          icon: Icons.calendar_view_week,
          title: 'По дням недели',
          subtitle: 'Дни недели, когда вы будете работать',
          onTap: () {
            _scheduleType = 'weekdays';
            setState(() => _step = 3);
          },
        ),
        const SizedBox(height: 12),
        _buildTypeCard(
          icon: Icons.repeat,
          title: 'Циклический график',
          subtitle: 'Повторяющийся график, например, 5/2, 2/2',
          onTap: () {
            _scheduleType = 'cyclic';
            setState(() => _step = 3);
          },
        ),
      ],
    );
  }

  Widget _buildTypeCard({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFF0F0F0), width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: const Color(0xFF666666)),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 14, color: Color(0xFF888888))),
          ])),
        ]),
      ),
    );
  }

  Widget _weekdayBtn(String label, int day) {
    final sel = _selectedWeekdays.contains(day);
    return GestureDetector(
      onTap: () => setState(() => sel ? _selectedWeekdays.remove(day) : _selectedWeekdays.add(day)),
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: sel ? const Color(0xFFDD1847) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? const Color(0xFFDD1847) : const Color(0xFFF0F0F0), width: 2),
        ),
        child: Center(child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: sel ? Colors.white : const Color(0xFF666666)))),
      ),
    );
  }

  void _openPeriodCalendar() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PeriodCalendarPicker(
        startDate: _periodStart ?? DateTime.now(),
        endDate: _periodEnd,
        noEndDate: _noEndDate,
        onSelected: (start, end, noEnd) {
          setState(() {
            _periodStart = start;
            _periodEnd = end;
            _noEndDate = noEnd;
          });
        },
      ),
    );
  }

  Widget _buildStepWeekdaysSettings() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        _buildSectionCard(
          title: 'Дни недели',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _weekdayBtn('Пн', 1), _weekdayBtn('Вт', 2), _weekdayBtn('Ср', 3),
              _weekdayBtn('Чт', 4), _weekdayBtn('Пт', 5), _weekdayBtn('Сб', 6), _weekdayBtn('Вс', 0),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          title: 'Период',
          child: GestureDetector(
            onTap: _openPeriodCalendar,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_today, size: 20, color: Color(0xFF666666)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${_formatDate(_periodStart ?? DateTime.now())} - ${_noEndDate ? "Бессрочно" : _formatDate(_periodEnd ?? DateTime.now())}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC)),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          title: 'Время работы',
          child: Column(children: [
            Row(children: [
              _buildTimePicker(_workStart, (t) => setState(() => _workStart = t)),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('—', style: TextStyle(color: Color(0xFF999999)))),
              _buildTimePicker(_workEnd, (t) => setState(() => _workEnd = t)),
            ]),
            const SizedBox(height: 12),
            _buildSwitchCard(
              icon: Icons.wb_sunny_outlined,
              label: 'Весь день',
              subtitle: 'С 00:00 до 23:59',
              value: _allDay,
              onChanged: (v) => setState(() => _allDay = v),
            ),
            const SizedBox(height: 8),
            _buildSwitchCard(
              icon: Icons.public,
              label: 'Онлайн-запись',
              subtitle: _onlineBooking ? 'Клиенты могут записаться' : 'Дни закрыты для онлайн',
              value: _onlineBooking,
              onChanged: (v) => setState(() => _onlineBooking = v),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          title: 'Перерывы',
          child: Column(children: [
            ..._breaks.asMap().entries.map((entry) {
              final i = entry.key;
              final b = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  const Icon(Icons.access_time, size: 18, color: Color(0xFF999999)),
                  const SizedBox(width: 8),
                  Text('${b['start']} – ${b['end']}', style: const TextStyle(fontSize: 14)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _breaks.removeAt(i)),
                    child: const Icon(Icons.close, size: 18, color: Color(0xFF999999)),
                  ),
                ]),
              );
            }),
            GestureDetector(
              onTap: () => setState(() => _breaks.add({'start': '13:00', 'end': '14:00'})),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, size: 18, color: Color(0xFFDD1847)),
                    SizedBox(width: 6),
                    Text('Добавить перерыв', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFDD1847))),
                  ],
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _loading ? null : _saveWeekdaysSchedule,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDD1847),
              disabledBackgroundColor: const Color(0xFFDD1847).withValues(alpha: 0.5),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('Сохранить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF888888), letterSpacing: 0.3)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildSwitchCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: value ? const Color(0xFFFDF2F5) : const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(icon, size: 20, color: value ? const Color(0xFFDD1847) : const Color(0xFF999999)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF999999))),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: const Color(0xFFDD1847),
        ),
      ]),
    );
  }

  Widget _buildTimePicker(TimeOfDay time, Function(TimeOfDay) onChanged) {
    return GestureDetector(
      onTap: () async {
        final result = await showTimePickerSheet(
          context,
          initialTime: time,
        );
        if (result != null) onChanged(result);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12)),
        child: Text(_formatTime(time), style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget _buildStepCyclicOptions() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _cyclicOption('Будни', 'Пн-Пт', () { _cyclicType = 'weekdays'; _goToCyclicTimeSettings(); }),
        _cyclicOption('Все дни', 'Пн-Вс', () { _cyclicType = 'all'; _goToCyclicTimeSettings(); }),
        _cyclicOption('Четные', null, () { _cyclicType = 'even'; _goToCyclicTimeSettings(); }),
        _cyclicOption('Нечетные', null, () { _cyclicType = 'odd'; _goToCyclicTimeSettings(); }),
        _cyclicOption('2/2', null, () { _cyclicType = '2/2'; _workDays = 2; _offDays = 2; _goToCyclicTimeSettings(); }),
        _cyclicOption('Своя схема', null, () => _showCustomSchemeDialog()),
      ],
    );
  }

  Widget _cyclicOption(String title, String? badge, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 16, color: Color(0xFF1A1A1A)))),
          if (badge != null) Text(badge, style: const TextStyle(fontSize: 14, color: Color(0xFF888888))),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC)),
        ]),
      ),
    );
  }

  void _goToCyclicTimeSettings() => setState(() => _step = 4);

  void _showCustomSchemeDialog() {
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const Text('Своя схема'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Рабочих дней'),
                Row(children: [
                  IconButton(onPressed: () => setDialogState(() => _workDays = (_workDays - 1).clamp(1, 30)), icon: const Icon(Icons.remove)),
                  Text('$_workDays', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  IconButton(onPressed: () => setDialogState(() => _workDays = (_workDays + 1).clamp(1, 30)), icon: const Icon(Icons.add)),
                ]),
              ]),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Выходных дней'),
                Row(children: [
                  IconButton(onPressed: () => setDialogState(() => _offDays = (_offDays - 1).clamp(1, 30)), icon: const Icon(Icons.remove)),
                  Text('$_offDays', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  IconButton(onPressed: () => setDialogState(() => _offDays = (_offDays + 1).clamp(1, 30)), icon: const Icon(Icons.add)),
                ]),
              ]),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12)),
                child: Text('График: $_workDays/$_offDays', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFFDD1847))),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _cyclicType = 'custom';
                _goToCyclicTimeSettings();
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDD1847)),
              child: const Text('Применить', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCyclicTimeSettings() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Период', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _openPeriodCalendar,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.calendar_today, size: 20, color: Color(0xFF666666)),
              const SizedBox(width: 12),
              Expanded(child: Text(
                '${_formatDate(_periodStart ?? DateTime.now())} - ${_noEndDate ? "Бессрочно" : _formatDate(_periodEnd ?? DateTime.now())}',
                style: const TextStyle(fontSize: 15),
              )),
              const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC)),
            ]),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Время работы', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(children: [
          _buildTimePicker(_workStart, (t) => setState(() => _workStart = t)),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('—')),
          _buildTimePicker(_workEnd, (t) => setState(() => _workEnd = t)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Checkbox(value: _allDay, onChanged: (v) => setState(() => _allDay = v ?? false), activeColor: const Color(0xFFDD1847)),
          const Text('Весь день', style: TextStyle(fontSize: 15)),
        ]),
        Row(children: [
          Checkbox(value: _onlineBooking, onChanged: (v) => setState(() => _onlineBooking = v ?? true), activeColor: const Color(0xFFDD1847)),
          const Text('Онлайн-запись', style: TextStyle(fontSize: 15)),
        ]),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => setState(() => _breaks.add({'start': '13:00', 'end': '14:00'})),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Добавить перерыв'),
          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFDD1847), side: const BorderSide(color: Color(0xFFDD1847)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
        ..._breaks.asMap().entries.map((entry) {
          final i = entry.key;
          final b = entry.value;
          return Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Expanded(
                child: Row(children: [
                  _buildTimePicker(TimeOfDay(hour: int.parse(b['start']!.split(':')[0]), minute: int.parse(b['start']!.split(':')[1])),
                    (t) => setState(() => _breaks[i]['start'] = _formatTime(t))),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('—')),
                  _buildTimePicker(TimeOfDay(hour: int.parse(b['end']!.split(':')[0]), minute: int.parse(b['end']!.split(':')[1])),
                    (t) => setState(() => _breaks[i]['end'] = _formatTime(t))),
                ]),
              ),
              IconButton(icon: const Icon(Icons.close, size: 20, color: Colors.grey), onPressed: () => setState(() => _breaks.removeAt(i))),
            ]),
          );
        }),
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _saveCyclicSchedule,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDD1847), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Сохранить график', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildStepTimeConfig() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        _buildSectionCard(
          title: 'Время работы',
          child: Column(children: [
            Row(children: [
              _buildTimePicker(_workStart, (t) => setState(() => _workStart = t)),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('—', style: TextStyle(color: Color(0xFF999999)))),
              _buildTimePicker(_workEnd, (t) => setState(() => _workEnd = t)),
            ]),
            const SizedBox(height: 12),
            _buildSwitchCard(
              icon: Icons.wb_sunny_outlined,
              label: 'Весь день',
              subtitle: 'С 00:00 до 23:59',
              value: _allDay,
              onChanged: (v) => setState(() => _allDay = v),
            ),
            const SizedBox(height: 8),
            _buildSwitchCard(
              icon: Icons.public,
              label: 'Онлайн-запись',
              subtitle: _onlineBooking ? 'Клиенты могут записаться' : 'Дни закрыты для онлайн',
              value: _onlineBooking,
              onChanged: (v) => setState(() => _onlineBooking = v),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          title: 'Перерывы',
          child: Column(children: [
            ..._breaks.asMap().entries.map((entry) {
              final i = entry.key;
              final b = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  const Icon(Icons.access_time, size: 18, color: Color(0xFF999999)),
                  const SizedBox(width: 8),
                  Text('${b['start']} – ${b['end']}', style: const TextStyle(fontSize: 14)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _breaks.removeAt(i)),
                    child: const Icon(Icons.close, size: 18, color: Color(0xFF999999)),
                  ),
                ]),
              );
            }),
            GestureDetector(
              onTap: () => setState(() => _breaks.add({'start': '13:00', 'end': '14:00'})),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, size: 18, color: Color(0xFFDD1847)),
                    SizedBox(width: 6),
                    Text('Добавить перерыв', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFDD1847))),
                  ],
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _loading ? null : _saveTimeConfig,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDD1847),
              disabledBackgroundColor: const Color(0xFFDD1847).withValues(alpha: 0.5),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('Применить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ==================== КАЛЕНДАРЬ ПЕРИОДА ====================
class _PeriodCalendarPicker extends StatefulWidget {
  final DateTime startDate;
  final DateTime? endDate;
  final bool noEndDate;
  final Function(DateTime, DateTime?, bool) onSelected;

  const _PeriodCalendarPicker({
    required this.startDate,
    this.endDate,
    required this.noEndDate,
    required this.onSelected,
  });

  @override
  State<_PeriodCalendarPicker> createState() => _PeriodCalendarPickerState();
}

class _PeriodCalendarPickerState extends State<_PeriodCalendarPicker> {
  late DateTime _startDate;
  DateTime? _endDate;
  late bool _noEndDate;
  bool _isSelectingEnd = false;

  @override
  void initState() {
    super.initState();
    _startDate = widget.startDate;
    _endDate = widget.endDate;
    _noEndDate = widget.noEndDate;
  }

  String _formatDate(DateTime date) {
    final months = ['янв', 'фев', 'мар', 'апр', 'мая', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return SizedBox(
      height: 550,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            if (_isSelectingEnd)
              IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _isSelectingEnd = false)),
            Expanded(child: Text(
              _isSelectingEnd ? 'Выберите дату окончания' : 'Выберите дату начала',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            )),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 6,
            itemBuilder: (_, offset) {
              final monthDate = DateTime(today.year, today.month + offset, 1);
              return _buildMonth(monthDate, today, now);
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF0F0F0)))),
          child: Column(children: [
            Row(children: [
              Checkbox(
                value: _noEndDate,
                onChanged: (v) {
                  setState(() {
                    _noEndDate = v ?? false;
                    if (_noEndDate) {
                      _endDate = null;
                      _isSelectingEnd = false;
                    }
                  });
                },
                activeColor: const Color(0xFFDD1847),
              ),
              const Text('Бессрочно', style: TextStyle(fontSize: 15)),
            ]),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Начало: ${_formatDate(_startDate)}', style: const TextStyle(fontSize: 13, color: Color(0xFF666666))),
                Text('Окончание: ${_endDate != null ? _formatDate(_endDate!) : "Бессрочно"}', style: const TextStyle(fontSize: 13, color: Color(0xFF666666))),
              ]),
            ),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: () {
                  widget.onSelected(_startDate, _endDate, _noEndDate);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDD1847), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Применить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildMonth(DateTime monthDate, DateTime today, DateTime now) {
    final year = monthDate.year;
    final month = monthDate.month;
    final months = ['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'];
    
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startDay = (firstDay.weekday % 7);
    
    final minDate = _isSelectingEnd ? _startDate : today;
    
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text('${months[month - 1]} $year', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
        itemCount: startDay + daysInMonth,
        itemBuilder: (_, i) {
          if (i < startDay) return const SizedBox();
          final day = i - startDay + 1;
          final date = DateTime(year, month, day);
          final isPast = date.isBefore(minDate);
          final isWeekend = date.weekday == 6 || date.weekday == 7;
          final isStart = date == _startDate;
          final isEnd = _endDate != null && date == _endDate;
          final isInRange = _endDate != null && date.isAfter(_startDate) && date.isBefore(_endDate!);
          
          return GestureDetector(
            onTap: isPast ? null : () {
              setState(() {
                if (_isSelectingEnd) {
                  if (!date.isBefore(_startDate)) {
                    _endDate = date;
                    _isSelectingEnd = false;
                  }
                } else {
                  _startDate = date;
                  _endDate = null;
                  _isSelectingEnd = true;
                }
              });
            },
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isStart || isEnd ? const Color(0xFFDD1847) : (isInRange ? const Color(0xFFFDF2F5) : Colors.transparent),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text('$day', style: TextStyle(
                  fontSize: 14,
                  fontWeight: (isStart || isEnd) ? FontWeight.w600 : FontWeight.w400,
                  color: isPast ? Colors.grey[300] : (isStart || isEnd ? Colors.white : (isWeekend ? const Color(0xFFDD1847) : Colors.black)),
                )),
              ),
            ),
          );
        },
      ),
    ]);
  }
}

// ==================== ВЫБОР МЕСЯЦА ====================
class _MonthPickerWidget extends StatelessWidget {
  final int selectedYear;
  final int selectedMonth;
  final Function(int, int) onSelected;

  const _MonthPickerWidget({
    required this.selectedYear,
    required this.selectedMonth,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final months = ['Янв', 'Фев', 'Мар', 'Апр', 'Май', 'Июн', 'Июл', 'Авг', 'Сен', 'Окт', 'Ноя', 'Дек'];
    final now = DateTime.now();
    int year = selectedYear;

    return StatefulBuilder(
      builder: (_, setState) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(onPressed: () => setState(() => year--), icon: const Icon(Icons.chevron_left)),
                Text('$year', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                IconButton(onPressed: () => setState(() => year++), icon: const Icon(Icons.chevron_right)),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(12, (i) {
                final sel = i == selectedMonth;
                final cur = year == now.year && i == now.month - 1;
                return GestureDetector(
                  onTap: () => onSelected(year, i),
                  child: Container(
                    width: (MediaQuery.of(context).size.width - 60) / 3,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: sel ? const Color(0xFFDD1847) : (cur ? const Color(0xFFFFF5F7) : const Color(0xFFF8F9FA)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: sel ? const Color(0xFFDD1847) : (cur ? const Color(0xFFF8A5B9) : const Color(0xFFF0F0F0)), width: 2),
                    ),
                    child: Text(months[i], textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: sel ? Colors.white : (cur ? const Color(0xFFDD1847) : Colors.black))),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}