export const MOTIVOS_OBRIGATORIOS = [
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
] as const

export const MOTIVOS_MANUTENCAO = [
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
] as const

export type TipoDocumentoCanonica = 'obrigatorio' | 'manutencao' | 'outros'

export function normalizeTipoDocumento(tipo?: string | null): TipoDocumentoCanonica {
  if (!tipo) return 'obrigatorio'
  const t = tipo.toLowerCase().trim()
  if (t === 'manutencao') return 'manutencao'
  if (t === 'outros' || t === 'outros_documentos') return 'outros'
  return 'obrigatorio'
}

export function getCategoriaBadge(tipo?: string | null): { label: string; bg: string; text: string; border: string } {
  const norm = normalizeTipoDocumento(tipo)
  switch (norm) {
    case 'obrigatorio':
      return {
        label: 'Obrigatório',
        bg: 'bg-blue-50',
        text: 'text-blue-700',
        border: 'border-blue-200',
      }
    case 'manutencao':
      return {
        label: 'Manutenção',
        bg: 'bg-amber-50',
        text: 'text-amber-700',
        border: 'border-amber-200',
      }
    case 'outros':
      return {
        label: 'Outros',
        bg: 'bg-purple-50',
        text: 'text-purple-700',
        border: 'border-purple-200',
      }
  }
}
