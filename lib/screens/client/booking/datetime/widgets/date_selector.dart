// lib/screens/client/booking/datetime/widgets/date_selector.dart

import 'package:flutter/material.dart';
import '../datetime_controller.dart';
import '../../calendar_popup.dart';

class DateSelector extends StatelessWidget {
  final DateTimeController controller;
  final Color primaryColor;

  static const _weekdaysShort = ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'];
  static const _monthsShort = [
    'янв.', 'фев.', 'мар.', 'апр.', 'мая', 'июн.',
    'июл.', 'авг.', 'сен.', 'окт.', 'ноя.', 'дек.',
  ];

  const DateSelector({
    super.key,
    required this.controller,
    required this.primaryColor,
  });

  Future<void> _openCalendar(BuildContext context) async {
    final availableDateStrings =
        controller.availableDates.map((d) => controller.formatDate(d)).toSet();

    final result = await showDialog<DateTime>(
      context: context,
      builder: (_) => CalendarPopup(
        selectedDate: controller.selectedDate ?? DateTime.now(),
        primaryColor: primaryColor,
        availableDates: availableDateStrings,
      ),
    );

    if (result != null) {
      final dateStr = controller.formatDate(result);
      if (availableDateStrings.contains(dateStr)) {
        controller.selectDate(result);
      }
    }
  }

  bool _isSelected(DateTime date) {
    final sel = controller.selectedDate;
    if (sel == null) return false;
    return sel.year == date.year && sel.month == date.month && sel.day == date.day;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => _openCalendar(context),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.calendar_today, color: primaryColor, size: 20),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 72,
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.pixels >= n.metrics.maxScrollExtent - 100) {
                  controller.loadAvailableDates(loadMore: true);
                }
                return false;
              },
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: controller.availableDates.length +
                    (controller.loadingMoreDates ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i >= controller.availableDates.length) {
                    return Container(
                      width: 62,
                      margin: const EdgeInsets.only(right: 8),
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  final date = controller.availableDates[i];
                  final selected = _isSelected(date);

                  return GestureDetector(
                    onTap: () => controller.selectDate(date),
                    child: Container(
                      width: 62,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: selected ? primaryColor : Colors.white,
                        border: Border.all(
                          color: selected ? primaryColor : const Color(0xFFE8E8E8),
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${date.day}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: selected ? Colors.white : Colors.black,
                            ),
                          ),
                          Text(
                            '${_weekdaysShort[date.weekday % 7]} '
                            '${_monthsShort[date.month - 1]}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
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
}
