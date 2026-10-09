// lib/screens/client/booking/steps/booking_master_services_step.dart
import 'package:flutter/material.dart';
import '../../../../widgets/cached_image.dart';

class BookingMasterServicesStep extends StatelessWidget {
  final List<Map<String, dynamic>> services;
  final List<Map<String, dynamic>> selectedServices;
  final Map<String, dynamic>? selectedMaster;
  final List<Map<String, dynamic>> employeeServiceLinks;
  final Color primaryColor;
  final Function(Map<String, dynamic>) onToggleService;
  
  const BookingMasterServicesStep({
    super.key,
    required this.services,
    required this.selectedServices,
    required this.selectedMaster,
    required this.employeeServiceLinks,
    required this.primaryColor,
    required this.onToggleService,
  });

  List<Map<String, dynamic>> get _masterServices {
    final masterServiceIds = employeeServiceLinks
        .where((l) => (l['employee_id'] as num).toInt() == (selectedMaster?['id'] as num?)?.toInt())
        .map((l) => (l['service_id'] as num).toInt())
        .toList();
    
    return services.where((s) => masterServiceIds.contains((s['id'] as num).toInt())).toList();
  }
  
  String _formatPrice(Map<String, dynamic> s) {
    final price = (s['price'] as num?)?.toInt() ?? 0;
    if (price == 0) return 'Бесплатно';
    final from = s['price_from'] == 1 || s['price_from'] == true;
    return '${from ? 'от ' : ''}$price ₽';
  }
  
  String _formatDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '$h ч $m мин';
    if (h > 0) return '$h ч';
    if (m > 0) return '$m мин';
    return '0 мин';
  }

  @override
  Widget build(BuildContext context) {
    final masterServices = _masterServices;
    
    return Column(
      children: [
        if (selectedMaster != null)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[200],
                  ),
                  child: selectedMaster!['avatar'] != null && selectedMaster!['avatar'].toString().isNotEmpty
                      ? ClipOval(child: CachedAvatar(url: selectedMaster!['avatar'], size: 48, radius: 24))
                      : Icon(Icons.person, size: 24, color: Colors.grey[400]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(selectedMaster!['name'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black)),
                      if (selectedMaster!['position'] != null)
                        Text(selectedMaster!['position'], style: const TextStyle(fontSize: 13, color: Colors.black54)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: masterServices.isEmpty
              ? const Center(child: Text('Нет доступных услуг', style: TextStyle(color: Colors.black54)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: masterServices.length,
                  itemBuilder: (_, i) {
                    final s = masterServices[i];
                    final selected = selectedServices.any((ss) => ss['id'] == s['id']);
                    return _buildServiceCard(s, selected);
                  },
                ),
        ),
      ],
    );
  }
  
  Widget _buildServiceCard(Map<String, dynamic> s, bool selected) {
    return GestureDetector(
      onTap: () => onToggleService(s),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFDF2F5) : Colors.white,
          border: Border.all(
            color: selected ? primaryColor : const Color(0xFFE8E8E8),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: s['photo_url'] != null && s['photo_url'].toString().isNotEmpty
                      ? ClipRRect(borderRadius: BorderRadius.circular(14), child: CachedAvatar(url: s['photo_url'], size: 64, radius: 14))
                      : Icon(Icons.photo, color: Colors.grey[400]),
                ),
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: selected ? primaryColor : Colors.white, width: 2),
                      color: selected ? primaryColor : Colors.black.withValues(alpha: 0.3),
                    ),
                    child: selected ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s['name'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black)),
                  if (s['category'] != null && s['category'].toString().isNotEmpty)
                    Text(s['category'], style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_formatPrice(s), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black)),
                if ((s['duration'] ?? 0) > 0)
                  Text(_formatDuration((s['duration'] as num).toInt()), style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}