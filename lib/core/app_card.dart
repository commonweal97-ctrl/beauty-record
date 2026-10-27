// lib/core/app_card.dart
//
// Единый стиль карточек в Apple-стиле:
//   - без обводки (Border.all), только мягкая тень;
//   - радиус 16, margin 8, padding 14;
//   - используется в услугах, сотрудниках, клиентах и т.д.

import 'package:flutter/material.dart';

class AppCard {
  static const double margin = 8;
  static const double padding = 14;
  static const double radius = 16;

  static List<BoxShadow> get shadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 14,
          offset: const Offset(0, 3),
        ),
      ];

  static BoxDecoration get decoration => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow,
      );

  /// Контейнер-карточка с единым стилем.
  static Widget wrap({required Widget child, EdgeInsets? padding}) {
    return Container(
      margin: const EdgeInsets.only(bottom: margin),
      padding: padding ?? const EdgeInsets.all(AppCard.padding),
      decoration: decoration,
      child: child,
    );
  }

  /// Поле ввода — без обводки, только фон + мягкая тень.
  static InputDecoration inputDecoration({
    String? hint,
    Widget? prefix,
    Widget? suffix,
    String? errorText,
  }) {
    return InputDecoration(
      hintText: hint,
      errorText: errorText,
      filled: true,
      fillColor: const Color(0xFFF8F8F8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDD1847), width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF44336))),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF44336), width: 1.5)),
      prefixIcon: prefix,
      suffixIcon: suffix,
    );
  }

  /// Стиль выбранного/невыбранного элемента (чип, карточка выбора).
  static BoxDecoration selectable({bool selected = false}) => BoxDecoration(
    color: selected ? const Color(0xFFFDF2F5) : Colors.white,
    borderRadius: BorderRadius.circular(14),
    boxShadow: [
      BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
    ],
    border: selected ? Border.all(color: const Color(0xFFDD1847), width: 1.5) : null,
  );
}
