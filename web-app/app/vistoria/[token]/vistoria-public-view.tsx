'use client'
import { useState } from 'react'
import {
  CheckCircle2, AlertTriangle, XCircle, MinusCircle,
  ChevronDown, ChevronUp, MapPin, Calendar, User, FileText, Camera
} from 'lucide-react'

interface VistoriaData {
  id: string; titulo: string; tipo_bem: string; tipo_vistoria: string
  endereco: string | null; cod_interno: string; status: string
  responsavel_nome: string | null; proprietario_nome: string | null
  inquilino_nome: string | null; plano: string; created_at: string
}

interface SecaoData { id: string; nome: string; icone_emoji: string; posicao: number }
interface ItemData { id: string; secao_id: string; nome: string; status: string; observacao: string | null; posicao: number }
interface FotoData { id: string; item_id: string; foto_url: string }
interface AssinaturaData { nome: string; papel: string; assinatura_url: string | null; assinado_em: string | null }

const TIPOS_BEM: Record<string, string> = {
  apartamento: '🏢 Apartamento', casa: '🏠 Casa', carro: '🚗 Carro',
  moto: '🏍️ Moto', barco: '⛵ Barco', equipamento: '🔧 Equipamento', personalizado: '📋 Personalizado',
}

const STATUS_LABELS: Record<string, { label: string; color: string; bg: string; icon: React.ReactNode }> = {
  ok:         { label: 'OK',         color: 'text-green-700', bg: 'bg-green-50 border-green-200', icon: <CheckCircle2 size={16} /> },
  atencao:    { label: 'Atenção',    color: 'text-yellow-700', bg: 'bg-yellow-50 border-yellow-200', icon: <AlertTriangle size={16} /> },
  danificado: { label: 'Danificado', color: 'text-red-700', bg: 'bg-red-50 border-red-200', icon: <XCircle size={16} /> },
  nao_existe: { label: 'Não existe', color: 'text-gray-500', bg: 'bg-gray-50 border-gray-200', icon: <MinusCircle size={16} /> },
}

const VISTORIA_STATUS: Record<string, { label: string; color: string }> = {
  rascunho: { label: 'Rascunho', color: 'bg-gray-100 text-gray-700' },
  em_andamento: { label: 'Em andamento', color: 'bg-blue-100 text-blue-700' },
  concluida: { label: 'Concluída', color: 'bg-green-100 text-green-700' },
  assinada: { label: 'Assinada', color: 'bg-purple-100 text-purple-700' },
}

