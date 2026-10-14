import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../widgets/cached_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../widgets/skeletons.dart';
import '../../../widgets/toast.dart';
import '../../../widgets/common/avatar_initials.dart';

class CreateBookingForClientSheet extends StatefulWidget {
  final int projectId;
  final int clientId;
  final String clientName;
  final VoidCallback onSaved;
  const CreateBookingForClientSheet({
    super.key,
    required this.projectId,
    required this.clientId,
    required this.clientName,
    required this.onSaved,
  });

  @override
  State<CreateBookingForClientSheet> createState() => _CreateBookingForClientSheetState();
}

class _CreateBookingForClientSheetState extends State<CreateBookingForClientSheet> {
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _employees = [];
  final Set<int> _selectedServiceIds = {};
  Map<String, dynamic>? _selectedMaster;
  final Map<int, int> _serviceMasters = {};
  Map<int, List<int>> _serviceEmployeeLinks = {};

  DateTime? _selectedDate;
  String? _selectedTime;
  final Map<String, bool> _selectedSlots = {};
  List<DateTime> _dates = [];
  final ScrollController _dateScrollController = ScrollController();
  Map<String, List<String>> _timeSlotsByMaster = {};

  String _dateTimeMode = 'single';
  final Map<int, String> _separateSelectedTimes = {};
  final Map<int, DateTime> _separateSelectedDates = {};
  Map<String, List<String>> _separateTimeSlots = {};

  String _currentStep = 'start';
  final List<String> _stepHistory = [];
  bool _loading = true;
  bool _saving = false;
  bool _loadingSlots = false;

  Map<int, Map<String, Map<String, String>>> _employeeWorkHoursAll = {};
  Map<int, Map<String, List<Map<String, int>>>> _bookedRangesAll = {};
  Map<int, Map<String, dynamic>> _fixedTimeAll = {};
  String? _maxScheduleDate;

