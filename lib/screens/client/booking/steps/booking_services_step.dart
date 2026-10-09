// lib/screens/client/booking/steps/booking_services_step.dart
import 'package:flutter/material.dart';
import '../../../../widgets/cached_image.dart';

class BookingServicesStep extends StatefulWidget {
  final List<Map<String, dynamic>> services;
  final List<Map<String, dynamic>> selectedServices;
  final List<String> activeCategories;
  final String searchQuery;
  final Color primaryColor;
  final String serviceLabelGenitive;
  final Function(Map<String, dynamic>) onToggleService;
  final Function(String) onSearchChanged;
  final Function(String) onCategoryToggle;
  
  const BookingServicesStep({
    super.key,
    required this.services,
    required this.selectedServices,
    required this.activeCategories,
    required this.searchQuery,
    required this.primaryColor,
    required this.serviceLabelGenitive,
    required this.onToggleService,
    required this.onSearchChanged,
    required this.onCategoryToggle,
  });

  @override
  State<BookingServicesStep> createState() => _BookingServicesStepState();
}

class _BookingServicesStepState extends State<BookingServicesStep> {
  String _searchQuery = '';
  final List<String> _activeCategories = [];
  
  List<Map<String, dynamic>> get _filteredServices {
    var filtered = widget.services;
    
    if (_searchQuery.isNotEmpty) {
      filtered = widget.services.where((s) =>
          (s['name']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          (s['category']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
        ).toList();
    }
    
    if (_activeCategories.isNotEmpty) {
      filtered = filtered.where((s) =>
          _activeCategories.contains(s['category']?.toString() ?? 'Без категории')
        ).toList();
    }
    
    return filtered;
  }
  
  List<String> get _categories {
    final categories = <String>[];
    for (var s in widget.services) {
      final cat = s['category']?.toString() ?? 'Без категории';
      if (!categories.contains(cat)) categories.add(cat);
    }
    return categories;
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
    final filteredServices = _filteredServices;
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Поиск ${widget.serviceLabelGenitive}...',
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
        if (_categories.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (_, i) {
                final cat = _categories[i];
                final active = _activeCategories.contains(cat);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          if (active) {
                            _activeCategories.remove(cat);
                          } else {
                            _activeCategories.add(cat);
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: active ? widget.primaryColor : Colors.white,
                          border: Border.all(
                            color: active ? widget.primaryColor : const Color(0xFFE0E0E0),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: active ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        Expanded(
          child: filteredServices.isEmpty
              ? const Center(child: Text('Нет доступных услуг', style: TextStyle(color: Colors.black54)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredServices.length,
                  itemBuilder: (_, i) {
                    final s = filteredServices[i];
                    final selected = widget.selectedServices.any((ss) => ss['id'] == s['id']);
                    return _buildServiceCard(s, selected);
                  },
                ),
        ),
      ],
    );
  }
  
  Widget _buildServiceCard(Map<String, dynamic> s, bool selected) {
    return GestureDetector(
      onTap: () => widget.onToggleService(s),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFDF2F5) : Colors.white,
          border: Border.all(
            color: selected ? widget.primaryColor : const Color(0xFFE8E8E8),
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
                      border: Border.all(color: selected ? widget.primaryColor : Colors.white, width: 2),
                      color: selected ? widget.primaryColor : Colors.black.withValues(alpha: 0.3),
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