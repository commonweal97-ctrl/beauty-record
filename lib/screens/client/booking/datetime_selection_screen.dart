// lib/screens/client/booking/datetime_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/api_service.dart';
import '../../../widgets/cached_image.dart';
import 'calendar_popup.dart';

class DateTimeSelectionScreen extends StatefulWidget {
  final int projectId;
  final List<Map<String, dynamic>> selectedServices;
  final Map<String, dynamic>? selectedMaster;
  final Map<int, int> serviceMasters;
  final List<Map<String, dynamic>> employees;
  final Color primaryColor;
  final Color buttonBg;
  final Color buttonText;
  final String specialistLabel;
  final String serviceLabel;
  final Function(DateTime, String, int?)? onDateTimeSelected;
  
  const DateTimeSelectionScreen({
    super.key,
    required this.projectId,
    required this.selectedServices,
    this.selectedMaster,
    required this.serviceMasters,
    required this.employees,
    required this.primaryColor,
    required this.buttonBg,
    required this.buttonText,
    this.specialistLabel = 'Специалисты',
    this.serviceLabel = 'Услуги',
    this.onDateTimeSelected,
  });

  @override
  State<DateTimeSelectionScreen> createState() => _DateTimeSelectionScreenState();
}

class _DateTimeSelectionScreenState extends State<DateTimeSelectionScreen> {
  List<DateTime> _availableDates = [];
  Map<int, List<String>> _timeSlotsByMaster = {};
  Map<int, Map<String, String>> _workHoursByMaster = {};
  
  DateTime? _selectedDate;
  String? _selectedTime;
  int? _selectedMasterId;
  
  bool _loadingDates = false;
  bool _loadingSlots = false;
  
  bool _hasMoreDates = true;
  bool _loadingMoreDates = false;
  int _dateOffset = 0;
  static const int _dateLimit = 14;
  
  static const _weekdaysShort = ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'];
  static const _monthsShort = ['янв.', 'фев.', 'мар.', 'апр.', 'мая', 'июн.', 'июл.', 'авг.', 'сен.', 'окт.', 'ноя.', 'дек.'];
  
  @override
  void initState() {
    super.initState();
    
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
    
    _loadAvailableDates();
  }
  
  @override
  void dispose() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
    
