// lib/widgets/common/time_picker_sheet.dart
//
// Единый time-picker для всего приложения (iOS-стиль).
// Использует CupertinoDatePicker (колёсики «часы | минуты») — нативно для iOS,
// привычно пользователю. Заменяет стандартный Material showTimePicker
// (круговой циферблат), который был неудобен.
//
// Использование:
//   final t = await showTimePickerSheet(context, initialTime: TimeOfDay(hour: 9, minute: 0));
//   if (t != null) { /* ... */ }

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

const _kAccent = Color(0xFFDD1847);
const _kTextPrimary = Color(0xFF1A1A1A);
const _kTextMuted = Color(0xFF666666);
const _kBorder = Color(0xFFE5E5E5);

/// Показать time-picker bottom-sheet (iOS-стиль, колёсики).
/// Возвращает TimeOfDay или null, если отменили.
Future<TimeOfDay?> showTimePickerSheet(
  BuildContext context, {
  required TimeOfDay initialTime,
  String? title,
  String? confirmLabel,
}) {
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _TimePickerSheet(
      initialTime: initialTime,
      title: title ?? 'Выберите время',
      confirmLabel: confirmLabel ?? 'Готово',
    ),
  );
}

class _TimePickerSheet extends StatefulWidget {
  final TimeOfDay initialTime;
  final String title;
  final String confirmLabel;

  const _TimePickerSheet({
    required this.initialTime,
    required this.title,
    required this.confirmLabel,
  });

  @override
  State<_TimePickerSheet> createState() => _TimePickerSheetState();
}

class _TimePickerSheetState extends State<_TimePickerSheet> {
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selected = DateTime(
      now.year,
      now.month,
      now.day,
      widget.initialTime.hour,
      widget.initialTime.minute,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _kBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Заголовок
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _kTextPrimary,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // CupertinoDatePicker — колёсики «часы | минуты»
            SizedBox(
              height: 200,
              child: CupertinoTheme(
                data: const CupertinoThemeData(
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: TextStyle(
                      fontSize: 22,
                      color: _kTextPrimary,
                    ),
                  ),
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: true,
                  initialDateTime: _selected,
                  minuteInterval: 5,
                  onDateTimeChanged: (d) {
                    setState(() => _selected = d);
                  },
                ),
              ),
            ),

            const Divider(height: 1, color: Color(0xFFF0F0F0)),

            // Кнопки
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        side: const BorderSide(color: _kBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Отмена',
                        style: TextStyle(
                          color: _kTextMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(
                        context,
                        TimeOfDay(
                          hour: _selected.hour,
                          minute: _selected.minute,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: _kAccent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        widget.confirmLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Time Range Picker — один попап с ДВУМЯ колёсиками (начало | конец).
// Используется там, где надо ввести диапазон (например, рабочее время смены).
// =============================================================================

/// Результат выбора диапазона времени.
class TimeRange {
  final TimeOfDay start;
  final TimeOfDay end;
  const TimeRange({required this.start, required this.end});
}

/// Показать time-range picker: два CupertinoDatePicker рядом.
Future<TimeRange?> showTimeRangePickerSheet(
  BuildContext context, {
  required TimeOfDay startTime,
  required TimeOfDay endTime,
  String? title,
}) {
  return showModalBottomSheet<TimeRange>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _TimeRangePickerSheet(
      startTime: startTime,
      endTime: endTime,
      title: title ?? 'Рабочее время',
    ),
  );
}

class _TimeRangePickerSheet extends StatefulWidget {
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String title;

  const _TimeRangePickerSheet({
    required this.startTime,
    required this.endTime,
    required this.title,
  });

  @override
  State<_TimeRangePickerSheet> createState() => _TimeRangePickerSheetState();
}

class _TimeRangePickerSheetState extends State<_TimeRangePickerSheet> {
  late DateTime _start;
  late DateTime _end;
  String? _activeField; // null | 'start' | 'end'

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _start = DateTime(now.year, now.month, now.day, widget.startTime.hour, widget.startTime.minute);
    _end = DateTime(now.year, now.month, now.day, widget.endTime.hour, widget.endTime.minute);
  }

  String _fmt(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  void _toggleField(String field) {
    setState(() {
      _activeField = (_activeField == field) ? null : field;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _kBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _kTextPrimary,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Поле «Начало»
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildField(
                key: 'start',
                label: 'Начало',
                value: _start,
                isActive: _activeField == 'start',
              ),
            ),

            const SizedBox(height: 12),

            // Поле «Конец»
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildField(
                key: 'end',
                label: 'Конец',
                value: _end,
                isActive: _activeField == 'end',
              ),
            ),

            // Inline-колесо (плавно раскрывается/закрывается)
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: _activeField == null
                  ? const SizedBox(width: double.infinity, height: 0)
                  : Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SizedBox(
                        height: 180,
                        child: CupertinoTheme(
                          data: const CupertinoThemeData(
                            textTheme: CupertinoTextThemeData(
                              dateTimePickerTextStyle: TextStyle(
                                fontSize: 22,
                                color: _kTextPrimary,
                              ),
                            ),
                          ),
                          child: CupertinoDatePicker(
                            key: ValueKey('wheel_$_activeField'),
                            mode: CupertinoDatePickerMode.time,
                            use24hFormat: true,
                            initialDateTime: _activeField == 'start' ? _start : _end,
                            minuteInterval: 5,
                            onDateTimeChanged: (d) {
                              setState(() {
                                if (_activeField == 'start') {
                                  _start = d;
                                } else if (_activeField == 'end') {
                                  _end = d;
                                }
                              });
                            },
                          ),
                        ),
                      ),
                    ),
            ),

            const SizedBox(height: 8),

            const Divider(height: 1, color: Color(0xFFF0F0F0)),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        side: const BorderSide(color: _kBorder),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Отмена', style: TextStyle(color: _kTextMuted, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(
                        context,
                        TimeRange(
                          start: TimeOfDay(hour: _start.hour, minute: _start.minute),
                          end: TimeOfDay(hour: _end.hour, minute: _end.minute),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: _kAccent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Готово', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required String key,
    required String label,
    required DateTime value,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: () => _toggleField(key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isActive ? _kAccent.withValues(alpha: 0.08) : const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? _kAccent : _kBorder,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isActive ? _kAccent : _kTextMuted,
              ),
            ),
            const Spacer(),
            Text(
              _fmt(value),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isActive ? _kAccent : _kTextPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 6),
            AnimatedRotation(
              duration: const Duration(milliseconds: 200),
              turns: isActive ? 0.5 : 0,
              child: Icon(
                Icons.keyboard_arrow_down,
                size: 22,
                color: isActive ? _kAccent : _kTextMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
