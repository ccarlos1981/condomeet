import 'package:equatable/equatable.dart';

enum AuthStatus { 
  unknown, 
  authenticated, 
  unauthenticated, 
  authenticating, 
  otpSent, 
  pendingPinSetup, 
  pendingConsent,
  needsRegistration,
  pendingApproval,
  rejected,
  locked,
  needsPasswordSetup,  // moradores migrados precisam definir senha
  forgotPasswordCodeSent, // código enviado via WhatsApp
}

class AuthState extends Equatable {
  final AuthStatus status;
  final String? phoneNumber;
  final String? errorMessage;
  final String? userId;
  final String? condominiumId;
  final String? role;
  final String? userName;
  final String? tipoEstrutura;
  final String? unitId;
  final bool isUnitBlocked;
  final String? profileStatus; // 'active', 'pending', 'rejected'
  final bool isUnlocked;
  final String? maskedWhatsapp; // WhatsApp mascarado para tela de reset

  const AuthState({
    this.status = AuthStatus.unknown,
    this.phoneNumber,
    this.errorMessage,
    this.userId,
    this.condominiumId,
    this.role,
    this.userName,
    this.tipoEstrutura,
    this.unitId,
    this.isUnitBlocked = false,
    this.profileStatus,
    this.isUnlocked = false,
    this.maskedWhatsapp,
  });

  const AuthState.unknown() : this();
  
  const AuthState.authenticated({
    String? userId,
    String? condominiumId,
    String? role,
    String? userName,
    String? tipoEstrutura,
    String? unitId,
    bool isUnitBlocked = false,
    String? profileStatus,
  }) : this(
          status: AuthStatus.authenticated,
          userId: userId,
          condominiumId: condominiumId,
          role: role,
          userName: userName,
          tipoEstrutura: tipoEstrutura,
          unitId: unitId,
          isUnitBlocked: isUnitBlocked,
          profileStatus: profileStatus,
          isUnlocked: true,
        );

  const AuthState.unauthenticated({String? error}) : this(status: AuthStatus.unauthenticated, errorMessage: error);
  const AuthState.otpSent(String phone) : this(status: AuthStatus.otpSent, phoneNumber: phone);
  const AuthState.pendingPinSetup({String? userId, String? userName, String? condominiumId, String? role}) 
    : this(status: AuthStatus.pendingPinSetup, userId: userId, userName: userName, condominiumId: condominiumId, role: role);

  const AuthState.pendingConsent({String? userId, String? userName}) 
    : this(status: AuthStatus.pendingConsent, userId: userId, userName: userName);

  const AuthState.needsRegistration() : this(status: AuthStatus.needsRegistration);
  
  const AuthState.pendingApproval({String? userId, String? userName, String? condominiumId, String? role}) 
    : this(status: AuthStatus.pendingApproval, userId: userId, userName: userName, condominiumId: condominiumId, role: role);

  /// Morador migrado — precisa definir senha. [phoneNumber] carrega o email temporariamente.
  const AuthState.needsPasswordSetup({required String email})
    : this(status: AuthStatus.needsPasswordSetup, phoneNumber: email);

  /// Código de reset de senha enviado via WhatsApp
  const AuthState.forgotPasswordCodeSent({required String email, String? maskedWhatsapp})
    : this(status: AuthStatus.forgotPasswordCodeSent, phoneNumber: email, maskedWhatsapp: maskedWhatsapp);

  @override
  List<Object?> get props => [status, phoneNumber, errorMessage, userId, condominiumId, role, userName, tipoEstrutura, unitId, isUnitBlocked, profileStatus, isUnlocked, maskedWhatsapp];

  AuthState copyWith({
    AuthStatus? status,
    String? phoneNumber,
    String? errorMessage,
    String? userId,
    String? condominiumId,
    String? role,
    String? userName,
    String? tipoEstrutura,
    String? unitId,
    bool? isUnitBlocked,
    String? profileStatus,
    bool? isUnlocked,
    String? maskedWhatsapp,
  }) {
    return AuthState(
      status: status ?? this.status,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      errorMessage: errorMessage ?? this.errorMessage,
      userId: userId ?? this.userId,
      condominiumId: condominiumId ?? this.condominiumId,
      role: role ?? this.role,
      userName: userName ?? this.userName,
      tipoEstrutura: tipoEstrutura ?? this.tipoEstrutura,
      unitId: unitId ?? this.unitId,
      isUnitBlocked: isUnitBlocked ?? this.isUnitBlocked,
      profileStatus: profileStatus ?? this.profileStatus,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      maskedWhatsapp: maskedWhatsapp ?? this.maskedWhatsapp,
    );
  }
}
