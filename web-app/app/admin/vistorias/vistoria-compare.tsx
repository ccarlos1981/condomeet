'use client'
import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import {
  ArrowLeft, CheckCircle2, AlertTriangle, XCircle, MinusCircle,
  Equal, TrendingUp, TrendingDown
} from 'lucide-react'

interface SecaoData { id: string; nome: string; icone_emoji: string; posicao: number }
interface ItemData { id: string; secao_id: string; nome: string; status: string; observacao: string | null; posicao: number }
interface FotoData { id: string; item_id: string; foto_url: string }

const STATUS_LABELS: Record<string, { label: string; color: string; bg: string; icon: React.ReactNode }> = {
  ok:         { label: 'OK',         color: 'text-green-700', bg: 'bg-green-50', icon: <CheckCircle2 size={14} /> },
  atencao:    { label: 'Atenção',    color: 'text-yellow-700', bg: 'bg-yellow-50', icon: <AlertTriangle size={14} /> },
  danificado: { label: 'Danificado', color: 'text-red-700', bg: 'bg-red-50', icon: <XCircle size={14} /> },
  nao_existe: { label: 'Não existe', color: 'text-gray-500', bg: 'bg-gray-50', icon: <MinusCircle size={14} /> },
}

const STATUS_RANK: Record<string, number> = { ok: 0, nao_existe: 1, atencao: 2, danificado: 3 }

interface CompareProps {
  entradaId: string
  saidaId: string
  entradaTitulo: string
  saidaTitulo: string
  onBack: () => void
}

