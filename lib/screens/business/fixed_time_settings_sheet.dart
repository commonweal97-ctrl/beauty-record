import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import '../../../widgets/skeletons.dart';
import '../../../widgets/toast.dart';

class FixedTimeSettingsSheet extends StatefulWidget {
  final int employeeId;
  final int projectId;
  final VoidCallback onSaved;

  const FixedTimeSettingsSheet({
    super.key,
    required this.employeeId,
    required this.projectId,
    required this.onSaved,
  });

  @override
  State<FixedTimeSettingsSheet> createState() => _FixedTimeSettingsSheetState();
}

class _FixedTimeSettingsSheetState extends State<FixedTimeSettingsSheet> {
  bool _enabled = false;
  bool _offerOther = false;
  bool _specificEnabled = false;

  Set<int> _activeWeekdays = {1, 2, 3, 4, 5};
  List<String> _weekdayTimes = [];

  Map<String, Map<String, dynamic>> _specificDays = {};
  DateTime _calendarMonth = DateTime.now();
  final Set<DateTime> _selectedDates = {};

  bool _loading = true;
  bool _saving = false;

  static const _weekdayNames = ['', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
  static const _weekdayFull = ['', 'Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'];
  static const _months = ['', 'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await ApiService.get('/api/employee/get-fixed-time?employee_id=${widget.employeeId}&project_id=${widget.projectId}');
      if (result['success'] == true && mounted) {
        final d = result['data'];
        final td = d['time_data'] as Map<String, dynamic>? ?? {};
        setState(() {
          _enabled = d['enabled'] == true;
          _offerOther = d['offer_other'] == true;
          _activeWeekdays = Set<int>.from((td['weekdays'] as List?)?.cast<int>() ?? [1, 2, 3, 4, 5]);
          _weekdayTimes = List<String>.from((td['times'] as List?)?.cast<String>() ?? []);
          _specificDays = Map<String, Map<String, dynamic>>.from(
            (td['specific_days'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, Map<String, dynamic>.from(v))) ?? {},
          );
          _specificEnabled = _specificDays.isNotEmpty;
          _loading = false;
        });
      } else if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiService.post('/api/employee/save-fixed-time', {
        'employee_id': widget.employeeId,
        'project_id': widget.projectId,
        'enabled': _enabled,
        'offer_other': _offerOther,
        'time_data': {
          'weekdays': _activeWeekdays.toList(),
          'times': _weekdayTimes,
          'specific_days': _specificDays,
          'mode': 'weekdays',
        },
      });
      if (mounted) {
        widget.onSaved();
        Navigator.pop(context);
        showToast(context, 'График сохранён');
      }
    } catch (_) {
      if (mounted) showToast(context, 'Ошибка сохранения', isError: true);
    }
    if (mounted) setState(() => _saving = false);
  }

