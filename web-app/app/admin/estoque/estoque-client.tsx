'use client'

import { useState } from 'react'
import { Package, MapPin, Tag, ShoppingCart, ArrowLeftRight, ClipboardList } from 'lucide-react'
import DashboardTab from './components/dashboard-tab'
import LocaisTab from './components/locais-tab'
import CategoriasTab from './components/categorias-tab'
import ProdutosTab from './components/produtos-tab'
import EntradaSaidaTab from './components/entrada-saida-tab'
import MovimentacoesTab from './components/movimentacoes-tab'

// Shared types
export type Local = {
  id: string
  condominio_id: string
  codigo: string
  nome: string
  observacoes: string | null
  ativo: boolean
  created_at: string
}

export type Categoria = {
  id: string
  condominio_id: string
  codigo: string
  nome: string
  observacoes: string | null
  ativo: boolean
  created_at: string
}

export type Produto = {
  id: string
  condominio_id: string
  local_id: string | null
  categoria_id: string | null
  fornecedor_id: string | null
  codigo: string
  nome: string
  descricao: string | null
  unidade: string
  tipo_controle: 'consumivel' | 'retornavel' | 'misto'
  foto_url: string | null
  marca: string | null
  quantidade_atual: number
  quantidade_minima: number
  quantidade_maxima: number
  data_validade: string | null
  custo_unitario: number
  ativo: boolean
  created_at: string
  estoque_locais?: { nome: string } | null
  estoque_categorias?: { nome: string } | null
  fornecedores?: { nome: string } | null
}

export type Fornecedor = {
  id: string
  nome: string
}

export type Movimentacao = {
  id: string
  condominio_id: string
  produto_id: string
  tipo: 'entrada' | 'saida' | 'emprestimo' | 'devolucao' | 'ajuste' | 'transferencia'
  quantidade: number
  motivo: string | null
  observacao: string | null
  realizado_por: string | null
  created_at: string
  estoque_produtos?: { nome: string; unidade: string } | null
  perfil?: { nome_completo: string } | null
}

export type Emprestimo = {
  id: string
  condominio_id: string
  produto_id: string
  quantidade: number
  retirado_por_nome: string
  retirado_por_perfil_id: string | null
  motivo: string | null
  observacao: string | null
  data_retirada: string
  data_prevista_devolucao: string | null
  data_devolucao_real: string | null
  status: 'emprestado' | 'devolvido' | 'atrasado' | 'perdido'
  registrado_por: string | null
  created_at: string
  estoque_produtos?: { nome: string; unidade: string } | null
}

type TabId = 'dashboard' | 'locais' | 'categorias' | 'produtos' | 'entrada-saida' | 'movimentacoes'

const TABS: { id: TabId; label: string; icon: React.ReactNode }[] = [
  { id: 'dashboard', label: 'ESTOQUE', icon: <Package size={16} /> },
  { id: 'locais', label: 'ADD LUGAR DE ESTOQUE', icon: <MapPin size={16} /> },
  { id: 'categorias', label: 'ADD CATEGORIA', icon: <Tag size={16} /> },
  { id: 'produtos', label: 'ADD PRODUTO', icon: <ShoppingCart size={16} /> },
  { id: 'entrada-saida', label: 'ENTRADA E SAÍDA', icon: <ArrowLeftRight size={16} /> },
  { id: 'movimentacoes', label: 'MOVIMENTAÇÕES', icon: <ClipboardList size={16} /> },
]

