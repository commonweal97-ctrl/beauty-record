// lib/screens/client/booking/steps/booking_confirm_step.dart
import 'package:flutter/material.dart';
import '../../../../widgets/cached_image.dart';

class BookingConfirmStep extends StatelessWidget {
  final Map<String, dynamic>? contactData;
  final List<Map<String, dynamic>> selectedServices;
  final Map<String, dynamic>? selectedMaster;
  final DateTime? selectedDate;
  final String? selectedTime;
  final List<Map<String, dynamic>> warnings;
  final bool agreeData;
  final bool agreeMarketing;
  final bool submitting;
  final Color primaryColor;
  final Color buttonBg;
  final Color buttonText;
  final Function(bool) onAgreeDataChanged;
  final Function(bool) onAgreeMarketingChanged;
  final VoidCallback onSubmit;
  final String Function(Map<String, dynamic>) formatPrice;
  final String Function(int) formatDuration;
  final int Function() getTotalPrice;
  final int Function() getTotalDuration;
  
  const BookingConfirmStep({
    super.key,
    required this.contactData,
    required this.selectedServices,
    required this.selectedMaster,
    required this.selectedDate,
    required this.selectedTime,
    required this.warnings,
    required this.agreeData,
    required this.agreeMarketing,
    required this.submitting,
    required this.primaryColor,
    required this.buttonBg,
    required this.buttonText,
    required this.onAgreeDataChanged,
    required this.onAgreeMarketingChanged,
    required this.onSubmit,
    required this.formatPrice,
    required this.formatDuration,
    required this.getTotalPrice,
    required this.getTotalDuration,
  });

  @override
  Widget build(BuildContext context) {
    final cd = contactData ?? {};
    
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Подтверждение записи', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black)),
        const SizedBox(height: 4),
        const Text('Проверьте данные перед отправкой', style: TextStyle(fontSize: 14, color: Colors.black54)),
        const SizedBox(height: 20),
        
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...selectedServices.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(s['name'] ?? '', style: const TextStyle(fontSize: 14, color: Colors.black))),
                    Text(formatPrice(s), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black)),
                  ],
                ),
              )).toList(),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Итого', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black)),
                  Text('${getTotalPrice()} ₽ · ${formatDuration(getTotalDuration())}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black)),
                ],
              ),
              if (selectedDate != null && selectedTime != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${selectedDate!.day}.${selectedDate!.month}.${selectedDate!.year} в $selectedTime',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (cd['name'] != null && cd['name'].isNotEmpty) ...[
                const Text('Клиент', style: TextStyle(fontSize: 13, color: Colors.black54)),
                Text('${cd['name']} ${cd['lastName'] ?? ''}'.trim(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black)),
                const SizedBox(height: 8),
              ],
              if (cd['phone'] != null && cd['phone'].isNotEmpty) ...[
                const Text('Телефон', style: TextStyle(fontSize: 13, color: Colors.black54)),
                Text(cd['phone'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black)),
                const SizedBox(height: 8),
              ],
              if (cd['email'] != null && cd['email'].isNotEmpty) ...[
                const Text('Email', style: TextStyle(fontSize: 13, color: Colors.black54)),
                Text(cd['email'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black)),
                const SizedBox(height: 8),
              ],
              if (cd['comment'] != null && cd['comment'].isNotEmpty) ...[
                const Text('Комментарий', style: TextStyle(fontSize: 13, color: Colors.black54)),
                Text(cd['comment'], style: const TextStyle(fontSize: 14, color: Colors.black54)),
                const SizedBox(height: 8),
              ],
              if (cd['promo'] != null && cd['promo'].isNotEmpty) ...[
                const Text('Промокод', style: TextStyle(fontSize: 13, color: Colors.black54)),
                Text(cd['promo'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black)),
              ],
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        ...warnings.map((w) {
          final config = w['config'];
          final warningText = config is Map ? config['warning_text']?.toString() : null;
          if (warningText == null) return const SizedBox.shrink();
          
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF9E6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(w['name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF8B6914))),
                const SizedBox(height: 4),
                Text(warningText, style: const TextStyle(fontSize: 13, color: Color(0xFF8B6914), height: 1.5)),
              ],
            ),
          );
        }).toList(),
        
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Нажимая «Завершить запись», вы соглашаетесь с условиями оферты и правилами бронирования.',
            style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.5),
          ),
        ),
        
        const SizedBox(height: 16),
        
        CheckboxListTile(
          value: agreeData,
          onChanged: (v) => onAgreeDataChanged(v ?? false),
          title: const Text(
            'Я прочитал и согласен на обработку персональных данных',
            style: TextStyle(fontSize: 14, color: Colors.black),
          ),
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: primaryColor,
        ),
        
        CheckboxListTile(
          value: agreeMarketing,
          onChanged: (v) => onAgreeMarketingChanged(v ?? true),
          title: const Text(
            'Согласен на получение информационно-рекламной рассылки',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: primaryColor,
        ),
        
        const SizedBox(height: 24),
        
        ElevatedButton(
          onPressed: agreeData && !submitting ? onSubmit : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: agreeData && !submitting ? buttonBg : Colors.grey[300],
            foregroundColor: buttonText,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(
            submitting ? 'Отправка...' : 'Завершить запись',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}