  void _pickWeekdayTime() async {
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _TimePickerSheet(initialTimes: _weekdayTimes),
    );
    if (result != null) setState(() => _weekdayTimes = result);
  }

  void _pickSpecificTime() async {
    if (_selectedDates.isEmpty) return;
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _TimePickerSheet(initialTimes: []),
    );
    if (result != null) {
      setState(() {
        for (final date in _selectedDates) {
          final key = DateFormat('yyyy-MM-dd').format(date);
          _specificDays[key] = {'is_day_off': false, 'times': result};
        }
        _specificEnabled = _specificDays.isNotEmpty;
        _selectedDates.clear();
      });
    }
  }

  void _setSpecificDayOff() {
    setState(() {
      for (final date in _selectedDates) {
        final key = DateFormat('yyyy-MM-dd').format(date);
        _specificDays[key] = {'is_day_off': true, 'times': []};
      }
      _specificEnabled = _specificDays.isNotEmpty;
      _selectedDates.clear();
    });
  }

  void _resetSpecificDays() {
    setState(() {
      for (final date in _selectedDates) {
        final key = DateFormat('yyyy-MM-dd').format(date);
        _specificDays.remove(key);
      }
      _specificEnabled = _specificDays.isNotEmpty;
      _selectedDates.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: const Center(
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
      ),
    );
    }

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.9,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))),
          child: Row(children: [
            GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.arrow_back)),
            const Spacer(),
            const Text('Фиксированное время', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const Spacer(),
            GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close)),
          ]),
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.all(20), children: [
            _buildSection('Фиксированное время', 'Включите, чтобы задать фиксированное время записи', _enabled, (v) => setState(() => _enabled = v)),
            const SizedBox(height: 24),
            _buildSectionTitle('Время начала записей по дням недели'),
            const SizedBox(height: 4),
            _buildHint('Укажите время для определенных дней недели, на которое клиенты смогут записаться онлайн. Клиенту будет предложено только это время из свободного. Фиксированное время может быть настроено индивидуально для разных дней недели'),
            const SizedBox(height: 12),
            _buildWeekdayButtons(),
            const SizedBox(height: 8),
            _buildWeekdayPreview(),
            const SizedBox(height: 8),
            if (_activeWeekdays.isNotEmpty)
              Align(alignment: Alignment.centerLeft, child: TextButton.icon(
                onPressed: _enabled ? _pickWeekdayTime : null,
                icon: const Icon(Icons.access_time, size: 16),
                label: const Text('Изменить время'),
                style: TextButton.styleFrom(foregroundColor: _enabled ? const Color(0xFFDD1847) : const Color(0xFFCCCCCC)),
              )),
            const SizedBox(height: 20),
            _buildSection('Предлагать другое время после заполнения фиксированного', 'Позволяет заполнять полный рабочий день, предлагая свободные окна между фиксированными записями', _offerOther, (v) => setState(() => _offerOther = v), small: true),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            _buildSection('Время записи на определённые дни', 'Настройте время для конкретных дней, отличное от недельного расписания. Выберите один или несколько дней для массового редактирования', _specificEnabled, (v) => setState(() => _specificEnabled = v)),
            if (_specificEnabled) ...[
              const SizedBox(height: 12),
              _buildMiniCalendar(),
              if (_selectedDates.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, -4))]),
                  child: Row(children: [
                    Expanded(child: Text('Выбрано дней: ${_selectedDates.length}', style: const TextStyle(fontSize: 13, color: Color(0xFF666666)))),
                    TextButton(onPressed: _resetSpecificDays, child: const Text('Сбросить', style: TextStyle(fontSize: 12))),
                    TextButton(onPressed: _setSpecificDayOff, child: const Text('Нерабочий', style: TextStyle(color: Color(0xFFDD1847), fontSize: 12))),
                    ElevatedButton(onPressed: _pickSpecificTime, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDD1847), padding: const EdgeInsets.symmetric(horizontal: 8)), child: const Text('Время', style: TextStyle(fontSize: 12, color: Colors.white))),
                  ]),
                ),
            ],
          ]),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF0F0F0)))),
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

  Widget _buildSection(String title, String subtitle, bool value, ValueChanged<bool> onChanged, {bool small = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: small ? 13 : 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF999999), height: 1.3)),
        ])),
        Switch(value: value, onChanged: onChanged, activeThumbColor: const Color(0xFFDD1847)),
      ]),
    );
  }

  Widget _buildSectionTitle(String text) => Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)));
  Widget _buildHint(String text) => Text(text, style: const TextStyle(fontSize: 11, color: Color(0xFF999999), height: 1.4));

  Widget _buildWeekdayButtons() {
    final labels = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return Wrap(spacing: 4, runSpacing: 4, children: List.generate(7, (i) {
      final dayKey = i + 1;
      final active = _activeWeekdays.contains(dayKey);
      return GestureDetector(
        onTap: () => setState(() { active ? _activeWeekdays.remove(dayKey) : _activeWeekdays.add(dayKey); }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: active ? const Color(0xFFDD1847) : const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(20), border: Border.all(color: active ? const Color(0xFFDD1847) : const Color(0xFFE0E0E0))),
          child: Text(labels[i], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: active ? Colors.white : const Color(0xFF666666))),
        ),
      );
    }));
  }

  Widget _buildWeekdayPreview() {
    if (_activeWeekdays.isEmpty) {
      return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(8)), child: const Text('Время не задано', style: TextStyle(color: Color(0xFF999999), fontSize: 13)));
    }
    final labels = ['', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final weekdays = _activeWeekdays.map((d) => labels[d]).join(', ');
    final timesText = _weekdayTimes.isEmpty ? 'Время не задано' : _weekdayTimes.take(3).join(', ') + (_weekdayTimes.length > 3 ? '...' : '');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(8)),
      child: RichText(text: TextSpan(style: const TextStyle(fontSize: 13, color: Color(0xFF666666)), children: [
        TextSpan(text: weekdays, style: const TextStyle(backgroundColor: Color(0xFFFDF2F5), color: Color(0xFFDD1847), fontWeight: FontWeight.w500)),
        TextSpan(text: ' $timesText'),
      ])),
    );
  }

  Widget _buildMiniCalendar() {
    final year = _calendarMonth.year;
    final month = _calendarMonth.month;
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final startOffset = firstDay.weekday % 7;
    final today = DateTime.now();
    final cellWidth = (MediaQuery.of(context).size.width - 64) / 7;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Row(children: [
          GestureDetector(onTap: () => setState(() => _calendarMonth = DateTime(year, month - 1)), child: const Icon(Icons.chevron_left, size: 20)),
          const SizedBox(width: 12),
          Text('${_months[month]} $year', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          GestureDetector(onTap: () => setState(() => _calendarMonth = DateTime(year, month + 1)), child: const Icon(Icons.chevron_right, size: 20)),
        ]),
        const SizedBox(height: 8),
        Row(
          children: ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб']
              .map((d) => SizedBox(width: cellWidth, child: Text(d, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Color(0xFF999999)))))
              .toList(),
        ),
        const SizedBox(height: 4),
        Wrap(children: [
          for (int i = 0; i < startOffset; i++)
            SizedBox(width: cellWidth, height: 36),
          for (int i = 1; i <= lastDay.day; i++)
            _buildCalendarDay(i, year, month, today, cellWidth),
        ]),
      ]),
    );
  }

  Widget _buildCalendarDay(int day, int year, int month, DateTime today, double cellWidth) {
    final date = DateTime(year, month, day);
    final key = DateFormat('yyyy-MM-dd').format(date);
    final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
    final isSelected = _selectedDates.any((d) => d.year == date.year && d.month == date.month && d.day == date.day);
    final isDayOff = _specificDays[key]?['is_day_off'] == true;
    final hasTime = _specificDays[key] != null && !isDayOff;

    return GestureDetector(
      onTap: () => setState(() {
        if (isSelected) {
          _selectedDates.removeWhere((d) => d.year == date.year && d.month == date.month && d.day == date.day);
        } else {
          _selectedDates.add(date);
        }
      }),
      child: Container(
        width: cellWidth, height: 36, margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFDD1847) : isDayOff ? const Color(0xFFE8E8E8) : hasTime ? const Color(0xFFFDF2F5) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: isToday && !isSelected ? Border.all(color: const Color(0xFFDD1847), width: 2) : null,
        ),
        child: Center(child: Text('$day', style: TextStyle(fontSize: 13, fontWeight: isToday ? FontWeight.w600 : FontWeight.w400, color: isSelected ? Colors.white : isDayOff ? const Color(0xFF999999) : const Color(0xFF1A1A1A)))),
      ),
    );
  }
}

