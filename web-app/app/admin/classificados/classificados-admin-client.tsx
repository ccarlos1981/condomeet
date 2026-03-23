'use client'
import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'
import {
  CheckCircle, XCircle, Clock, Image as ImageIcon,
  ChevronDown, ChevronUp, ArrowLeft
} from 'lucide-react'
import Link from 'next/link'

interface Perfil {
  nome_completo: string
  bloco_txt: string
  apto_txt: string
  whatsapp: string
}

interface Classificado {
  id: string
  titulo: string
  descricao: string
  categoria: string
  marca_modelo: string
  preco: number | null
  condicao: string
  mostrar_telefone: boolean
  foto_url: string | null
  status: string
  cod_interno: string
  created_at: string
  perfil: Perfil | null
}

const CATEGORIAS: Record<string, string> = {
  eletronicos: 'Eletrônicos',
  moveis: 'Móveis',
  roupas: 'Roupas',
  veiculos: 'Veículos',
  servicos: 'Serviços',
  imoveis: 'Imóveis',
  carros_e_pecas: 'Carros e Peças',
  outros: 'Outros',
}

function getBlocoLabel(tipo?: string) {
  if (tipo === 'casa_quadra') return 'Quadra'
  if (tipo === 'casa_rua') return 'Rua'
  return 'Bloco'
}
function getAptoLabel(tipo?: string) {
  if (tipo === 'casa_quadra') return 'Lote'
  if (tipo === 'casa_rua') return 'Número'
  return 'Apto'
}

