// lib/screens/client/booking/datetime/datetime_controller.dart
//
// ChangeNotifier-контроллер для шага выбора даты/времени.
//
// Отвечает за:
//   - Загрузку доступных дат (с пагинацией).
//   - Загрузку слотов по мастерам для конкретной даты.
//   - Хранение выбранных date/time/masterId.
//
// Не знает о UI. Тестируется в unit-тестах без Flutter.

import 'package:flutter/foundation.dart';

import '../../../../services/api_service.dart';
import '../../../../core/app_logger.dart';

class DateTimeController extends ChangeNotifier {
  // ========== ВХОДНЫЕ ДАННЫЕ ==========
  final int projectId;
  final List<Map<String, dynamic>> selectedServices;
  final Map<String, dynamic>? selectedMaster;
  final Map<int, int> serviceMasters;
  final List<Map<String, dynamic>> employees;

  // ========== СОСТОЯНИЕ ==========
  List<DateTime> _availableDates = [];
  Map<int, List<String>> _timeSlotsByMaster = {};
  Map<int, Map<String, String>> _workHoursByMaster = {};

  DateTime? _selectedDate;
  String? _selectedTime;
  int? _selectedMasterId;

  bool _loadingDates = false;
  bool _loadingSlots = false;
  bool _loadingMoreDates = false;
  bool _hasMoreDates = true;
  int _dateOffset = 0;

  static const int _dateLimit = 14;

  DateTimeController({
    required this.projectId,
    required this.selectedServices,
    this.selectedMaster,
    required this.serviceMasters,
    required this.employees,
  });

  // ========== ГЕТТЕРЫ ==========
  List<DateTime> get availableDates => _availableDates;
  Map<int, List<String>> get timeSlotsByMaster => _timeSlotsByMaster;
  Map<int, Map<String, String>> get workHoursByMaster => _workHoursByMaster;
  DateTime? get selectedDate => _selectedDate;
  String? get selectedTime => _selectedTime;
  int? get selectedMasterId => _selectedMasterId;
  bool get loadingDates => _loadingDates;
  bool get loadingSlots => _loadingSlots;
  bool get loadingMoreDates => _loadingMoreDates;
  bool get hasMoreDates => _hasMoreDates;

  bool get canContinue => _selectedDate != null && _selectedTime != null;

  // ========== ИНИЦИАЛИЗАЦИЯ ==========
  Future<void> initialize() async {
    await loadAvailableDates();
  }

  // ========== МАСТЕРА ==========
  /// Собрать id мастеров, участвующих в услугах:
  /// 1. Если мастер явно назначен в serviceMasters — берём его.
  /// 2. Иначе — все мастера, оказывающие услугу (из employee['service_ids']).
  /// 3. Если пусто — все мастера.
  List<int> getMasterIds() {
    final ids = <int>{};

    for (final service in selectedServices) {
      final sid = (service['id'] as num).toInt();
      final masterId = serviceMasters[sid];

      if (masterId != null) {
        ids.add(masterId);
      } else {
        for (final emp in employees) {
          final serviceIds = emp['service_ids'];
          if (serviceIds is List && serviceIds.contains(sid)) {
            ids.add((emp['id'] as num).toInt());
          }
        }
      }
    }

    if (ids.isEmpty) {
      ids.addAll(employees.map((m) => (m['id'] as num).toInt()));
    }

    return ids.toList();
  }

