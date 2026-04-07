'use client'

import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'
import type { Produto, Movimentacao, Emprestimo } from '../estoque-client'
import { ArrowLeftRight, ArrowDown, ArrowUp, Save } from 'lucide-react'

export default function EntradaSaidaTab({
  produtos,
  setProdutos,
  setMovimentacoes,
  setEmprestimos,
  condominioId,
  userId,
}: {
  produtos: Produto[]
  setProdutos: React.Dispatch<React.SetStateAction<Produto[]>>
  setMovimentacoes: React.Dispatch<React.SetStateAction<Movimentacao[]>>
  setEmprestimos: React.Dispatch<React.SetStateAction<Emprestimo[]>>
  condominioId: string
  userId: string
}) {
  const supabase = createClient()
  const router = useRouter()
  const [tipo, setTipo] = useState<'entrada' | 'saida'>('entrada')
  const [produtoId, setProdutoId] = useState('')
  const [quantidade, setQuantidade] = useState('')
  const [motivo, setMotivo] = useState('')
  const [observacao, setObservacao] = useState('')
  const [isSaving, setIsSaving] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')

  // Loan fields (for retornável/misto on saída)
  const [retiradoPorNome, setRetiradoPorNome] = useState('')
  const [dataPrevistaDevolucao, setDataPrevistaDevolucao] = useState('')
  const [isEmprestimo, setIsEmprestimo] = useState(false)

  const selectedProduct = produtos.find(p => p.id === produtoId)
  const showLoanFields = tipo === 'saida' && selectedProduct && (
    selectedProduct.tipo_controle === 'retornavel' ||
    (selectedProduct.tipo_controle === 'misto' && isEmprestimo)
  )
  const showMixedChoice = tipo === 'saida' && selectedProduct?.tipo_controle === 'misto'

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!produtoId) { setError('Selecione um produto'); return }
    const qty = parseInt(quantidade)
    if (!qty || qty <= 0) { setError('Quantidade inválida'); return }

    if (tipo === 'saida' && selectedProduct && qty > selectedProduct.quantidade_atual) {
      setError(`Estoque insuficiente. Disponível: ${selectedProduct.quantidade_atual} ${selectedProduct.unidade}`)
      return
    }

    if (showLoanFields && !retiradoPorNome.trim()) {
      setError('Informe quem está retirando o item')
      return
    }

    setIsSaving(true)
    setError('')
    setSuccess('')

    try {
      const isLoan = showLoanFields || (selectedProduct?.tipo_controle === 'retornavel' && tipo === 'saida')
      const movTipo = isLoan ? 'emprestimo' : tipo

      // 1. Record movement
      const { data: movData, error: movError } = await supabase
        .from('estoque_movimentacoes')
        .insert({
          condominio_id: condominioId,
          produto_id: produtoId,
          tipo: movTipo,
          quantidade: qty,
          motivo: motivo.trim() || null,
          observacao: observacao.trim() || null,
          realizado_por: userId,
        })
        .select('*, estoque_produtos(nome, unidade), perfil:realizado_por(nome_completo)')
        .single()
      if (movError) throw movError

      // 2. Update product quantity
      const adjustment = tipo === 'entrada' ? qty : -qty
      const { error: updError } = await supabase
        .from('estoque_produtos')
        .update({
          quantidade_atual: (selectedProduct?.quantidade_atual || 0) + adjustment,
          updated_at: new Date().toISOString(),
        })
        .eq('id', produtoId)
      if (updError) throw updError

      // 3. If loan, create emprestimo record
      if (isLoan) {
        const { data: empData, error: empError } = await supabase
          .from('estoque_emprestimos')
          .insert({
            condominio_id: condominioId,
            produto_id: produtoId,
            quantidade: qty,
            retirado_por_nome: retiradoPorNome.trim(),
            motivo: motivo.trim() || null,
            observacao: observacao.trim() || null,
            data_retirada: new Date().toISOString(),
            data_prevista_devolucao: dataPrevistaDevolucao || null,
            status: 'emprestado',
            registrado_por: userId,
          })
          .select('*, estoque_produtos(nome, unidade)')
          .single()
        if (empError) throw empError
        if (empData) setEmprestimos(prev => [empData, ...prev])
      }

      // Update local state
      if (movData) setMovimentacoes(prev => [movData, ...prev])
      const novaQuantidade = (selectedProduct?.quantidade_atual || 0) + adjustment
      setProdutos(prev => prev.map(p => p.id === produtoId ? { ...p, quantidade_atual: novaQuantidade } : p))

      // 4. Push notification if stock became critical or zeroed (only on exit)
      if (tipo === 'saida' && selectedProduct) {
        let tipoAlerta: string | null = null
        if (novaQuantidade === 0) {
          tipoAlerta = 'zerado'
        } else if (
          novaQuantidade <= selectedProduct.quantidade_minima &&
          selectedProduct.quantidade_minima > 0 &&
          selectedProduct.quantidade_atual > selectedProduct.quantidade_minima
        ) {
          tipoAlerta = 'critico'
        }

        if (tipoAlerta) {
          // Fire-and-forget — don't block UI
          supabase.functions.invoke('estoque-critico-notify', {
            body: {
              condominio_id: condominioId,
              produto_nome: selectedProduct.nome,
              quantidade_atual: novaQuantidade,
              quantidade_minima: selectedProduct.quantidade_minima,
              unidade: selectedProduct.unidade,
              tipo_alerta: tipoAlerta,
            },
          }).then(res => {
            if (res.error) console.warn('Push estoque notification error:', res.error)
            else console.log('Push estoque notification sent:', res.data)
          })
        }
      }

      setSuccess(`${tipo === 'entrada' ? 'Entrada' : isLoan ? 'Empréstimo' : 'Saída'} registrada com sucesso! ${qty} ${selectedProduct?.unidade || 'un.'} de ${selectedProduct?.nome}`)

      // Reset form
      setProdutoId('')
      setQuantidade('')
      setMotivo('')
      setObservacao('')
      setRetiradoPorNome('')
      setDataPrevistaDevolucao('')
      setIsEmprestimo(false)
      router.refresh()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erro ao registrar movimentação.')
    } finally {
      setIsSaving(false)
    }
  }

  return (
    <div>
      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6 mb-6">
        <h2 className="text-xl font-bold text-gray-800 flex items-center gap-2 mb-1">
          <ArrowLeftRight size={22} className="text-[#FC5931]" />
          Movimentar Estoque
        </h2>
        <p className="text-gray-500 text-sm">Registre entradas e saídas de produtos do estoque.</p>
      </div>

      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6 max-w-2xl mx-auto">
        <form onSubmit={handleSave} className="space-y-5">
          {/* Tipo: Entrada / Saída */}
          <div className="flex justify-center gap-4 mb-2">
            <label className={`flex items-center gap-3 px-6 py-3 rounded-xl border-2 cursor-pointer transition-all ${tipo === 'entrada' ? 'border-green-500 bg-green-50' : 'border-gray-200 hover:border-gray-300'}`}>
              <input type="radio" name="tipo" checked={tipo === 'entrada'} onChange={() => { setTipo('entrada'); setIsEmprestimo(false) }} className="hidden" />
              <ArrowDown size={20} className={tipo === 'entrada' ? 'text-green-600' : 'text-gray-400'} />
              <span className={`font-semibold ${tipo === 'entrada' ? 'text-green-700' : 'text-gray-500'}`}>Entrada</span>
            </label>
            <label className={`flex items-center gap-3 px-6 py-3 rounded-xl border-2 cursor-pointer transition-all ${tipo === 'saida' ? 'border-red-500 bg-red-50' : 'border-gray-200 hover:border-gray-300'}`}>
              <input type="radio" name="tipo" checked={tipo === 'saida'} onChange={() => setTipo('saida')} className="hidden" />
              <ArrowUp size={20} className={tipo === 'saida' ? 'text-red-600' : 'text-gray-400'} />
              <span className={`font-semibold ${tipo === 'saida' ? 'text-red-700' : 'text-gray-500'}`}>Saída</span>
            </label>
          </div>

          {/* Produto */}
          <div className="grid grid-cols-[140px_1fr] items-center gap-4">
            <label className="text-gray-600 font-medium">Produto:</label>
            <select value={produtoId} onChange={e => setProdutoId(e.target.value)} title="Produto" className="w-full border border-gray-300 rounded-xl px-4 py-2 bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] transition-all">
              <option value="">Escolha o produto</option>
              {produtos.filter(p => p.ativo).map(p => (
                <option key={p.id} value={p.id}>
                  {p.nome} (Estoque: {p.quantidade_atual} {p.unidade})
                </option>
              ))}
            </select>
          </div>

          {/* Product info badge */}
          {selectedProduct && (
            <div className="ml-[156px] flex flex-wrap gap-2 text-xs">
              <span className="bg-gray-100 text-gray-600 px-2 py-1 rounded-lg">
                📍 {selectedProduct.estoque_locais?.nome || 'Sem local'}
              </span>
              <span className={`px-2 py-1 rounded-lg ${
                selectedProduct.tipo_controle === 'consumivel' ? 'bg-orange-50 text-orange-600' :
                selectedProduct.tipo_controle === 'retornavel' ? 'bg-purple-50 text-purple-600' :
                'bg-teal-50 text-teal-600'
              }`}>
                {selectedProduct.tipo_controle === 'consumivel' ? '🧴 Consumível' :
                 selectedProduct.tipo_controle === 'retornavel' ? '🔄 Retornável' : '🔀 Misto'}
              </span>
              <span className={`px-2 py-1 rounded-lg font-semibold ${selectedProduct.quantidade_atual <= selectedProduct.quantidade_minima ? 'bg-red-50 text-red-600' : 'bg-green-50 text-green-600'}`}>
                Estoque: {selectedProduct.quantidade_atual} {selectedProduct.unidade}
              </span>
            </div>
          )}

          {/* Mixed choice: consumo ou empréstimo? */}
          {showMixedChoice && (
            <div className="ml-[156px] p-3 bg-teal-50 rounded-xl border border-teal-200">
              <p className="text-sm font-semibold text-teal-800 mb-2">Este produto é misto. Qual tipo de saída?</p>
              <div className="flex gap-3">
                <label className={`flex items-center gap-2 px-4 py-2 rounded-lg border cursor-pointer transition-all ${!isEmprestimo ? 'border-orange-400 bg-orange-50' : 'border-gray-200'}`}>
                  <input type="radio" checked={!isEmprestimo} onChange={() => setIsEmprestimo(false)} className="hidden" />
                  <span className="text-sm">🧴 Consumo (baixa definitiva)</span>
                </label>
                <label className={`flex items-center gap-2 px-4 py-2 rounded-lg border cursor-pointer transition-all ${isEmprestimo ? 'border-purple-400 bg-purple-50' : 'border-gray-200'}`}>
                  <input type="radio" checked={isEmprestimo} onChange={() => setIsEmprestimo(true)} className="hidden" />
                  <span className="text-sm">🔄 Empréstimo (vai devolver)</span>
                </label>
              </div>
            </div>
          )}

          {/* Quantidade */}
          <div className="grid grid-cols-[140px_1fr] items-center gap-4">
            <label className="text-gray-600 font-medium">Quantidade:</label>
            <input type="number" min="1" value={quantidade} onChange={e => setQuantidade(e.target.value)} placeholder="Digite a quantidade" className="w-full border border-gray-300 rounded-xl px-4 py-2 bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] transition-all" />
          </div>

          {/* Loan-specific fields */}
          {showLoanFields && (
            <>
              <div className="grid grid-cols-[140px_1fr] items-center gap-4">
                <label className="text-gray-600 font-medium">Retirado por:</label>
                <input type="text" required value={retiradoPorNome} onChange={e => setRetiradoPorNome(e.target.value)} placeholder="Nome de quem está retirando" className="w-full border border-gray-300 rounded-xl px-4 py-2 bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] transition-all" />
              </div>
              <div className="grid grid-cols-[140px_1fr] items-center gap-4">
                <label className="text-gray-600 font-medium">Devolução prevista:</label>
                <input
                  type="date"
                  title="Data prevista de devolução"
                  value={dataPrevistaDevolucao}
                  onChange={e => setDataPrevistaDevolucao(e.target.value)}
                  className="w-full border border-gray-300 rounded-xl px-4 py-2 bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] transition-all"
                />
              </div>
            </>
          )}

          {/* Motivo */}
          <div className="grid grid-cols-[140px_1fr] items-center gap-4">
            <label className="text-gray-600 font-medium">Motivo {tipo === 'saida' ? 'da saída' : ''}:</label>
            <input type="text" value={motivo} onChange={e => setMotivo(e.target.value)} placeholder="Motivo" className="w-full border border-gray-300 rounded-xl px-4 py-2 bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] transition-all" />
          </div>

          {/* Observação */}
          <div className="grid grid-cols-[140px_1fr] items-start gap-4">
            <label className="text-gray-600 font-medium mt-2">Observação:</label>
            <textarea value={observacao} onChange={e => setObservacao(e.target.value)} placeholder="Escreva aqui uma observação" rows={3} className="w-full border border-gray-300 rounded-xl px-4 py-2 bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] transition-all resize-none" />
          </div>

          {error && <div className="p-3 bg-red-50 text-red-600 border border-red-100 rounded-xl text-sm">{error}</div>}
          {success && <div className="p-3 bg-green-50 text-green-600 border border-green-100 rounded-xl text-sm flex items-center gap-2">✅ {success}</div>}

          <div className="flex items-center justify-center gap-4 mt-6">
            <button type="submit" disabled={isSaving} className="bg-[#FC5931] hover:bg-[#D42F1D] text-white px-8 py-2.5 rounded-2xl font-medium shadow-sm transition-colors flex items-center gap-2 disabled:opacity-50">
              <Save size={16} />
              {isSaving ? 'Salvando...' : 'Salvar'}
            </button>
            <button
              type="button"
              onClick={() => { setProdutoId(''); setQuantidade(''); setMotivo(''); setObservacao(''); setRetiradoPorNome(''); setError(''); setSuccess('') }}
              className="bg-white border border-gray-300 text-gray-700 hover:bg-gray-50 px-8 py-2.5 rounded-2xl font-medium shadow-sm transition-colors"
            >
              Limpar
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