export default function ClassificadosAdminClient({
  classificados: initialClassificados,
  condominioId,
  tipoEstrutura,
}: {
  classificados: Classificado[]
  condominioId: string
  tipoEstrutura: string
}) {
  const supabase = createClient()
  const router = useRouter()
  const [classificados, setClassificados] = useState(initialClassificados)
  const [loading, setLoading] = useState<Record<string, boolean>>({})
  const [expandedId, setExpandedId] = useState<string | null>(null)
  const [filter, setFilter] = useState<'todos' | 'pendente' | 'aprovado' | 'rejeitado'>('pendente')

  const blocoLabel = getBlocoLabel(tipoEstrutura)
  const aptoLabel = getAptoLabel(tipoEstrutura)

  const filtered = classificados.filter(c => filter === 'todos' ? true : c.status === filter)

  async function handleAction(id: string, newStatus: 'aprovado' | 'rejeitado') {
    setLoading(prev => ({ ...prev, [id]: true }))
    try {
      const { data: { user } } = await supabase.auth.getUser()

      const { error } = await supabase
        .from('classificados')
        .update({
          status: newStatus,
          aprovado_por: user?.id,
        })
        .eq('id', id)

      if (error) throw error

      // Trigger notification
      try {
        await supabase.functions.invoke('classificados-notify', {
          body: { condominio_id: condominioId, classificado_id: id, action: newStatus }
        })
      } catch (e) {
        console.warn('Notification failed:', e)
      }

      setClassificados(prev =>
        prev.map(c => c.id === id ? { ...c, status: newStatus } : c)
      )
      router.refresh()
    } catch (error) {
      console.error('Error updating classificado:', error)
      alert('Erro ao atualizar anúncio')
    } finally {
      setLoading(prev => ({ ...prev, [id]: false }))
    }
  }

  const statusBadge = (status: string) => {
    switch (status) {
      case 'aprovado': return <span className="inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-bold bg-green-100 text-green-700"><CheckCircle size={12} /> Aprovado</span>
      case 'rejeitado': return <span className="inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-bold bg-red-100 text-red-700"><XCircle size={12} /> Rejeitado</span>
      default: return <span className="inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-bold bg-yellow-100 text-yellow-700"><Clock size={12} /> Pendente</span>
    }
  }

  return (
    <div className="max-w-4xl mx-auto py-8 px-4">
      {/* Header */}
      <div className="flex items-center gap-3 mb-6">
        <Link href="/admin" className="p-2 rounded-lg hover:bg-gray-100 transition-colors">
          <ArrowLeft size={20} />
        </Link>
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Aprovar Classificados</h1>
          <p className="text-sm text-gray-500">Gerencie os anúncios dos moradores</p>
        </div>
      </div>

      {/* Filter tabs */}
      <div className="flex gap-2 mb-6">
        {(['pendente', 'aprovado', 'rejeitado', 'todos'] as const).map(f => (
          <button
            key={f}
            onClick={() => setFilter(f)}
            className={`px-4 py-2 rounded-full text-sm font-medium transition-all ${
              filter === f
                ? 'bg-[#FC5931] text-white shadow-md'
                : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
            }`}
          >
            {f === 'todos' ? 'Todos' : f.charAt(0).toUpperCase() + f.slice(1)}
            {f !== 'todos' && (
              <span className="ml-1 text-xs">
                ({classificados.filter(c => c.status === f).length})
              </span>
            )}
          </button>
        ))}
      </div>

      {/* Cards */}
      {filtered.length === 0 ? (
        <div className="text-center py-16 text-gray-400">
          <Clock size={48} className="mx-auto mb-3 opacity-50" />
          <p className="text-lg font-medium">Nenhum anúncio {filter !== 'todos' ? filter : ''}</p>
        </div>
      ) : (
        <div className="space-y-4">
          {filtered.map(c => (
            <div key={c.id} className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
              <div
                className="p-5 cursor-pointer hover:bg-gray-50 transition-colors"
                onClick={() => setExpandedId(expandedId === c.id ? null : c.id)}
              >
                <div className="flex gap-4">
                  {/* Photo */}
                  <div className="w-20 h-20 rounded-xl bg-gray-100 flex-shrink-0 overflow-hidden flex items-center justify-center">
                    {c.foto_url ? (
                      <img src={c.foto_url} alt={c.titulo} className="w-full h-full object-cover" />
                    ) : (
                      <ImageIcon size={24} className="text-gray-300" />
                    )}
                  </div>

                  {/* Info */}
                  <div className="flex-1 min-w-0">
                    <div className="flex items-start justify-between gap-2">
                      <h3 className="font-bold text-gray-900 truncate">{c.titulo}</h3>
                      {statusBadge(c.status)}
                    </div>
                    <p className="text-sm text-gray-500 mt-1">
                      <strong>Dono:</strong> {c.perfil?.nome_completo ?? 'N/A'}
                    </p>
                    <p className="text-sm text-gray-500">
                      {blocoLabel}: {c.perfil?.bloco_txt ?? '?'} · {aptoLabel}: {c.perfil?.apto_txt ?? '?'}
                    </p>
                    <div className="flex items-center gap-3 mt-1">
                      {c.preco && (
                        <span className="text-sm font-bold text-green-600">
                          R$ {Number(c.preco).toFixed(2).replace('.', ',')}
                        </span>
                      )}
                      <span className="text-xs text-gray-400">
                        {new Date(c.created_at).toLocaleDateString('pt-BR')}
                      </span>
                      <span className="text-xs text-gray-400">Cod: {c.cod_interno}</span>
                    </div>
                  </div>

                  <button className="self-center text-gray-400">
                    {expandedId === c.id ? <ChevronUp size={20} /> : <ChevronDown size={20} />}
                  </button>
                </div>
              </div>

              {/* Expanded details */}
              {expandedId === c.id && (
                <div className="px-5 pb-5 border-t border-gray-100 pt-4">
                  <div className="grid grid-cols-2 gap-3 text-sm mb-4">
                    <div><span className="text-gray-500">Categoria:</span> {CATEGORIAS[c.categoria] ?? c.categoria}</div>
                    <div><span className="text-gray-500">Condição:</span> {c.condicao === 'novo' ? 'Novo' : 'Usado'}</div>
                    {c.marca_modelo && <div><span className="text-gray-500">Marca/Modelo:</span> {c.marca_modelo}</div>}
                    <div><span className="text-gray-500">Telefone visível:</span> {c.mostrar_telefone ? 'Sim' : 'Não'}</div>
                    {c.mostrar_telefone && c.perfil?.whatsapp && (
                      <div><span className="text-gray-500">WhatsApp:</span> {c.perfil.whatsapp}</div>
                    )}
                  </div>
                  {c.descricao && (
                    <div className="mb-4">
                      <span className="text-sm text-gray-500">Descrição:</span>
                      <p className="text-sm text-gray-700 mt-1 whitespace-pre-wrap">{c.descricao}</p>
                    </div>
                  )}

                  {/* Action buttons */}
                  {c.status === 'pendente' && (
                    <div className="flex gap-3">
                      <button
                        onClick={() => handleAction(c.id, 'aprovado')}
                        disabled={loading[c.id]}
                        className="flex-1 flex items-center justify-center gap-2 py-2.5 bg-green-500 hover:bg-green-600 text-white font-bold rounded-xl transition-colors disabled:opacity-50"
                      >
                        <CheckCircle size={18} />
                        {loading[c.id] ? 'Processando...' : 'Aprovar'}
                      </button>
                      <button
                        onClick={() => handleAction(c.id, 'rejeitado')}
                        disabled={loading[c.id]}
                        className="flex-1 flex items-center justify-center gap-2 py-2.5 bg-red-500 hover:bg-red-600 text-white font-bold rounded-xl transition-colors disabled:opacity-50"
                      >
                        <XCircle size={18} />
                        {loading[c.id] ? 'Processando...' : 'Rejeitar'}
                      </button>
                    </div>
                  )}
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
