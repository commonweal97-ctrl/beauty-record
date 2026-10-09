// lib/screens/client/booking/steps/booking_contact_step.dart
import 'package:flutter/material.dart';

class BookingContactStep extends StatelessWidget {
  final TextEditingController commentController;
  final TextEditingController promoController;
  final Color primaryColor;
  final InputDecoration Function(String) inputDecoration;
  
  const BookingContactStep({
    super.key,
    required this.commentController,
    required this.promoController,
    required this.primaryColor,
    required this.inputDecoration,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Контактные данные', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black)),
        const SizedBox(height: 4),
        const Text('Комментарий и промокод', style: TextStyle(fontSize: 14, color: Colors.black54)),
        const SizedBox(height: 20),
        
        // Комментарий
        _buildLabel('Комментарий'),
        TextField(
          controller: commentController,
          decoration: inputDecoration('Ваш комментарий к записи...'),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        
        // Промокод
        _buildLabel('Промокод'),
        TextField(
          controller: promoController,
          decoration: inputDecoration('Введите промокод'),
        ),
      ],
    );
  }
  
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black)),
    );
  }
}