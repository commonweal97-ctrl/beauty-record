// lib/screens/client/booking/widgets/schedule_block.dart
import 'package:flutter/material.dart';

class ScheduleBlock extends StatefulWidget {
  final Map<String, dynamic> scheduleData;
  final Color primaryColor;
  
  const ScheduleBlock({
    super.key,
    required this.scheduleData,
    required this.primaryColor,
  });

  @override
  State<ScheduleBlock> createState() => _ScheduleBlockState();
}

class _ScheduleBlockState extends State<ScheduleBlock> {
  bool _expanded = false;
  
  @override
  Widget build(BuildContext context) {
    final daysFull = ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'];
    
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _expanded ? widget.primaryColor.withValues(alpha: 0.3) : const Color(0xFFE8E8E8),
          ),
        ),
        child: Column(
          children: [
            // Заголовок
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'График работы',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: widget.primaryColor.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: widget.primaryColor,
                    size: 20,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Пн — всегда видим
            _buildDayRow(0, daysFull[0], 1.0, bold: true),
            
            // Вт — полупрозрачный намёк
            if (!_expanded) _buildDayRow(1, daysFull[1], 0.3),
            
            // Остальные дни — при раскрытии
            if (_expanded) ...[
              _buildDayRow(1, daysFull[1], 1.0),
              _buildDayRow(2, daysFull[2], 1.0),
              _buildDayRow(3, daysFull[3], 1.0),
              _buildDayRow(4, daysFull[4], 1.0),
              _buildDayRow(5, daysFull[5], 1.0),
              _buildDayRow(6, daysFull[6], 1.0),
            ],
            
            // Градиент — только когда свёрнут
            if (!_expanded)
              Container(
                height: 16,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFFF8F8F8).withValues(alpha: 0),
                      const Color(0xFFF8F8F8),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDayRow(int idx, String day, double opacity, {bool bold = false}) {
    final s = widget.scheduleData[idx.toString()];
    final time = s != null
        ? '${(s['start'] ?? '').toString().substring(0, 5)} – ${(s['end'] ?? '').toString().substring(0, 5)}'
        : 'Выходной';
    final color = s != null ? const Color(0xFF1A1A1A) : const Color(0xFFCCCCCC);
    
    return Opacity(
      opacity: opacity,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              day,
              style: TextStyle(
                fontSize: bold ? 15 : 14,
                fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
            Text(
              time,
              style: TextStyle(
                fontSize: bold ? 16 : 14,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}