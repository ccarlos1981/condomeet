import 'package:flutter/material.dart';

const List<String> kMotivosObrigatorios = [
  'Alvará Sanitário (piscinas e outros)',
  'Apólice de seguro',
  'ART Condomínio',
  'ART Unidades',
  'Atas de Assembleias',
  'Balancetes e prestação de contas',
  'Certidões Negativas de Débitos',
  'Certificado corpo de bombeiros',
  'Certificado de estanqueidade de gás',
  'CNPJ',
  'Contratos',
  'Convenção',
  'Financeiro',
  'Inspeção predial',
  'Laudos dos geradores',
  'Laudos de Análise de Água',
  'Laudos Elevadores',
  'Manutenção de extintores e mangueiras',
  'Para raios',
  'Plantas Estruturais e projetos',
  'Processos judiciais',
  'Regimento',
  'Teste bombas dágua',
  'Teste de estanqueidade do gás',
  'Trabalhistas',
];

const List<String> kMotivosManutencao = [
  'Ar condicionado, sauna e energia limpa',
  'Bombas dagua',
  'Caixas d´agua',
  'Canos, torneiras, registros e mangueiras',
  'Circuito de vídeo',
  'Desentupidora',
  'eletro eletrônicos',
  'Elevadores',
  'Equipamentos de Incêndio',
  'Fachada',
  'Funcionários',
  'Geradores',
  'iluminação e sensores',
  'Impermeabilização',
  'Jardim',
  'Limpezas especiais (fossas, dedetização e outras)',
  'Marcenaria, pinturas, alvenaria e ferragens',
  'Móveis',
  'Piscina',
  'Portões',
  'Ressarcimentos',
  'Sinalizações',
  'Válvulas redutoras de pressão',
  'sistema de gás',
  'Telefonia e interfone',
  'Treinamentos',
  'Vidros',
];

String normalizeTipoDocumento(String? tipo) {
  if (tipo == null || tipo.isEmpty) return 'obrigatorio';
  final t = tipo.toLowerCase().trim();
  if (t == 'manutencao') return 'manutencao';
  if (t == 'outros' || t == 'outros_documentos') return 'outros';
  return 'obrigatorio';
}

String getCategoriaLabel(String? tipo) {
  final norm = normalizeTipoDocumento(tipo);
  switch (norm) {
    case 'obrigatorio':
      return 'Obrigatório';
    case 'manutencao':
      return 'Manutenção';
    case 'outros':
      return 'Outros';
    default:
      return 'Obrigatório';
  }
}

class CategoriaBadgeStyle {
  final Color backgroundColor;
  final Color textColor;
  final Color borderColor;

  const CategoriaBadgeStyle({
    required this.backgroundColor,
    required this.textColor,
    required this.borderColor,
  });
}

CategoriaBadgeStyle getCategoriaBadgeStyle(String? tipo) {
  final norm = normalizeTipoDocumento(tipo);
  switch (norm) {
    case 'obrigatorio':
      return const CategoriaBadgeStyle(
        backgroundColor: Color(0xFFEFF6FF), // blue-50
        textColor: Color(0xFF1D4ED8), // blue-700
        borderColor: Color(0xFFBFDBFE), // blue-200
      );
    case 'manutencao':
      return const CategoriaBadgeStyle(
        backgroundColor: Color(0xFFFFFBEB), // amber-50
        textColor: Color(0xFFB45309), // amber-700
        borderColor: Color(0xFFFDE68A), // amber-200
      );
    case 'outros':
      return const CategoriaBadgeStyle(
        backgroundColor: Color(0xFFFAF5FF), // purple-50
        textColor: Color(0xFF7E22CE), // purple-700
        borderColor: Color(0xFFE9D5FF), // purple-200
      );
    default:
      return const CategoriaBadgeStyle(
        backgroundColor: Color(0xFFF3F4F6),
        textColor: Color(0xFF374151),
        borderColor: Color(0xFFE5E7EB),
      );
  }
}
