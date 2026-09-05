export interface Fornecedor {
  id: string
  condominio_id: string
  nome: string
  tipo: string
  telefone?: string | null
  documento?: string | null
  observacoes?: string | null
  ativo?: boolean
  created_at?: string
  updated_at?: string
}

export interface ContratoPasta {
  id: string
  condominio_id: string
  nome: string
  observacao?: string | null
  created_at?: string
}

export interface Contrato {
  id: string
  condominio_id: string
  titulo: string
  pasta_id?: string | null
  categoria?: string | null
  tipo: string
  fornecedor_id?: string | null
  fornecedor_nome?: string | null
  valor_mensal?: number | null
  data_expedicao?: string | null
  data_validade?: string | null
  sem_validade: boolean
  lembrar_30: boolean
  lembrar_60: boolean
  lembrar_90: boolean
  arquivo_url?: string | null
  arquivo_nome?: string | null
  mostrar_moradores: boolean
  avisar_moradores: boolean
  descricao?: string | null
  created_at: string
  updated_at: string
  fornecedores?: {
    id: string
    nome: string
    telefone?: string | null
    documento?: string | null
    tipo?: string | null
  } | null
  contrato_pastas?: {
    id: string
    nome: string
  } | null
}

export type StatusContratoType =
  | 'PERMANENTE'
  | 'INDETERMINADO'
  | 'VENCIDO'
  | 'VENCE_HOJE'
  | 'VENCENDO'
  | 'VIGENTE'

export interface StatusContratoInfo {
  type: StatusContratoType
  label: string
  color: 'gray' | 'red' | 'orange' | 'amber' | 'emerald'
  diasDiferenca?: number
}

export function calcularStatusContrato(contrato: Contrato): StatusContratoInfo {
  if (contrato.sem_validade) {
    return {
      type: 'PERMANENTE',
      label: 'Permanente',
      color: 'gray',
    }
  }

  if (!contrato.data_validade) {
    return {
      type: 'INDETERMINADO',
      label: 'Não informado',
      color: 'gray',
    }
  }

  const today = new Date()
  today.setHours(0, 0, 0, 0)
  
  const validade = new Date(contrato.data_validade + 'T00:00:00')
  const diffTime = validade.getTime() - today.getTime()
  const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24))

  if (diffDays < 0) {
    const absDays = Math.abs(diffDays)
    return {
      type: 'VENCIDO',
      label: `Vencido há ${absDays} ${absDays === 1 ? 'dia' : 'dias'}`,
      color: 'red',
      diasDiferenca: diffDays,
    }
  }

  if (diffDays === 0) {
    return {
      type: 'VENCE_HOJE',
      label: 'Vence hoje',
      color: 'orange',
      diasDiferenca: 0,
    }
  }

  if (diffDays <= 30) {
    return {
      type: 'VENCENDO',
      label: `Vence em ${diffDays} ${diffDays === 1 ? 'dia' : 'dias'}`,
      color: 'amber',
      diasDiferenca: diffDays,
    }
  }

  return {
    type: 'VIGENTE',
    label: 'Vigente',
    color: 'emerald',
    diasDiferenca: diffDays,
  }
}

export function formatMoney(val?: number | null): string {
  if (val === null || val === undefined) return 'Não informado'
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
  }).format(val)
}
