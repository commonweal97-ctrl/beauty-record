// lib/models/user.dart
//
// Модель пользователя Б-Записи.

class User {
  final int id;
  final String email;
  final String phone;
  final bool hasPin;
  final String? role; // 'client' | 'salon_owner' | null

  const User({
    required this.id,
    this.email = '',
    this.phone = '',
    this.hasPin = false,
    this.role,
  });

  User copyWith({
    int? id,
    String? email,
    String? phone,
    bool? hasPin,
    String? role,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      hasPin: hasPin ?? this.hasPin,
      role: role ?? this.role,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User &&
        other.id == id &&
        other.email == email &&
        other.phone == phone &&
        other.hasPin == hasPin &&
        other.role == role;
  }

  @override
  int get hashCode => Object.hash(id, email, phone, hasPin, role);

  @override
  String toString() =>
      'User(id: $id, email: $email, phone: $phone, hasPin: $hasPin, role: $role)';
}
