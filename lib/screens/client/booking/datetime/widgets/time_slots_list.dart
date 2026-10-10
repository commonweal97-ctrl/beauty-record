// lib/screens/client/booking/datetime/widgets/time_slots_list.dart

import 'package:flutter/material.dart';
import '../datetime_controller.dart';
import 'master_slot_card.dart';

class TimeSlotsList extends StatelessWidget {
  final DateTimeController controller;
  final Color primaryColor;

  const TimeSlotsList({
    super.key,
    required this.controller,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    if (controller.loadingSlots) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.timeSlotsByMaster.isEmpty) {
      return const Center(
        child: Text(
          'Нет доступного времени',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    final widgets = <Widget>[];
    controller.timeSlotsByMaster.forEach((masterId, slots) {
      final master = controller.findMasterById(masterId);
      if (slots.isNotEmpty && master != null) {
        widgets.add(
          MasterSlotCard(
            master: master,
            masterId: masterId,
            slots: slots,
            selectedTime: controller.selectedTime,
            selectedMasterId: controller.selectedMasterId,
            primaryColor: primaryColor,
            onSelect: controller.selectTime,
          ),
        );
      }
    });

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const Text(
          'Доступное время',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black),
        ),
        const SizedBox(height: 12),
        ...widgets,
      ],
    );
  }
}