  static const _weekdays = ['', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
  static const _months = ['', 'янв.', 'фев.', 'мар.', 'апр.', 'мая', 'июн.', 'июл.', 'авг.', 'сен.', 'окт.', 'ноя.', 'дек.'];

  @override
  void initState() {
    super.initState();
    _loadData();
    _generateDates();
  }

  @override
  void dispose() {
    _dateScrollController.dispose();
    super.dispose();
  }

  void _generateDates() {
    final today = DateTime.now();
    final clean = DateTime(today.year, today.month, today.day);
    _dates = List.generate(90, (i) => DateTime(clean.year, clean.month, clean.day + i));
  }

  void _loadData() async {
  try {
    final servicesRes = await ApiService.get('/api/service/list?project_id=${widget.projectId}');
    final employeesRes = await ApiService.get('/api/employee/list?project_id=${widget.projectId}');
    final linksRes = await ApiService.get('/api/employee-service-links?project_id=${widget.projectId}');
    
    if (mounted) {
      setState(() {
        if (servicesRes['success'] == true && servicesRes['data'] != null) {
          _services = List<Map<String, dynamic>>.from(servicesRes['data']);
        }
        
        if (employeesRes['success'] == true && employeesRes['data'] != null) {
          _employees = List<Map<String, dynamic>>.from(employeesRes['data']).map((e) {
            final firstName = (e['first_name'] ?? '').toString().trim();
            final lastName = (e['last_name'] ?? '').toString().trim();
            final name = (e['name'] ?? '').toString().trim();
            return {
              ...e,
              'name': (name.isNotEmpty && name != 'undefined' && name != 'null')
                  ? name
                  : (firstName.isNotEmpty || lastName.isNotEmpty ? '$firstName $lastName'.trim() : 'Сотрудник #${e['id']}'),
            };
          }).toList();
        }

        if (linksRes['success'] == true && linksRes['data'] != null) {
          final links = List<Map<String, dynamic>>.from(linksRes['data']);
          _serviceEmployeeLinks = {};
          for (final link in links) {
            final sid = link['service_id'] as int;
            final eid = link['employee_id'] as int;
            _serviceEmployeeLinks.putIfAbsent(sid, () => []).add(eid);
          }
        }

        _loading = false;
      });
    }
  } catch (_) {
    if (mounted) setState(() => _loading = false);
  }
}

  List<Map<String, dynamic>> _getMastersForService(int serviceId) {
    final linkedIds = _serviceEmployeeLinks[serviceId];
    if (linkedIds != null && linkedIds.isNotEmpty) {
      return _employees.where((e) => linkedIds.contains(e['id'] as int)).toList();
    }
    return _employees;
  }

  void _toggleService(int id) {
    setState(() {
      if (_selectedServiceIds.contains(id)) {
        _selectedServiceIds.remove(id);
        _serviceMasters.remove(id);
      } else {
        _selectedServiceIds.add(id);
      }
    });
  }

  void _selectMaster(Map<String, dynamic> master) {
  setState(() {
    _selectedMaster = master;
  });
  // Пользователь нажмет "Продолжить" для перехода дальше
}
  
  void _assignMasterToService(int serviceId, int masterId) {
    setState(() => _serviceMasters[serviceId] = masterId);
  }

  void _goToStep(String step) {
    setState(() {
      _stepHistory.add(_currentStep);
      _currentStep = step;
      if (step == 'datetime') _loadTimeSlotsData();
    });
  }

  void _goBack() {
    if (_stepHistory.isEmpty) {
      Navigator.pop(context);
      return;
    }
    setState(() => _currentStep = _stepHistory.removeLast());
  }

  List<int> _getMasterIds() {
    final ids = <int>{};
    
    // Приоритет: назначенные мастера из _serviceMasters
    if (_serviceMasters.isNotEmpty) {
      for (final entry in _serviceMasters.entries) {
        ids.add(entry.value);
      }
    } else if (_selectedMaster != null) {
      ids.add(_selectedMaster!['id'] as int);
    } else if (_selectedServiceIds.length == 1 && _serviceMasters.isEmpty) {
      for (final m in _getMastersForService(_selectedServiceIds.first)) {
        ids.add(m['id'] as int);
      }
    }
    
    if (ids.isEmpty) {
      for (final e in _employees) {
        ids.add(e['id'] as int);
      }
    }
    
    return ids.toList();
  }

  void _loadTimeSlotsData() async {
    setState(() => _loadingSlots = true);
    final masterIds = _getMasterIds();
    
    if (masterIds.isEmpty) {
      setState(() => _loadingSlots = false);
      return;
    }
    
    final today = DateTime.now();
    final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final endDate = DateTime(today.year, today.month, today.day + 90);
    final endDateStr = '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';

    try {
      final result = await ApiService.get(
        '/api/booking/time-slots-data?project_id=${widget.projectId}&date=$dateStr&end_date=$endDateStr&employee_ids=${masterIds.join(",")}',
      );
      
      if (result['success'] == true && mounted) {
        final data = result['data'];
        
        setState(() {
          _maxScheduleDate = data['max_schedule_date'];
          _employeeWorkHoursAll = {};
          _bookedRangesAll = {};
          _fixedTimeAll = {};
          
          final schedulesData = data['schedules'];
          
          if (schedulesData is Map<String, dynamic>) {
            for (final dateKey in schedulesData.keys) {
              final daySchedules = schedulesData[dateKey];
              if (daySchedules is Map<String, dynamic>) {
                for (final eid in daySchedules.keys) {
                  final s = daySchedules[eid];
                  if (s is Map<String, dynamic>) {
                    final empId = int.tryParse(eid) ?? 0;
                    _employeeWorkHoursAll[empId] ??= {};
                    if (s['is_working'] == true && s['start_time'] != null && s['end_time'] != null) {
                      _employeeWorkHoursAll[empId]![dateKey] = {
                        'start': s['start_time'].toString().substring(0, 5),
                        'end': s['end_time'].toString().substring(0, 5),
                      };
                    } else {
                      _employeeWorkHoursAll[empId]![dateKey] = {'start': '00:00', 'end': '00:00'};
                    }
                  }
                }
              }
            }
          }
          
          final bookings = data['bookings'] as List? ?? [];
          for (final b in bookings) {
            if (b is Map<String, dynamic>) {
              final eid = b['employee_id'] as int? ?? 0;
              final bookingDate = b['date'] as String? ?? '';
              _bookedRangesAll[eid] ??= {};
              _bookedRangesAll[eid]![bookingDate] ??= [];
              final startParts = (b['start_time'] as String?)?.split(':') ?? ['0', '0'];
              final endParts = (b['end_time'] as String?)?.split(':') ?? ['0', '0'];
              _bookedRangesAll[eid]![bookingDate]!.add({
                'start': int.parse(startParts[0]) * 60 + int.parse(startParts[1]),
                'end': int.parse(endParts[0]) * 60 + int.parse(endParts[1]) + (b['break_after'] as int? ?? 0),
              });
            }
          }
          
          final occupiedTimes = data['occupied_times'] as List? ?? [];
          for (final o in occupiedTimes) {
            if (o is Map<String, dynamic>) {
              final eid = o['employee_id'] as int? ?? 0;
              final occDate = o['date'] as String? ?? '';
              _bookedRangesAll[eid] ??= {};
              _bookedRangesAll[eid]![occDate] ??= [];
              final startParts = (o['start_time'] as String?)?.split(':') ?? ['0', '0'];
              final endParts = (o['end_time'] as String?)?.split(':') ?? ['0', '0'];
              _bookedRangesAll[eid]![occDate]!.add({
                'start': int.parse(startParts[0]) * 60 + int.parse(startParts[1]),
                'end': int.parse(endParts[0]) * 60 + int.parse(endParts[1]),
              });
            }
          }
          
          final fixedTimes = data['fixed_times'] as Map<String, dynamic>? ?? {};
          for (final eid in fixedTimes.keys) {
            _fixedTimeAll[int.tryParse(eid) ?? 0] = fixedTimes[eid] as Map<String, dynamic>;
          }
          
          _loadingSlots = false;
        });
        
        if (_dateTimeMode == 'single' || _dateTimeMode == 'sequential') {
          _findNearestAvailableDate();
        } else if (_dateTimeMode == 'separate') {
          _renderSeparateTimeSlots();
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSlots = false);
    }
  }

  void _findNearestAvailableDate() {
    // ignore: unused_local_variable
    final totalDuration = _getTotalDuration();
    final today = DateTime.now();
    final clean = DateTime(today.year, today.month, today.day);

    void tryDate(int offset) {
      if (offset > 90) {
        setState(() {
          _selectedDate = clean;
          _selectedTime = null;
          _selectedSlots.clear();
        });
        _updateTimeSlots();
        return;
      }
      final date = DateTime(clean.year, clean.month, clean.day + offset);
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      if (_maxScheduleDate != null && dateStr.compareTo(_maxScheduleDate!) > 0) {
        tryDate(offset + 1);
        return;
      }
      for (final masterId in _getMasterIds()) {
        final wh = _employeeWorkHoursAll[masterId]?[dateStr];
        if (wh == null || (wh['start'] == '00:00' && wh['end'] == '00:00')) continue;
        final slots = _generateTimeSlots(masterId, dateStr, totalDuration);
        if (slots.isNotEmpty) {
          setState(() {
            _selectedDate = date;
            _selectedTime = null;
            _selectedSlots.clear();
          });
          _updateTimeSlots();
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelectedDate());
          return;
        }
      }
      tryDate(offset + 1);
    }

    tryDate(0);
  }

  void _scrollToSelectedDate() {
    if (_selectedDate == null || !_dateScrollController.hasClients) return;
    final index = _dates.indexWhere((d) => d.year == _selectedDate!.year && d.month == _selectedDate!.month && d.day == _selectedDate!.day);
    if (index >= 0) {
      final viewportWidth = _dateScrollController.position.viewportDimension;
      final targetOffset = (index * 64.0) - (viewportWidth / 2) + 32;
      _dateScrollController.animateTo(
        targetOffset.clamp(0.0, _dateScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  int _getTotalDuration() {
    return _selectedServiceIds.fold(0, (sum, id) {
      final service = _services.firstWhere((s) => s['id'] == id, orElse: () => {});
      return sum + (int.tryParse(service['duration']?.toString() ?? '0') ?? 0);
    });
  }

  List<String> _generateTimeSlots(int employeeId, String dateStr, int serviceDuration) {
    final wh = _employeeWorkHoursAll[employeeId]?[dateStr];
    if (wh == null) return [];
    final start = wh['start'] ?? '00:00';
    final end = wh['end'] ?? '00:00';
    if (start == '00:00' && end == '00:00') return [];
    final startMin = int.parse(start.split(':')[0]) * 60 + int.parse(start.split(':')[1]);
    final endMin = int.parse(end.split(':')[0]) * 60 + int.parse(end.split(':')[1]);
    final bookedRanges = _bookedRangesAll[employeeId]?[dateStr] ?? [];
    final fixedTime = _fixedTimeAll[employeeId];
    final allSlots = <String>[];

    if (fixedTime != null && fixedTime['enabled'] == true) {
      final times = (fixedTime['time_data']?['times'] as List?)?.cast<String>() ?? [];
      for (final t in times) {
        final parts = t.split(':');
        final m = int.parse(parts[0]) * 60 + int.parse(parts[1]);
        if (m >= startMin && (serviceDuration == 0 || m + serviceDuration <= endMin)) {
          allSlots.add(t);
        }
      }
    } else {
      for (int m = startMin; m < endMin; m += 30) {
        if (serviceDuration > 0 && m + serviceDuration > endMin) continue;
        final h = m ~/ 60;
        final min = m % 60;
        allSlots.add('${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}');
      }
    }

    final availableSlots = allSlots.where((slot) {
      final parts = slot.split(':');
      final slotMin = int.parse(parts[0]) * 60 + int.parse(parts[1]);
      final slotEnd = slotMin + serviceDuration;
      return !bookedRanges.any((range) => slotMin < range['end']! && slotEnd > range['start']!);
    }).toList();

    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (dateStr == todayStr) {
      final currentMin = now.hour * 60 + now.minute;
      return availableSlots.where((slot) {
        final parts = slot.split(':');
        final slotMin = int.parse(parts[0]) * 60 + int.parse(parts[1]);
        return slotMin > currentMin;
      }).toList();
    }
    return availableSlots;
  }

  void _updateTimeSlots() {
    if (_selectedDate == null) return;
    final dateStr = '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';
    // ignore: unused_local_variable
    final totalDuration = _getTotalDuration();

    final mastersToShow = <Map<String, dynamic>>[];
    final shownIds = <int>{};

    if (_selectedMaster != null) {
      final mid = _selectedMaster!['id'] as int;
      final wh = _employeeWorkHoursAll[mid]?[dateStr];
      if (wh != null && !(wh['start'] == '00:00' && wh['end'] == '00:00')) {
        mastersToShow.add(_selectedMaster!);
        shownIds.add(mid);
      }
    } else if (_selectedServiceIds.length == 1 && _serviceMasters.isEmpty) {
      for (final m in _getMastersForService(_selectedServiceIds.first)) {
        final mid = m['id'] as int;
        if (shownIds.contains(mid)) continue;
        final wh = _employeeWorkHoursAll[mid]?[dateStr];
        if (wh != null && !(wh['start'] == '00:00' && wh['end'] == '00:00')) {
          shownIds.add(mid);
          mastersToShow.add(m);
        }
      }
    } else if (_serviceMasters.isNotEmpty) {
      final addedMasterIds = <int>{};
      for (final entry in _serviceMasters.entries) {
        final mid = entry.value;
        if (addedMasterIds.contains(mid)) continue;
        addedMasterIds.add(mid);
        final m = _employees.firstWhere(
          (e) => e['id'] == mid,
          orElse: () => {},
        );
        if (m.isNotEmpty) {
          final wh = _employeeWorkHoursAll[mid]?[dateStr];
          if (wh != null && !(wh['start'] == '00:00' && wh['end'] == '00:00')) {
            if (!shownIds.contains(mid)) {
              shownIds.add(mid);
              mastersToShow.add(m);
            }
          }
        }
      }
    }

    if (mastersToShow.isEmpty) {
      for (final m in _employees) {
        final mid = m['id'] as int;
        if (shownIds.contains(mid)) continue;
        final wh = _employeeWorkHoursAll[mid]?[dateStr];
        if (wh != null && !(wh['start'] == '00:00' && wh['end'] == '00:00')) {
          mastersToShow.add(m);
          shownIds.add(mid);
        }
      }
    }

    setState(() {
      _timeSlotsByMaster = {};
      for (final m in mastersToShow) {
        final mid = m['id'] as int;
        final slots = _generateTimeSlots(mid, dateStr, totalDuration);
        if (slots.isNotEmpty) {
          _timeSlotsByMaster['${mid}_$dateStr'] = slots;
        }
      }
    });
  }

  void _switchDateTimeMode(String mode) {
    setState(() {
      _dateTimeMode = mode;
      _selectedDate = null;
      _selectedTime = null;
      _selectedSlots.clear();
      _separateSelectedTimes.clear();
      _separateSelectedDates.clear();
      _separateTimeSlots = {};
      _timeSlotsByMaster = {};
    });
    _loadTimeSlotsData();
  }

  void _selectDate(DateTime date) {
    if (_dateTimeMode == 'single' || _dateTimeMode == 'sequential') {
      setState(() {
        _selectedDate = date;
        _selectedTime = null;
        _selectedSlots.clear();
      });
      _updateTimeSlots();
    }
  }

  void _selectSlot(int masterId, String time) {
    if (_dateTimeMode == 'single' || _dateTimeMode == 'sequential') {
      setState(() {
        _selectedSlots.clear();
        _selectedSlots['${masterId}_$time'] = true;
        _selectedTime = time;
        for (final sid in _selectedServiceIds) {
          _serviceMasters[sid] = masterId;
        }
      });
    }
  }

  void _renderSeparateTimeSlots() {
    final selectedServices = _services.where((s) => _selectedServiceIds.contains(s['id'])).toList();
    final today = DateTime.now();
    final clean = DateTime(today.year, today.month, today.day);
    final dateStr = '${clean.year}-${clean.month.toString().padLeft(2, '0')}-${clean.day.toString().padLeft(2, '0')}';

    setState(() {
      _separateTimeSlots = {};
      _separateSelectedDates.clear();
      _separateSelectedTimes.clear();
      
      for (int idx = 0; idx < selectedServices.length; idx++) {
        final s = selectedServices[idx];
        final mid = _serviceMasters[s['id']];
        if (mid == null) continue;
        
        final sDuration = int.tryParse(s['duration']?.toString() ?? '0') ?? 0;
        final wh = _employeeWorkHoursAll[mid]?[dateStr];
        
        if (wh != null && !(wh['start'] == '00:00' && wh['end'] == '00:00')) {
          final slots = _generateTimeSlots(mid, dateStr, sDuration);
          _separateTimeSlots['${idx}_$dateStr'] = slots;
        }
        _separateSelectedDates[idx] = clean;
      }
    });
  }

  void _selectSeparateSlot(int idx, int masterId, String time) {
    setState(() {
      _separateSelectedTimes[idx] = time;
      final servicesList = _services.where((s) => _selectedServiceIds.contains(s['id'])).toList();
      if (idx < servicesList.length) {
        _serviceMasters[servicesList[idx]['id']] = masterId;
      }
    });
  }

  void _loadSlotsForSeparateService(int idx, int serviceId, int masterId, DateTime date) {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final service = _services.firstWhere((s) => s['id'] == serviceId, orElse: () => {});
    if (service.isEmpty) return;
    final sDuration = int.tryParse(service['duration']?.toString() ?? '0') ?? 0;
    final slots = _generateTimeSlots(masterId, dateStr, sDuration);
    setState(() {
      _separateTimeSlots['${idx}_$dateStr'] = slots;
      _separateSelectedDates[idx] = date;
      _separateSelectedTimes.remove(idx);
    });
  }

  void _createBooking() async {
    if (_dateTimeMode == 'separate') {
      final selectedServices = _services.where((s) => _selectedServiceIds.contains(s['id'])).toList();
      final allSelected = selectedServices.asMap().entries.every((e) => _separateSelectedTimes.containsKey(e.key));
      if (!allSelected) return;
    } else {
      if (_selectedDate == null || _selectedTime == null) return;
    }

    setState(() => _saving = true);
    final dateStr = _selectedDate != null
        ? '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}'
        : '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';

    final serviceMastersMap = <int, int>{};
    
    if (_selectedMaster != null) {
      for (final sid in _selectedServiceIds) {
        serviceMastersMap[sid] = _selectedMaster!['id'] as int;
      }
    } else {
      serviceMastersMap.addAll(_serviceMasters);
    }

    int? masterId;
    if (_selectedMaster != null) {
      masterId = _selectedMaster!['id'] as int;
    } else if (_serviceMasters.isNotEmpty) {
      masterId = _serviceMasters.values.first;
    }

    try {
      final result = await ApiService.createBooking(
        projectId: widget.projectId,
        date: dateStr,
        startTime: _selectedTime != null ? '$_selectedTime:00' : '09:00:00',
        serviceIds: _selectedServiceIds.toList(),
        employeeId: masterId ?? 0,
        clientName: widget.clientName,
        clientPhone: '',
        clientId: widget.clientId,
        serviceMasters: serviceMastersMap,
      );
      if (result['success'] == true && mounted) {
        Navigator.pop(context);
        widget.onSaved();
        showToast(context, 'Запись создана!');
      } else if (mounted) {
        showToast(context, result['error'] ?? 'Ошибка создания', isError: true);
      }
    } catch (_) {
      if (mounted) {
        showToast(context, 'Ошибка соединения', isError: true);
      }
    }
    if (mounted) setState(() => _saving = false);
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        _buildHeader(),
        Expanded(child: _buildBody()),
        if (_currentStep != 'start') _buildFooter(bottomInset),
      ]),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: _goBack,
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
            child: const Center(child: Icon(Icons.arrow_back, color: Color(0xFF666666), size: 20)),
          ),
        ),
        const Spacer(),
        const Text('Создать запись', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
        const Spacer(),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
            child: const Center(child: Icon(Icons.close, color: Color(0xFF666666), size: 20)),
          ),
        ),
      ]),
    );
  }

  Widget _buildBody() {
    switch (_currentStep) {
      case 'start': return _buildStartScreen();
      case 'services': return _buildServicesScreen();
      case 'masters': return _buildMastersScreen();
      case 'master-services': return _buildMasterServicesScreen();
      case 'master-assignment': return _buildMasterAssignmentScreen();
      case 'datetime': return _buildDateTimeScreen();
      case 'confirm': return _buildConfirmScreen();
      default: return _buildStartScreen();
    }
  }

  Widget _buildStartScreen() {
  return Padding(
    padding: const EdgeInsets.all(20),
    child: Column(children: [
      const SizedBox(height: 40),
      const Text('Выберите услугу или специалиста', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)), textAlign: TextAlign.center),
      const SizedBox(height: 24),
      _buildStartOption(iconPath: 'assets/services.svg', title: 'Выбрать услугу', subtitle: 'Выбор из списка услуг', onTap: () => _goToStep('services')),
      const SizedBox(height: 12),
      _buildStartOption(iconPath: 'assets/clients.svg', title: 'Выбрать специалиста', subtitle: 'Подбор по специалисту', onTap: () => _goToStep('masters')),
    ]),
  );
}

