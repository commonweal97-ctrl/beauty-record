import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import '../../../widgets/skeletons.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/toast.dart';

class RepeatBookingScreen extends StatefulWidget {
  final int bookingId;
  final bool isReschedule;
  const RepeatBookingScreen({super.key, required this.bookingId, this.isReschedule = false});

  @override
  State<RepeatBookingScreen> createState() => _RepeatBookingScreenState();
}

class _RepeatBookingScreenState extends State<RepeatBookingScreen> {
  Map<String, dynamic>? _booking;
  List<String> _slots = [];
  DateTime _selectedDate = DateTime.now();
  String? _selectedTime;
  bool _loading = true;
  bool _showConfirm = false;
  int _totalDuration = 60;
  Set<String> _availableDates = {};

  String get _actionLabel => widget.isReschedule ? 'Перенос записи' : 'Повторная запись';
  String get _confirmTitle => widget.isReschedule ? 'Подтверждение переноса' : 'Подтверждение записи';
  String get _confirmBtn => widget.isReschedule ? 'Перенести' : 'Подтвердить';
  String get _successMsg => widget.isReschedule ? 'Запись перенесена!' : 'Запись создана!';
  String get _continueBtn => 'Продолжить';

  @override
  void initState() {
    super.initState();
    _loadBooking();
  }

