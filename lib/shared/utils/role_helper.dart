import 'package:condomeet/features/auth/presentation/bloc/auth_state.dart';

/// Remove acentos e caracteres especiais para comparação canônica segura.
String _normalizeRole(String? input) {
  if (input == null) return '';
  const withAccents    = 'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ';
  const withoutAccents = 'aaaaaeeeeiiiioooooouuuucnAAAAEEEEIIIIOOOOOUUUUCN';
  var result = input.trim().toLowerCase();
  for (var i = 0; i < withAccents.length; i++) {
    result = result.replaceAll(withAccents[i], withoutAccents[i]);
  }
  return result;
}

/// Valida de forma canônica se um papel (papel_sistema) possui privilégios administrativos no condomínio.
///
/// Papéis com acesso administrativo:
/// - Admin: 'Admin', 'admin', 'ADMIN', 'administrador', 'administradora'
/// - Síndico: 'síndico', 'sindico', 'síndico (a)', 'sindico (a)', 'síndico(a)', 'sindico(a)', 'syndic'
/// - Subsíndico: 'subsíndico', 'subsindico', 'subsíndico (a)', 'subsindico (a)', 'sub_sindico', 'sub sindico'
///
/// Rejeita expressamente:
/// - Morador, Inquilino, Locatário, Proprietário, Visitante, Porteiro, Portaria, Zelador, Funcionário, null, vazios.
bool isAdministrativeRole(String? role) {
  if (role == null) return false;
  final r = _normalizeRole(role);
  if (r.isEmpty) return false;

  // Papéis não-administrativos explícitos (bloqueio preventivo)
  if (r.startsWith('morador') ||
      r.startsWith('inquilino') ||
      r.startsWith('locat') ||
      r.startsWith('propriet') ||
      r.startsWith('visit') ||
      r.startsWith('porteir') ||
      r.startsWith('portaria') ||
      r.startsWith('zelador') ||
      r.startsWith('limpeza') ||
      r.startsWith('funcionario') ||
      r.startsWith('terceirizado') ||
      r.startsWith('afiliado') ||
      r.startsWith('servico')) {
    return false;
  }

  // Whitelist canônica de papéis administrativos
  if (r == 'admin' ||
      r == 'administrador' ||
      r == 'administradora' ||
      r == 'superadmin' ||
      r == 'super_admin' ||
      r == 'master' ||
      r == 'syndic') {
    return true;
  }

  // Tratamento controlado de variações de síndico e subsíndico
  if (r.contains('sindico') || r.contains('subsindico')) {
    return true;
  }

  return false;
}

/// Valida se um papel possui privilégio Master / SuperAdmin global.
/// Nota institucional: Administradores de condomínio ('Admin') NÃO são Master globais.
bool isMasterRole(String? role) {
  if (role == null) return false;
  final r = _normalizeRole(role);
  return r == 'superadmin' || r == 'super_admin' || r == 'master';
}

/// Retorna o rótulo visual oficial para exibição na interface do Mobile.
/// Ex: 'Admin' -> 'Administrador', 'Síndico' -> 'Síndico'
String formatRoleName(String? role) {
  if (role == null || role.trim().isEmpty) return 'Morador';
  final r = _normalizeRole(role);
  if (r == 'admin' || r == 'administrador' || r == 'administradora') {
    return 'Administrador';
  }
  if (r.contains('subsindico') || (r.contains('sub') && r.contains('sindico'))) {
    return 'Subsíndico';
  }
  if (r.contains('sindico')) {
    return 'Síndico';
  }
  if (r.startsWith('porteir') || r.startsWith('portaria')) {
    return 'Porteiro';
  }
  if (r.startsWith('zelador')) {
    return 'Zelador';
  }
  if (r.startsWith('morador')) {
    return 'Morador';
  }
  return role.trim();
}

/// Extensão no AuthState para acesso direto à verificação administrativa
extension AuthStateRoleX on AuthState {
  bool get isAdministrativeUser => isAdministrativeRole(role);
  bool get isMasterUser => isMasterRole(role);
  String get formattedRoleName => formatRoleName(role);
}

