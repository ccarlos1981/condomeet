import 'package:condomeet/core/errors/result.dart';

class Resident {
  final String id;
  final String fullName;
  final String? unitNumber;
  final String? block;
  final String? avatarUrl;
  final String? unitId;
  final bool isUnitBlocked;
  final String? phoneNumber;
  final String status; // 'pendente', 'aprovado', 'rejeitado'
  // Extra fields for the approval panel
  final String? email;
  final String? tipoMorador;
  final String? papelSistema;
  final DateTime? createdAt;

  Resident({
    required this.id,
    required this.fullName,
    this.unitNumber,
    this.block,
    this.avatarUrl,
    this.unitId,
    this.isUnitBlocked = false,
    this.phoneNumber,
    this.status = 'active',
    this.email,
    this.tipoMorador,
    this.papelSistema,
    this.createdAt,
  });

  factory Resident.fromMap(Map<String, dynamic> map) {
    return Resident(
      id: map['id'] as String,
      fullName: map['nome_completo'] as String? ?? map['full_name'] as String? ?? 'Desconhecido',
      unitNumber: (map['apto_txt'] ?? map['unit_number'] ?? map['numero'])?.toString(),
      block: (map['bloco_txt'] ?? map['block'] ?? map['nome_ou_numero'])?.toString(),
      avatarUrl: map['avatar_url'] as String?,
      unitId: map['unit_id'] as String? ?? map['unidade_id'] as String?,
      isUnitBlocked: (map['bloqueada'] == true || map['bloqueada'] == 1 || map['is_blocked'] == true || map['is_blocked'] == 1),
      phoneNumber: map['whatsapp'] as String? ?? map['phone'] as String? ?? map['phone_number'] as String?,
      status: map['status_aprovacao'] as String? ?? map['status'] as String? ?? 'active',
      email: map['email'] as String?,
      tipoMorador: map['tipo_morador'] as String?,
      papelSistema: map['papel_sistema'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
    );
  }
}

abstract class ResidentRepository {
  /// Searches for residents in the local database matching the query (name or unit).
  Future<Result<List<Resident>>> searchResidents(String query, String condominiumId);

  /// Requests self-registration for a new resident.
  Future<Result<void>> requestSelfRegistration({
    required String name,
    required String block,
    required String unit,
    String? photoPath,
    String? condominiumId,
  });

  /// Fetches residents awaiting approval for a specific condominium.
  Future<Result<List<Resident>>> getPendingResidents(String condominiumId);

  /// Fetches ALL residents for a condominium (any status).
  Future<Result<List<Resident>>> getAllResidents(String condominiumId);

  /// Approves a pending resident.
  Future<Result<void>> approveResident(String residentId);

  /// Rejects/Deletes a pending resident request.
  Future<Result<void>> rejectResident(String residentId);

  /// Blocks an approved resident (sets status to 'bloqueado').
  Future<Result<void>> blockResident(String residentId);

  /// Unblocks a resident (sets status back to 'aprovado').
  Future<Result<void>> unblockResident(String residentId);
}
