// lib/utils/api_errors.dart
//
// Парсер структурированных ошибок API:
//   { success: false, message: "...", errors: {field: "текст"} }
//
// Использование:
//   final errs = ApiErrors.fromResponse(result);
//   TextField(decoration: InputDecoration(
//     errorText: errs['first_name'],
//   ))

class ApiErrors {
  final String? message;
  final Map<String, String> fields;

  const ApiErrors({this.message, this.fields = const {}});

  factory ApiErrors.fromResponse(Map<String, dynamic> r) {
    final raw = r['errors'];
    final fields = <String, String>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        fields[k.toString()] = v.toString();
      });
    }
    return ApiErrors(
      message: r['message']?.toString(),
      fields: fields,
    );
  }

  bool get hasFields => fields.isNotEmpty;
  bool get isEmpty => message == null && fields.isEmpty;

  String? operator [](String key) => fields[key];

  @override
  String toString() => 'ApiErrors(message: $message, fields: $fields)';
}
