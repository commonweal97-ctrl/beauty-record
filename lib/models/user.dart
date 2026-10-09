// lib/models/user.dart
//
// Модель пользователя Б-Записи.

class User {
  final int id;
  final String email;
  final bool hasPin;
  final String? role; // 'client' | 'business' | null

  const User({
    required this.id,
    this.email = '',
    this.hasPin = false,
    this.role,
  });

  User copyWith({
    int? id,
    String? email,
    bool? hasPin,
    String? role,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
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
        other.hasPin == hasPin &&
        other.role == role;
  }

  @override
  int get hashCode => Object.hash(id, email, hasPin, role);

  @override
  String toString() =>
      'User(id: $id, email: $email, hasPin: $hasPin, role: $role)';
}