Widget _buildStartOption({required String iconPath, required String title, required String subtitle, required VoidCallback onTap}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE0E0E0), width: 2)),
      child: Row(children: [
        SvgPicture.asset(iconPath, width: 24, height: 24),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 13, color: Color(0xFF888888))),
        ])),
        const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC)),
      ]),
    ),
  );
}

  Widget _buildServicesScreen() {
    return Column(children: [
      const Padding(padding: EdgeInsets.all(16), child: Text('Выберите услуги', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)))),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _services.length,
          itemBuilder: (_, i) {
            final s = _services[i];
            final sel = _selectedServiceIds.contains(s['id']);
            final duration = int.tryParse(s['duration']?.toString() ?? '0') ?? 0;
            final price = double.tryParse(s['price']?.toString() ?? '0') ?? 0;
            return GestureDetector(
              onTap: () => _toggleService(s['id']),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: sel ? const Color(0xFFFDF2F5) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: sel ? const Color(0xFFDD1847) : const Color(0xFFE8E8E8), width: 2),
                ),
                child: Row(children: [
                  Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      color: sel ? const Color(0xFFDD1847) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: sel ? const Color(0xFFDD1847) : const Color(0xFFDDDDDD), width: 2),
                    ),
                    child: sel ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s['name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
                    const SizedBox(height: 2),
                    Text('${price == 0 ? 'Бесплатно' : 'от $price ₽'} · ${_formatDuration(duration)}', style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
                  ])),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }

  Widget _buildMastersScreen() {
    return Column(children: [
      const Padding(padding: EdgeInsets.all(16), child: Text('Выберите специалиста', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)))),
      Expanded(
        child: _employees.isEmpty 
          ? const Center(child: Text('Нет доступных специалистов', style: TextStyle(color: Color(0xFF888888))))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _employees.length,
              itemBuilder: (_, i) {
                final m = _employees[i];
                final sel = _selectedMaster != null && _selectedMaster!['id'] == m['id'];
                return GestureDetector(
                  onTap: () => _selectMaster(m),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: sel ? const Color(0xFFFDF2F5) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: sel ? const Color(0xFFDD1847) : const Color(0xFFE8E8E8), width: 2),
                    ),
                    child: Row(children: [
                      _buildAvatar(m, 48),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text((m['name'] ?? '').toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
                        if ((m['position'] ?? '').toString().isNotEmpty) Text(m['position'].toString(), style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
                      ])),
                      Container(
                        width: 20, height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: sel ? const Color(0xFFDD1847) : const Color(0xFFDDDDDD), width: 2),
                          color: sel ? const Color(0xFFDD1847) : null,
                        ),
                        child: sel ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
                      ),
                    ]),
                  ),
                );
              },
            ),
      ),
    ]);
  }

  Widget _buildMasterServicesScreen() {
    if (_selectedMaster == null) return const SizedBox();
    
    final masterServices = _services.where((s) {
      final links = _serviceEmployeeLinks[s['id']];
      return links == null || links.isEmpty || links.contains(_selectedMaster!['id']);
    }).toList();
    
    return Column(children: [
      Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          _buildAvatar(_selectedMaster!, 56),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((_selectedMaster!['name'] ?? '').toString(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            if ((_selectedMaster!['position'] ?? '').toString().isNotEmpty) Text(_selectedMaster!['position'].toString(), style: const TextStyle(fontSize: 13, color: Color(0xFF888888))),
          ])),
        ]),
      ),
      const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Выберите услуги', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)))),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: masterServices.length,
          itemBuilder: (_, i) {
            final s = masterServices[i];
            final sel = _selectedServiceIds.contains(s['id']);
            final duration = int.tryParse(s['duration']?.toString() ?? '0') ?? 0;
            final price = double.tryParse(s['price']?.toString() ?? '0') ?? 0;
            return GestureDetector(
              onTap: () => _toggleService(s['id']),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: sel ? const Color(0xFFFDF2F5) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: sel ? const Color(0xFFDD1847) : const Color(0xFFE8E8E8), width: 2),
                ),
                child: Row(children: [
                  Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      color: sel ? const Color(0xFFDD1847) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: sel ? const Color(0xFFDD1847) : const Color(0xFFDDDDDD), width: 2),
                    ),
                    child: sel ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s['name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
                    const SizedBox(height: 2),
                    Text('${price == 0 ? 'Бесплатно' : 'от $price ₽'} · ${_formatDuration(duration)}', style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
                  ])),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }

  Widget _buildMasterAssignmentScreen() {
    final selectedServices = _services.where((s) => _selectedServiceIds.contains(s['id'])).toList();
    return Column(children: [
      const Padding(padding: EdgeInsets.all(16), child: Column(children: [
        Text('Назначение специалистов', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)), textAlign: TextAlign.center),
        SizedBox(height: 4),
        Text('Выберите специалиста для каждой услуги', style: TextStyle(fontSize: 13, color: Color(0xFF888888)), textAlign: TextAlign.center),
      ])),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: selectedServices.map((s) {
            final masterId = _serviceMasters[s['id']];
            final master = masterId != null ? _employees.firstWhere((e) => e['id'] == masterId, orElse: () => {}) : null;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text((s['name'] ?? '').toString(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('${s['price'] ?? 0} ₽ · ${_formatDuration(int.tryParse(s['duration']?.toString() ?? '0') ?? 0)}', style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _showMasterPickerForService(s['id']),
                  child: master != null && master.isNotEmpty
                      ? Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE8E8E8)), color: const Color(0xFFFAFAFA)),
                          child: Row(children: [
                            _buildAvatar(master, 40),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(master['name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              if (master['position'] != null) Text(master['position'].toString(), style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
                            ])),
                            const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC), size: 16),
                          ]),
                        )
                      : Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE0E0E0))),
                          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.person_add, size: 16, color: Color(0xFF888888)),
                            SizedBox(width: 8),
                            Text('Назначить специалиста', style: TextStyle(fontSize: 13, color: Color(0xFF888888))),
                          ]),
                        ),
                ),
              ]),
            );
          }).toList(),
        ),
      ),
    ]);
  }

  void _showMasterPickerForService(int serviceId) {
    final currentMasterId = _serviceMasters[serviceId];
    final masters = _getMastersForService(serviceId);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFF5F5F5),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('Выберите специалиста', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(_services.firstWhere((s) => s['id'] == serviceId, orElse: () => {})['name'] ?? '', style: const TextStyle(fontSize: 13, color: Color(0xFF888888))),
            ]),
          ),
          Flexible(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shrinkWrap: true,
              itemCount: masters.length,
              itemBuilder: (_, i) {
                final m = masters[i];
                final isSelected = currentMasterId == m['id'];
                return GestureDetector(
                  onTap: () {
                    _assignMasterToService(serviceId, m['id']);
                    Navigator.pop(context);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFFDF2F5) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isSelected ? const Color(0xFFDD1847) : const Color(0xFFE8E8E8), width: 2),
                    ),
                    child: Row(children: [
                      _buildAvatar(m, 44),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text((m['name'] ?? '').toString(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        if ((m['position'] ?? '').toString().isNotEmpty) Text(m['position'].toString(), style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
                      ])),
                      if (isSelected) const Icon(Icons.check, color: Color(0xFFDD1847), size: 20),
                    ]),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(backgroundColor: const Color(0xFFF0F0F0), foregroundColor: const Color(0xFF666666), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: const Text('Отмена', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildDateTimeScreen() {
    final selectedServices = _services.where((s) => _selectedServiceIds.contains(s['id'])).toList();
    return Column(children: [
      const Padding(padding: EdgeInsets.all(16), child: Text('Выберите дату и время', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)))),
      if (selectedServices.length >= 2) ...[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _switchDateTimeMode('sequential'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _dateTimeMode == 'sequential' ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: _dateTimeMode == 'sequential' ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))] : null,
                    ),
                    child: Text('Последовательно', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _dateTimeMode == 'sequential' ? const Color(0xFF1A1A1A) : const Color(0xFF888888))),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => _switchDateTimeMode('separate'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _dateTimeMode == 'separate' ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: _dateTimeMode == 'separate' ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))] : null,
                    ),
                    child: Text('Разное время', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _dateTimeMode == 'separate' ? const Color(0xFF1A1A1A) : const Color(0xFF888888))),
                  ),
                ),
              ),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Text(
            _dateTimeMode == 'sequential' ? 'Последовательно — выберите время начала первой услуги.' : 'Разное время — выберите время для каждой услуги отдельно.',
            style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
          ),
        ),
      ],
      if (_dateTimeMode == 'single' || _dateTimeMode == 'sequential')
        Expanded(child: _buildSingleDateTimeContent(selectedServices))
      else if (_dateTimeMode == 'separate')
        Expanded(child: _buildSeparateDateTimeContent(selectedServices)),
    ]);
  }

  Widget _buildSingleDateTimeContent(List<Map<String, dynamic>> selectedServices) {
    // ignore: unused_local_variable
    final totalDuration = _getTotalDuration();
    return Column(children: [
      SizedBox(
        height: 80,
        child: Row(children: [
          GestureDetector(
            onTap: () => _showCalendarPicker(),
            child: Container(
              width: 44, height: 44,
              margin: const EdgeInsets.only(left: 16, right: 8),
              decoration: BoxDecoration(color: const Color(0xFFFDF2F5), borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.calendar_today, color: Color(0xFFDD1847), size: 22),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _dateScrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 16),
              itemCount: _dates.length,
              itemBuilder: (_, i) {
                final d = _dates[i];
                final sel = _selectedDate != null && d.year == _selectedDate!.year && d.month == _selectedDate!.month && d.day == _selectedDate!.day;
                final today = DateTime.now();
                final isToday = d.year == today.year && d.month == today.month && d.day == today.day;
                final isPast = d.isBefore(DateTime(today.year, today.month, today.day));
                return GestureDetector(
                  onTap: isPast ? null : () => _selectDate(d),
                  child: Container(
                    width: 62, margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: sel ? const Color(0xFFDD1847) : isToday ? const Color(0xFFFDF2F5) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: sel ? const Color(0xFFDD1847) : isToday ? const Color(0xFFDD1847).withValues(alpha: 0.5) : const Color(0xFFE8E8E8), width: 2),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text('${d.day}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: sel ? Colors.white : (isPast ? const Color(0xFFCCCCCC) : const Color(0xFF1A1A1A)))),
                      Text('${_weekdays[d.weekday]} ${_months[d.month]}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sel ? Colors.white.withValues(alpha: 0.8) : (isPast ? const Color(0xFFCCCCCC) : const Color(0xFF888888)))),
                    ]),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
      if (_dateTimeMode == 'sequential' && selectedServices.length >= 2)
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ПОСЛЕДОВАТЕЛЬНОСТЬ УСЛУГ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF888888))),
            const SizedBox(height: 8),
            ...selectedServices.asMap().entries.map((entry) {
              final s = entry.value;
              final mid = _serviceMasters[s['id']];
              final m = mid != null ? _employees.firstWhere((e) => e['id'] == mid, orElse: () => {}) : null;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  Text('${entry.key + 1}. ', style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
                  Text((s['name'] ?? '').toString(), style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A1A))),
                  if (m != null && m.isNotEmpty) Text(' (${(m['name'] ?? '').toString()})', style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
                ]),
              );
            }),
          ]),
        ),
      Expanded(
        child: _loadingSlots
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
            : _timeSlotsByMaster.isEmpty
                ? const Center(child: Text('Нет доступного времени', style: TextStyle(color: Color(0xFF888888))))
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: _timeSlotsByMaster.entries.map((entry) {
                      final keyParts = entry.key.split('_');
                      final masterId = int.parse(keyParts[0]);
                      final master = _employees.firstWhere((e) => e['id'] == masterId, orElse: () => {});
                      if (master.isEmpty || entry.value.isEmpty) return const SizedBox.shrink();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            _buildAvatar(master, 40),
                            const SizedBox(width: 12),
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text((master['name'] ?? '').toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              Text('${selectedServices.length} услуг', style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
                            ]),
                          ]),
                          const SizedBox(height: 12),
                          Wrap(spacing: 8, runSpacing: 8, children: entry.value.map((time) {
                            final slotKey = '${masterId}_$time';
                            final isSelected = _selectedSlots[slotKey] == true;
                            return GestureDetector(
                              onTap: () => _selectSlot(masterId, time),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFFFDF2F5) : const Color(0xFFF8F8F8),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: isSelected ? const Color(0xFFDD1847) : const Color(0xFFE0E0E0)),
                                ),
                                child: Text(time, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isSelected ? const Color(0xFFDD1847) : const Color(0xFF1A1A1A))),
                              ),
                            );
                          }).toList()),
                        ]),
                      );
                    }).toList(),
                  ),
      ),
    ]);
  }

  Widget _buildSeparateDateTimeContent(List<Map<String, dynamic>> selectedServices) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: selectedServices.asMap().entries.map((entry) {
        final idx = entry.key;
        final s = entry.value;
        final mid = _serviceMasters[s['id']];
        final m = mid != null ? _employees.firstWhere((e) => e['id'] == mid, orElse: () => {}) : null;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('УСЛУГА ${idx + 1}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF888888))),
            const SizedBox(height: 4),
            Text((s['name'] ?? '').toString(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
            if (m != null && m.isNotEmpty) Text((m['name'] ?? '').toString(), style: const TextStyle(fontSize: 13, color: Color(0xFF888888))),
            const SizedBox(height: 2),
            Text('${s['price'] ?? 0} ₽ · ${_formatDuration(int.tryParse(s['duration']?.toString() ?? '0') ?? 0)}', style: const TextStyle(fontSize: 13, color: Color(0xFF888888))),
            const SizedBox(height: 12),
            SizedBox(
              height: 76,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _dates.length,
                itemBuilder: (_, di) {
                  final d = _dates[di];
                  final selDate = _separateSelectedDates[idx];
                  final sel = selDate != null && d.year == selDate.year && d.month == selDate.month && d.day == selDate.day;
                  final today = DateTime.now();
                  final isToday = d.year == today.year && d.month == today.month && d.day == today.day;
                  final isPast = d.isBefore(DateTime(today.year, today.month, today.day));
                  return GestureDetector(
                    onTap: isPast ? null : () => _loadSlotsForSeparateService(idx, s['id'], mid ?? 0, d),
                    child: Container(
                      width: 62, margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: sel ? const Color(0xFFDD1847) : isToday ? const Color(0xFFFDF2F5) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: sel ? const Color(0xFFDD1847) : isToday ? const Color(0xFFDD1847).withValues(alpha: 0.5) : const Color(0xFFE8E8E8), width: 2),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('${d.day}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: sel ? Colors.white : (isPast ? const Color(0xFFCCCCCC) : const Color(0xFF1A1A1A)))),
                        Text('${_weekdays[d.weekday]} ${_months[d.month]}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sel ? Colors.white.withValues(alpha: 0.8) : (isPast ? const Color(0xFFCCCCCC) : const Color(0xFF888888)))),
                      ]),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Builder(builder: (context) {
              final dateKey = _separateSelectedDates[idx];
              final dateStr = dateKey != null ? '${dateKey.year}-${dateKey.month.toString().padLeft(2, '0')}-${dateKey.day.toString().padLeft(2, '0')}' : '';
              final slots = _separateTimeSlots['${idx}_$dateStr'] ?? [];
              final selectedTime = _separateSelectedTimes[idx];
              if (slots.isEmpty) {
                return const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Нет доступного времени', style: TextStyle(fontSize: 12, color: Color(0xFFAAAAAA))));
              }
              return Wrap(spacing: 8, runSpacing: 8, children: slots.map((time) {
                final isSelected = selectedTime == time;
                return GestureDetector(
                  onTap: () => _selectSeparateSlot(idx, mid ?? 0, time),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFFDF2F5) : const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? const Color(0xFFDD1847) : const Color(0xFFE0E0E0)),
                    ),
                    child: Text(time, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isSelected ? const Color(0xFFDD1847) : const Color(0xFF1A1A1A))),
                  ),
                );
              }).toList());
            }),
          ]),
        );
      }).toList(),
    );
  }

  void _showCalendarPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CalendarPicker(
        selectedDate: _selectedDate ?? DateTime.now(),
        onDateSelected: (date) {
          Navigator.pop(context);
          _selectDate(date);
        },
      ),
    );
  }

  Widget _buildConfirmScreen() {
    final selectedServices = _services.where((s) => _selectedServiceIds.contains(s['id'])).toList();
    final totalPrice = selectedServices.fold<double>(0, (sum, s) => sum + (double.tryParse(s['price']?.toString() ?? '0') ?? 0));
    final totalDuration = selectedServices.fold<int>(0, (sum, s) => sum + (int.tryParse(s['duration']?.toString() ?? '0') ?? 0));
    final shownMasters = <int>{};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Подтверждение записи', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('УСЛУГИ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF888888))),
            const SizedBox(height: 12),
            ...selectedServices.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text((s['name'] ?? '').toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
                  Text(_formatDuration(int.tryParse(s['duration']?.toString() ?? '0') ?? 0), style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
                ])),
                Text('${s['price'] ?? 0} ₽', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
              ]),
            )),
            const SizedBox(height: 16),
            const Text('ДАТА И ВРЕМЯ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF888888))),
            const SizedBox(height: 8),
            Text('${_selectedDate != null ? "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}" : ""} в ${_selectedTime ?? ""}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
            const SizedBox(height: 16),
            const Text('СПЕЦИАЛИСТЫ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF888888))),
            const SizedBox(height: 8),
            ...selectedServices.map((s) {
              final mid = _serviceMasters[s['id']];
              if (mid == null || shownMasters.contains(mid)) return const SizedBox.shrink();
              shownMasters.add(mid);
              final m = _employees.firstWhere((e) => e['id'] == mid, orElse: () => {});
              if (m.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  _buildAvatar(m, 32),
                  const SizedBox(width: 8),
                  Text((m['name'] ?? '').toString(), style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A1A))),
                ]),
              );
            }),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFF0F0F0)),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Итого', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              Text('$totalPrice ₽', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFFDD1847))),
            ]),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Длительность', style: TextStyle(fontSize: 14, color: Color(0xFF888888))),
              Text(_formatDuration(totalDuration), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ]),
          ]),
        ),
      ],
    );
  }

  Widget _buildFooter(double bottomInset) {
    final selectedServices = _services.where((s) => _selectedServiceIds.contains(s['id'])).toList();
    final totalPrice = selectedServices.fold<double>(0, (sum, s) => sum + (double.tryParse(s['price']?.toString() ?? '0') ?? 0));
    final totalDuration = selectedServices.fold<int>(0, (sum, s) => sum + (int.tryParse(s['duration']?.toString() ?? '0') ?? 0));

    bool hasSelection;
    if (_currentStep == 'services' || _currentStep == 'master-services') {
      hasSelection = _selectedServiceIds.isNotEmpty;
    } else if (_currentStep == 'masters') {
      hasSelection = _selectedMaster != null;
    } else if (_currentStep == 'master-assignment') {
      hasSelection = selectedServices.every((s) => _serviceMasters.containsKey(s['id']));
    } else if (_currentStep == 'datetime') {
      hasSelection = _dateTimeMode == 'separate'
          ? selectedServices.asMap().entries.every((e) => _separateSelectedTimes.containsKey(e.key))
          : _selectedDate != null && _selectedTime != null;
    } else if (_currentStep == 'confirm') {
      hasSelection = true;
    } else {
      hasSelection = true;
    }

    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFF0F0F0)))),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('$totalPrice ₽', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
          Text('${selectedServices.length} услуг · ${_formatDuration(totalDuration)}', style: const TextStyle(fontSize: 13, color: Color(0xFF888888))),
        ])),
        const SizedBox(width: 16),
        ElevatedButton(
          onPressed: (!hasSelection || _saving) ? null : () {
            if (_currentStep == 'confirm') {
              _createBooking();
            } else if (_currentStep == 'services') {
              _selectedServiceIds.length >= 2 ? _goToStep('master-assignment') : _goToStep('datetime');
            } else if (_currentStep == 'masters') {
              if (_selectedMaster != null) {
                _goToStep('master-services');
              }
            } else if (_currentStep == 'master-services') {
              _selectedServiceIds.length >= 2 ? _goToStep('master-assignment') : _goToStep('datetime');
            } else if (_currentStep == 'master-assignment') {
              _goToStep('datetime');
            } else if (_currentStep == 'datetime') {
              _goToStep('confirm');
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDD1847),
            disabledBackgroundColor: const Color(0xFFCCCCCC),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: _saving
    ? const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
          SizedBox(width: 8),
          Text('Создание...', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
        ],
      )
    : Text(_currentStep == 'confirm' ? 'Создать запись' : 'Продолжить', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
        ),
      ]),
    );
  }

  Widget _buildAvatar(Map<String, dynamic> master, double size) {
    final name = (master['name'] ?? '').toString();
    final avatarUrl = master['avatar']?.toString();
    return Container(
      width: size, height: size,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF0F0F0)),
      clipBehavior: Clip.antiAlias,
      child: avatarUrl != null && avatarUrl.isNotEmpty
          ? CachedAvatar(url: avatarUrl, size: size, radius: size / 2)
          : AvatarInitials(name: name, size: size, bgColor: const Color(0xFFF0F0F0), textColor: const Color(0xFF999999)),
    );
  }

  String _formatDuration(int duration) {
    final h = duration ~/ 60;
    final m = duration % 60;
    if (h > 0 && m > 0) return '$h ч $m мин';
    if (h > 0) return '$h ч';
    if (m > 0) return '$m мин';
    return '0 мин';
  }
}

class _CalendarPicker extends StatefulWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;
  const _CalendarPicker({required this.selectedDate, required this.onDateSelected});

  @override
  State<_CalendarPicker> createState() => _CalendarPickerState();
}

class _CalendarPickerState extends State<_CalendarPicker> {
  late DateTime _selected;
  final ScrollController _scrollController = ScrollController();
  final List<DateTime> _months = [];
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
      setState(() => _months.insert(0, DateTime(_months.first.year, _months.first.month - 1)));
      _scrollController.jumpTo(offset + 340);
    }
    if (offset > (_months.length - 3) * 340) {
      setState(() => _months.add(DateTime(_months.last.year, _months.last.month + 1)));
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
    final today = DateTime.now();
    return SizedBox(
      height: 500,
      child: Column(children: [
        Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 8), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
        Text(_headerText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'].map((d) => SizedBox(width: 36, child: Text(d, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: d == 'Сб' || d == 'Вс' ? const Color(0xFFDD1847) : Colors.grey)))).toList(),
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
              final m = ['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'];
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