export default function VistoriaPublicView({
  vistoria, secoes, itens, fotos, assinaturas, condoNome,
}: {
  vistoria: VistoriaData
  secoes: SecaoData[]
  itens: ItemData[]
  fotos: FotoData[]
  assinaturas: AssinaturaData[]
  condoNome: string
}) {
  const [expandedSections, setExpandedSections] = useState<Set<string>>(
    new Set(secoes.map(s => s.id))
  )
  const [lightboxUrl, setLightboxUrl] = useState<string | null>(null)

  const toggleSection = (id: string) => {
    setExpandedSections(prev => {
      const next = new Set(prev)
      if (next.has(id)) next.delete(id); else next.add(id)
      return next
    })
  }

  const totalItens = itens.length
  const okCount = itens.filter(i => i.status === 'ok').length
  const atencaoCount = itens.filter(i => i.status === 'atencao').length
  const danificadoCount = itens.filter(i => i.status === 'danificado').length
  const vstatus = VISTORIA_STATUS[vistoria.status] ?? VISTORIA_STATUS.rascunho

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-50 to-gray-100">
      {/* Lightbox */}
      {lightboxUrl && (
        <div className="fixed inset-0 bg-black/80 z-50 flex items-center justify-center p-4"
          onClick={() => setLightboxUrl(null)}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={lightboxUrl} alt="Foto ampliada" className="max-w-full max-h-full object-contain rounded-2xl" />
        </div>
      )}

      {/* Header */}
      <header className="bg-gradient-to-r from-[#FC5931] to-[#ff7a5c] text-white">
        <div className="max-w-4xl mx-auto px-6 py-8">
          <div className="flex items-center gap-2 text-white/70 text-sm mb-2">
            <FileText size={14} />
            <span>Condomeet Check • {condoNome}</span>
          </div>
          <h1 className="text-2xl sm:text-3xl font-bold mb-1">{vistoria.titulo}</h1>
          <div className="flex flex-wrap items-center gap-3 text-white/80 text-sm mt-3">
            <span>{TIPOS_BEM[vistoria.tipo_bem]}</span>
            <span>•</span>
            <span>{vistoria.tipo_vistoria === 'entrada' ? '📥 Entrada' : vistoria.tipo_vistoria === 'saida' ? '📤 Saída' : '🔄 Periódica'}</span>
            <span className={`px-2.5 py-0.5 rounded-full text-xs font-bold ${vstatus.color}`}>{vstatus.label}</span>
          </div>
        </div>
      </header>

      <main className="max-w-4xl mx-auto px-6 py-8 space-y-6">
        {/* Info Card */}
        <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6">
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-sm">
            {vistoria.endereco && (
              <div className="flex items-center gap-2 text-gray-600">
                <MapPin size={16} className="text-gray-400" />
                <span>{vistoria.endereco}</span>
              </div>
            )}
            <div className="flex items-center gap-2 text-gray-600">
              <Calendar size={16} className="text-gray-400" />
              <span>{new Date(vistoria.created_at).toLocaleDateString('pt-BR', { day: '2-digit', month: 'long', year: 'numeric' })}</span>
            </div>
            {vistoria.responsavel_nome && (
              <div className="flex items-center gap-2 text-gray-600">
                <User size={16} className="text-gray-400" />
                <span>Responsável: <strong>{vistoria.responsavel_nome}</strong></span>
              </div>
            )}
            {vistoria.proprietario_nome && (
              <div className="flex items-center gap-2 text-gray-600">
                <User size={16} className="text-gray-400" />
                <span>Proprietário: <strong>{vistoria.proprietario_nome}</strong></span>
              </div>
            )}
            {vistoria.inquilino_nome && (
              <div className="flex items-center gap-2 text-gray-600">
                <User size={16} className="text-gray-400" />
                <span>Inquilino: <strong>{vistoria.inquilino_nome}</strong></span>
              </div>
            )}
            <div className="flex items-center gap-2 text-gray-400 text-xs">
              <span>Código: #{vistoria.cod_interno}</span>
            </div>
          </div>
        </div>

        {/* Stats */}
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
          {[
            { label: 'Total', value: totalItens, color: 'bg-blue-500' },
            { label: 'OK', value: okCount, color: 'bg-green-500' },
            { label: 'Atenção', value: atencaoCount, color: 'bg-yellow-500' },
            { label: 'Danificado', value: danificadoCount, color: 'bg-red-500' },
          ].map(stat => (
            <div key={stat.label} className={`${stat.color} text-white rounded-2xl p-4 text-center shadow-sm`}>
              <p className="text-2xl font-bold">{stat.value}</p>
              <p className="text-xs opacity-80 mt-0.5">{stat.label}</p>
            </div>
          ))}
        </div>

        {/* Sections */}
        {secoes.sort((a, b) => a.posicao - b.posicao).map(secao => {
          const secaoItens = itens.filter(i => i.secao_id === secao.id).sort((a, b) => a.posicao - b.posicao)
          const isExpanded = expandedSections.has(secao.id)
          const secaoProblems = secaoItens.filter(i => i.status === 'danificado' || i.status === 'atencao').length

          return (
            <div key={secao.id} className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
              {/* Section header */}
              <button
                onClick={() => toggleSection(secao.id)}
                className="w-full flex items-center justify-between px-6 py-4 hover:bg-gray-50 transition-colors"
              >
                <div className="flex items-center gap-3">
                  <span className="text-xl">{secao.icone_emoji}</span>
                  <h2 className="text-lg font-bold text-gray-900">{secao.nome}</h2>
                  <span className="text-xs text-gray-400">{secaoItens.length} itens</span>
                  {secaoProblems > 0 && (
                    <span className="px-2 py-0.5 bg-red-100 text-red-600 rounded-full text-xs font-bold">
                      ⚠️ {secaoProblems}
                    </span>
                  )}
                </div>
                {isExpanded ? <ChevronUp size={20} className="text-gray-400" /> : <ChevronDown size={20} className="text-gray-400" />}
              </button>

              {/* Items */}
              {isExpanded && (
                <div className="border-t border-gray-100">
                  {secaoItens.map(item => {
                    const itemFotos = fotos.filter(f => f.item_id === item.id)
                    const st = STATUS_LABELS[item.status] ?? STATUS_LABELS.ok

                    return (
                      <div key={item.id} className="px-6 py-4 border-b border-gray-50 last:border-b-0">
                        <div className="flex items-center justify-between mb-2">
                          <span className="font-medium text-gray-800">{item.nome}</span>
                          <span className={`flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-bold border ${st.bg} ${st.color}`}>
                            {st.icon} {st.label}
                          </span>
                        </div>

                        {item.observacao && (
                          <p className="text-sm text-gray-500 bg-gray-50 rounded-xl px-4 py-2 mt-2">
                            💬 {item.observacao}
                          </p>
                        )}

                        {itemFotos.length > 0 && (
                          <div className="flex flex-wrap gap-2 mt-3">
                            {itemFotos.map(foto => (
                              <button key={foto.id} onClick={() => setLightboxUrl(foto.foto_url)}
                                className="relative w-20 h-20 rounded-xl overflow-hidden border border-gray-200 hover:opacity-80 transition-opacity group">
                                {/* eslint-disable-next-line @next/next/no-img-element */}
                                <img src={foto.foto_url} alt="" className="w-full h-full object-cover" />
                                <div className="absolute inset-0 bg-black/0 group-hover:bg-black/10 transition-colors flex items-center justify-center">
                                  <Camera size={16} className="text-white opacity-0 group-hover:opacity-100 transition-opacity drop-shadow-lg" />
                                </div>
                              </button>
                            ))}
                          </div>
                        )}
                      </div>
                    )
                  })}
                </div>
              )}
            </div>
          )
        })}

        {/* Signatures */}
        {assinaturas.length > 0 && (
          <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6">
            <h2 className="text-lg font-bold text-gray-900 mb-4">✍️ Assinaturas</h2>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              {assinaturas.map((sig, i) => (
                <div key={i} className="border border-gray-200 rounded-xl p-4">
                  {sig.assinatura_url ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={sig.assinatura_url} alt={`Assinatura de ${sig.nome}`}
                      className="w-full h-20 object-contain mb-2" />
                  ) : (
                    <div className="w-full h-20 bg-gray-50 rounded-lg flex items-center justify-center text-gray-300 text-sm mb-2">
                      Pendente
                    </div>
                  )}
                  <p className="font-bold text-gray-800 text-sm">{sig.nome}</p>
                  <p className="text-xs text-gray-500 capitalize">{sig.papel}</p>
                  {sig.assinado_em && (
                    <p className="text-xs text-gray-400 mt-1">
                      {new Date(sig.assinado_em).toLocaleDateString('pt-BR')}
                    </p>
                  )}
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Footer */}
        <div className="text-center text-xs text-gray-400 py-6">
          <p>Relatório gerado pelo <strong>Condomeet Check</strong></p>
          <p className="mt-1">condomeet.app.br</p>
        </div>
      </main>
    </div>
  )
}