// ==================== ПИКЕР ВРЕМЕНИ ====================
class _TimePickerSheet extends StatefulWidget {
  final List<String> initialTimes;
  const _TimePickerSheet({required this.initialTimes});

  @override
  State<_TimePickerSheet> createState() => _TimePickerSheetState();
}

class _TimePickerSheetState extends State<_TimePickerSheet> {
  late List<String> _selectedTimes;
  TimeOfDay _from = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _to = const TimeOfDay(hour: 20, minute: 0);
  int _step = 5;

  static const _steps = [5, 15, 30, 60, 90];

  @override
  void initState() {
    super.initState();
    _selectedTimes = List.from(widget.initialTimes);
  }

  List<String> _generateSlots() {
    final slots = <String>[];
    int fromMin = _from.hour * 60 + _from.minute;
    int toMin = _to.hour * 60 + _to.minute;
    for (int m = fromMin; m <= toMin; m += _step) {
      final h = (m ~/ 60).toString().padLeft(2, '0');
      final min = (m % 60).toString().padLeft(2, '0');
      slots.add('$h:$min');
    }
    return slots;
  }

  void _toggleSlot(String time) {
    setState(() {
      _selectedTimes.contains(time) ? _selectedTimes.remove(time) : _selectedTimes.add(time);
      _selectedTimes.sort();
    });
  }

