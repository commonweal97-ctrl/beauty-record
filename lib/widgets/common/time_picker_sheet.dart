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