  void _loadBooking() async {
    try {
      final result = await ApiService.get('/api/booking/get?booking_id=${widget.bookingId}');
      if (result['success'] == true && mounted) {
        setState(() {
          _booking = result['data'];
          _totalDuration = int.tryParse(result['data']['total_duration']?.toString() ?? '60') ?? 60;
          _loading = false;
        });
        _loadSlots();
        _loadAvailableDates();
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _loadAvailableDates() async {
    if (_booking == null) return;
    try {
      final dates = await ApiService.getAvailableDates(
        _booking!['project_id'] ?? 0,
        _booking!['master_id'] ?? 0,
        _booking!['service_ids'] ?? '',
      );
      if (mounted) setState(() => _availableDates = dates);
    } catch (_) {}
  }

  void _loadSlots() async {
    if (_booking == null) return;
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final projectId = _booking!['project_id'];
    final empId = _booking!['master_id'];

    try {
      final results = await Future.wait([
        ApiService.get('/api/booking/list?project_id=$projectId&date=$dateStr'),
        ApiService.get('/api/occupied-time/list?project_id=$projectId&date=$dateStr'),
        ApiService.get('/api/employee/schedule/get?employee_id=$empId&project_id=$projectId&year=${_selectedDate.year}&month=${_selectedDate.month}'),
        ApiService.get('/api/employee/get-fixed-time?employee_id=$empId&project_id=$projectId'),
      ]);

      final bookings = results[0]['success'] == true ? List<Map<String, dynamic>>.from(results[0]['data'] ?? []) : [];
      final occupied = results[1]['success'] == true ? List<Map<String, dynamic>>.from(results[1]['data'] ?? []) : [];
      final schedule = results[2]['success'] == true ? results[2]['data'] : {};
      final fixedTime = results[3]['success'] == true && results[3]['data'] != null && results[3]['data']['enabled'] == true ? results[3]['data'] : null;

      final bookedRanges = <Map<String, int>>[];
      for (final b in bookings) {
        if (b['status'] == 'cancelled') continue;
        bookedRanges.add({'start': _t(b['start_time']), 'end': _t(b['end_time']) + (int.tryParse(b['break_after']?.toString() ?? '0') ?? 0)});
      }
      for (final o in occupied) {
        bookedRanges.add({'start': _t(o['start_time']), 'end': _t(o['end_time'])});
      }

      int startMin = 9 * 60, endMin = 18 * 60;
      final dayKey = _selectedDate.day.toString();
      final daySchedule = schedule[dayKey];
      if (daySchedule != null) {
        if (daySchedule['is_working'] == false) { if (mounted) setState(() => _slots = []); return; }
        startMin = _t(daySchedule['start_time'] ?? '09:00');
        endMin = _t(daySchedule['end_time'] ?? '18:00');
      }

      final allSlots = <String>[];
      if (fixedTime != null) {
        for (final t in (fixedTime['time_data']?['times'] ?? []) as List) {
          final m = _t(t.toString());
          if (m >= startMin && m + _totalDuration <= endMin) allSlots.add(t.toString().substring(0, 5));
        }
      } else {
        for (int m = startMin; m + _totalDuration <= endMin; m += 30) {
          allSlots.add('${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}');
        }
      }

      final now = DateTime.now();
      final isToday = dateStr == DateFormat('yyyy-MM-dd').format(now);
      final currentMin = now.hour * 60 + now.minute + 30;

      if (mounted) {
        setState(() {
          _slots = allSlots.where((s) {
            final m = _t(s);
            final end = m + _totalDuration;
            if (bookedRanges.any((r) => m < r['end']! && end > r['start']!)) return false;
            if (isToday && m < currentMin) return false;
            return true;
          }).toList();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _slots = []);
    }
  }

  int _t(String t) {
    final parts = t.split(':');
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  void _openCalendar() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.white, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _CalendarPicker(
        selectedDate: _selectedDate, availableDates: _availableDates,
        onDateSelected: (date) { setState(() { _selectedDate = date; _selectedTime = null; }); Navigator.pop(ctx); _loadSlots(); },
      ),
    );
  }

  void _finish() async {
    if (_selectedTime == null || _booking == null) return;
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    try {
      final result = widget.isReschedule
          ? await ApiService.rescheduleBooking(bookingId: widget.bookingId, date: dateStr, time: '$_selectedTime:00')
          : await ApiService.createBooking(
              projectId: _booking!['project_id'] ?? 0, date: dateStr, startTime: '$_selectedTime:00',
              serviceIds: (_booking!['service_ids'] ?? '').toString().split(',').map((s) => int.tryParse(s.trim()) ?? 0).where((id) => id > 0).toList(),
              employeeId: _booking!['master_id'] ?? 0,
              clientName: _booking!['client_name'] ?? '', clientPhone: _booking!['client_phone'] ?? '',
            );
      if (result['success'] == true && mounted) {
        showToast(context, _successMsg);
        Navigator.pop(context);
      } else if (mounted) {
        showToast(context, result['message'] ?? result['error'] ?? 'Ошибка', isError: true);
      }
    } catch (e) {
      if (mounted) showToast(context, 'Ошибка соединения', isError: true);
    }
  }

  Widget _photoPlaceholder({double size = 36}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(size / 2),
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
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(backgroundColor: const Color(0xFFDD1847), foregroundColor: Colors.white, elevation: 0, title: Text(_actionLabel), leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context))),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SkeletonBox(height: 16, width: 200),
                const SizedBox(height: 8),
                const SkeletonBox(height: 16, width: 120),
                const SizedBox(height: 12),
                Row(children: [
                  const SkeletonCircle(size: 36),
                  const SizedBox(width: 8),
                  const SkeletonBox(height: 16, width: 140),
                ]),
              ]),
            ),
            const SizedBox(height: 16),
            Row(children: [
              const SkeletonBox(width: 44, height: 44, radius: 14),
              const SizedBox(width: 12),
              Expanded(child: SizedBox(height: 62, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: 5, itemBuilder: (_, _) => const Padding(padding: EdgeInsets.only(right: 8), child: SkeletonBox(width: 62, height: 62, radius: 14))))),
            ]),
            const SizedBox(height: 20),
            Wrap(spacing: 8, children: List.generate(6, (_) => const Padding(padding: EdgeInsets.only(bottom: 8), child: SkeletonBox(width: 80, height: 40, radius: 12)))),
          ]),
        ),
      );
    }
    if (_booking == null) return const Scaffold(backgroundColor: Colors.white, body: Center(child: Text('Ошибка загрузки')));
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(backgroundColor: const Color(0xFFDD1847), foregroundColor: Colors.white, elevation: 0,
        title: Text(_showConfirm ? _confirmTitle : _actionLabel),
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context))),
      body: _showConfirm ? _buildConfirm() : _buildSelect(),
    );
  }

  Widget _buildSelect() {
    final b = _booking!;
    final days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final masterAvatar = b['master_avatar'];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(b['service_names'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            if (b['total_price'] != null) Text('от ${b['total_price']} ₽', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFDD1847))),
            const SizedBox(height: 8),
            Row(children: [
              masterAvatar != null && masterAvatar.toString().isNotEmpty
                  ? CachedAvatar(url: masterAvatar, size: 36, radius: 18)
                  : _photoPlaceholder(),
              const SizedBox(width: 8), Text(b['master_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        Row(children: [
          GestureDetector(onTap: _openCalendar, child: Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFFDF2F5), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.calendar_today, color: Color(0xFFDD1847), size: 22))),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(height: 62, child: ListView.builder(
              scrollDirection: Axis.horizontal, itemCount: 30,
              itemBuilder: (_, i) {
                final date = DateTime.now().add(Duration(days: i));
                final dateStr = DateFormat('yyyy-MM-dd').format(date);
                if (_availableDates.isNotEmpty && !_availableDates.contains(dateStr)) return const SizedBox.shrink();
                final isSelected = dateStr == DateFormat('yyyy-MM-dd').format(_selectedDate);
                final isToday = dateStr == DateFormat('yyyy-MM-dd').format(DateTime.now());
                return GestureDetector(
                  onTap: () { setState(() { _selectedDate = date; _selectedTime = null; }); _loadSlots(); },
                  child: Container(
                    width: 62, margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFDD1847) : (isToday ? const Color(0xFFFDF2F5) : Colors.white),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isSelected ? const Color(0xFFDD1847) : (isToday ? const Color(0xFFDD1847).withValues(alpha: 0.5) : const Color(0xFFE8E8E8))),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text('${date.day}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : Colors.black)),
                      Text(days[date.weekday - 1], style: TextStyle(fontSize: 10, color: isSelected ? Colors.white70 : Colors.grey)),
                    ]),
                  ),
                );
              },
            )),
          ),
        ]),
        const SizedBox(height: 20),
        if (_slots.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('Нет доступного времени', style: TextStyle(color: Colors.grey))))
        else
          Wrap(spacing: 8, children: _slots.map((t) {
            final isSel = _selectedTime == t;
            return GestureDetector(
              onTap: () => setState(() => _selectedTime = t),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(color: isSel ? const Color(0xFFFDF2F5) : const Color(0xFFF8F8F8), border: Border.all(color: isSel ? const Color(0xFFDD1847) : const Color(0xFFE0E0E0)), borderRadius: BorderRadius.circular(12)),
                child: Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isSel ? const Color(0xFFDD1847) : Colors.black)),
              ),
            );
          }).toList()),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
          onPressed: _selectedTime != null ? () => setState(() => _showConfirm = true) : null,
          style: ElevatedButton.styleFrom(backgroundColor: _selectedTime != null ? const Color(0xFFDD1847) : Colors.grey, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: Text(_continueBtn, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
        )),
      ]),
    );
  }

  Widget _buildConfirm() {
    final b = _booking!;
    final dateStr = '${_selectedDate.day} ${['','января','февраля','марта','апреля','мая','июня','июля','августа','сентября','октября','ноября','декабря'][_selectedDate.month]} ${_selectedDate.year}';
    final masterAvatar = b['master_avatar'];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Дата и время', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))), const SizedBox(height: 4),
            Text(dateStr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text(_selectedTime ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFFDD1847))),
            const Divider(height: 24),
            const Text('Услуга', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            Text(b['service_names'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            if (b['total_price'] != null) Text('от ${b['total_price']} ₽', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFDD1847))),
            const Divider(height: 24),
            Row(children: [
              masterAvatar != null && masterAvatar.toString().isNotEmpty
                  ? CachedAvatar(url: masterAvatar, size: 40, radius: 20)
                  : _photoPlaceholder(size: 40),
              const SizedBox(width: 10),
              Text(b['master_name'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ]),
          ]),
        ),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => setState(() => _showConfirm = false), style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), padding: const EdgeInsets.symmetric(vertical: 16)), child: const Text('Назад'))),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton(onPressed: _finish, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDD1847), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), padding: const EdgeInsets.symmetric(vertical: 16)), child: Text(_confirmBtn, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)))),
        ]),
      ]),
    );
  }
}

