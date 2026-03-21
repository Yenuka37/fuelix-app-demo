class UserModel {
  final int? id;
  final String firstName;
  final String lastName;
  final String nic;
  final String email;
  final String password;
  final DateTime? createdAt;

  UserModel({
    this.id,
    required this.firstName,
    required this.lastName,
    required this.nic,
    required this.email,
    required this.password,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'nic': nic,
      'email': email,
      'password': password,
      'created_at':
          createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as int?,
      firstName: map['first_name'] as String,
      lastName: map['last_name'] as String,
      nic: map['nic'] as String,
      email: map['email'] as String,
      password: map['password'] as String,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
    );
  }

  UserModel copyWith({
    int? id,
    String? firstName,
    String? lastName,
    String? nic,
    String? email,
    String? password,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      nic: nic ?? this.nic,
      email: email ?? this.email,
      password: password ?? this.password,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get fullName => '$firstName $lastName';

  @override
  String toString() {
    return 'UserModel(id: $id, fullName: $fullName, nic: $nic, email: $email)';
  }
}