export default function EstoqueClient({
  condominioId,
  condominioNome,
  userId,
  initialLocais,
  initialCategorias,
  initialProdutos,
  initialFornecedores,
  initialMovimentacoes,
  initialEmprestimos,
}: {
  condominioId: string
  condominioNome: string
  userId: string
  initialLocais: Local[]
  initialCategorias: Categoria[]
  initialProdutos: Produto[]
  initialFornecedores: Fornecedor[]
  initialMovimentacoes: Movimentacao[]
  initialEmprestimos: Emprestimo[]
}) {
  const [activeTab, setActiveTab] = useState<TabId>('dashboard')
  const [locais, setLocais] = useState<Local[]>(initialLocais)
  const [categorias, setCategorias] = useState<Categoria[]>(initialCategorias)
  const [produtos, setProdutos] = useState<Produto[]>(initialProdutos)
  const [fornecedores] = useState<Fornecedor[]>(initialFornecedores)
  const [movimentacoes, setMovimentacoes] = useState<Movimentacao[]>(initialMovimentacoes)
  const [emprestimos, setEmprestimos] = useState<Emprestimo[]>(initialEmprestimos)



  return (
    <div className="p-4 md:p-6 max-w-[1400px] mx-auto">
      {/* Header */}
      <div className="bg-linear-to-r from-[#1e1e2e] to-[#2d1b3d] rounded-2xl p-5 mb-6 relative overflow-hidden">
        <div className="absolute inset-0 bg-[url('data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAiIGhlaWdodD0iNDAiIHZpZXdCb3g9IjAgMCA0MCA0MCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48ZGVmcz48cGF0dGVybiBpZD0iZ3JpZCIgd2lkdGg9IjQwIiBoZWlnaHQ9IjQwIiBwYXR0ZXJuVW5pdHM9InVzZXJTcGFjZU9uVXNlIj48cGF0aCBkPSJNIDQwIDAgTCAwIDAgMCA0MCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJ3aGl0ZSIgc3Ryb2tlLW9wYWNpdHk9IjAuMDMiIHN0cm9rZS13aWR0aD0iMSIvPjwvcGF0dGVybj48L2RlZnM+PHJlY3Qgd2lkdGg9IjEwMCUiIGhlaWdodD0iMTAwJSIgZmlsbD0idXJsKCNncmlkKSIvPjwvc3ZnPg==')] opacity-50" />
        <div className="relative z-10">
          <h1 className="text-xl md:text-2xl font-bold text-white flex items-center gap-3">
            <div className="bg-white/10 p-2.5 rounded-xl backdrop-blur-sm">
              <Package size={24} className="text-orange-400" />
            </div>
            Controle de Estoque
          </h1>
          <p className="text-white/50 mt-1.5 text-sm">{condominioNome}</p>
        </div>
      </div>

      {/* Tabs Navigation */}
      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 mb-6 overflow-hidden">
        <div className="flex overflow-x-auto scrollbar-hide">
          {TABS.map(tab => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={`flex items-center gap-2 px-4 py-3.5 text-xs font-bold whitespace-nowrap border-b-3 transition-all duration-200 ${
                activeTab === tab.id
                  ? 'text-[#FC5931] border-[#FC5931] bg-[#FC5931]/5'
                  : 'text-gray-500 border-transparent hover:text-gray-700 hover:bg-gray-50'
              }`}
            >
              {tab.icon}
              <span className="hidden sm:inline">{tab.label}</span>
              <span className="sm:hidden">{tab.label.split(' ').slice(-1)[0]}</span>
            </button>
          ))}
        </div>
      </div>

      {/* Tab Content */}
      <div className="min-h-[500px]">
        {activeTab === 'dashboard' && (
          <DashboardTab
            produtos={produtos}
            emprestimos={emprestimos}
            movimentacoes={movimentacoes}
            locais={locais}
            categorias={categorias}
          />
        )}
        {activeTab === 'locais' && (
          <LocaisTab
            locais={locais}
            setLocais={setLocais}
            condominioId={condominioId}
          />
        )}
        {activeTab === 'categorias' && (
          <CategoriasTab
            categorias={categorias}
            setCategorias={setCategorias}
            condominioId={condominioId}
          />
        )}
        {activeTab === 'produtos' && (
          <ProdutosTab
            produtos={produtos}
            setProdutos={setProdutos}
            locais={locais}
            setLocais={setLocais}
            categorias={categorias}
            setCategorias={setCategorias}
            fornecedores={fornecedores}
            condominioId={condominioId}
          />
        )}
        {activeTab === 'entrada-saida' && (
          <EntradaSaidaTab
            produtos={produtos}
            setProdutos={setProdutos}
            setMovimentacoes={setMovimentacoes}
            setEmprestimos={setEmprestimos}
            condominioId={condominioId}
            userId={userId}
          />
        )}
        {activeTab === 'movimentacoes' && (
          <MovimentacoesTab
            movimentacoes={movimentacoes}
            emprestimos={emprestimos}
            setEmprestimos={setEmprestimos}
            produtos={produtos}
            setProdutos={setProdutos}
            setMovimentacoes={setMovimentacoes}
            condominioId={condominioId}
            userId={userId}
          />
        )}
      </div>
    </div>
  )
}
