import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../widgets/skeletons.dart';
import '../../../widgets/cached_image.dart';
import '../../../utils/name_utils.dart';
import '../../../widgets/common/avatar_initials.dart';
import '../../../widgets/toast.dart';
import '../../widgets/common/time_picker_sheet.dart';
import 'create_booking_sheet.dart';

// ==================== МОДЕЛЬ ДАННЫХ МЕСЯЦА ====================
class _MonthData {
  final int year;
  final int month;
  final List<DateTime> dates;
  final List<Map<String, dynamic>> employees;
  final Map<int, Set<int>> bookingDays;

  _MonthData({
    required this.year,
    required this.month,
    required this.dates,
    required this.employees,
    required this.bookingDays,
  });

  String get key => '$year-${month.toString().padLeft(2, '0')}';
}

// ==================== ЭКРАН ====================
class ScheduleViewScreenV2 extends StatefulWidget {
  final int projectId;
  const ScheduleViewScreenV2({super.key, required this.projectId});

  @override
  State<ScheduleViewScreenV2> createState() => _ScheduleViewScreenV2State();
}

class _ScheduleViewScreenV2State extends State<ScheduleViewScreenV2> {
  // ===== Состояние =====
  List<_MonthData> _months = [];
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _loading = true;
  bool _appendLock = false;
  bool _initialScrollSkip = true;
  final Set<String> _selectedCells = {};
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadInitialMonth();
    _horizontalScrollController.addListener(_onHorizontalScroll);
    // 1с — не триггерит appendPrev при открытии
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) _initialScrollSkip = false;
    });
  }

  @override
  void dispose() {
    _horizontalScrollController.removeListener(_onHorizontalScroll);
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  // ===== Первичная загрузка =====
  Future<void> _loadInitialMonth() async {
    final data = await _fetchMonth(_currentMonth.year, _currentMonth.month);
    if (mounted && data != null) {
      setState(() {
        _months = [data];
        _loading = false;
      });
    }
  }

  // ===== Fetch одного месяца =====
  Future<_MonthData?> _fetchMonth(int year, int month) async {
    final projectId = widget.projectId;
    final monthStr = month.toString().padLeft(2, '0');
    final lastDay = DateTime(year, month + 1, 0).day;
    final endDate = '$year-$monthStr-${lastDay.toString().padLeft(2, '0')}';
    try {
      // 1) Сотрудники
      final empResult = await ApiService.get('/api/employee/list?project_id=$projectId');
      List<Map<String, dynamic>> emps = [];
      if (empResult['success'] == true) {
        emps = List<Map<String, dynamic>>.from(empResult['data'] ?? []);
      }

      // 2) Booking days (для индикатора)
      final Map<int, Set<int>> bookingDays = {};
      try {
        final bookingResult = await ApiService.get(
          '/api/booking/list?project_id=$projectId&date=$year-$monthStr-01&end_date=$endDate',
        );
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
                bookingDays.putIfAbsent(empId, () => {});
                bookingDays[empId]!.add(day);
              }
            }
          }
        }
      } on ApiException catch (e) {
        if (mounted) showToast(context, e.message, isError: true);
      }

      // 3) График каждого сотрудника (schedule_data по дню)
      final futures = emps.map((e) async {
        final schedResult = await ApiService.get(
          '/api/employee/schedule/get?employee_id=${e['id']}&project_id=$projectId&year=$year&month=$monthStr',
        );
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
      final fetchedEmployees = await Future.wait(futures);

      // 4) Нормализация ключей → YYYY-MM-DD (единый формат)
      for (final emp in fetchedEmployees) {
        final oldData = emp['schedule_data'];
        if (oldData is Map<String, dynamic>) {
          final newData = <String, dynamic>{};
          oldData.forEach((k, v) {
            final day = int.tryParse(k);
            if (day != null) {
              newData['$year-$monthStr-${day.toString().padLeft(2, '0')}'] = v;
            } else {
              newData[k] = v;
            }
          });
          emp['schedule_data'] = newData;
        }
      }

      final dim = DateTime(year, month + 1, 0).day;
      final dates = List.generate(dim, (i) => DateTime(year, month, i + 1));
      return _MonthData(
        year: year,
        month: month,
        dates: dates,
        employees: fetchedEmployees,
        bookingDays: bookingDays,
      );
    } catch (e) {
      debugPrint('[SCHED-v2] _fetchMonth ERROR: $e');
      if (mounted) setState(() => _loading = false);
      return null;
    }
  }

  // ===== onScroll — append next/prev при краях =====
  void _onHorizontalScroll() {
    if (!_horizontalScrollController.hasClients) return;
    if (_initialScrollSkip) return;
    if (_appendLock || _loading) return;
    final pos = _horizontalScrollController.position;
    final nearRight = pos.pixels >= (pos.maxScrollExtent - 10);
    final nearLeft = pos.pixels <= 10;
    if (nearRight) {
      appendNextMonth();
    } else if (nearLeft && _months.length > 1) {
      appendPrevMonth();
    }
  }

  Future<void> appendNextMonth() async {
    if (_appendLock) return;
    _appendLock = true;
    try {
      final last = _months.last;
      final next = DateTime(last.year, last.month + 1, 1);
      final data = await _fetchMonth(next.year, next.month);
      if (mounted && data != null) {
        setState(() => _months.add(data));
      }
    } finally {
      _appendLock = false;
    }
  }

  Future<void> appendPrevMonth() async {
    if (_appendLock) return;
    _appendLock = true;
    final prevScrollLeft = _horizontalScrollController.hasClients
        ? _horizontalScrollController.offset
        : 0.0;
    try {
      final first = _months.first;
      final prev = DateTime(first.year, first.month - 1, 1);
      final data = await _fetchMonth(prev.year, prev.month);
      if (mounted && data != null) {
        setState(() => _months.insert(0, data));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_horizontalScrollController.hasClients) return;
          final delta = data.dates.length * 85.0;
          _horizontalScrollController.jumpTo(prevScrollLeft + delta);
        });
      }
    } finally {
      _appendLock = false;
    }
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    final weekdays = const ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'];
    final months = const ['янв.', 'фев.', 'мар.', 'апр.', 'мая', 'июн.', 'июл.', 'авг.', 'сен.', 'окт.', 'ноя.', 'дек.'];
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
          const Expanded(
            child: Text('График работы', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ),
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
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _months.asMap().entries.map((entry) => _buildMonthTable(
                              entry.value, weekdays, months,
                              fixedColWidth, cellWidth, headerHeight, rowHeight,
                              showFixedCol: entry.key == 0,
                            )).toList(),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 0,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(color: Color(0x0A000000), offset: Offset(2, 0), blurRadius: 4),
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
                              ..._buildFixedEmployeesColumn(fixedColWidth, rowHeight),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
      if (_selectedCells.isNotEmpty) _buildSelectionPanel(),
    ]);
  }

  // ==================== КОЛОНКА СОТРУДНИКОВ (фикс. слева) ====================
  List<Widget> _buildFixedEmployeesColumn(double fixedColWidth, double rowHeight) {
    if (_months.isEmpty) return [];
    return _months.first.employees.map((e) {
      return Container(
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
      );
    }).toList();
  }

  // ==================== ТАБЛИЦА МЕСЯЦА ====================
  Widget _buildMonthTable(
    _MonthData m,
    List<String> weekdays,
    List<String> months,
    double fixedColWidth,
    double cellWidth,
    double headerHeight,
    double rowHeight, {
    bool showFixedCol = false,
  }) {
    return Column(
      key: ValueKey('m-${m.year}-${m.month}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          if (showFixedCol) SizedBox(width: fixedColWidth, height: headerHeight),
          ...m.dates.map((d) => _buildDateHeader(d, weekdays, months, cellWidth, headerHeight)),
        ]),
        ...m.employees.map((e) => Row(children: [
          if (showFixedCol) SizedBox(width: fixedColWidth, height: rowHeight),
          ...m.dates.map((d) => _buildCell(e, d, m, cellWidth, rowHeight)),
        ])),
      ],
    );
  }

  Widget _buildDateHeader(DateTime d, List<String> weekdays, List<String> months,
      double cellWidth, double headerHeight) {
    return Container(
      width: cellWidth,
      height: headerHeight,
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
          Text('${d.day}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          Text(months[d.month - 1], style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
        ],
      ),
    );
  }

  Widget _buildCell(Map<String, dynamic> e, DateTime d, _MonthData m,
      double cellWidth, double rowHeight) {
    final key = '${e['id']}_${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final sel = _selectedCells.contains(key);
    final range = _timeRange(e, d);
    final isWeekend = d.weekday == 6 || d.weekday == 7;
    final empId = e['id'] as int;
    final hasBookings = m.bookingDays[empId]?.contains(d.day) ?? false;

    return GestureDetector(
      onTap: () => _toggleCell(e['id'] as int, d),
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
              Container(
                width: 76, height: 46,
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
              if (_isOnlineClosed(e, d))
                Positioned(
                  top: 4, right: 4,
                  child: Icon(Icons.public_off, size: 14, color: const Color(0xFFDD1847).withValues(alpha: 0.55)),
                ),
              if (hasBookings)
                Positioned(
                  bottom: 6,
                  child: Container(
                    width: 5, height: 5,
                    decoration: BoxDecoration(
                      color: sel ? Colors.white : const Color(0xFFDD1847),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== МЕТОДЫ ====================
  String _timeRange(Map<String, dynamic> emp, DateTime date) {
    final scheduleData = emp['schedule_data'];
    if (scheduleData is Map<String, dynamic> && scheduleData.isNotEmpty) {
      final fullKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final daySchedule = scheduleData[fullKey];
      if (daySchedule != null && daySchedule is Map<String, dynamic>) {
        if (daySchedule['is_day_off'] == true) return 'Выходной';
        final startTime = daySchedule['start_time']?.toString();
        final endTime = daySchedule['end_time']?.toString();
        if (startTime != null && endTime != null) {
          return '${startTime.substring(0, 5)} – ${endTime.substring(0, 5)}';
        }
      }
    }
    return '';
  }

  bool _isOnlineClosed(Map<String, dynamic> emp, DateTime date) {
    final scheduleData = emp['schedule_data'];
    if (scheduleData is Map<String, dynamic>) {
      final fullKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final daySchedule = scheduleData[fullKey];
      if (daySchedule is Map<String, dynamic> && daySchedule['online_booking'] == false) {
        return true;
      }
    }
    return false;
  }

  void _toggleCell(int empId, DateTime date) {
    final key = '${empId}_${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    setState(() {
      _selectedCells.contains(key) ? _selectedCells.remove(key) : _selectedCells.add(key);
    });
  }

  void _clearSelection() => setState(() => _selectedCells.clear());

  bool get _canCreateBookingFromSelection {
    if (_selectedCells.length != 1) return false;
    final key = _selectedCells.first;
    final parts = key.split('_');
    if (parts.length < 2) return false;
    final empId = int.tryParse(parts[0]);
    if (empId == null) return false;
    final dateParts = parts[1].split('-');
    if (dateParts.length != 3) return false;
    final year = int.tryParse(dateParts[0]);
    final month = int.tryParse(dateParts[1]);
    final day = int.tryParse(dateParts[2]);
    if (year == null || month == null || day == null) return false;
    for (final m in _months) {
      final emp = m.employees.firstWhere(
        (e) => e['id'] == empId,
        orElse: () => <String, dynamic>{},
      );
      if (emp.isNotEmpty) {
        final range = _timeRange(emp, DateTime(year, month, day));
        return range.isNotEmpty && range != 'Выходной';
      }
    }
    return false;
  }

  void _createBookingFromSelection() {
    if (_selectedCells.length != 1) return;
    final key = _selectedCells.first;
    final parts = key.split('_');
    if (parts.length < 2) return;
    final empId = int.tryParse(parts[0]);
    if (empId == null) return;
    final dateParts = parts[1].split('-');
    if (dateParts.length != 3) return;
    final year = int.tryParse(dateParts[0]);
    final month = int.tryParse(dateParts[1]);
    final day = int.tryParse(dateParts[2]);
    if (year == null || month == null || day == null) return;
    final dateStr = '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => CreateBookingSheet(
        projectId: widget.projectId,
        employeeId: empId,
        date: dateStr,
        startTime: '09:00',
      ),
    ).then((result) {
      if (result == true && mounted) {
        setState(() => _selectedCells.clear());
        _loadInitialMonth();
      }
    });
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
            _selectedCells.clear();
            _loading = true;
          });
          _loadInitialMonth();
          Navigator.pop(context);
        },
      ),
    );
  }

  void _openScheduleSettings() {
    if (_selectedCells.isNotEmpty) {
      final allDates = _months.expand((m) => m.dates).toList();
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _ScheduleSettingsSheet(
          projectId: widget.projectId,
          onSaved: () {
            _selectedCells.clear();
            _loadInitialMonth();
          },
          initialMode: 'time_config',
          selectedCells: _selectedCells.toSet(),
          dates: allDates,
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _ScheduleSettingsSheet(
          projectId: widget.projectId,
          onSaved: () => _loadInitialMonth(),
        ),
      );
    }
  }

  Widget _buildSelectionPanel() {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: [
            BoxShadow(color: Color(0x14000000), blurRadius: 24, offset: Offset(0, -4)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      Text(
                        'Выбрано: ${_selectedCells.length}',
                        style: const TextStyle(color: Color(0xFF8A8A8E), fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      const Spacer(),
                      if (_canCreateBookingFromSelection)
                        _ApplePrimaryButton(
                          label: 'Создать запись',
                          icon: Icons.add_rounded,
                          onTap: _createBookingFromSelection,
                        ),
                    ],
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Expanded(child: _AppleSecondaryChip(icon: Icons.close_rounded, label: 'Сбросить', onTap: _clearSelection, tone: _AppleSecondaryTone.gray)),
                    const SizedBox(width: 8),
                    Expanded(child: _AppleSecondaryChip(icon: Icons.delete_outline_rounded, label: 'Очистить', onTap: _clearSelection, tone: _AppleSecondaryTone.danger)),
                    const SizedBox(width: 8),
                    Expanded(child: _AppleSecondaryChip(icon: Icons.tune_rounded, label: 'Настроить', onTap: _openScheduleSettings, tone: _AppleSecondaryTone.primary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== APPLE BUTTONS ====================
class _ApplePrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _ApplePrimaryButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFDD1847), Color(0xFFC1163D)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFDD1847).withValues(alpha: 0.28),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
                  child: Icon(icon, color: Colors.white, size: 15),
                ),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: -0.1)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _AppleSecondaryTone { gray, danger, primary }

class _AppleSecondaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final _AppleSecondaryTone tone;
  const _AppleSecondaryChip({required this.icon, required this.label, required this.onTap, this.tone = _AppleSecondaryTone.primary});

  @override
  Widget build(BuildContext context) {
    late final Color fg;
    late final Color bg;
    if (tone == _AppleSecondaryTone.gray) {
      fg = const Color(0xFF6E6E73);
      bg = const Color(0xFFF2F2F7);
    } else if (tone == _AppleSecondaryTone.danger) {
      fg = const Color(0xFFFF3B30);
      bg = const Color(0x14FF3B30);
    } else {
      fg = const Color(0xFF007AFF);
      bg = const Color(0x14007AFF);
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 4),
              Flexible(
                child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg, letterSpacing: -0.1), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== ВЫБОР МЕСЯЦА ====================
class _MonthPickerWidget extends StatelessWidget {
  final int selectedYear;
  final int selectedMonth;
  final Function(int, int) onSelected;
  const _MonthPickerWidget({required this.selectedYear, required this.selectedMonth, required this.onSelected});

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
              spacing: 8, runSpacing: 8,
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


