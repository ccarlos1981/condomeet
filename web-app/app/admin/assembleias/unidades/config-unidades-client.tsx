'use client'
import { useState, useCallback } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import {
  ArrowLeft, Building2, Gavel, Save, RotateCcw,
  ShieldCheck, ShieldOff, Ban, CheckCircle2,
  Users, Scale, Smartphone, AlertTriangle, Info, Filter
} from 'lucide-react'

interface Unidade {
  id: string
  bloco: string
  apartamento: string
  fracao_ideal: number
  bloqueada_assembleia: boolean
  bloqueada_app: boolean
  moradores_count: number
}

export default function ConfigUnidadesClient({
  condoNome,
  tipoEstrutura,
  unidades: initialUnidades,
}: {
  condoNome: string
  tipoEstrutura: string
  unidades: Unidade[]
}) {
  const router = useRouter()
  const supabase = createClient()
  const [unidades, setUnidades] = useState<Unidade[]>(initialUnidades)
  const [saving, setSaving] = useState(false)
  const [saved, setSaved] = useState(false)
  const [changed, setChanged] = useState(false)
  const [filterBloco, setFilterBloco] = useState('')
  const [filterApto, setFilterApto] = useState('')

  // Track changes
  const markChanged = useCallback(() => {
    setChanged(true)
    setSaved(false)
  }, [])

  // Update fração ideal for a unit
  function updateFracao(id: string, value: number) {
    setUnidades(prev => prev.map(u =>
      u.id === id ? { ...u, fracao_ideal: value } : u
    ))
    markChanged()
  }

  // Toggle bloqueada_assembleia
  function toggleBloqueioAssembleia(id: string) {
    setUnidades(prev => prev.map(u =>
      u.id === id ? { ...u, bloqueada_assembleia: !u.bloqueada_assembleia } : u
    ))
    markChanged()
  }

  // Toggle bloqueada_app
  function toggleBloqueioApp(id: string) {
    setUnidades(prev => prev.map(u =>
      u.id === id ? { ...u, bloqueada_app: !u.bloqueada_app } : u
    ))
    markChanged()
  }

  // Preencher todas com peso 1
  function resetAllFracao() {
    setUnidades(prev => prev.map(u => ({ ...u, fracao_ideal: 1.00 })))
    markChanged()
  }

  // Desbloquear todas (assembleia)
  function unlockAllAssembleia() {
    setUnidades(prev => prev.map(u => ({ ...u, bloqueada_assembleia: false })))
    markChanged()
  }

  // Save all changes
  async function saveChanges() {
    setSaving(true)
    try {
      const updates = unidades.map(u =>
        supabase
          .from('unidades')
          .update({
            fracao_ideal: u.fracao_ideal,
            bloqueada_assembleia: u.bloqueada_assembleia,
            bloqueada_app: u.bloqueada_app,
          })
          .eq('id', u.id)
      )

      await Promise.all(updates)
      setSaved(true)
      setChanged(false)

      // refresh server data
      router.refresh()
    } catch (e) {
      alert('Erro ao salvar: ' + e)
    } finally {
      setSaving(false)
    }
  }

  // Stats
  const totalUnidades = unidades.length
  const bloqAssembleia = unidades.filter(u => u.bloqueada_assembleia).length
  const bloqApp = unidades.filter(u => u.bloqueada_app).length
  const pesoTotal = unidades.reduce((sum, u) => sum + (u.bloqueada_assembleia ? 0 : u.fracao_ideal), 0)

  const labelUnidade = tipoEstrutura === 'casas' ? 'Casa' : 'Apto'

  // Unique values for filters
  const blocos = [...new Set(unidades.map(u => u.bloco))].sort((a, b) => a.localeCompare(b, undefined, { numeric: true }))
  const aptos = [...new Set(
    unidades
      .filter(u => !filterBloco || u.bloco === filterBloco)
      .map(u => u.apartamento)
  )].sort((a, b) => a.localeCompare(b, undefined, { numeric: true }))

  // Filtered unidades
  const filteredUnidades = unidades.filter(u => {
    if (filterBloco && u.bloco !== filterBloco) return false
    if (filterApto && u.apartamento !== filterApto) return false
    return true
  })

  return (
    <div className="max-w-5xl mx-auto px-4 py-8">

      {/* HEADER */}
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-3">
          <button
            onClick={() => router.push('/admin/assembleias')}
            className="p-2 rounded-lg hover:bg-gray-100 transition-colors"
          >
            <ArrowLeft size={20} className="text-gray-600" />
          </button>
          <div>
            <h1 className="text-2xl font-bold text-gray-800 flex items-center gap-3">
              <Building2 size={24} className="text-[#FC5931]" />
              Configurar Unidades
            </h1>
            <p className="text-sm text-gray-500">{condoNome} · {totalUnidades} unidades</p>
          </div>
        </div>

        <button
          onClick={saveChanges}
          disabled={!changed || saving}
          className={`flex items-center gap-2 px-6 py-2.5 rounded-xl font-medium text-sm transition-all ${
            changed
              ? 'bg-[#FC5931] text-white hover:bg-[#e04a2a] shadow-lg shadow-[#FC5931]/20'
              : saved
              ? 'bg-green-500 text-white'
              : 'bg-gray-100 text-gray-400 cursor-not-allowed'
          }`}
        >
          {saving ? (
            <>Salvando...</>
          ) : saved ? (
            <><CheckCircle2 size={16} /> Salvo!</>
          ) : (
            <><Save size={16} /> Salvar Alterações</>
          )}
        </button>
      </div>

      {/* INFO TIP */}
      <div className="flex items-start gap-3 p-4 bg-blue-50 rounded-xl text-sm text-blue-700 mb-6">
        <Info size={18} className="mt-0.5 shrink-0" />
        <div>
          <p className="font-medium">Configuração de unidades para Assembleias</p>
          <p className="text-xs mt-1 text-blue-600">
            Defina o peso do voto (fração ideal) de cada unidade e controle os bloqueios.
            Unidades bloqueadas para assembleia não poderão votar. Unidades bloqueadas no app
            impedem o acesso de todos os moradores vinculados.
          </p>
        </div>
      </div>

      {/* STATS */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 mb-6">
        <div className="bg-white rounded-xl border border-gray-100 p-4 shadow-sm">
          <div className="flex items-center gap-2 mb-1">
            <Building2 size={16} className="text-blue-500" />
            <span className="text-xs text-gray-500">Total</span>
          </div>
          <p className="text-2xl font-bold text-gray-800">{totalUnidades}</p>
        </div>
        <div className="bg-white rounded-xl border border-gray-100 p-4 shadow-sm">
          <div className="flex items-center gap-2 mb-1">
            <Scale size={16} className="text-green-500" />
            <span className="text-xs text-gray-500">Peso Total Votação</span>
          </div>
          <p className="text-2xl font-bold text-gray-800">{pesoTotal.toFixed(2)}</p>
        </div>
        <div className="bg-white rounded-xl border border-gray-100 p-4 shadow-sm">
          <div className="flex items-center gap-2 mb-1">
            <Gavel size={16} className="text-orange-500" />
            <span className="text-xs text-gray-500">Bloq. Assembleia</span>
          </div>
          <p className="text-2xl font-bold text-orange-600">{bloqAssembleia}</p>
        </div>
        <div className="bg-white rounded-xl border border-gray-100 p-4 shadow-sm">
          <div className="flex items-center gap-2 mb-1">
            <Smartphone size={16} className="text-red-500" />
            <span className="text-xs text-gray-500">Bloq. App</span>
          </div>
          <p className="text-2xl font-bold text-red-600">{bloqApp}</p>
        </div>
      </div>

      {/* QUICK ACTIONS + FILTERS */}
      <div className="flex gap-3 mb-6 flex-wrap items-center">
        <button
          onClick={resetAllFracao}
          className="flex items-center gap-2 px-4 py-2 bg-white border border-gray-200 rounded-xl text-sm font-medium text-gray-700 hover:bg-gray-50 transition-colors"
        >
          <RotateCcw size={14} />
          Preencher todas com peso 1
        </button>
        <button
          onClick={unlockAllAssembleia}
          className="flex items-center gap-2 px-4 py-2 bg-white border border-gray-200 rounded-xl text-sm font-medium text-gray-700 hover:bg-gray-50 transition-colors"
        >
          <ShieldCheck size={14} />
          Desbloquear todas (Assembleia)
        </button>

        <div className="ml-auto flex gap-3">
          <div className="relative">
            <select
              value={filterBloco}
              onChange={e => { setFilterBloco(e.target.value); setFilterApto('') }}
              className="appearance-none flex items-center gap-2 pl-9 pr-4 py-2 bg-white border border-gray-200 rounded-xl text-sm font-medium text-gray-700 hover:bg-gray-50 transition-colors cursor-pointer outline-none"
              title="Filtrar por bloco"
            >
              <option value="">Todos Blocos</option>
              {blocos.map(b => (
                <option key={b} value={b}>Bloco {b}</option>
              ))}
            </select>
            <Filter size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none" />
          </div>
          <div className="relative">
            <select
              value={filterApto}
              onChange={e => setFilterApto(e.target.value)}
              className="appearance-none flex items-center gap-2 pl-9 pr-4 py-2 bg-white border border-gray-200 rounded-xl text-sm font-medium text-gray-700 hover:bg-gray-50 transition-colors cursor-pointer outline-none"
              title="Filtrar por apartamento"
            >
              <option value="">{`Todos ${labelUnidade}s`}</option>
              {aptos.map(a => (
                <option key={a} value={a}>{labelUnidade} {a}</option>
              ))}
            </select>
            <Filter size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none" />
          </div>
        </div>
      </div>

      {/* TABLE */}
      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
        <table className="w-full">
          <thead>
            <tr className="bg-gray-50 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide">
              <th className="px-4 py-3">Bloco</th>
              <th className="px-4 py-3">{labelUnidade}</th>
              <th className="px-4 py-3 text-center">
                <div className="flex items-center justify-center gap-1">
                  <Users size={12} />
                  Moradores
                </div>
              </th>
              <th className="px-4 py-3 text-center">
                <div className="flex items-center justify-center gap-1">
                  <Scale size={12} />
                  Peso do Voto
                </div>
              </th>
              <th className="px-4 py-3 text-center">
                <div className="flex items-center justify-center gap-1">
                  <Gavel size={12} />
                  Bloq. Assembleia
                </div>
              </th>
              <th className="px-4 py-3 text-center">
                <div className="flex items-center justify-center gap-1">
                  <Smartphone size={12} />
                  Bloq. App
                </div>
              </th>
            </tr>
          </thead>
          <tbody>
            {filteredUnidades.map((u, idx) => (
              <tr
                key={u.id}
                className={`border-t border-gray-50 hover:bg-gray-50/50 transition-colors ${
                  u.bloqueada_app ? 'bg-red-50/30' : u.bloqueada_assembleia ? 'bg-orange-50/30' : ''
                }`}
              >
                {/* Bloco */}
                <td className="px-4 py-3">
                  <span className="text-sm font-medium text-gray-800">{u.bloco}</span>
                </td>

                {/* Apartamento */}
                <td className="px-4 py-3">
                  <span className="text-sm font-medium text-gray-800">{u.apartamento}</span>
                </td>

                {/* Moradores */}
                <td className="px-4 py-3 text-center">
                  <span className={`inline-flex items-center justify-center w-7 h-7 rounded-full text-xs font-bold ${
                    u.moradores_count > 0 ? 'bg-blue-100 text-blue-700' : 'bg-gray-100 text-gray-400'
                  }`}>
                    {u.moradores_count}
                  </span>
                </td>

                {/* Peso do Voto */}
                <td className="px-4 py-3 text-center">
                  <input
                    type="number"
                    step="0.01"
                    min="0"
                    max="99"
                    value={u.fracao_ideal}
                    onChange={e => updateFracao(u.id, parseFloat(e.target.value) || 0)}
                    className={`w-20 px-2 py-1.5 rounded-lg border text-center text-sm font-medium outline-none transition-colors ${
                      u.bloqueada_assembleia
                        ? 'border-gray-200 bg-gray-100 text-gray-400 cursor-not-allowed'
                        : u.fracao_ideal !== 1 
                          ? 'border-blue-300 bg-blue-50 text-blue-700 focus:ring-2 focus:ring-blue-200'
                          : 'border-gray-200 text-gray-700 focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931]'
                    }`}
                    disabled={u.bloqueada_assembleia}
                    title="Peso do voto desta unidade"
                  />
                </td>

                {/* Bloqueio Assembleia */}
                <td className="px-4 py-3 text-center">
                  <button
                    onClick={() => toggleBloqueioAssembleia(u.id)}
                    className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold transition-all ${
                      u.bloqueada_assembleia
                        ? 'bg-orange-100 text-orange-700 hover:bg-orange-200'
                        : 'bg-green-50 text-green-700 hover:bg-green-100'
                    }`}
                    title={u.bloqueada_assembleia ? 'Desbloquear para assembleia' : 'Bloquear para assembleia'}
                  >
                    {u.bloqueada_assembleia ? (
                      <><ShieldOff size={13} /> Bloqueada</>
                    ) : (
                      <><ShieldCheck size={13} /> Liberada</>
                    )}
                  </button>
                </td>

                {/* Bloqueio App */}
                <td className="px-4 py-3 text-center">
                  <button
                    onClick={() => toggleBloqueioApp(u.id)}
                    className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold transition-all ${
                      u.bloqueada_app
                        ? 'bg-red-100 text-red-700 hover:bg-red-200'
                        : 'bg-green-50 text-green-700 hover:bg-green-100'
                    }`}
                    title={u.bloqueada_app ? 'Desbloquear acesso ao app' : 'Bloquear acesso ao app'}
                  >
                    {u.bloqueada_app ? (
                      <><Ban size={13} /> Bloqueada</>
                    ) : (
                      <><CheckCircle2 size={13} /> Liberada</>
                    )}
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Warning about App Block */}
      {bloqApp > 0 && (
        <div className="flex items-start gap-3 p-4 bg-red-50 rounded-xl text-sm text-red-700 mt-6">
          <AlertTriangle size={18} className="mt-0.5 shrink-0" />
          <div>
            <p className="font-medium">⚠️ {bloqApp} unidade(s) com bloqueio de app</p>
            <p className="text-xs mt-1 text-red-600">
              Os moradores dessas unidades perderão acesso completo ao aplicativo.
              Use esta opção apenas em situações graves (ex: inadimplência prolongada).
            </p>
          </div>
        </div>
      )}

      {/* Floating save bar when there are changes */}
      {changed && (
        <div className="fixed bottom-6 left-1/2 -translate-x-1/2 z-50 bg-gray-900 text-white px-6 py-3 rounded-2xl shadow-2xl flex items-center gap-4 animate-slide-up">
          <span className="text-sm">Você tem alterações não salvas</span>
          <button
            onClick={saveChanges}
            disabled={saving}
            className="px-4 py-1.5 bg-[#FC5931] rounded-lg text-sm font-semibold hover:bg-[#e04a2a] transition-colors"
          >
            {saving ? 'Salvando...' : 'Salvar'}
          </button>
        </div>
      )}
    </div>
  )
}
