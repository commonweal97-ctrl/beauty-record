// employee_schedule_screen.dart
import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../widgets/skeletons.dart';
import '../../../widgets/toast.dart';

class EmployeeScheduleScreen extends StatefulWidget {
  final int employeeId;
  final int projectId;
  final String employeeName;

  const EmployeeScheduleScreen({
    super.key,
    required this.employeeId,
    required this.projectId,
    required this.employeeName,
  });

  @override
  State<EmployeeScheduleScreen> createState() => _EmployeeScheduleScreenState();
}

class _EmployeeScheduleScreenState extends State<EmployeeScheduleScreen> {
  final Map<String, Map<String, dynamic>> _scheduleData = {};
  final Map<String, bool> _loadedMonths = {};
  final Set<String> _selectedDays = {};
  final ScrollController _scrollController = ScrollController();

  DateTime _currentMonth = DateTime.now();
  final bool _loading = false;
  bool _showMonthPicker = false;
  bool _initialScrollDone = false;

  static const _months = [
    'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
    'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
  ];
  static const _weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _loadMonthsAround(_currentMonth);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels < 200) {
      _loadMoreMonths(-1);
    } else if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 200) {
      _loadMoreMonths(1);
    }
    setState(() {});
  }

  void _loadMoreMonths(int direction) {
    final newMonth = DateTime(_currentMonth.year, _currentMonth.month + direction);
    if (!_loadedMonths.containsKey(_monthKey(newMonth))) {
      _loadMonthsAround(newMonth);
    }
  }

  void _loadMonthsAround(DateTime center) {
    for (int i = -6; i <= 6; i++) {
      final m = DateTime(center.year, center.month + i);
      final key = _monthKey(m);
      if (!_loadedMonths.containsKey(key)) {
        _loadedMonths[key] = false;
        _fetchSchedule(m.year, m.month);
      }
    }
  }

  Future<void> _fetchSchedule(int year, int month) async {
    final key = _monthKey(DateTime(year, month));
    try {
      final result = await ApiService.get(
        '/api/employee/schedule/get?employee_id=${widget.employeeId}&project_id=${widget.projectId}&year=$year&month=$month',
      );
      if (result['success'] == true && mounted) {
        setState(() {
          _scheduleData[key] = Map<String, Map<String, dynamic>>.from(
            (result['data'] as Map?)?.map((k, v) => MapEntry(k, v != null ? Map<String, dynamic>.from(v) : {})) ?? {},
          );
          _loadedMonths[key] = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadedMonths[key] = true);
    }
  }

  String _monthKey(DateTime d) => '${d.year}-${(d.month).toString().padLeft(2, '0')}';

  void _toggleDay(int day, int year, int month) {
    final key = '$year-$month-$day';
    setState(() {
      _selectedDays.contains(key) ? _selectedDays.remove(key) : _selectedDays.add(key);
    });
  }

  void _configureSelectedDays() async {
    // Предзагружаем данные для выбранных дней, чтобы избежать мигания
    final monthsToLoad = <String>{};
    for (final key in _selectedDays) {
      final parts = key.split('-');
      final y = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      monthsToLoad.add(_monthKey(DateTime(y, m)));
    }
    
    // Ждём загрузки всех нужных месяцев
    await Future.wait(monthsToLoad.map((mk) async {
      if (_loadedMonths[mk] != true) {
        final parts = mk.split('-');
        await _fetchSchedule(int.parse(parts[0]), int.parse(parts[1]));
      }
    }));
    
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _DayConfigSheet(
        employeeId: widget.employeeId,
        projectId: widget.projectId,
        selectedDays: _selectedDays.toSet(),
        onSaved: () {
          _selectedDays.clear();
          _loadedMonths.clear();
          _scheduleData.clear();
          _loadMonthsAround(_currentMonth);
        },
      ),
    );
  }

  void _clearSelectedDays() {
    setState(() {
      for (final key in _selectedDays) {
        final parts = key.split('-');
        final y = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final mk = _monthKey(DateTime(y, m));
        _scheduleData[mk]?.remove(parts[2]);
      }
      _selectedDays.clear();
    });
  }

  double _getMonthHeight() {
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstDay = (DateTime(_currentMonth.year, _currentMonth.month, 1).weekday - 1) % 7;
    final rows = ((firstDay + daysInMonth) / 7).ceil();
    
    const headerHeight = 44.0;
    const weekdayHeight = 20.0;
    const dayCellHeight = 52.0;
    const margins = 8.0;
    
    return headerHeight + weekdayHeight + (rows * dayCellHeight) + margins;
  }

  void _scrollToCurrentMonth() {
    if (!_scrollController.hasClients || _initialScrollDone) return;
    
    final currentMonthIndex = 6;
    final monthHeight = _getMonthHeight();
    final targetOffset = currentMonthIndex * monthHeight;
    
    _scrollController.jumpTo(targetOffset);
    _initialScrollDone = true;
  }

  List<Widget> _buildMonthWidgets() {
    final widgets = <Widget>[];
    for (int i = -6; i <= 6; i++) {
      final m = DateTime(_currentMonth.year, _currentMonth.month + i);
      widgets.add(_buildMonth(m.year, m.month));
    }
    return widgets;
  }

  Widget _buildMonth(int year, int month) {
    final key = _monthKey(DateTime(year, month));
    final data = _scheduleData[key] ?? {};
    final loaded = _loadedMonths[key] == true;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstDay = (DateTime(year, month, 1).weekday - 1) % 7;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text('${_months[month - 1]} $year', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
        Row(
          children: _weekdays.map((d) => Expanded(
            child: Center(child: Text(d, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: d == 'Сб' || d == 'Вс' ? const Color(0xFFDD1847) : const Color(0xFF888888)))),
          )).toList(),
        ),
        for (int row = 0; row < ((firstDay + daysInMonth) / 7).ceil(); row++)
          Row(
            children: List.generate(7, (col) {
              final idx = row * 7 + col;
              if (idx < firstDay || idx >= firstDay + daysInMonth) {
                return const Expanded(child: SizedBox(height: 56));
              }
              final day = idx - firstDay + 1;
              final dayKey = day.toString();
              final schedule = data[dayKey];
              final selKey = '$year-$month-$day';
              final selected = _selectedDays.contains(selKey);
              final isWeekend = col >= 5;

              return Expanded(
                child: GestureDetector(
                  onTap: () => _toggleDay(day, year, month),
                  child: Container(
                    height: 56,
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFFFDF2F5) : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Stack(children: [
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text('$day', style: TextStyle(fontSize: 14, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: isWeekend ? const Color(0xFFDD1847) : selected ? const Color(0xFFDD1847) : const Color(0xFF1A1A1A))),
                            if (loaded && schedule != null)
                              Container(
                                margin: const EdgeInsets.only(top: 2),
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: schedule['is_day_off'] == true ? const Color(0xFFFCE4E4) : const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  schedule['is_day_off'] == true ? 'Вых.' : '${(schedule['start_time'] ?? '09:00').toString().substring(0, 5)}–${(schedule['end_time'] ?? '18:00').toString().substring(0, 5)}',
                                  style: TextStyle(fontSize: 9, color: schedule['is_day_off'] == true ? const Color(0xFFC62828) : const Color(0xFF666666)),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            else if (!loaded)
                              Container(
                                margin: const EdgeInsets.only(top: 2),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const SkeletonBox(height: 9, width: 36, radius: 4),
                              ),
                          ],
                        ),
                      ),
                      if (selected)
                        Positioned(top: 4, right: 4, child: Container(width: 16, height: 16, decoration: const BoxDecoration(color: Color(0xFFDD1847), shape: BoxShape.circle), child: const Icon(Icons.check, size: 10, color: Colors.white))),
                    ]),
                  ),
                ),
              );
            }),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentMonth();
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showMonthPicker = !_showMonthPicker),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Flexible(
                      child: Text(
                        '${_months[_currentMonth.month - 1]} ${_currentMonth.year}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                  ]),
                ),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ]),
          ),

          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: _buildMonthWidgets(),
            ),
          ),

          if (_selectedDays.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, -4))]),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Выбрано: ${_selectedDays.length} дн.', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: TextButton(onPressed: () => setState(() => _selectedDays.clear()), child: const Text('Сбросить', style: TextStyle(fontSize: 13)))),
                    Expanded(child: TextButton(onPressed: _clearSelectedDays, child: const Text('Очистить', style: TextStyle(color: Color(0xFFDD1847), fontSize: 13)))),
                    Expanded(child: ElevatedButton(onPressed: _configureSelectedDays, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDD1847), padding: const EdgeInsets.symmetric(vertical: 10)), child: const Text('Настроить', style: TextStyle(fontSize: 13, color: Colors.white)))),
                  ]),
                ],
              ),
            ),
        ]),
      ),
    );
  }
}

