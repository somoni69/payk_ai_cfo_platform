class UserProfile {
  final String id;
  final String fullName;
  final String username;
  final String? email;
  final String? phone;
  final String role;
  final bool active;
  final bool twoFactor;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    required this.fullName,
    required this.username,
    this.email,
    this.phone,
    required this.role,
    required this.active,
    required this.twoFactor,
    required this.createdAt,
  });
}
