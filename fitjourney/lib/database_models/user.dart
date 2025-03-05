class AppUser {
  final String userId;
  final String firstName;
  final String lastName;
  final double? heightCm;
  final DateTime? registrationDate;
  final DateTime? lastLogin;

  AppUser({
    required this.userId,
    required this.firstName,
    required this.lastName,
    this.heightCm,
    this.registrationDate,
    this.lastLogin,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      userId: map['user_id'],
      firstName: map['first_name'],
      lastName: map['last_name'],
      heightCm: map['height_cm'],
      registrationDate: map['registration_date'] != null
          ? DateTime.parse(map['registration_date'])
          : null,
      lastLogin: map['last_login'] != null
          ? DateTime.parse(map['last_login'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'first_name': firstName,
      'last_name': lastName,
      'height_cm': heightCm,
      'registration_date': registrationDate?.toIso8601String(),
      'last_login': lastLogin?.toIso8601String(),
    };
  }
}