// ==================== НАСТРОЙКА ДНЯ ====================
class _DayConfigSheet extends StatefulWidget {
  final int employeeId;
  final int projectId;
  final Set<String> selectedDays;
  final VoidCallback onSaved;

  const _DayConfigSheet({required this.employeeId, required this.projectId, required this.selectedDays, required this.onSaved});

  @override
  State<_DayConfigSheet> createState() => _DayConfigSheetState();
}

class _DayConfigSheetState extends State<_DayConfigSheet> {
  bool _isWorking = true;
  bool _isAllDay = false;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 18, minute: 0);
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final days = widget.selectedDays.map((key) {
      final parts = key.split('-');
      return {'year': int.parse(parts[0]), 'month': int.parse(parts[1]), 'day': int.parse(parts[2])};
    }).toList();

    try {
      await ApiService.post('/api/employee/schedule/save', {
        'employee_id': widget.employeeId,
        'project_id': widget.projectId,
        'days': days,
        'start_time': _isAllDay ? null : '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
        'end_time': _isAllDay ? null : '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
        'is_all_day': _isAllDay,
        'is_day_off': !_isWorking,
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
        showToast(context, 'График сохранён');
      }
    } catch (_) {
      if (mounted) showToast(context, 'Ошибка сохранения', isError: true);
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _pickStartTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _startTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFFDD1847),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (t != null) setState(() => _startTime = t);
  }

  Future<void> _pickEndTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _endTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFFDD1847),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (t != null) setState(() => _endTime = t);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Настройка дня', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Выбрано дней: ${widget.selectedDays.length}', style: const TextStyle(color: Color(0xFF888888))),
        const SizedBox(height: 20),
        Row(children: [
          const Text('Рабочий день'),
          const Spacer(),
          Switch(value: _isWorking, onChanged: (v) => setState(() => _isWorking = v), activeThumbColor: const Color(0xFFDD1847)),
        ]),
        if (_isWorking) ...[
          const SizedBox(height: 16),
          Row(children: [
            const Text('Весь день'),
            const Spacer(),
            Switch(value: _isAllDay, onChanged: (v) => setState(() => _isAllDay = v), activeThumbColor: const Color(0xFFDD1847)),
          ]),
          if (!_isAllDay) ...[
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: GestureDetector(onTap: _pickStartTime, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE0E0E0)), borderRadius: BorderRadius.circular(10)), child: Text('${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 14))))),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('—')),
              Expanded(child: GestureDetector(onTap: _pickEndTime, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE0E0E0)), borderRadius: BorderRadius.circular(10)), child: Text('${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 14))))),
            ]),
          ],
        ],
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
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
      ]),
    );
  }
}