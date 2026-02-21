import 'package:equatable/equatable.dart';

enum ConsentType { termsOfService, privacyPolicy }

class UserConsent extends Equatable {
  final String id;
  final String userId;
  final ConsentType consentType;
  final DateTime grantedAt;
  final DateTime? revokedAt;

  const UserConsent({
    required this.id,
    required this.userId,
    required this.consentType,
    required this.grantedAt,
    this.revokedAt,
  });

  bool get isActive => revokedAt == null;

  factory UserConsent.fromJson(Map<String, dynamic> json) {
    return UserConsent(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      consentType: _parseConsentType(json['consent_type'] as String),
      grantedAt: DateTime.parse(json['granted_at'] as String),
      revokedAt: json['revoked_at'] != null
          ? DateTime.parse(json['revoked_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'consent_type': _consentTypeToString(consentType),
      'granted_at': grantedAt.toIso8601String(),
      'revoked_at': revokedAt?.toIso8601String(),
    };
  }

  static ConsentType _parseConsentType(String value) {
    switch (value) {
      case 'terms_of_service':
        return ConsentType.termsOfService;
      case 'privacy_policy':
        return ConsentType.privacyPolicy;
      default:
        return ConsentType.termsOfService;
    }
  }

  static String _consentTypeToString(ConsentType type) {
    switch (type) {
      case ConsentType.termsOfService:
        return 'terms_of_service';
      case ConsentType.privacyPolicy:
        return 'privacy_policy';
    }
  }

  @override
  List<Object?> get props => [id, userId, consentType, grantedAt, revokedAt];
}
