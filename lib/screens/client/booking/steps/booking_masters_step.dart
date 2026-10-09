// lib/screens/client/booking/steps/booking_masters_step.dart
import 'package:flutter/material.dart';
import '../../../../widgets/cached_image.dart';

class BookingMastersStep extends StatefulWidget {
  final List<Map<String, dynamic>> employees;
  final Color primaryColor;
  final String specialistLabelGenitive;
  final Function(Map<String, dynamic>) onSelectMaster;
  
  const BookingMastersStep({
    super.key,
    required this.employees,
    required this.primaryColor,
    required this.specialistLabelGenitive,
    required this.onSelectMaster,
  });

  @override
  State<BookingMastersStep> createState() => _BookingMastersStepState();
}

class _BookingMastersStepState extends State<BookingMastersStep> {
  String _searchQuery = '';
  
  List<Map<String, dynamic>> get _filteredMasters {
    if (_searchQuery.isEmpty) return widget.employees;
    
    return widget.employees.where((m) =>
        (m['name']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
        (m['position']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
      ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredMasters = _filteredMasters;
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Поиск ${widget.specialistLabelGenitive}...',
              hintStyle: const TextStyle(color: Colors.black45),
              prefixIcon: const Icon(Icons.search, color: Colors.black45),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
            ),
          ),
        ),
        Expanded(
          child: filteredMasters.isEmpty
              ? const Center(child: Text('Нет доступных специалистов', style: TextStyle(color: Colors.black54)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredMasters.length,
                  itemBuilder: (_, i) {
                    final m = filteredMasters[i];
                    return _buildMasterCard(m);
                  },
                ),
        ),
      ],
    );
  }
  
  Widget _buildMasterCard(Map<String, dynamic> m) {
    return GestureDetector(
      onTap: () => widget.onSelectMaster(m),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE8E8E8), width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[200],
              ),
              child: m['avatar'] != null && m['avatar'].toString().isNotEmpty
                  ? ClipOval(child: CachedAvatar(url: m['avatar'], size: 56, radius: 28))
                  : Icon(Icons.person, size: 28, color: Colors.grey[400]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m['name'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black)),
                  if (m['position'] != null && m['position'].toString().isNotEmpty)
                    Text(m['position'], style: const TextStyle(fontSize: 13, color: Colors.black54)),
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