class _CalendarPicker extends StatefulWidget {
  final DateTime selectedDate;
  final Set<String> availableDates;
  final Function(DateTime) onDateSelected;
  const _CalendarPicker({required this.selectedDate, required this.availableDates, required this.onDateSelected});

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
    WidgetsBinding.instance.addPostFrameCallback((_) { _scrollToSelected(); _scrollController.addListener(_onScroll); });
  }

  void _generateMonths() {
    _months.clear();
    final now = DateTime(_selected.year, _selected.month);
    for (int i = -6; i <= 6; i++) { _months.add(DateTime(now.year, now.month + i)); }
  }

  void _scrollToSelected() {
    final index = _months.indexWhere((m) => m.year == _selected.year && m.month == _selected.month);
    if (index >= 0) _scrollController.jumpTo(index * 340.0);
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    final index = (offset / 340).round();
    if (index >= 0 && index < _months.length) _updateHeader(_months[index]);
    if (offset < 400) { _months.insert(0, DateTime(_months.first.year, _months.first.month - 1)); _scrollController.jumpTo(offset + 340); }
    if (offset > (_months.length - 3) * 340) { _months.add(DateTime(_months.last.year, _months.last.month + 1)); }
  }

  void _updateHeader(DateTime month) {
    final m = ['Январь','Февраль','Март','Апрель','Май','Июнь','Июль','Август','Сентябрь','Октябрь','Ноябрь','Декабрь'];
    setState(() => _headerText = '${m[month.month - 1]} ${month.year}');
  }

  @override
  void dispose() { _scrollController.removeListener(_onScroll); _scrollController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final m = ['Январь','Февраль','Март','Апрель','Май','Июнь','Июль','Август','Сентябрь','Октябрь','Ноябрь','Декабрь'];
    final today = DateTime.now();
    return SizedBox(height: 500, child: Column(children: [
      Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 8), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
      Text(_headerText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)), const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: ['Пн','Вт','Ср','Чт','Пт','Сб','Вс'].map((d) => SizedBox(width: 36, child: Text(d, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: d == 'Сб' || d == 'Вс' ? const Color(0xFFDD1847) : Colors.grey)))).toList()),
      const SizedBox(height: 4),
      Expanded(child: ListView.builder(controller: _scrollController, itemCount: _months.length, itemExtent: 340, itemBuilder: (_, mi) {
        final mt = _months[mi];
        final dim = DateTime(mt.year, mt.month + 1, 0).day;
        final fd = DateTime(mt.year, mt.month, 1); final so = fd.weekday - 1;
        return Column(children: [
          Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('${m[mt.month - 1]} ${mt.year}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7), itemCount: so + dim, itemBuilder: (_, i) {
            if (i < so) return const SizedBox.shrink();
            final day = i - so + 1; final date = DateTime(mt.year, mt.month, day);
            final ds = DateFormat('yyyy-MM-dd').format(date);
            final sel = date.day == _selected.day && date.month == _selected.month && date.year == _selected.year;
            final it = date.day == today.day && date.month == today.month && date.year == today.year;
            final we = date.weekday == 6 || date.weekday == 7;
            final av = widget.availableDates.isEmpty || widget.availableDates.contains(ds);
            final past = date.isBefore(DateTime(today.year, today.month, today.day));
            return GestureDetector(
              onTap: (av && !past) ? () { setState(() => _selected = date); widget.onDateSelected(date); } : null,
              child: Container(margin: const EdgeInsets.all(1), decoration: BoxDecoration(color: sel ? const Color(0xFFDD1847) : (it ? const Color(0xFFFDF2F5) : Colors.transparent), shape: BoxShape.circle), alignment: Alignment.center,
                child: Text('$day', style: TextStyle(fontSize: 14, fontWeight: it || sel ? FontWeight.w600 : FontWeight.w400, color: sel ? Colors.white : (!av || past) ? Colors.grey[300] : we ? const Color(0xFFDD1847) : Colors.black))),
            );
          }),
        ]);
      })),
    ]));
  }
}