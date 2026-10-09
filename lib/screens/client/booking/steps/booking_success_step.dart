// lib/screens/client/booking/steps/booking_success_step.dart
import 'package:flutter/material.dart';
import '../../../../widgets/cached_image.dart';

class BookingSuccessStep extends StatelessWidget {
  final Map<String, dynamic>? contactData;
  final List<Map<String, dynamic>> selectedServices;
  final Map<String, dynamic>? selectedMaster;
  final DateTime? selectedDate;
  final String? selectedTime;
  final Color primaryColor;
  final Color buttonBg;
  final Color buttonText;
  final String Function(Map<String, dynamic>) formatPrice;
  final String Function(int) formatDuration;
  final int Function() getTotalPrice;
  final int Function() getTotalDuration;
  final VoidCallback onDone;
  
  const BookingSuccessStep({
    super.key,
    required this.contactData,
    required this.selectedServices,
    required this.selectedMaster,
    required this.selectedDate,
    required this.selectedTime,
    required this.primaryColor,
    required this.buttonBg,
    required this.buttonText,
    required this.formatPrice,
    required this.formatDuration,
    required this.getTotalPrice,
    required this.getTotalDuration,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final cd = contactData ?? {};
    final clientName = cd['name'] ?? '';
    
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 20),
        
        // Иконка успеха
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFE8F5E9),
          ),
          child: const Icon(Icons.check, size: 40, color: Color(0xFF2E7D32)),
        ),
        
        const SizedBox(height: 24),
        
        const Text(
          'Запись создана!',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.black),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 8),
        
        Text(
          'Спасибо, $clientName!\nВаша запись успешно оформлена.',
          style: const TextStyle(fontSize: 15, color: Colors.black54),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 32),
        
        // Карточка с деталями
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Дата и время
              if (selectedDate != null && selectedTime != null) ...[
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.calendar_today, color: primaryColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${selectedDate!.day}.${selectedDate!.month}.${selectedDate!.year} в $selectedTime',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black),
                        ),
                        Text(
                          'Длительность: ${formatDuration(getTotalDuration())}',
                          style: const TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
              ],
              
              // Мастер
              if (selectedMaster != null) ...[
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[200],
                      ),
                      child: selectedMaster!['avatar'] != null && selectedMaster!['avatar'].toString().isNotEmpty
                          ? ClipOval(child: CachedAvatar(url: selectedMaster!['avatar'], size: 40, radius: 20))
                          : Icon(Icons.person, size: 20, color: Colors.grey[400]),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedMaster!['name'] ?? '',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black),
                        ),
                        if (selectedMaster!['position'] != null)
                          Text(
                            selectedMaster!['position'],
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              
              // Услуги
              ...selectedServices.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(s['name'] ?? '', style: const TextStyle(fontSize: 14, color: Colors.black))),
                    Text(formatPrice(s), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black)),
                  ],
                ),
              )).toList(),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        ElevatedButton(
          onPressed: onDone,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: BorderSide(color: primaryColor, width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('Готово', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
        
        const SizedBox(height: 16),
        const Text(
          'В личном кабинете вы сможете отменить или перенести запись',
          style: TextStyle(fontSize: 13, color: Colors.black54),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}