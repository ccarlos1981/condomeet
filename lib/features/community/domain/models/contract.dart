import 'package:flutter/material.dart';

enum StatusContratoType {
  permanente,
  indeterminado,
  vencido,
  venceHoje,
  vencendo,
  vigente,
}

class StatusContratoInfo {
  final StatusContratoType type;
  final String label;
  final Color color;
  final Color backgroundColor;
  final IconData icon;
  final int? diasDiferenca;

  const StatusContratoInfo({
    required this.type,
    required this.label,
    required this.color,
    required this.backgroundColor,
    required this.icon,
    this.diasDiferenca,
  });
}

class CondoContract {
  final String id;
  final String condominioId;
  final String titulo;
  final String? pastaId;
  final String? pastaNome;
  final String? categoria;
  final String tipo;
  final String? fornecedorId;
  final String? fornecedorNome;
  final String? fornecedorTelefone;
  final String? fornecedorDoc;
  final String? fornecedorTipo;
  final double? valorMensal;
  final DateTime? dataExpedicao;
  final DateTime? dataValidade;
  final bool semValidade;
  final bool lembrar30;
  final bool lembrar60;
  final bool lembrar90;
  final String? arquivoUrl;
  final String? arquivoNome;
  final bool mostrarMoradores;
  final bool avisarMoradores;
  final String? descricao;
  final DateTime createdAt;

  const CondoContract({
    required this.id,
    required this.condominioId,
    required this.titulo,
    this.pastaId,
    this.pastaNome,
    this.categoria,
    this.tipo = 'obrigatorio',
    this.fornecedorId,
    this.fornecedorNome,
    this.fornecedorTelefone,
    this.fornecedorDoc,
    this.fornecedorTipo,
    this.valorMensal,
    this.dataExpedicao,
    this.dataValidade,
    this.semValidade = false,
    this.lembrar30 = false,
    this.lembrar60 = false,
    this.lembrar90 = false,
    this.arquivoUrl,
    this.arquivoNome,
    this.mostrarMoradores = false,
    this.avisarMoradores = false,
    this.descricao,
    required this.createdAt,
  });

  String get nomeFornecedorExibicao {
    if (fornecedorNome != null && fornecedorNome!.isNotEmpty) {
      return fornecedorNome!;
    }
    return 'Fornecedor não informado';
  }

  StatusContratoInfo get statusInfo {
    if (semValidade) {
      return const StatusContratoInfo(
        type: StatusContratoType.permanente,
        label: 'Permanente',
        color: Color(0xFF4B5563),
        backgroundColor: Color(0xFFF3F4F6),
        icon: Icons.all_inclusive,
      );
    }

    if (dataValidade == null) {
      return const StatusContratoInfo(
        type: StatusContratoType.indeterminado,
        label: 'Não informado',
        color: Color(0xFF6B7280),
        backgroundColor: Color(0xFFF3F4F6),
        icon: Icons.help_outline,
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final val = DateTime(dataValidade!.year, dataValidade!.month, dataValidade!.day);
    final diffDays = val.difference(today).inDays;

    if (diffDays < 0) {
      final abs = diffDays.abs();
      return StatusContratoInfo(
        type: StatusContratoType.vencido,
        label: 'Vencido há $abs ${abs == 1 ? 'dia' : 'dias'}',
        color: const Color(0xFFDC2626),
        backgroundColor: const Color(0xFFFEF2F2),
        icon: Icons.error_outline,
        diasDiferenca: diffDays,
      );
    }

    if (diffDays == 0) {
      return const StatusContratoInfo(
        type: StatusContratoType.venceHoje,
        label: 'Vence hoje',
        color: Color(0xFFEA580C),
        backgroundColor: Color(0xFFFFF7ED),
        icon: Icons.warning_amber_rounded,
        diasDiferenca: 0,
      );
    }

    if (diffDays <= 30) {
      return StatusContratoInfo(
        type: StatusContratoType.vencendo,
        label: 'Vence em $diffDays ${diffDays == 1 ? 'dia' : 'dias'}',
        color: const Color(0xFFD97706),
        backgroundColor: const Color(0xFFFFFBEB),
        icon: Icons.access_time_rounded,
        diasDiferenca: diffDays,
      );
    }

    return StatusContratoInfo(
      type: StatusContratoType.vigente,
      label: 'Vigente',
      color: const Color(0xFF059669),
      backgroundColor: const Color(0xFFECFDF5),
      icon: Icons.check_circle_outline,
      diasDiferenca: diffDays,
    );
  }

  factory CondoContract.fromMap(Map<String, dynamic> map) {
    final fornecedorMap = map['fornecedores'] as Map<String, dynamic>?;
    final pastaMap = map['contrato_pastas'] as Map<String, dynamic>?;

    final resolvedFornecedorNome = (fornecedorMap?['nome'] as String?) ??
        (map['fornecedor_nome'] as String?);

    return CondoContract(
      id: map['id'] as String,
      condominioId: map['condominio_id'] as String? ?? '',
      titulo: map['titulo'] as String? ?? '',
      pastaId: map['pasta_id'] as String?,
      pastaNome: pastaMap?['nome'] as String?,
      categoria: map['categoria'] as String?,
      tipo: map['tipo'] as String? ?? 'obrigatorio',
      fornecedorId: map['fornecedor_id'] as String?,
      fornecedorNome: resolvedFornecedorNome,
      fornecedorTelefone: fornecedorMap?['telefone'] as String?,
      fornecedorDoc: fornecedorMap?['documento'] as String?,
      fornecedorTipo: fornecedorMap?['tipo'] as String?,
      valorMensal: (map['valor_mensal'] is num)
          ? (map['valor_mensal'] as num).toDouble()
          : null,
      dataExpedicao: map['data_expedicao'] != null
          ? DateTime.tryParse(map['data_expedicao'] as String)
          : null,
      dataValidade: map['data_validade'] != null
          ? DateTime.tryParse(map['data_validade'] as String)
          : null,
      semValidade: map['sem_validade'] == true,
      lembrar30: map['lembrar_30'] == true,
      lembrar60: map['lembrar_60'] == true,
      lembrar90: map['lembrar_90'] == true,
      arquivoUrl: map['arquivo_url'] as String?,
      arquivoNome: map['arquivo_nome'] as String?,
      mostrarMoradores: map['mostrar_moradores'] == true,
      avisarMoradores: map['avisar_moradores'] == true,
      descricao: map['descricao'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }
}
