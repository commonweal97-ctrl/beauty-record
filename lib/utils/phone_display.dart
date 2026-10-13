// lib/utils/phone_display.dart
//
// Красивое отображение телефона: 🇷🇺 +7 (920) 854-81-51

String formatPhoneDisplay(String raw) {
  if (raw.isEmpty) return '';
  final digits = raw.replaceAll(RegExp(r'[^\d]'), '');
  if (digits.isEmpty) return raw;

  // RU/KZ: 7XXXXXXXXXX (11 цифр)
  if (digits.startsWith('7') && digits.length == 11) {
    final d = digits.substring(1);
    // KZ: 7 7XX XXX XX XX
    if (digits[1] == '7') {
      return '🇰🇿 +7 (${d.substring(0, 3)}) ${d.substring(3, 6)}-${d.substring(6, 8)}-${d.substring(8, 10)}';
    }
    return '🇷🇺 +7 (${d.substring(0, 3)}) ${d.substring(3, 6)}-${d.substring(6, 8)}-${d.substring(8, 10)}';
  }

  // BY: 375XXXXXXXXX (12 цифр)
  if (digits.startsWith('375') && digits.length == 12) {
    final d = digits.substring(3);
    return '🇧🇾 +375 (${d.substring(0, 2)}) ${d.substring(2, 5)}-${d.substring(5, 7)}-${d.substring(7, 9)}';
  }

  // UA: 380XXXXXXXXX (12 цифр)
  if (digits.startsWith('380') && digits.length == 12) {
    final d = digits.substring(3);
    return '🇺🇦 +380 (${d.substring(0, 2)}) ${d.substring(2, 5)}-${d.substring(5, 7)}-${d.substring(7, 9)}';
  }

  return raw;
}
