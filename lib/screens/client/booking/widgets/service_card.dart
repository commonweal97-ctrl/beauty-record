// lib/screens/client/booking/widgets/service_card.dart
import 'package:flutter/material.dart';
import '../../../../widgets/cached_image.dart';

class ServiceCard extends StatelessWidget {
  final Map<String, dynamic> service;
  final Color primaryColor;
  final VoidCallback onTap;
  
  const ServiceCard({
    super.key,
    required this.service,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final priceRaw = service['price'];
    final price = priceRaw is int ? priceRaw : (priceRaw is double ? priceRaw.toInt() : (int.tryParse(priceRaw?.toString() ?? '') ?? 0));
    
    final durationRaw = service['duration'];
    final duration = durationRaw is int ? durationRaw : (durationRaw is double ? durationRaw.toInt() : (int.tryParse(durationRaw?.toString() ?? '') ?? 0));
    
    final priceFrom = service['price_from'] == true || service['price_from'] == 1 || service['price_from'] == '1';
    
    String durationStr = '';
    if (duration > 0) {
      final hours = duration ~/ 60;
      final minutes = duration % 60;
      if (hours > 0 && minutes > 0) {
        durationStr = '$hours ч $minutes мин';
      } else if (hours > 0) {
        durationStr = '$hours ч';
      } else {
        durationStr = '$minutes мин';
      }
    }
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Изображение
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
              ),
              child: service['photo_url'] != null && service['photo_url'].toString().isNotEmpty
                  ? CachedAvatar(
                      url: service['photo_url'],
                      size: 280,
                      radius: 0,
                    )
                  : Icon(
                      Icons.spa,
                      color: Colors.grey[400],
                      size: 48,
                    ),
            ),
            
            // Контент
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Название
                  Text(
                    service['name']?.toString() ?? '',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  // Категория
                  if (service['category'] != null && service['category'].toString().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        service['category'].toString(),
                        style: TextStyle(
                          fontSize: 10,
                          color: primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 10),
                  
                  // Цена и длительность
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Цена
                      Expanded(
                        child: Text(
                          price > 0 ? '${priceFrom ? 'от ' : ''}$price ₽' : 'Бесплатно',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A1A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      
                      // Длительность
                      if (durationStr.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.schedule,
                                size: 11,
                                color: Colors.black,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                durationStr,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}