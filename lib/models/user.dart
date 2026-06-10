class User {
  final int id;
  final String name;
  final String email;
  final String paymentMethod;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.paymentMethod,
  });

  /// Convert User object to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'payment_method': paymentMethod,
    };
  }

  /// Create User object from Map (database result)
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int,
      name: map['name'] as String,
      email: map['email'] as String,
      paymentMethod: map['payment_method'] as String,
    );
  }

  /// Create a copy of User with optional field updates
  User copyWith({
    int? id,
    String? name,
    String? email,
    String? paymentMethod,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }

  @override
  String toString() {
    return 'User{id: $id, name: $name, email: $email, paymentMethod: $paymentMethod}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is User &&
        other.id == id &&
        other.name == name &&
        other.email == email &&
        other.paymentMethod == paymentMethod;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        email.hashCode ^
        paymentMethod.hashCode;
  }
}
