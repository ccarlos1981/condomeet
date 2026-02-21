import 'package:equatable/equatable.dart';

enum UserRole { admin, porter, resident }

class Profile extends Equatable {
  final String id;
  final String condominiumId;
  final String? fullName;
  final UserRole role;
  final String? avatarUrl;

  const Profile({
    required this.id,
    required this.condominiumId,
    this.fullName,
    required this.role,
    this.avatarUrl,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      condominiumId: json['condominium_id'] as String,
      fullName: json['full_name'] as String?,
      role: UserRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => UserRole.resident,
      ),
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'condominium_id': condominiumId,
      'full_name': fullName,
      'role': role.name,
      'avatar_url': avatarUrl,
    };
  }

  @override
  List<Object?> get props => [id, condominiumId, fullName, role, avatarUrl];
}
