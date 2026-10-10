// lib/screens/client/booking/datetime/widgets/datetime_bottom_bar.dart

import 'package:flutter/material.dart';

class DateTimeBottomBar extends StatelessWidget {
  final int totalPrice;
  final int totalDuration;
  final int serviceCount;
  final bool canContinue;
  final Color buttonBg;
  final Color buttonText;
  final VoidCallback onContinue;

  const DateTimeBottomBar({
    super.key,
    required this.totalPrice,
    required this.totalDuration,
    required this.serviceCount,
    required this.canContinue,
    required this.buttonBg,
    required this.buttonText,
    required this.onContinue,
  });

  String _formatDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '$h ч $m мин';
    if (h > 0) return '$h ч';
    if (m > 0) return '$m мин';
    return '0 мин';
  }

  String _serviceWord(int count) {
    if (count == 1) return 'услуга';
    if (count >= 2 && count <= 4) return 'услуги';
    return 'услуг';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
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
                  Text(
                    '$totalPrice ₽',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$serviceCount ${_serviceWord(serviceCount)} · ${_formatDuration(totalDuration)}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: canContinue ? onContinue : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: canContinue ? buttonBg : Colors.grey[300],
                foregroundColor: buttonText,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                minimumSize: const Size(0, 36),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'Продолжить',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
