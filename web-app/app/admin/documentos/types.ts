export type Pasta = {
  id: string
  nome: string
  observacao: string | null
  created_at: string
}

export type DocumentoTipo = {
  id: string
  condominio_id: string | null
  nome: string
  descricao: string | null
  categoria_padrao: string
  icone: string
  is_system: boolean
  ativo: boolean
  ordem: number
  recorrente: boolean
  normalmente_tem_validade: boolean
  permite_lembrete: boolean
  permite_exibir_moradores: boolean
  permite_notificacao: boolean
  created_at?: string
  updated_at?: string
}

export type DocumentoTipoPrioridade = {
  id: string
  condominio_id: string
  tipo_id: string
  is_prioritario: boolean
  ordem: number
  created_at?: string
  updated_at?: string
}

export type Documento = {
  id: string
  condominio_id?: string
  pasta_id: string | null
  titulo: string
  categoria: string | null
  tipo_id: string | null // FONTE CANÔNICA
  tipo: string // CAMPO LEGADO DE COMPATIBILIDADE
  sem_validade: boolean // NOVO CAMPO
  arquivo_url: string | null
  arquivo_nome: string | null
  data_expedicao: string | null
  data_validade: string | null
  lembrar_30: boolean
  lembrar_60: boolean
  lembrar_90: boolean
  avisar_moradores: boolean
  mostrar_moradores: boolean
  descricao: string | null
  updated_at: string
  created_at?: string
}
