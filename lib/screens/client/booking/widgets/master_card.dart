import 'package:flutter/material.dart';
import '../../../../widgets/cached_image.dart';

class MasterCard extends StatelessWidget {
  final Map<String, dynamic> master;
  final Map<String, dynamic>? stats;
  final Color primaryColor;
  final Color buttonBg;
  final Color buttonText;
  final VoidCallback onBook;
  final VoidCallback onTap;
  
  const MasterCard({
    super.key,
    required this.master,
    this.stats,
    required this.primaryColor,
    required this.buttonBg,
    required this.buttonText,
    required this.onBook,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ratingRaw = stats?['avg_rating'];
    final rating = ratingRaw is num ? ratingRaw.toDouble() : (double.tryParse(ratingRaw?.toString() ?? '') ?? 0.0);
    final reviewsRaw = stats?['total'];
    final reviewsCount = reviewsRaw is num ? reviewsRaw.toInt() : (int.tryParse(reviewsRaw?.toString() ?? '') ?? 0);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[200],
              ),
              child: master['avatar'] != null && master['avatar'].toString().isNotEmpty
                  ? ClipOval(child: CachedAvatar(url: master['avatar'], size: 80, radius: 40))
                  : Icon(Icons.person, size: 40, color: Colors.grey[400]),
            ),
            const SizedBox(height: 10),
            Text(master['name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
            if (master['position'] != null && master['position'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(master['position'], style: const TextStyle(fontSize: 12, color: Color(0xFF888)), textAlign: TextAlign.center),
              ),
            const SizedBox(height: 8),
            Text('★ $rating · $reviewsCount', style: const TextStyle(fontSize: 12, color: Color(0xFFF5A623))),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onBook,
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonBg,
                  foregroundColor: buttonText,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Записаться', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}