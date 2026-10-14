import 'package:flutter/material.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/common/avatar_initials.dart';

class ServiceDetailModal extends StatefulWidget {
  final Map<String, dynamic> service;
  final List<Map<String, dynamic>> employees;
  final List<Map<String, dynamic>> employeeServiceLinks;
  final Color primaryColor;
  
  const ServiceDetailModal({
    super.key,
    required this.service,
    required this.employees,
    required this.employeeServiceLinks,
    required this.primaryColor,
  });

  @override
  State<ServiceDetailModal> createState() => _ServiceDetailModalState();
}

class _ServiceDetailModalState extends State<ServiceDetailModal> {
  List<Map<String, dynamic>> get _serviceMasters {
    final masterIds = widget.employeeServiceLinks
        .where((l) => (l['service_id'] as num).toInt() == (widget.service['id'] as num).toInt())
        .map((l) => (l['employee_id'] as num).toInt())
        .toList();
    
    return widget.employees.where((e) => masterIds.contains((e['id'] as num).toInt())).toList();
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
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final masters = _serviceMasters;
    final duration = (service['duration'] as num?)?.toInt() ?? 0;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            // Хедер
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: widget.primaryColor,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Услуга',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Фото услуги
                  if (service['photo_url'] != null && service['photo_url'].toString().isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AspectRatio(
                        aspectRatio: 4/3,
                        child: CachedAvatar(url: service['photo_url'], size: double.infinity, radius: 0),
                      ),
                    ),
                  
                  const SizedBox(height: 16),
                  
                  // Название и цена
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(service['name'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                        if (service['category'] != null && service['category'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(service['category'], style: TextStyle(fontSize: 14, color: widget.primaryColor, fontWeight: FontWeight.w500)),
                          ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text(_formatPrice(service), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                            if (duration > 0) ...[
                              const SizedBox(width: 16),
                              Container(width: 1, height: 40, color: const Color(0xFFE0E0E0)),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Длительность', style: TextStyle(fontSize: 13, color: Color(0x000ff888))),
                                  Text(_formatDuration(duration), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Описание
                  if (service['description'] != null && service['description'].toString().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Описание услуги', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          Text(service['description'], style: const TextStyle(fontSize: 14, color: Color(0x000ff555), height: 1.6)),
                        ],
                      ),
                    ),
                  ],
                  
                  // Специалисты
                  const SizedBox(height: 20),
                  const Text('Специалисты', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  
                  if (masters.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('Нет доступных специалистов', style: TextStyle(color: Color(0x000ff999))),
                    )
                  else
                    ...masters.map((master) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE8E8E8)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 56, height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey[200],
                            ),
                            child: master['avatar'] != null && master['avatar'].toString().isNotEmpty
                                ? ClipOval(child: CachedAvatar(url: master['avatar'], size: 56, radius: 28))
                                : AvatarInitials(name: (master['name'] ?? '').toString(), size: 56),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(master['name'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                if (master['position'] != null && master['position'].toString().isNotEmpty)
                                  Text(master['position'], style: const TextStyle(fontSize: 13, color: Color(0x000ff888))),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              // Открыть запись с этим мастером
                              Navigator.pop(context, master);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.primaryColor,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Записаться', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                          ),
                        ],
                      ),
                    )),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}