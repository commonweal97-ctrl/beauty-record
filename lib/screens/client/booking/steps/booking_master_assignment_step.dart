// lib/screens/client/booking/steps/booking_master_assignment_step.dart
import 'package:flutter/material.dart';
import '../../../../widgets/cached_image.dart';

class BookingMasterAssignmentStep extends StatelessWidget {
  final List<Map<String, dynamic>> services;
  final List<Map<String, dynamic>> employees;
  final List<Map<String, dynamic>> employeeServiceLinks;
  final Map<int, int> serviceMasters;
  final Color primaryColor;
  final String specialistLabel;
  final Function(int serviceId, int masterId) onAssign;

  const BookingMasterAssignmentStep({
    super.key,
    required this.services,
    required this.employees,
    required this.employeeServiceLinks,
    required this.serviceMasters,
    required this.primaryColor,
    required this.specialistLabel,
    required this.onAssign,
  });

  List<Map<String, dynamic>> _mastersForService(int serviceId) {
    final masterIds = employeeServiceLinks
        .where((l) => (l['service_id'] as num).toInt() == serviceId)
        .map((l) => (l['employee_id'] as num).toInt())
        .toSet();
    return employees.where((e) => masterIds.contains((e['id'] as num).toInt())).toList();
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
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: services.length,
      itemBuilder: (_, i) {
        final s = services[i];
        final serviceId = (s['id'] as num).toInt();
        final assignedMasterId = serviceMasters[serviceId];
        final masters = _mastersForService(serviceId);

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8E8E8), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s['name'] ?? '',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              if ((s['duration'] ?? 0) > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _formatDuration((s['duration'] as num).toInt()),
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ),
              const SizedBox(height: 12),
              if (masters.isEmpty)
                const Text(
                  'Нет доступных специалистов',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: masters.map((m) {
                    final masterId = (m['id'] as num).toInt();
                    final selected = assignedMasterId == masterId;
                    final avatarUrl = m['avatar']?.toString();
                    return GestureDetector(
                      onTap: () => onAssign(serviceId, masterId),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? const Color(0xFFFDF2F5) : Colors.white,
                          border: Border.all(
                            color: selected ? primaryColor : const Color(0xFFE8E8E8),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipOval(
                              child: (avatarUrl != null && avatarUrl.isNotEmpty)
                                  ? CachedAvatar(url: avatarUrl, size: 28, radius: 14)
                                  : Container(
                                      width: 28, height: 28,
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.person, size: 16, color: Colors.grey),
                                    ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              m['name'] ?? '',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                                color: selected ? primaryColor : Colors.black,
                              ),
                            ),
                            if (selected) ...[
                              const SizedBox(width: 6),
                              Icon(Icons.check, size: 16, color: primaryColor),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }
}
