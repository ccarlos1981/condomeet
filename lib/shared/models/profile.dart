import 'package:equatable/equatable.dart';

enum UserRole { admin, porter, resident }

class Profile extends Equatable {
  final String id;
  final String condominiumId;
  final String? fullName;
  final String? unitNumber;
  final String? block;
  final UserRole role;
  final String? avatar_url;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  const Profile({
    required this.id,
    required this.condominiumId,
    this.fullName,
    this.unitNumber,
    this.block,
    required this.role,
    this.avatar_url,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      condominiumId: (json['condominio_id'] ?? json['condominium_id']) as String,
      fullName: json['full_name'] as String?,
      unitNumber: json['unit_number'] as String?,
      block: json['block'] as String?,
      role: _parseRole(json['role'] as String?),
      avatar_url: json['avatar_url'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      deletedAt: json['deleted_at'] != null ? DateTime.parse(json['deleted_at'] as String) : null,
    );
  }

  static UserRole _parseRole(String? role) {
    final cleanRole = role?.trim().toLowerCase();
    return UserRole.values.firstWhere(
      (e) => e.name == cleanRole,
      orElse: () => UserRole.resident,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'condominium_id': condominiumId,
      'full_name': fullName,
      'unit_number': unitNumber,
      'block': block,
      'role': role.name,
      'avatar_url': avatar_url,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, condominiumId, fullName, unitNumber, block, role, avatar_url, createdAt, updatedAt, deletedAt];
}
