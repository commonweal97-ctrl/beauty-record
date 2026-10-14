// lib/widgets/common/avatar_initials.dart
//
// Единая заглушка-аватар: буквы имени/фамилии в кружке.
// Используется везде, где нет фото (клиенты, мастера, чаты, отзывы).

import 'package:flutter/material.dart';

class AvatarInitials extends StatelessWidget {
  final String name;
  final double size;
  final double? radius; // null = круг
  final Color bgColor;
  final Color textColor;

  const AvatarInitials({
    super.key,
    required this.name,
    this.size = 48,
    this.radius,
    this.bgColor = const Color(0xFFF8F8F8),
    this.textColor = const Color(0xFFDD1847),
  });

  /// Извлекает initials из имени.
  /// «Иван Петров» → «ИП»
  /// «Иван» → «И»
  /// «?» → «?»
  static String initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == '?') return '?';
    final parts = trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final r = radius ?? size / 2;
    final text = initials(name);
    final fontSize = size * 0.4;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(r),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
