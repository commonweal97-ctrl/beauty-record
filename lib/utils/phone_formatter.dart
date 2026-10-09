// lib/utils/phone_formatter.dart
class PhoneFormatter {
  static String clean(String phone) {
    return phone.replaceAll(RegExp(r'\D'), '');
  }
  
  static bool isValid(String phone, int maxDigits) {
    final digits = clean(phone);
    return digits.length == maxDigits;
  }
  
  static String normalizeForApi(String phone, String countryDial) {
    return '$countryDial${clean(phone)}';
  }
  
  static String formatRu(String digits) {
    String formatted = '';
    if (digits.isNotEmpty) formatted += digits.substring(0, digits.length > 3 ? 3 : digits.length);
    if (digits.length > 3) formatted += ' ${digits.substring(3, digits.length > 6 ? 6 : digits.length)}';
    if (digits.length > 6) formatted += ' ${digits.substring(6, digits.length > 8 ? 8 : digits.length)}';
    if (digits.length > 8) formatted += ' ${digits.substring(8)}';
    return formatted;
  }
}