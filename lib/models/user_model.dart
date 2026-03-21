class UserModel {
  final int? id;
  final String firstName;
  final String lastName;
  final String nic;
  final String mobile;
  // Address
  final String addressLine1;
  final String addressLine2;
  final String addressLine3;
  final String district;
  final String province;
  final String postalCode;
  // Account
  final String email;
  final String password;
  final DateTime? createdAt;

  UserModel({
    this.id,
    required this.firstName,
    required this.lastName,
    required this.nic,
    required this.mobile,
    required this.addressLine1,
    this.addressLine2 = '',
    this.addressLine3 = '',
    required this.district,
    required this.province,
    required this.postalCode,
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
      'mobile': mobile,
      'address_line1': addressLine1,
      'address_line2': addressLine2,
      'address_line3': addressLine3,
      'district': district,
      'province': province,
      'postal_code': postalCode,
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
      mobile: map['mobile'] as String? ?? '',
      addressLine1: map['address_line1'] as String? ?? '',
      addressLine2: map['address_line2'] as String? ?? '',
      addressLine3: map['address_line3'] as String? ?? '',
      district: map['district'] as String? ?? '',
      province: map['province'] as String? ?? '',
      postalCode: map['postal_code'] as String? ?? '',
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
    String? mobile,
    String? addressLine1,
    String? addressLine2,
    String? addressLine3,
    String? district,
    String? province,
    String? postalCode,
    String? email,
    String? password,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      nic: nic ?? this.nic,
      mobile: mobile ?? this.mobile,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      addressLine3: addressLine3 ?? this.addressLine3,
      district: district ?? this.district,
      province: province ?? this.province,
      postalCode: postalCode ?? this.postalCode,
      email: email ?? this.email,
      password: password ?? this.password,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get fullName => '$firstName $lastName';

  String get fullAddress {
    final parts = [
      addressLine1,
      addressLine2,
      addressLine3,
      district,
      province,
    ].where((p) => p.isNotEmpty).toList();
    return parts.join(', ');
  }

  @override
  String toString() =>
      'UserModel(id: $id, fullName: $fullName, nic: $nic, mobile: $mobile, email: $email)';
}
