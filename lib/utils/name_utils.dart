// lib/utils/name_utils.dart
//
// Единый источник имени сотрудника/клиента из map.
// Убирает дублирование в schedule_view, month_view, journal.

/// Полное имя: `name` → `first_name last_name` → `'Сотрудник'`.
String extractName(Map<String, dynamic> e) {
  final name = e['name']?.toString() ?? '';
  final first = e['first_name']?.toString() ?? '';
  final last = e['last_name']?.toString() ?? '';
  if (name.isNotEmpty) return name;
  if (first.isNotEmpty || last.isNotEmpty) return '$first $last'.trim();
  return 'Сотрудник';
}

/// Короткое имя: `Иван П.` (для узких ячеек).
String extractShortName(Map<String, dynamic> e) {
  final full = extractName(e);
  if (full == 'Сотрудник') return full;
  final parts = full.split(' ').where((w) => w.isNotEmpty).toList();
  if (parts.isEmpty) return full;
  if (parts.length == 1) return parts[0];
  return '${parts[0]} ${parts[1][0]}.';
}
