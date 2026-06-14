class User {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? virtualNumber;
  final String? token;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.virtualNumber,
    this.token,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      virtualNumber: json['virtual_number'],
      token: json['token'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'virtual_number': virtualNumber,
    };
  }
}
