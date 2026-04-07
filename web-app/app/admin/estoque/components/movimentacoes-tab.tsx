'use client'

import { useMemo, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'
import type { Movimentacao, Emprestimo, Produto } from '../estoque-client'
import { ClipboardList, CheckCircle2, AlertCircle, XCircle, Clock } from 'lucide-react'

type TabView = 'movimentacoes' | 'emprestimos'

export default function MovimentacoesTab({
  movimentacoes,
  emprestimos,
  setEmprestimos,
  produtos,
  setProdutos,
  setMovimentacoes,
  condominioId,
  userId,
}: {
  movimentacoes: Movimentacao[]
  emprestimos: Emprestimo[]
  setEmprestimos: React.Dispatch<React.SetStateAction<Emprestimo[]>>
  produtos: Produto[]
  setProdutos: React.Dispatch<React.SetStateAction<Produto[]>>
  setMovimentacoes: React.Dispatch<React.SetStateAction<Movimentacao[]>>
  condominioId: string
  userId: string
}) {
  const supabase = createClient()
  const router = useRouter()
  const [view, setView] = useState<TabView>('movimentacoes')
  const [filterProduto, setFilterProduto] = useState('')
  const [filterTipo, setFilterTipo] = useState('')
  const [page, setPage] = useState(1)
  const perPage = 20

  // Emprestimo return
  const [returningId, setReturningId] = useState<string | null>(null)
  const [isReturning, setIsReturning] = useState(false)

  // Filtered movements
  const filtered = useMemo(() => {
    return movimentacoes.filter(m => {
      if (filterProduto && m.produto_id !== filterProduto) return false
      if (filterTipo && m.tipo !== filterTipo) return false
      return true
    })
  }, [movimentacoes, filterProduto, filterTipo])

  const totalPages = Math.max(1, Math.ceil(filtered.length / perPage))
  const paginated = filtered.slice((page - 1) * perPage, page * perPage)

  // Pending emprestimos
  const pendingEmprestimos = emprestimos.filter(e => e.status === 'emprestado' || e.status === 'atrasado')

  const getTipoLabel = (t: string) => {
    const map: Record<string, { label: string; color: string }> = {
      entrada: { label: 'Entrada', color: 'bg-green-100 text-green-700' },
      saida: { label: 'Saída', color: 'bg-red-100 text-red-700' },
      emprestimo: { label: 'Empréstimo', color: 'bg-purple-100 text-purple-700' },
      devolucao: { label: 'Devolução', color: 'bg-blue-100 text-blue-700' },
      ajuste: { label: 'Ajuste', color: 'bg-yellow-100 text-yellow-700' },
      transferencia: { label: 'Transferência', color: 'bg-teal-100 text-teal-700' },
    }
    return map[t] || { label: t, color: 'bg-gray-100 text-gray-700' }
  }

  const formatDate = (d: string) => {
    const date = new Date(d)
    return date.toLocaleDateString('pt-BR')
  }

  const formatDateTime = (d: string) => {
    const date = new Date(d)
    return date.toLocaleDateString('pt-BR') + ' ' + date.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })
  }

  // Handle return of borrowed item
  const handleReturn = async (emp: Emprestimo) => {
    if (!confirm(`Confirmar devolução de ${emp.quantidade} ${emp.estoque_produtos?.unidade || 'un'} de "${emp.estoque_produtos?.nome || 'produto'}" por ${emp.retirado_por_nome}?`)) return

    setReturningId(emp.id)
    setIsReturning(true)

    try {
      // 1. Update emprestimo
      const { error: empError } = await supabase
        .from('estoque_emprestimos')
        .update({ status: 'devolvido', data_devolucao_real: new Date().toISOString(), updated_at: new Date().toISOString() })
        .eq('id', emp.id)
      if (empError) throw empError

      // 2. Record return movement
      const { data: movData, error: movError } = await supabase
        .from('estoque_movimentacoes')
        .insert({
          condominio_id: condominioId,
          produto_id: emp.produto_id,
          tipo: 'devolucao',
          quantidade: emp.quantidade,
          motivo: `Devolução por ${emp.retirado_por_nome}`,
          realizado_por: userId,
        })
        .select('*, estoque_produtos(nome, unidade), perfil:realizado_por(nome_completo)')
        .single()
      if (movError) throw movError

      // 3. Update product quantity
      const prod = produtos.find(p => p.id === emp.produto_id)
      if (prod) {
        const { error: updError } = await supabase
          .from('estoque_produtos')
          .update({ quantidade_atual: prod.quantidade_atual + emp.quantidade, updated_at: new Date().toISOString() })
          .eq('id', emp.produto_id)
        if (updError) throw updError
        setProdutos(prev => prev.map(p => p.id === emp.produto_id ? { ...p, quantidade_atual: p.quantidade_atual + emp.quantidade } : p))
      }

      // Update local state
      setEmprestimos(prev => prev.map(e => e.id === emp.id ? { ...e, status: 'devolvido' as const, data_devolucao_real: new Date().toISOString() } : e))
      if (movData) setMovimentacoes(prev => [movData, ...prev])

      router.refresh()
    } catch (err) {
      alert('Erro ao registrar devolução: ' + (err instanceof Error ? err.message : 'Erro desconhecido'))
    } finally {
      setIsReturning(false)
      setReturningId(null)
    }
  }

  const getStatusBadge = (status: string) => {
    const map: Record<string, { label: string; icon: React.ReactNode; color: string }> = {
      emprestado: { label: 'Emprestado', icon: <Clock size={14} />, color: 'bg-amber-100 text-amber-700' },
      devolvido: { label: 'Devolvido', icon: <CheckCircle2 size={14} />, color: 'bg-green-100 text-green-700' },
      atrasado: { label: 'Atrasado', icon: <AlertCircle size={14} />, color: 'bg-red-100 text-red-700' },
      perdido: { label: 'Perdido', icon: <XCircle size={14} />, color: 'bg-gray-200 text-gray-700' },
    }
    const s = map[status] || { label: status, icon: null, color: 'bg-gray-100 text-gray-600' }
    return (
      <span className={`inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-semibold ${s.color}`}>
        {s.icon}
        {s.label}
      </span>
    )
  }

  return (
    <div>
      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6 mb-6">
        <div className="flex items-center justify-between flex-wrap gap-4">
          <div>
            <h2 className="text-xl font-bold text-gray-800 flex items-center gap-2">
              <ClipboardList size={22} className="text-[#FC5931]" />
              Controle de Estoque – Movimentações
            </h2>
            <p className="text-gray-500 text-sm mt-1">Histórico completo de entradas, saídas e empréstimos.</p>
          </div>
          <div className="flex gap-2">
            <button
              onClick={() => setView('movimentacoes')}
              className={`px-4 py-2 rounded-xl text-sm font-semibold transition-all ${view === 'movimentacoes' ? 'bg-[#FC5931] text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}`}
            >
              📋 Movimentações
            </button>
            <button
              onClick={() => setView('emprestimos')}
              className={`px-4 py-2 rounded-xl text-sm font-semibold transition-all relative ${view === 'emprestimos' ? 'bg-[#FC5931] text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}`}
            >
              🔄 Empréstimos
              {pendingEmprestimos.length > 0 && (
                <span className="absolute -top-1.5 -right-1.5 bg-red-500 text-white text-[10px] font-bold w-5 h-5 rounded-full flex items-center justify-center animate-pulse">
                  {pendingEmprestimos.length}
                </span>
              )}
            </button>
          </div>
        </div>
      </div>

      {view === 'movimentacoes' ? (
        <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
          {/* Filters */}
          <div className="p-4 border-b border-gray-100 flex flex-wrap gap-3">
            <select
              value={filterProduto}
              onChange={e => { setFilterProduto(e.target.value); setPage(1) }}
              title="Filtrar por produto"
              className="border border-gray-200 rounded-xl px-3 py-2 text-sm bg-gray-50 focus:bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/20 min-w-[180px]"
            >
              <option value="">Produto do estoque</option>
              {produtos.filter(p => p.ativo).map(p => (
                <option key={p.id} value={p.id}>{p.nome}</option>
              ))}
            </select>
            <select
              value={filterTipo}
              onChange={e => { setFilterTipo(e.target.value); setPage(1) }}
              title="Filtrar por tipo"
              className="border border-gray-200 rounded-xl px-3 py-2 text-sm bg-gray-50 focus:bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/20 min-w-[140px]"
            >
              <option value="">Todos os tipos</option>
              <option value="entrada">Entrada</option>
              <option value="saida">Saída</option>
              <option value="emprestimo">Empréstimo</option>
              <option value="devolucao">Devolução</option>
              <option value="ajuste">Ajuste</option>
              <option value="transferencia">Transferência</option>
            </select>
          </div>

          {/* Table matching the user's screenshot layout */}
          <div className="overflow-x-auto">
            <table className="w-full text-left text-sm">
              <thead>
                <tr className="bg-gray-50 text-gray-500 text-xs uppercase tracking-wider">
                  <th className="px-4 py-3 font-semibold">Data</th>
                  <th className="px-4 py-3 font-semibold">Produto</th>
                  <th className="px-4 py-3 font-semibold text-center">Tipo moviment.</th>
                  <th className="px-4 py-3 font-semibold text-center">Quantidade</th>
                  <th className="px-4 py-3 font-semibold">Responsável</th>
                  <th className="px-4 py-3 font-semibold text-center">Saldo atual</th>
                  <th className="px-4 py-3 font-semibold">Motivo</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {paginated.length === 0 ? (
                  <tr>
                    <td colSpan={7} className="px-4 py-12 text-center text-gray-400">
                      <ClipboardList size={40} className="mx-auto mb-3 opacity-30" />
                      <p className="font-medium">Nenhuma movimentação registrada</p>
                    </td>
                  </tr>
                ) : paginated.map(m => {
                  const tipoInfo = getTipoLabel(m.tipo)
                  const product = produtos.find(p => p.id === m.produto_id)
                  return (
                    <tr key={m.id} className="hover:bg-gray-50 transition-colors">
                      <td className="px-4 py-3 text-gray-600 whitespace-nowrap">{formatDate(m.created_at)}</td>
                      <td className="px-4 py-3 font-medium text-gray-800">{m.estoque_produtos?.nome || '—'}</td>
                      <td className="px-4 py-3 text-center">
                        <span className={`inline-block px-2.5 py-1 rounded-full text-xs font-semibold ${tipoInfo.color}`}>
                          {tipoInfo.label}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-center font-semibold text-gray-800">{m.quantidade}</td>
                      <td className="px-4 py-3 text-gray-600">{m.perfil?.nome_completo || '—'}</td>
                      <td className="px-4 py-3 text-center font-semibold text-gray-800">{product ? product.quantidade_atual : '—'}</td>
                      <td className="px-4 py-3 text-gray-500 max-w-[200px] truncate" title={m.motivo || ''}>{m.motivo || '—'}</td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>

          {/* Pagination */}
          {totalPages > 1 && (
            <div className="flex items-center justify-center gap-2 p-4 border-t border-gray-100">
              <button onClick={() => setPage(p => Math.max(1, p - 1))} disabled={page === 1} className="px-3 py-1.5 text-sm rounded-lg border border-gray-200 text-gray-500 hover:bg-gray-50 disabled:opacity-30 transition-colors">‹</button>
              <span className="text-sm text-gray-500">{page} de {totalPages}</span>
              <button onClick={() => setPage(p => Math.min(totalPages, p + 1))} disabled={page === totalPages} className="px-3 py-1.5 text-sm rounded-lg border border-gray-200 text-gray-500 hover:bg-gray-50 disabled:opacity-30 transition-colors">›</button>
            </div>
          )}
        </div>
      ) : (
        /* Empréstimos View */
        <div className="space-y-4">
          {/* Pending section */}
          {pendingEmprestimos.length > 0 && (
            <div className="bg-amber-50 rounded-2xl border border-amber-200 p-4 mb-4">
              <h3 className="font-bold text-amber-800 text-sm mb-3 flex items-center gap-2">
                <Clock size={16} />
                Itens Emprestados ({pendingEmprestimos.length})
              </h3>
              <div className="space-y-3">
                {pendingEmprestimos.map(emp => (
                  <div key={emp.id} className="bg-white rounded-xl p-4 border border-amber-100 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                    <div className="flex-1">
                      <p className="font-semibold text-gray-800">{emp.estoque_produtos?.nome || 'Produto'}</p>
                      <div className="flex flex-wrap gap-2 mt-1 text-xs text-gray-500">
                        <span>👤 {emp.retirado_por_nome}</span>
                        <span>📦 Qtd: {emp.quantidade} {emp.estoque_produtos?.unidade}</span>
                        <span>📅 Retirada: {formatDateTime(emp.data_retirada)}</span>
                        {emp.data_prevista_devolucao && (
                          <span className={new Date(emp.data_prevista_devolucao) < new Date() ? 'text-red-600 font-semibold' : ''}>
                            ⏰ Prev. devolução: {formatDate(emp.data_prevista_devolucao)}
                          </span>
                        )}
                      </div>
                      {emp.motivo && <p className="text-xs text-gray-400 mt-1">Motivo: {emp.motivo}</p>}
                    </div>
                    <div className="flex items-center gap-2">
                      {getStatusBadge(emp.status)}
                      <button
                        onClick={() => handleReturn(emp)}
                        disabled={isReturning && returningId === emp.id}
                        className="bg-green-500 hover:bg-green-600 text-white px-4 py-2 rounded-xl text-sm font-semibold transition-colors disabled:opacity-50 flex items-center gap-1.5"
                      >
                        <CheckCircle2 size={14} />
                        {isReturning && returningId === emp.id ? 'Registrando...' : 'Registrar Devolução'}
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* All emprestimos history */}
          <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
            <div className="p-4 border-b border-gray-100">
              <h3 className="font-bold text-gray-800">Histórico de Empréstimos</h3>
            </div>
            <div className="overflow-x-auto">
              <table className="w-full text-left text-sm">
                <thead>
                  <tr className="bg-gray-50 text-gray-500 text-xs uppercase tracking-wider">
                    <th className="px-4 py-3 font-semibold">Data Retirada</th>
                    <th className="px-4 py-3 font-semibold">Produto</th>
                    <th className="px-4 py-3 font-semibold">Retirado por</th>
                    <th className="px-4 py-3 font-semibold text-center">Qtd</th>
                    <th className="px-4 py-3 font-semibold">Status</th>
                    <th className="px-4 py-3 font-semibold">Devolução</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-100">
                  {emprestimos.length === 0 ? (
                    <tr>
                      <td colSpan={6} className="px-4 py-12 text-center text-gray-400">
                        Nenhum empréstimo registrado
                      </td>
                    </tr>
                  ) : emprestimos.map(emp => (
                    <tr key={emp.id} className={`hover:bg-gray-50 transition-colors ${emp.status === 'emprestado' ? 'bg-amber-50/50' : ''}`}>
                      <td className="px-4 py-3 text-gray-600 whitespace-nowrap">{formatDateTime(emp.data_retirada)}</td>
                      <td className="px-4 py-3 font-medium text-gray-800">{emp.estoque_produtos?.nome || '—'}</td>
                      <td className="px-4 py-3 text-gray-600">{emp.retirado_por_nome}</td>
                      <td className="px-4 py-3 text-center font-semibold">{emp.quantidade}</td>
                      <td className="px-4 py-3">{getStatusBadge(emp.status)}</td>
                      <td className="px-4 py-3 text-gray-500 text-xs">
                        {emp.data_devolucao_real ? formatDateTime(emp.data_devolucao_real) : '—'}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