export default function VistoriaCompare({ entradaId, saidaId, entradaTitulo, saidaTitulo, onBack }: CompareProps) {
  const supabase = createClient()
  const [loading, setLoading] = useState(true)

  const [entradaSecoes, setEntradaSecoes] = useState<SecaoData[]>([])
  const [entradaItens, setEntradaItens] = useState<ItemData[]>([])
  const [entradaFotos, setEntradaFotos] = useState<FotoData[]>([])

  const [saidaSecoes, setSaidaSecoes] = useState<SecaoData[]>([])
  const [saidaItens, setSaidaItens] = useState<ItemData[]>([])
  const [saidaFotos, setSaidaFotos] = useState<FotoData[]>([])

  const [lightboxUrl, setLightboxUrl] = useState<string | null>(null)

  useEffect(() => {
    loadBoth()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  async function loadData(vistoriaId: string) {
    const { data: secoes } = await supabase.from('vistoria_secoes').select('*').eq('vistoria_id', vistoriaId).order('posicao')
    const secIds = (secoes ?? []).map(s => s.id)
    const { data: itens } = secIds.length > 0
      ? await supabase.from('vistoria_itens').select('*').in('secao_id', secIds).order('posicao')
      : { data: [] }
    const itemIds = (itens ?? []).map(i => i.id)
    const { data: fotos } = itemIds.length > 0
      ? await supabase.from('vistoria_fotos').select('*').in('item_id', itemIds).order('posicao')
      : { data: [] }
    return { secoes: secoes ?? [], itens: itens ?? [], fotos: fotos ?? [] }
  }

  async function loadBoth() {
    setLoading(true)
    const [entrada, saida] = await Promise.all([loadData(entradaId), loadData(saidaId)])
    setEntradaSecoes(entrada.secoes)
    setEntradaItens(entrada.itens)
    setEntradaFotos(entrada.fotos)
    setSaidaSecoes(saida.secoes)
    setSaidaItens(saida.itens)
    setSaidaFotos(saida.fotos)
    setLoading(false)
  }

  if (loading) {
    return (
      <div className="max-w-7xl mx-auto py-20 text-center text-gray-400">
        <div className="animate-spin w-8 h-8 border-4 border-[#FC5931] border-t-transparent rounded-full mx-auto mb-4" />
        <p>Carregando comparação...</p>
      </div>
    )
  }

  // Match sections by name
  const allSecaoNames = [...new Set([
    ...entradaSecoes.map(s => s.nome),
    ...saidaSecoes.map(s => s.nome),
  ])]

  // Compute stats
  let improved = 0, worsened = 0, unchanged = 0

  allSecaoNames.forEach(nome => {
    const eSec = entradaSecoes.find(s => s.nome === nome)
    const sSec = saidaSecoes.find(s => s.nome === nome)
    if (!eSec || !sSec) return

    const eItens = entradaItens.filter(i => i.secao_id === eSec.id)
    const sItens = saidaItens.filter(i => i.secao_id === sSec.id)

    eItens.forEach(eItem => {
      const sItem = sItens.find(si => si.nome === eItem.nome)
      if (!sItem) return
      const eRank = STATUS_RANK[eItem.status] ?? 0
      const sRank = STATUS_RANK[sItem.status] ?? 0
      if (sRank < eRank) improved++
      else if (sRank > eRank) worsened++
      else unchanged++
    })
  })

  return (
    <div className="max-w-7xl mx-auto py-4 px-4">
      {/* Lightbox */}
      {lightboxUrl && (
        <div className="fixed inset-0 bg-black/80 z-50 flex items-center justify-center p-4" onClick={() => setLightboxUrl(null)}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={lightboxUrl} alt="Foto" className="max-w-full max-h-full object-contain rounded-2xl" />
        </div>
      )}

      {/* Header */}
      <button onClick={onBack} className="flex items-center gap-2 text-gray-500 hover:text-gray-700 text-sm mb-4">
        <ArrowLeft size={16} /> Voltar
      </button>

      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-5 mb-6">
        <h1 className="text-xl font-bold text-gray-900 mb-1">🔄 Comparação de Vistorias</h1>
        <p className="text-sm text-gray-500">Entrada × Saída — diferenças item por item</p>

        {/* Summary stats */}
        <div className="grid grid-cols-3 gap-3 mt-4">
          <div className="bg-green-50 border border-green-200 rounded-xl p-3 text-center">
            <TrendingUp size={18} className="text-green-600 mx-auto mb-1" />
            <p className="text-lg font-bold text-green-700">{improved}</p>
            <p className="text-xs text-green-600">Melhorou</p>
          </div>
          <div className="bg-gray-50 border border-gray-200 rounded-xl p-3 text-center">
            <Equal size={18} className="text-gray-500 mx-auto mb-1" />
            <p className="text-lg font-bold text-gray-700">{unchanged}</p>
            <p className="text-xs text-gray-500">Sem alteração</p>
          </div>
          <div className="bg-red-50 border border-red-200 rounded-xl p-3 text-center">
            <TrendingDown size={18} className="text-red-600 mx-auto mb-1" />
            <p className="text-lg font-bold text-red-700">{worsened}</p>
            <p className="text-xs text-red-600">Piorou</p>
          </div>
        </div>
      </div>

      {/* Column Headers */}
      <div className="grid grid-cols-2 gap-4 mb-4">
        <div className="bg-blue-50 border border-blue-200 rounded-xl px-4 py-3">
          <p className="text-xs font-bold text-blue-600 uppercase tracking-wider">📥 Entrada</p>
          <p className="text-sm font-bold text-gray-800 truncate">{entradaTitulo}</p>
        </div>
        <div className="bg-orange-50 border border-orange-200 rounded-xl px-4 py-3">
          <p className="text-xs font-bold text-orange-600 uppercase tracking-wider">📤 Saída</p>
          <p className="text-sm font-bold text-gray-800 truncate">{saidaTitulo}</p>
        </div>
      </div>

      {/* Section by section comparison */}
      {allSecaoNames.map(nome => {
        const eSec = entradaSecoes.find(s => s.nome === nome)
        const sSec = saidaSecoes.find(s => s.nome === nome)
        const emoji = eSec?.icone_emoji ?? sSec?.icone_emoji ?? '🏠'

        const eItens = eSec ? entradaItens.filter(i => i.secao_id === eSec.id).sort((a, b) => a.posicao - b.posicao) : []
        const sItens = sSec ? saidaItens.filter(i => i.secao_id === sSec.id).sort((a, b) => a.posicao - b.posicao) : []
        const allItemNames = [...new Set([...eItens.map(i => i.nome), ...sItens.map(i => i.nome)])]

        return (
          <div key={nome} className="bg-white rounded-2xl shadow-sm border border-gray-100 mb-4 overflow-hidden">
            <div className="px-5 py-3 bg-gray-50 border-b border-gray-100">
              <h2 className="text-base font-bold text-gray-800">{emoji} {nome}</h2>
            </div>

            <div className="divide-y divide-gray-50">
              {allItemNames.map(itemName => {
                const eItem = eItens.find(i => i.nome === itemName)
                const sItem = sItens.find(i => i.nome === itemName)
                const eSt = STATUS_LABELS[eItem?.status ?? 'nao_existe'] ?? STATUS_LABELS.nao_existe
                const sSt = STATUS_LABELS[sItem?.status ?? 'nao_existe'] ?? STATUS_LABELS.nao_existe

                const eRank = STATUS_RANK[eItem?.status ?? 'nao_existe'] ?? 0
                const sRank = STATUS_RANK[sItem?.status ?? 'nao_existe'] ?? 0
                const diff = sRank - eRank
                const diffIcon = diff < 0 ? <TrendingUp size={14} className="text-green-500" />
                  : diff > 0 ? <TrendingDown size={14} className="text-red-500" />
                  : null

                const eFotos = eItem ? entradaFotos.filter(f => f.item_id === eItem.id) : []
                const sFotos = sItem ? saidaFotos.filter(f => f.item_id === sItem.id) : []

                const rowBg = diff > 0 ? 'bg-red-50/40' : diff < 0 ? 'bg-green-50/40' : ''

                return (
                  <div key={itemName} className={`px-5 py-3 ${rowBg}`}>
                    {/* Item name + diff indicator */}
                    <div className="flex items-center gap-2 mb-2">
                      <span className="font-medium text-gray-800 text-sm">{itemName}</span>
                      {diffIcon}
                    </div>

                    {/* Two-column comparison */}
                    <div className="grid grid-cols-2 gap-4">
                      {/* Entrada */}
                      <div>
                        {eItem ? (
                          <>
                            <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-lg text-xs font-bold ${eSt.bg} ${eSt.color}`}>
                              {eSt.icon} {eSt.label}
                            </span>
                            {eItem.observacao && (
                              <p className="text-xs text-gray-500 mt-1 bg-gray-50 rounded-lg px-2 py-1">💬 {eItem.observacao}</p>
                            )}
                            {eFotos.length > 0 && (
                              <div className="flex gap-1 mt-2">
                                {eFotos.slice(0, 3).map(f => (
                                  <button key={f.id} onClick={() => setLightboxUrl(f.foto_url)} className="w-14 h-14 rounded-lg overflow-hidden border border-gray-200 hover:opacity-80">
                                    {/* eslint-disable-next-line @next/next/no-img-element */}
                                    <img src={f.foto_url} alt="" className="w-full h-full object-cover" />
                                  </button>
                                ))}
                                {eFotos.length > 3 && (
                                  <span className="w-14 h-14 rounded-lg bg-gray-100 flex items-center justify-center text-xs text-gray-400">
                                    +{eFotos.length - 3}
                                  </span>
                                )}
                              </div>
                            )}
                          </>
                        ) : (
                          <span className="text-xs text-gray-300 italic">Não avaliado</span>
                        )}
                      </div>

                      {/* Saída */}
                      <div>
                        {sItem ? (
                          <>
                            <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-lg text-xs font-bold ${sSt.bg} ${sSt.color}`}>
                              {sSt.icon} {sSt.label}
                            </span>
                            {sItem.observacao && (
                              <p className="text-xs text-gray-500 mt-1 bg-gray-50 rounded-lg px-2 py-1">💬 {sItem.observacao}</p>
                            )}
                            {sFotos.length > 0 && (
                              <div className="flex gap-1 mt-2">
                                {sFotos.slice(0, 3).map(f => (
                                  <button key={f.id} onClick={() => setLightboxUrl(f.foto_url)} className="w-14 h-14 rounded-lg overflow-hidden border border-gray-200 hover:opacity-80">
                                    {/* eslint-disable-next-line @next/next/no-img-element */}
                                    <img src={f.foto_url} alt="" className="w-full h-full object-cover" />
                                  </button>
                                ))}
                                {sFotos.length > 3 && (
                                  <span className="w-14 h-14 rounded-lg bg-gray-100 flex items-center justify-center text-xs text-gray-400">
                                    +{sFotos.length - 3}
                                  </span>
                                )}
                              </div>
                            )}
                          </>
                        ) : (
                          <span className="text-xs text-gray-300 italic">Não avaliado</span>
                        )}
                      </div>
                    </div>
                  </div>
                )
              })}
            </div>
          </div>
        )
      })}

      {/* Legend */}
      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-5">
        <p className="text-xs font-bold text-gray-400 uppercase tracking-wider mb-3">Legenda</p>
        <div className="flex flex-wrap gap-4 text-xs text-gray-600">
          <span className="flex items-center gap-1"><TrendingUp size={12} className="text-green-500" /> Item melhorou</span>
          <span className="flex items-center gap-1"><TrendingDown size={12} className="text-red-500" /> Item piorou</span>
          <span className="flex items-center gap-1"><Equal size={12} className="text-gray-400" /> Sem alteração</span>
        </div>
        <div className="flex flex-wrap gap-3 mt-3">
          {Object.entries(STATUS_LABELS).map(([k, v]) => (
            <span key={k} className={`flex items-center gap-1 px-2 py-0.5 rounded-lg text-xs font-bold ${v.bg} ${v.color}`}>
              {v.icon} {v.label}
            </span>
          ))}
        </div>
      </div>
    </div>
  )
}
