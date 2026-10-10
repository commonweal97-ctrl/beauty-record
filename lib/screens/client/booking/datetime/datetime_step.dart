// lib/screens/client/booking/datetime/datetime_step.dart
//
// UI-компонент шага "Дата и время".
//
// Использует DateTimeController для всей логики.
// Никаких Navigator.pop — вместо этого onBack и onSelected.

import 'package:flutter/material.dart';

import 'datetime_controller.dart';
import 'widgets/date_selector.dart';
import 'widgets/time_slots_list.dart';
import 'widgets/datetime_bottom_bar.dart';

class DateTimeStep extends StatefulWidget {
  final int projectId;
  final List<Map<String, dynamic>> selectedServices;
  final Map<String, dynamic>? selectedMaster;
  final Map<int, int> serviceMasters;
  final List<Map<String, dynamic>> employees;
  final Color primaryColor;
  final Color buttonBg;
  final Color buttonText;
  final String specialistLabel;
  final String serviceLabel;
  final VoidCallback onBack;
  final void Function(DateTime date, String time, int? masterId) onSelected;

  const DateTimeStep({
    super.key,
    required this.projectId,
    required this.selectedServices,
    this.selectedMaster,
    required this.serviceMasters,
    required this.employees,
    required this.primaryColor,
    required this.buttonBg,
    required this.buttonText,
    this.specialistLabel = 'Специалисты',
    this.serviceLabel = 'Услуги',
    required this.onBack,
    required this.onSelected,
  });

  @override
  State<DateTimeStep> createState() => _DateTimeStepState();
}

class _DateTimeStepState extends State<DateTimeStep> {
  late final DateTimeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DateTimeController(
      projectId: widget.projectId,
      selectedServices: widget.selectedServices,
      selectedMaster: widget.selectedMaster,
      serviceMasters: widget.serviceMasters,
      employees: widget.employees,
    );
    _controller.addListener(_onControllerUpdate);
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  void _handleContinue() {
    final date = _controller.selectedDate;
    final time = _controller.selectedTime;
    if (date == null || time == null) return;
    widget.onSelected(date, time, _controller.selectedMasterId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
          DateTimeBottomBar(
            totalPrice: widget.selectedServices.fold(
              0, (sum, s) => sum + ((s['price'] as num?)?.toInt() ?? 0),
            ),
            totalDuration: widget.selectedServices.fold(
              0, (sum, s) => sum + ((s['duration'] as num?)?.toInt() ?? 0),
            ),
            serviceCount: widget.selectedServices.length,
            canContinue: _controller.canContinue,
            buttonBg: widget.buttonBg,
            buttonText: widget.buttonText,
            onContinue: _handleContinue,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: widget.primaryColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: widget.onBack,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Дата и время',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Выберите дату',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              if (_controller.loadingDates)
                const Center(child: CircularProgressIndicator())
              else if (_controller.availableDates.isEmpty)
                const Text(
                  'Нет доступных дат',
                  style: TextStyle(color: Colors.black54),
                )
              else
                DateSelector(
                  controller: _controller,
                  primaryColor: widget.primaryColor,
                ),
            ],
          ),
        ),
        Expanded(
          child: TimeSlotsList(
            controller: _controller,
            primaryColor: widget.primaryColor,
          ),
        ),
      ],
    );
  }
}
