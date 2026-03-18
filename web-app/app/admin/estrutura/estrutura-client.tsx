'use client'

import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'
import { Building2, Home, Grid3X3, Plus, Trash2, Sparkles, X, AlertCircle } from 'lucide-react'
import GenerateDialog from './generate-dialog'

type Bloco = { id: string; nome_ou_numero: string }
type Apartamento = { id: string; numero: string }
type Unidade = {
  id: string
  bloco_id: string
  apartamento_id: string
  bloqueada: boolean
  bloco_nome: string
  apto_numero: string
}

interface Props {
  condoId: string
  blocos: Bloco[]
  apartamentos: Apartamento[]
  unidades: Unidade[]
}

type Tab = 'blocos' | 'aptos' | 'unidades'

export default function EstruturaClient({ condoId, blocos, apartamentos, unidades }: Props) {
  const router = useRouter()
  const supabase = createClient()
  const [tab, setTab] = useState<Tab>('blocos')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [showAdd, setShowAdd] = useState(false)
  const [addValue, setAddValue] = useState('')
  const [showGenerate, setShowGenerate] = useState(false)

  const tabs: { key: Tab; label: string; icon: React.ReactNode }[] = [
    { key: 'blocos', label: 'Blocos', icon: <Building2 size={16} /> },
    { key: 'aptos', label: 'Aptos', icon: <Home size={16} /> },
    { key: 'unidades', label: 'Unidades', icon: <Grid3X3 size={16} /> },
  ]

  async function addBloco() {
    if (!addValue.trim()) return
    setLoading(true)
    setError(null)
    try {
      const id = crypto.randomUUID()
      await supabase.from('blocos').insert({
        id,
        condominio_id: condoId,
        nome_ou_numero: addValue.trim(),
        created_at: new Date().toISOString(),
      })
      setAddValue('')
      setShowAdd(false)
      router.refresh()
    } catch (e) {
      setError(`Erro ao adicionar bloco: ${e}`)
    } finally {
      setLoading(false)
    }
  }

  async function deleteBloco(blocoId: string) {
    if (!confirm('Excluir este bloco? Todas as unidades vinculadas serão removidas.')) return
    setLoading(true)
    try {
      await supabase.from('unidades').delete().eq('bloco_id', blocoId)
      await supabase.from('blocos').delete().eq('id', blocoId)
      router.refresh()
    } catch (e) {
      setError(`Erro: ${e}`)
    } finally {
      setLoading(false)
    }
  }

  async function addApto() {
    if (!addValue.trim()) return
    setLoading(true)
    setError(null)
    try {
      const id = crypto.randomUUID()
      await supabase.from('apartamentos').insert({
        id,
        condominio_id: condoId,
        numero: addValue.trim(),
        created_at: new Date().toISOString(),
      })
      setAddValue('')
      setShowAdd(false)
      router.refresh()
    } catch (e) {
      setError(`Erro ao adicionar apto: ${e}`)
    } finally {
      setLoading(false)
    }
  }

  async function deleteApto(aptoId: string) {
    if (!confirm('Excluir este apartamento? Unidades vinculadas serão removidas.')) return
    setLoading(true)
    try {
      await supabase.from('unidades').delete().eq('apartamento_id', aptoId)
      await supabase.from('apartamentos').delete().eq('id', aptoId)
      router.refresh()
    } catch (e) {
      setError(`Erro: ${e}`)
    } finally {
      setLoading(false)
    }
  }

  async function deleteUnidade(unidadeId: string) {
    if (!confirm('Excluir esta unidade?')) return
    setLoading(true)
    try {
      await supabase.from('unidades').delete().eq('id', unidadeId)
      router.refresh()
    } catch (e) {
      setError(`Erro: ${e}`)
    } finally {
      setLoading(false)
    }
  }

  async function handleGenerate(selectedBlocos: string[], selectedAptos: string[]) {
    setLoading(true)
    setError(null)
    try {
      const payload = []
      for (const blocoId of selectedBlocos) {
        for (const aptoId of selectedAptos) {
          const unitId = crypto.randomUUID()
          payload.push({
            id: unitId,
            condominio_id: condoId,
            bloco_id: blocoId,
            apartamento_id: aptoId,
            bloqueada: false,
            created_at: new Date().toISOString(),
          })
        }
      }
      await supabase.from('unidades').upsert(payload, {
        onConflict: 'condominio_id,bloco_id,apartamento_id',
      })
      setShowGenerate(false)
      router.refresh()
    } catch (e) {
      setError(`Erro ao gerar unidades: ${e}`)
    } finally {
      setLoading(false)
    }
  }

  const [page, setPage] = useState(1)
  const itemsPerPage = 10

  const filteredBlocos = blocos.filter(b => b.nome_ou_numero !== '0')
  const filteredAptos = apartamentos.filter(a => a.numero !== '0')
  const filteredUnidades = unidades.filter(u => u.bloco_nome !== '0' && u.apto_numero !== '0')

  const totalPages = Math.ceil(filteredUnidades.length / itemsPerPage)
  const paginatedUnidades = filteredUnidades.slice((page - 1) * itemsPerPage, page * itemsPerPage)

  return (
    <div>
      {/* Header */}
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-3">
          <Building2 size={28} className="text-[#FC5931]" />
          Estrutura do Condomínio
        </h1>
        <p className="text-gray-500 mt-1">Gerencie blocos, apartamentos e unidades</p>
      </div>

      {error && (
        <div className="mb-4 bg-red-50 border border-red-200 text-red-700 rounded-xl p-4 flex gap-2 items-center">
          <AlertCircle size={18} />
          <span className="text-sm">{error}</span>
          <button onClick={() => setError(null)} className="ml-auto" title="Fechar erro"><X size={16} /></button>
        </div>
      )}

      {/* Tabs */}
      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
        <div className="flex border-b border-gray-100">
          {tabs.map(t => (
            <button
              key={t.key}
              onClick={() => { setTab(t.key); setShowAdd(false); setPage(1) }}
              className={`flex-1 flex items-center justify-center gap-2 py-4 text-sm font-semibold transition-all ${
                tab === t.key
                  ? 'text-[#FC5931] border-b-2 border-[#FC5931] bg-red-50/30'
                  : 'text-gray-400 hover:text-gray-600'
              }`}
            >
              {t.icon}
              {t.label}
              <span className={`text-xs px-2 py-0.5 rounded-full ${
                tab === t.key ? 'bg-[#FC5931]/10 text-[#FC5931]' : 'bg-gray-100 text-gray-400'
              }`}>
                {t.key === 'blocos' ? filteredBlocos.length : t.key === 'aptos' ? filteredAptos.length : filteredUnidades.length}
              </span>
            </button>
          ))}
        </div>

        <div className="p-6">
          {/* ═══ BLOCOS TAB ═══ */}
          {tab === 'blocos' && (
            <div>
              <div className="flex justify-between items-center mb-4">
                <h2 className="text-lg font-bold text-gray-800">Blocos</h2>
                <button
                  onClick={() => setShowAdd(!showAdd)}
                  className="flex items-center gap-2 px-4 py-2 bg-[#FC5931] text-white rounded-xl text-sm font-medium hover:bg-[#e04a25] transition-colors"
                >
                  <Plus size={16} />
                  Adicionar Bloco
                </button>
              </div>

              {showAdd && (
                <div className="mb-4 flex gap-2">
                  <input
                    type="text"
                    placeholder="Nome ou número do bloco (ex: A, B, 1, 2)"
                    value={addValue}
                    onChange={e => setAddValue(e.target.value)}
                    onKeyDown={e => e.key === 'Enter' && addBloco()}
                    className="flex-1 px-4 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931]"
                    autoFocus
                  />
                  <button
                    onClick={addBloco}
                    disabled={loading || !addValue.trim()}
                    className="px-6 py-2.5 bg-[#FC5931] text-white rounded-xl text-sm font-medium hover:bg-[#e04a25] disabled:opacity-50 transition-colors"
                  >
                    {loading ? 'Salvando...' : 'Salvar'}
                  </button>
                </div>
              )}

              {filteredBlocos.length === 0 ? (
                <div className="text-center py-16 text-gray-400">
                  <Building2 size={48} className="mx-auto mb-3 opacity-30" />
                  <p>Nenhum bloco cadastrado</p>
                </div>
              ) : (
                <div className="space-y-2">
                  {filteredBlocos.map(b => (
                    <div key={b.id} className="flex items-center justify-between p-4 bg-gray-50 rounded-xl hover:bg-gray-100 transition-colors">
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 bg-white rounded-lg flex items-center justify-center border border-gray-200">
                          <Building2 size={18} className="text-[#FC5931]" />
                        </div>
                        <span className="font-semibold text-gray-800">{b.nome_ou_numero}</span>
                      </div>
                      <button
                        onClick={() => deleteBloco(b.id)}
                        className="p-2 text-red-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                        title="Excluir bloco"
                      >
                        <Trash2 size={16} />
                      </button>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}

          {/* ═══ APTOS TAB ═══ */}
          {tab === 'aptos' && (
            <div>
              <div className="flex justify-between items-center mb-4">
                <h2 className="text-lg font-bold text-gray-800">Apartamentos</h2>
                <button
                  onClick={() => setShowAdd(!showAdd)}
                  className="flex items-center gap-2 px-4 py-2 bg-[#FC5931] text-white rounded-xl text-sm font-medium hover:bg-[#e04a25] transition-colors"
                >
                  <Plus size={16} />
                  Adicionar Apto
                </button>
              </div>

              {showAdd && (
                <div className="mb-4 flex gap-2">
                  <input
                    type="text"
                    placeholder="Número do apartamento (ex: 101, 102)"
                    value={addValue}
                    onChange={e => setAddValue(e.target.value)}
                    onKeyDown={e => e.key === 'Enter' && addApto()}
                    className="flex-1 px-4 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931]"
                    autoFocus
                  />
                  <button
                    onClick={addApto}
                    disabled={loading || !addValue.trim()}
                    className="px-6 py-2.5 bg-[#FC5931] text-white rounded-xl text-sm font-medium hover:bg-[#e04a25] disabled:opacity-50 transition-colors"
                  >
                    {loading ? 'Salvando...' : 'Salvar'}
                  </button>
                </div>
              )}

              {filteredAptos.length === 0 ? (
                <div className="text-center py-16 text-gray-400">
                  <Home size={48} className="mx-auto mb-3 opacity-30" />
                  <p>Nenhum apartamento cadastrado</p>
                </div>
              ) : (
                <div className="grid grid-cols-4 sm:grid-cols-6 md:grid-cols-8 lg:grid-cols-10 gap-3">
                  {filteredAptos.map(a => (
                    <div key={a.id} className="relative group bg-gray-50 rounded-xl p-3 text-center hover:bg-gray-100 transition-colors border border-gray-100">
                      <Home size={18} className="mx-auto text-[#FC5931] mb-1" />
                      <span className="text-sm font-bold text-[#FC5931]">{a.numero}</span>
                      <button
                        onClick={() => deleteApto(a.id)}
                        className="absolute -top-1 -right-1 w-5 h-5 bg-red-500 text-white rounded-full flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity"
                        title="Excluir"
                      >
                        <X size={10} />
                      </button>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}

          {/* ═══ UNIDADES TAB ═══ */}
          {tab === 'unidades' && (
            <div>
              <div className="flex justify-between items-center mb-4">
                <h2 className="text-lg font-bold text-gray-800">Unidades</h2>
                {filteredBlocos.length > 0 && filteredAptos.length > 0 && (
                  <button
                    onClick={() => setShowGenerate(true)}
                    className="flex items-center gap-2 px-4 py-2 bg-[#FC5931] text-white rounded-xl text-sm font-medium hover:bg-[#e04a25] transition-colors"
                  >
                    <Sparkles size={16} />
                    Gerar Unidades
                  </button>
                )}
              </div>

              {filteredBlocos.length === 0 || filteredAptos.length === 0 ? (
                <div className="text-center py-16 text-gray-400">
                  <AlertCircle size={48} className="mx-auto mb-3 opacity-30" />
                  <p>Cadastre pelo menos 1 bloco e 1 apartamento<br />para poder gerar as unidades.</p>
                </div>
              ) : filteredUnidades.length === 0 ? (
                <div className="text-center py-16 text-gray-400">
                  <Grid3X3 size={48} className="mx-auto mb-3 opacity-30" />
                  <p>Nenhuma unidade gerada ainda</p>
                  <button
                    onClick={() => setShowGenerate(true)}
                    className="mt-4 px-6 py-2.5 bg-[#FC5931] text-white rounded-xl text-sm font-medium hover:bg-[#e04a25]"
                  >
                    <Sparkles size={14} className="inline mr-2" />
                    Gerar Unidades
                  </button>
                </div>
              ) : (
                <div className="space-y-4">
                  <div className="overflow-x-auto">
                    <table className="w-full">
                      <thead>
                        <tr className="border-b border-gray-100">
                          <th className="text-left pb-3 text-xs font-semibold text-gray-400 uppercase tracking-wider">Bloco</th>
                          <th className="text-left pb-3 text-xs font-semibold text-gray-400 uppercase tracking-wider">Apto</th>
                          <th className="text-left pb-3 text-xs font-semibold text-gray-400 uppercase tracking-wider">Status</th>
                          <th className="text-right pb-3 text-xs font-semibold text-gray-400 uppercase tracking-wider">Ações</th>
                        </tr>
                      </thead>
                      <tbody>
                        {paginatedUnidades.map(u => (
                          <tr key={u.id} className="border-b border-gray-50 hover:bg-gray-50/50 transition-colors">
                            <td className="py-3">
                              <div className="flex items-center gap-2">
                                <Building2 size={14} className="text-[#FC5931]" />
                                <span className="font-medium text-gray-800">{u.bloco_nome}</span>
                              </div>
                            </td>
                            <td className="py-3">
                              <div className="flex items-center gap-2">
                                <Home size={14} className="text-gray-400" />
                                <span className="text-gray-700">{u.apto_numero}</span>
                              </div>
                            </td>
                            <td className="py-3">
                              <span className={`text-xs px-2 py-1 rounded-full font-medium ${
                                u.bloqueada ? 'bg-red-50 text-red-600' : 'bg-green-50 text-green-600'
                              }`}>
                                {u.bloqueada ? 'Bloqueada' : 'Ativa'}
                              </span>
                            </td>
                            <td className="py-3 text-right">
                              <button
                                onClick={() => deleteUnidade(u.id)}
                                className="p-1.5 text-red-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                                title="Excluir unidade"
                              >
                                <Trash2 size={14} />
                              </button>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                  {totalPages > 1 && (
                    <div className="flex items-center justify-between mt-4 border-t border-gray-100 pt-4">
                      <span className="text-sm text-gray-500">
                        Mostrando {(page - 1) * itemsPerPage + 1} até {Math.min(page * itemsPerPage, filteredUnidades.length)} de {filteredUnidades.length}
                      </span>
                      <div className="flex gap-2">
                        <button
                          onClick={() => setPage(p => Math.max(1, p - 1))}
                          disabled={page === 1}
                          className="px-3 py-1 text-sm border border-gray-200 rounded-lg hover:bg-gray-50 disabled:opacity-50"
                        >
                          Anterior
                        </button>
                        <button
                          onClick={() => setPage(p => Math.min(totalPages, p + 1))}
                          disabled={page === totalPages}
                          className="px-3 py-1 text-sm border border-gray-200 rounded-lg hover:bg-gray-50 disabled:opacity-50"
                        >
                          Próxima
                        </button>
                      </div>
                    </div>
                  )}
                </div>
              )}
            </div>
          )}
        </div>
      </div>

      {/* Generate Dialog */}
      {showGenerate && (
        <GenerateDialog
          blocos={filteredBlocos}
          apartamentos={filteredAptos}
          unidades={unidades}
          loading={loading}
          onGenerate={handleGenerate}
          onClose={() => setShowGenerate(false)}
        />
      )}
    </div>
  )
}
