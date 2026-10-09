// lib/screens/client/booking/calendar_popup.dart
import 'package:flutter/material.dart';

class CalendarPopup extends StatefulWidget {
  final DateTime selectedDate;
  final Color primaryColor;
  final Set<String> availableDates;
  
  const CalendarPopup({
    super.key,
    required this.selectedDate,
    required this.primaryColor,
    required this.availableDates,
  });

  @override
  State<CalendarPopup> createState() => _CalendarPopupState();
}

class _CalendarPopupState extends State<CalendarPopup> {
  late DateTime _currentDate;
  late DateTime _selected;
  final ScrollController _scrollController = ScrollController();
  
  final List<String> _monthsRu = [
    'Январь','Февраль','Март','Апрель','Май','Июнь',
    'Июль','Август','Сентябрь','Октябрь','Ноябрь','Декабрь'
  ];
  
  final List<String> _weekdaysShort = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
  
  @override
  void initState() {
    super.initState();
    _selected = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
    );
    _currentDate = DateTime(_selected.year, _selected.month, 1);
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  
  String get _monthYearTitle {
    return '${_monthsRu[_currentDate.month - 1]} ${_currentDate.year}';
  }
  
  void _changeMonth(int delta) {
    setState(() {
      _currentDate = DateTime(_currentDate.year, _currentDate.month + delta, 1);
    });
  }
  
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
  
  List<_MonthData> _generateMonths() {
    final today = DateTime.now();
    final todayTime = DateTime(today.year, today.month, today.day);
    final selectedTime = DateTime(_selected.year, _selected.month, _selected.day);
    
    final months = <_MonthData>[];
    
    // Начинаем с текущего месяца (offset 0) + 12 месяцев вперёд
    for (int offset = 0; offset <= 12; offset++) {
      final monthDate = DateTime(_currentDate.year, _currentDate.month + offset, 1);
      final year = monthDate.year;
      final month = monthDate.month;
      
      final title = '${_monthsRu[month - 1]} $year';
      final days = <_DayData>[];
      
      final firstDay = DateTime(year, month, 1);
      int startDay = firstDay.weekday - 1;
      if (startDay < 0) startDay = 0;
      
      final daysInMonth = DateTime(year, month + 1, 0).day;
      
      for (int i = 0; i < startDay; i++) {
        days.add(_DayData.empty());
      }
      
      for (int d = 1; d <= daysInMonth; d++) {
        final dayDate = DateTime(year, month, d);
        final dayTime = DateTime(year, month, d);
        
        final dateStr = _formatDate(dayDate);
        final isAvailable = widget.availableDates.contains(dateStr);
        final isPast = dayTime.isBefore(todayTime);
        
        days.add(_DayData(
          day: d,
          weekend: dayDate.weekday == DateTime.saturday || dayDate.weekday == DateTime.sunday,
          isToday: dayTime == todayTime,
          isSelected: dayTime == selectedTime,
          isPast: isPast,
          isAvailable: isAvailable,
          date: dayDate,
        ));
      }
      
      months.add(_MonthData(title: title, days: days, year: year, month: month));
    }
    
    return months;
  }
  
  @override
  Widget build(BuildContext context) {
    if (_currentDate.year != _selected.year || _currentDate.month != _selected.month) {
      _currentDate = DateTime(_selected.year, _selected.month, 1);
    }
    
    final months = _generateMonths();
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        height: screenHeight * 0.85,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _changeMonth(-1),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.chevron_left, color: Colors.grey[700], size: 22),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _monthYearTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _changeMonth(1),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.chevron_right, color: Colors.grey[700], size: 22),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.close, color: Colors.grey[700], size: 20),
                    ),
                  ),
                ],
              ),
            ),
            
            const Divider(height: 1),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: _weekdaysShort.map((d) => Expanded(
                  child: Center(
                    child: Text(d, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[500])),
                  ),
                )).toList(),
              ),
            ),
            
            const Divider(height: 1),
            
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: months.length,
                itemBuilder: (_, monthIndex) {
                  final month = months[monthIndex];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Text(
                          month.title,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.grey[700]),
                        ),
                      ),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          childAspectRatio: 1.1,
                        ),
                        itemCount: month.days.length,
                        itemBuilder: (_, dayIndex) {
                          final day = month.days[dayIndex];
                          
                          if (day.empty) {
                            return const SizedBox.shrink();
                          }
                          
                          final canSelect = day.isAvailable && !day.isPast;
                          
                          return GestureDetector(
                            onTap: canSelect ? () {
                              Navigator.pop(context, day.date);
                            } : null,
                            child: Container(
                              margin: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: day.isSelected 
                                    ? widget.primaryColor 
                                    : day.isToday && canSelect
                                        ? widget.primaryColor.withOpacity(0.1) 
                                        : Colors.transparent,
                                border: day.isToday && !day.isSelected
                                    ? Border.all(color: widget.primaryColor, width: 1)
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  '${day.day}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: day.isSelected || day.isToday ? FontWeight.w700 : FontWeight.w400,
                                    color: day.isSelected
                                        ? Colors.white
                                        : !canSelect
                                            ? Colors.grey[300]
                                            : day.weekend
                                                ? Colors.red[400]
                                                : Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthData {
  final String title;
  final List<_DayData> days;
  final int year;
  final int month;
  
  _MonthData({
    required this.title,
    required this.days,
    required this.year,
    required this.month,
  });
}

class _DayData {
  final int? day;
  final bool empty;
  final bool weekend;
  final bool isToday;
  final bool isSelected;
  final bool isPast;
  final bool isAvailable;
  final DateTime? date;
  
  _DayData({
    this.day,
    this.empty = false,
    this.weekend = false,
    this.isToday = false,
    this.isSelected = false,
    this.isPast = false,
    this.isAvailable = false,
    this.date,
  });
  
  factory _DayData.empty() => _DayData(empty: true);
}