  // ========== ЗАГРУЗКА ДАТ ==========
  Future<void> loadAvailableDates({bool loadMore = false}) async {
    if (loadMore) {
      if (_loadingMoreDates || !_hasMoreDates) return;
      _loadingMoreDates = true;
      _dateOffset += _dateLimit;
    } else {
      _loadingDates = true;
      _dateOffset = 0;
      _availableDates = [];
      _hasMoreDates = true;
    }
    notifyListeners();

    final now = DateTime.now();
    final startDate = formatDate(now.add(Duration(days: _dateOffset)));
    final endDate = formatDate(DateTime(now.year, now.month + 3, now.day));

    final masterIds = getMasterIds();
    final serviceIds = selectedServices.map((s) => (s['id'] as num).toInt()).join(',');

    if (masterIds.isEmpty) {
      _loadingDates = false;
      _loadingMoreDates = false;
      notifyListeners();
      return;
    }

    final newDates = <DateTime>[];

    for (final masterId in masterIds) {
      try {
        final result = await ApiService.get(
          '/api/booking/availability-summary?project_id=$projectId&employee_id=$masterId'
          '&start_date=$startDate&end_date=$endDate&service_ids=$serviceIds&limit=$_dateLimit',
        );

        if (result['success'] == true && result['data'] != null) {
          final dates = result['data']['available_dates'];
          final hasMore = result['data']['has_more'] ?? false;
          _hasMoreDates = hasMore;

          if (dates is List) {
            for (final d in dates) {
              if (d is Map && d['date'] != null) {
                final date = parseDate(d['date'].toString());
                if (date != null) newDates.add(date);
              }
            }
          }
        }
      } catch (e) {
        AppLogger.debug('loadAvailableDates error for master $masterId: $e');
      }
    }

    // Уникальные даты + сортировка
    final unique = <String, DateTime>{};
    for (final d in _availableDates) unique[formatDate(d)] = d;
    for (final d in newDates) unique[formatDate(d)] = d;
    _availableDates = unique.values.toList()..sort((a, b) => a.compareTo(b));

    _loadingDates = false;
    _loadingMoreDates = false;
    notifyListeners();

    if (!loadMore && _availableDates.isNotEmpty && _selectedDate == null) {
      selectDate(_availableDates.first);
    }
  }

  // ========== ВЫБОР ДАТЫ ==========
  Future<void> selectDate(DateTime date) async {
    _selectedDate = date;
    _selectedTime = null;
    _selectedMasterId = null;
    _timeSlotsByMaster = {};
    notifyListeners();

    await _loadTimeSlots(date);
  }

  Future<void> _loadTimeSlots(DateTime date) async {
    _loadingSlots = true;
    notifyListeners();

    final dateStr = formatDate(date);
    final masterIds = getMasterIds();
    final serviceIds = selectedServices.map((s) => (s['id'] as num).toInt()).join(',');

    try {
      final result = await ApiService.get(
        '/api/booking/time-slots-data?project_id=$projectId&date=$dateStr&end_date=$dateStr'
        '&employee_ids=${masterIds.join(',')}&service_ids=$serviceIds',
      );

      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        _workHoursByMaster = {};
        _timeSlotsByMaster = {};

        final timeSlots = data['time_slots'];
        if (timeSlots is Map) {
          final daySlots = timeSlots[dateStr];
          if (daySlots is Map) {
            daySlots.forEach((key, value) {
              if (value is List) {
                _timeSlotsByMaster[int.parse(key.toString())] =
                    value.map((s) => s.toString()).toList();
              }
            });
          }
        }

        final schedules = data['schedules'];
        if (schedules is Map) {
          final daySchedules = schedules[dateStr];
          if (daySchedules is Map) {
            daySchedules.forEach((key, value) {
              if (value is Map) {
                _workHoursByMaster[int.parse(key.toString())] = {
                  'start': value['start_time']?.toString() ?? '09:00',
                  'end': value['end_time']?.toString() ?? '18:00',
                };
              }
            });
          }
        }
      }
    } catch (e) {
      AppLogger.debug('loadTimeSlots error: $e');
    }

    _loadingSlots = false;
    notifyListeners();
  }

  // ========== ВЫБОР ВРЕМЕНИ ==========
  void selectTime(int masterId, String time) {
    _selectedTime = time;
    _selectedMasterId = masterId;
    notifyListeners();
  }

  // ========== ХЕЛПЕРЫ ==========
  String formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  DateTime? parseDate(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  Map<String, dynamic>? findMasterById(int masterId) {
    for (final m in employees) {
      if ((m['id'] as num).toInt() == masterId) return m;
    }
    return null;
  }
}
