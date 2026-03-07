import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object> get props => [];
}

class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

class AuthPhoneSubmitted extends AuthEvent {
  final String phoneNumber;
  const AuthPhoneSubmitted(this.phoneNumber);

  @override
  List<Object> get props => [phoneNumber];
}

class AuthOtpVerified extends AuthEvent {
  final String phoneNumber;
  final String otpCode;
  const AuthOtpVerified({required this.phoneNumber, required this.otpCode});

  @override
  List<Object> get props => [phoneNumber, otpCode];
}

class AuthPinSetupCompleted extends AuthEvent {
  final String pin;
  const AuthPinSetupCompleted(this.pin);

  @override
  List<Object> get props => [pin];
}

class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

class AuthPinUnlocked extends AuthEvent {
  const AuthPinUnlocked();
}


// Novos Eventos baseados nas telas de UI enviadas
class AuthLoginSubmitted extends AuthEvent {
  final String email;
  final String password;
  const AuthLoginSubmitted({required this.email, required this.password});

  @override
  List<Object> get props => [email, password];
}

class AuthResidentRegistrationSubmitted extends AuthEvent {
  final String email;
  final String password;
  final String condominioId;
  final String unidadeId;
  final String nomeCompleto;
  final String whatsapp;
  final String tipoMorador;
  final String papelSistema;
  final bool consentimentoWhatsapp;
  final String? blocoTxt;
  final String? aptoTxt;

  const AuthResidentRegistrationSubmitted({
    required this.email,
    required this.password,
    required this.condominioId,
    required this.unidadeId,
    required this.nomeCompleto,
    required this.whatsapp,
    required this.tipoMorador,
    required this.papelSistema,
    required this.consentimentoWhatsapp,
    this.blocoTxt,
    this.aptoTxt,
  });

  @override
  List<Object> get props => [email, password, condominioId, unidadeId, nomeCompleto, whatsapp, tipoMorador, papelSistema, consentimentoWhatsapp, if (blocoTxt != null) blocoTxt!, if (aptoTxt != null) aptoTxt!];
}

class AuthSindicoRegistrationSubmitted extends AuthEvent {
  final String email;
  final String password;
  final Map<String, dynamic> condominioData;
  final String nomeCompleto;
  final String whatsapp;

  const AuthSindicoRegistrationSubmitted({
    required this.email,
    required this.password,
    required this.condominioData,
    required this.nomeCompleto,
    required this.whatsapp,
  });

  @override
  List<Object> get props => [email, password, condominioData, nomeCompleto, whatsapp];
}
