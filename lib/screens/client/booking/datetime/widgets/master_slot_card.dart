// lib/screens/client/booking/datetime/widgets/master_slot_card.dart

import 'package:flutter/material.dart';
import '../../../../../widgets/common/avatar_initials.dart';
import '../../../../../widgets/cached_image.dart';

class MasterSlotCard extends StatelessWidget {
  final Map<String, dynamic> master;
  final int masterId;
  final List<String> slots;
  final String? selectedTime;
  final int? selectedMasterId;
  final Color primaryColor;
  final void Function(int masterId, String time) onSelect;

  const MasterSlotCard({
    super.key,
    required this.master,
    required this.masterId,
    required this.slots,
    required this.selectedTime,
    required this.selectedMasterId,
    required this.primaryColor,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[200],
                ),
                child: master['avatar'] != null && master['avatar'].toString().isNotEmpty
                    ? ClipOval(
                        child: CachedAvatar(
                          url: master['avatar'].toString(),
                          size: 40,
                          radius: 20,
                        ),
                      )
                    : AvatarInitials(name: (master['name'] ?? '').toString(), size: 40),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      master['name'] ?? 'Специалист',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    if (master['position'] != null &&
                        master['position'].toString().isNotEmpty)
                      Text(
                        master['position'],
                        style: const TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: slots.map((time) {
              final selected =
                  selectedTime == time && selectedMasterId == masterId;
              return GestureDetector(
                onTap: () => onSelect(masterId, time),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFFDF2F5) : const Color(0xFFF8F8F8),
                    border: Border.all(
                      color: selected ? primaryColor : const Color(0xFFE0E0E0),
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    time,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: selected ? primaryColor : Colors.black,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