  void _massSelect(int interval) {
    final slots = _generateSlots();
    setState(() {
      _selectedTimes = slots.where((s) {
        final parts = s.split(':');
        final m = int.parse(parts[0]) * 60 + int.parse(parts[1]);
        final fromMin = _from.hour * 60 + _from.minute;
        return (m - fromMin) % interval == 0;
      }).toList();
    });
  }

  Future<void> _pickFrom() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _from,
      helpText: 'Начало',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
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
    if (t != null) setState(() => _from = t);
  }

  Future<void> _pickTo() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _to,
      helpText: 'Конец',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
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
    if (t != null) setState(() => _to = t);
  }

  @override
  Widget build(BuildContext context) {
    final allSlots = _generateSlots();
    final morning = allSlots.where((s) => int.parse(s.split(':')[0]) < 12).toList();
    final afternoon = allSlots.where((s) { final h = int.parse(s.split(':')[0]); return h >= 12 && h < 18; }).toList();
    final evening = allSlots.where((s) => int.parse(s.split(':')[0]) >= 18).toList();

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))),
          child: Row(children: [
            const Expanded(child: Text('Настроить время', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ]),
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.all(20), children: [
            const Text('Диапазон', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: GestureDetector(onTap: _pickFrom, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE0E0E0)), borderRadius: BorderRadius.circular(10)), child: Text('${_from.hour.toString().padLeft(2, '0')}:${_from.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 14))))),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('—', style: TextStyle(color: Color(0xFF999999)))),
              Expanded(child: GestureDetector(onTap: _pickTo, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE0E0E0)), borderRadius: BorderRadius.circular(10)), child: Text('${_to.hour.toString().padLeft(2, '0')}:${_to.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 14))))),
            ]),
            const SizedBox(height: 16),
            const Text('Шаг вывода времени', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(spacing: 3, runSpacing: 3, children: _steps.map((s) => GestureDetector(
              onTap: () => setState(() => _step = s),
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: _step == s ? const Color(0xFFDD1847) : const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(20), border: Border.all(color: _step == s ? const Color(0xFFDD1847) : const Color(0xFFE0E0E0))), child: Text('$s мин', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _step == s ? Colors.white : const Color(0xFF666666)))),
            )).toList()),
            const SizedBox(height: 16),
            const Text('Выбор времени', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(spacing: 3, runSpacing: 3, children: [30, 60, 90, 180].map((m) {
              final label = m >= 180 ? 'Каждые ${m ~/ 60} ч' : 'Каждые $m мин';
              return GestureDetector(
                onTap: () => _massSelect(m),
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE0E0E0))), child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF666666)))),
              );
            }).toList()),
            const SizedBox(height: 16),
            if (morning.isNotEmpty) ...[
              const Text('УТРО', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF999999))),
              const SizedBox(height: 6),
              _buildSlotGrid(morning),
            ],
            if (afternoon.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('ДЕНЬ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF999999))),
              const SizedBox(height: 6),
              _buildSlotGrid(afternoon),
            ],
            if (evening.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('ВЕЧЕР', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF999999))),
              const SizedBox(height: 6),
              _buildSlotGrid(evening),
            ],
            const SizedBox(height: 80),
          ]),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFF0F0F0)))),
          child: SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
            onPressed: () => Navigator.pop(context, _selectedTimes),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDD1847), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Применить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
          )),
        ),
      ]),
    );
  }

  Widget _buildSlotGrid(List<String> slots) {
    return Wrap(spacing: 3, runSpacing: 3, children: slots.map((s) {
      final sel = _selectedTimes.contains(s);
      return GestureDetector(
        onTap: () => _toggleSlot(s),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: sel ? const Color(0xFFDD1847) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: sel ? const Color(0xFFDD1847) : const Color(0xFFE0E0E0)),
          ),
          child: Text(s, style: TextStyle(fontSize: 12, color: sel ? Colors.white : const Color(0xFF666666))),
        ),
      );
    }).toList());
  }
}