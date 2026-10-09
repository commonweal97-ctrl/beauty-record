// lib/screens/client/booking/steps/booking_start_step.dart
import 'package:flutter/material.dart';

class BookingStartStep extends StatelessWidget {
  final String serviceLabelAccusative;
  final String specialistLabelAccusative;
  final String serviceLabelGenitive;
  final String specialistLabelGenitive;
  final Color primaryColor;
  final VoidCallback onSelectServices;
  final VoidCallback onSelectMasters;
  
  const BookingStartStep({
    super.key,
    required this.serviceLabelAccusative,
    required this.specialistLabelAccusative,
    required this.serviceLabelGenitive,
    required this.specialistLabelGenitive,
    required this.primaryColor,
    required this.onSelectServices,
    required this.onSelectMasters,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Text(
            'Выберите $serviceLabelAccusative или $specialistLabelAccusative',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _buildOption(
            icon: Icons.list_alt,
            title: 'Выбрать $serviceLabelAccusative',
            subtitle: 'Выбор из списка $serviceLabelGenitive',
            onTap: onSelectServices,
          ),
          const SizedBox(height: 16),
          _buildOption(
            icon: Icons.person,
            title: 'Выбрать $specialistLabelAccusative',
            subtitle: 'Подбор по $specialistLabelGenitive',
            onTap: onSelectMasters,
          ),
          const Spacer(),
          const Text(
            'Онлайн-запись предоставлена сервисом',
            style: TextStyle(fontSize: 13, color: Color(0xFFAAA)),
          ),
        ],
      ),
    );
  }
  
  Widget _buildOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE0E0E0), width: 2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: primaryColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }
}