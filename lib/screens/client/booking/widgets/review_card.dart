// lib/screens/client/booking/widgets/review_card.dart
import 'package:flutter/material.dart';

class ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;
  final Color primaryColor;
  
  const ReviewCard({super.key, required this.review, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    final ratingRaw = review['rating'];
    final rating = ratingRaw is num ? ratingRaw.toDouble() : (double.tryParse(ratingRaw?.toString() ?? '') ?? 0.0);
    final clientName = review['client_name']?.toString() ?? 'Анонимно';
    final dateStr = review['created_at']?.toString() ?? '';
    final comment = review['comment']?.toString() ?? '';
    final employeeName = review['employee_name']?.toString() ?? '';
    final isAnonymous = review['is_anonymous'] == true || review['is_anonymous'] == 1;
    
    String displayName = clientName;
    if (!isAnonymous && displayName.isNotEmpty && displayName != 'Анонимно') {
      final parts = displayName.split(' ');
      if (parts.length > 1) {
        displayName = '${parts[0]} ${parts[1].substring(0, 1)}.';
      }
    }
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        ...List.generate(5, (i) => Icon(
                          i < rating.round() ? Icons.star : Icons.star_border,
                          size: 16,
                          color: i < rating.round() ? const Color(0xFFF5A623) : const Color(0xFFE5E7EB),
                        )),
                        const SizedBox(width: 8),
                        Text(
                          dateStr,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0x000ff999),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              if (employeeName.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person,
                        size: 14,
                        color: primaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        employeeName,
                        style: TextStyle(
                          fontSize: 13,
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              comment,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}