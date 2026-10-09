// lib/screens/client/booking/widgets/bottom_booking_bar.dart
import 'package:flutter/material.dart';

class BottomBookingBar extends StatelessWidget {
  final Color buttonBg;
  final Color buttonText;
  final VoidCallback onBook;
  final VoidCallback onMyBookings;
  
  const BottomBookingBar({
    super.key,
    required this.buttonBg,
    required this.buttonText,
    required this.onBook,
    required this.onMyBookings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: SafeArea(
        child: Center(
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onBook,
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonBg,
                foregroundColor: buttonText,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                shadowColor: buttonBg.withOpacity(0.4),
              ),
              child: const Text(
                'Записаться',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}