    super.dispose();
  }
  
  List<int> _getMasterIds() {
    final ids = <int>{};
    
    for (final service in widget.selectedServices) {
      final sid = (service['id'] as num).toInt();
      final masterId = widget.serviceMasters[sid];
      
      if (masterId != null) {
        ids.add(masterId);
      } else {
        for (final emp in widget.employees) {
          final serviceIds = emp['service_ids'];
          if (serviceIds != null && serviceIds is List && serviceIds.contains(sid)) {
            ids.add((emp['id'] as num).toInt());
          }
        }
      }
    }
    
    if (ids.isEmpty) {
      ids.addAll(widget.employees.map((m) => (m['id'] as num).toInt()));
    }
    
    return ids.toList();
  }
  
  Future<void> _loadAvailableDates({bool loadMore = false}) async {
    if (loadMore) {
      if (_loadingMoreDates || !_hasMoreDates) return;
      setState(() => _loadingMoreDates = true);
      _dateOffset += _dateLimit;
    } else {
      setState(() => _loadingDates = true);
      _dateOffset = 0;
      _availableDates = [];
      _hasMoreDates = true;
    }
    
    final now = DateTime.now();
    final startDate = _formatDate(now.add(Duration(days: _dateOffset)));
    final endDate = _formatDate(DateTime(now.year, now.month + 3, now.day));
    
    final masterIds = _getMasterIds();
    final serviceIds = widget.selectedServices.map((s) => (s['id'] as num).toInt()).join(',');
    
    if (masterIds.isEmpty) {
      setState(() {
        _loadingDates = false;
        _loadingMoreDates = false;
      });
      return;
    }
    
    final availableDates = <DateTime>[];
    
    for (final masterId in masterIds) {
      final result = await ApiService.get(
        '/api/booking/availability-summary?project_id=${widget.projectId}&employee_id=$masterId&start_date=$startDate&end_date=$endDate&service_ids=$serviceIds&limit=$_dateLimit'
      );
      
      if (result['success'] == true && result['data'] != null) {
        final dates = result['data']['available_dates'];
        final hasMore = result['data']['has_more'] ?? false;
        _hasMoreDates = hasMore;
        
        if (dates != null && dates is List) {
          for (final d in dates) {
            if (d is Map && d['date'] != null) {
              final date = _parseDate(d['date'].toString());
              if (date != null) {
                availableDates.add(date);
              }
            }
          }
        }
      }
    }
    
    final uniqueDates = <String, DateTime>{};
    for (final d in _availableDates) {
      uniqueDates[_formatDate(d)] = d;
    }
    for (final d in availableDates) {
      uniqueDates[_formatDate(d)] = d;
    }
    
    final allDates = uniqueDates.values.toList()
      ..sort((a, b) => a.compareTo(b));
    
    if (mounted) {
      setState(() {
        _availableDates = allDates;
        _loadingDates = false;
        _loadingMoreDates = false;
      });
    }
    
    if (!loadMore && _availableDates.isNotEmpty && _selectedDate == null) {
      _selectDate(_availableDates.first);
    }
  }
  
  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
      _selectedTime = null;
      _selectedMasterId = null;
      _timeSlotsByMaster = {};
    });
    _loadTimeSlots(date);
  }
  
  Future<void> _loadTimeSlots(DateTime date) async {
    setState(() => _loadingSlots = true);
    
    final dateStr = _formatDate(date);
    final masterIds = _getMasterIds();
    final serviceIds = widget.selectedServices.map((s) => (s['id'] as num).toInt()).join(',');
    
    final result = await ApiService.get(
      '/api/booking/time-slots-data?project_id=${widget.projectId}&date=$dateStr&end_date=$dateStr&employee_ids=${masterIds.join(',')}&service_ids=$serviceIds'
    );
    
    if (result['success'] == true && result['data'] != null) {
      final data = result['data'];
      
      _workHoursByMaster = {};
      _timeSlotsByMaster = {};
      
      final timeSlots = data['time_slots'];
      
      if (timeSlots != null && timeSlots is Map) {
        final daySlots = timeSlots[dateStr];
        
        if (daySlots != null && daySlots is Map) {
          daySlots.forEach((key, value) {
            if (value is List) {
              final masterId = int.parse(key.toString());
              _timeSlotsByMaster[masterId] = value.map((s) => s.toString()).toList();
            }
          });
        }
      }
      
      final schedules = data['schedules'];
      if (schedules != null && schedules is Map) {
        final daySchedules = schedules[dateStr];
        if (daySchedules != null && daySchedules is Map) {
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
    
    if (mounted) {
      setState(() => _loadingSlots = false);
    }
  }
  
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
  
  DateTime? _parseDate(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length != 3) return null;
    
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    
    if (year == null || month == null || day == null) return null;
    
    return DateTime(year, month, day);
  }
  
  String _formatDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '$h ч $m мин';
    if (h > 0) return '$h ч';
    if (m > 0) return '$m мин';
    return '0 мин';
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
          _buildBottomBar(),
        ],
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: widget.primaryColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Дата и время',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildBody() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Выберите дату', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black)),
              const SizedBox(height: 12),
              
              if (_loadingDates)
                const Center(child: CircularProgressIndicator())
              else if (_availableDates.isEmpty)
                const Text('Нет доступных дат', style: TextStyle(color: Colors.black54))
              else
                _buildDateSelector(),
            ],
          ),
        ),
        
        Expanded(
          child: _loadingSlots
              ? const Center(child: CircularProgressIndicator())
              : _timeSlotsByMaster.isEmpty
                  ? const Center(child: Text('Нет доступного времени', style: TextStyle(color: Colors.black54)))
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        const Text('Доступное время', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black)),
                        const SizedBox(height: 12),
                        ..._buildTimeSlots(),
                      ],
                    ),
        ),
      ],
    );
  }
  
  Widget _buildDateSelector() {
    return Row(
      children: [
        // Иконка календаря — открывает попап
        GestureDetector(
          onTap: () async {
            // Собираем доступные даты в Set для быстрого поиска
            final availableDateStrings = _availableDates.map((d) => _formatDate(d)).toSet();
            
            final result = await showDialog<DateTime>(
              context: context,
              builder: (_) => CalendarPopup(
                selectedDate: _selectedDate ?? DateTime.now(),
                primaryColor: widget.primaryColor,
                availableDates: availableDateStrings,
              ),
            );
            
            if (result != null) {
              // Проверяем, что выбранная дата доступна
              final dateStr = _formatDate(result);
              if (availableDateStrings.contains(dateStr)) {
                _selectDate(result);
              }
            }
          },
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: widget.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.calendar_today, color: widget.primaryColor, size: 20),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 72,
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.pixels >= notification.metrics.maxScrollExtent - 100) {
                  _loadAvailableDates(loadMore: true);
                }
                return false;
              },
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _availableDates.length + (_loadingMoreDates ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i >= _availableDates.length) {
                    return Container(
                      width: 62,
                      margin: const EdgeInsets.only(right: 8),
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    );
                  }
                  
                  final date = _availableDates[i];
                  final selected = _selectedDate != null &&
                      _selectedDate!.year == date.year &&
                      _selectedDate!.month == date.month &&
                      _selectedDate!.day == date.day;
                  
                  return GestureDetector(
                    onTap: () => _selectDate(date),
                    child: Container(
                      width: 62,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: selected ? widget.primaryColor : Colors.white,
                        border: Border.all(color: selected ? widget.primaryColor : const Color(0xFFE8E8E8)),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('${date.day}', style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : Colors.black,
                          )),
                          Text(
                            '${_weekdaysShort[date.weekday % 7]} ${_monthsShort[date.month - 1]}',
                            style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600,
                              color: selected ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  List<Widget> _buildTimeSlots() {
    final widgets = <Widget>[];
    
    _timeSlotsByMaster.forEach((masterId, slots) {
      final master = _findMasterById(masterId);
      
      if (slots.isNotEmpty && master != null) {
        widgets.add(_buildMasterCard(master, masterId, slots));
      }
    });
    
    return widgets;
  }
  
  Map<String, dynamic>? _findMasterById(int masterId) {
    for (final m in widget.employees) {
      if ((m['id'] as num).toInt() == masterId) {
        return m;
      }
    }
    return null;
  }
  
  Widget _buildMasterCard(Map<String, dynamic> master, int masterId, List<String> slots) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[200],
                ),
                child: master['avatar'] != null && master['avatar'].toString().isNotEmpty
                    ? ClipOval(
                        child: CachedAvatar(
                          url: master['avatar'].toString(),
                          size: 40,
                          radius: 20,
                        ),
                      )
                    : Icon(Icons.person, size: 20, color: Colors.grey[400]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(master['name'] ?? 'Специалист', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black)),
                    if (master['position'] != null && master['position'].toString().isNotEmpty)
                      Text(master['position'], style: const TextStyle(fontSize: 13, color: Colors.black54)),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Wrap(
            spacing: 8, runSpacing: 8,
            children: slots.map((time) {
              final selected = _selectedTime == time && _selectedMasterId == masterId;
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedTime = time;
                    _selectedMasterId = masterId;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFFDF2F5) : const Color(0xFFF8F8F8),
                    border: Border.all(color: selected ? widget.primaryColor : const Color(0xFFE0E0E0)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(time, style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500,
                    color: selected ? widget.primaryColor : Colors.black,
                  )),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBottomBar() {
    final canContinue = _selectedDate != null && _selectedTime != null;
    final totalPrice = widget.selectedServices.fold(0, (sum, s) => sum + ((s['price'] as num?)?.toInt() ?? 0));
    final totalDuration = widget.selectedServices.fold(0, (sum, s) => sum + ((s['duration'] as num?)?.toInt() ?? 0));
    final serviceCount = widget.selectedServices.length;
    final serviceWord = serviceCount == 1 ? 'услуга' : (serviceCount >= 2 && serviceCount <= 4 ? 'услуги' : 'услуг');
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$totalPrice ₽', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black)),
                  const SizedBox(height: 2),
                  Text(
                    '$serviceCount $serviceWord · ${_formatDuration(totalDuration)}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: canContinue
                  ? () {
                      if (widget.onDateTimeSelected != null) {
                        widget.onDateTimeSelected!(_selectedDate!, _selectedTime!, _selectedMasterId);
                      } else {
                        Navigator.pop(context, {
                          'date': _selectedDate,
                          'time': _selectedTime,
                          'master_id': _selectedMasterId,
                        });
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: canContinue ? widget.buttonBg : Colors.grey[300],
                foregroundColor: widget.buttonText,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                minimumSize: const Size(0, 36),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Продолжить', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}