'use client'

import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'

type Perfil = {
  nome_completo: string
  bloco_txt: string | null
  apto_txt: string | null
}

type Occurrence = {
  id: string
  resident_id: string
  assunto: string | null
  description: string
  category: string
  status: string
  photo_url: string | null
  admin_response: string | null
  admin_response_at: string | null
  created_at: string
  perfil: Perfil | null
}

const CATEGORY_LABELS: Record<string, string> = {
  maintenance: 'Manutenção',
  security: 'Segurança',
  noise: 'Barulho',
  others: 'Outros',
}

const STATUS_CONFIG: Record<string, { label: string; color: string; bg: string }> = {
  pending: { label: 'Pendente', color: 'text-orange-700', bg: 'bg-orange-50 border-orange-200' },
  open: { label: 'Aberto', color: 'text-blue-700', bg: 'bg-blue-50 border-blue-200' },
  inProgress: { label: 'Em Andamento', color: 'text-yellow-700', bg: 'bg-yellow-50 border-yellow-200' },
  resolved: { label: 'Resolvido', color: 'text-green-700', bg: 'bg-green-50 border-green-200' },
  closed: { label: 'Fechado', color: 'text-gray-700', bg: 'bg-gray-50 border-gray-200' },
}

function formatDate(dateStr: string | null): string {
  if (!dateStr) return '—'
  return new Intl.DateTimeFormat('pt-BR', {
    day: '2-digit', month: '2-digit', year: '2-digit',
    hour: '2-digit', minute: '2-digit',
  }).format(new Date(dateStr))
}

function StatusBadge({ status }: { status: string }) {
  const cfg = STATUS_CONFIG[status] ?? STATUS_CONFIG.pending
  return (
    <span className={`text-xs font-semibold px-2.5 py-1 rounded-full border ${cfg.bg} ${cfg.color}`}>
      {cfg.label}
    </span>
  )
}

function OccurrenceCard({
  occ,
  number,
  isAdmin,
  onRespond,
}: {
  occ: Occurrence
  number: number
  isAdmin: boolean
  onRespond: (id: string, response: string) => Promise<void>
}) {
  const [isExpanded, setIsExpanded] = useState(false)
  const [responseText, setResponseText] = useState(occ.admin_response ?? '')
  const [saving, setSaving] = useState(false)
  const [saved, setSaved] = useState(false)

  const hasResponse = !!occ.admin_response

  const handleSave = async () => {
    if (!responseText.trim()) return
    setSaving(true)
    await onRespond(occ.id, responseText.trim())
    setSaving(false)
    setSaved(true)
    setTimeout(() => setSaved(false), 3000)
  }

  const residentLabel = occ.perfil
    ? `${occ.perfil.nome_completo}${occ.perfil.bloco_txt ? ` · ${occ.perfil.bloco_txt}/${occ.perfil.apto_txt}` : ''}`
    : 'Morador'

  return (
    <div className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
      {/* Header */}
      <div
        className="flex items-center justify-between px-5 py-4 cursor-pointer hover:bg-gray-50 transition-colors"
        onClick={() => setIsExpanded(!isExpanded)}
      >
        <div className="flex items-center gap-3 min-w-0">
          <span className="text-xs font-bold text-gray-400 shrink-0">#{number}</span>
          <div className="min-w-0">
            <p className="font-semibold text-gray-900 truncate">
              {occ.assunto || occ.description.substring(0, 50)}
            </p>
            <p className="text-xs text-gray-400 mt-0.5">
              {isAdmin ? residentLabel + ' · ' : ''}{CATEGORY_LABELS[occ.category] ?? occ.category} · {formatDate(occ.created_at)}
            </p>
          </div>
        </div>
        <div className="flex items-center gap-3 shrink-0 ml-3">
          <StatusBadge status={occ.status} />
          <svg
            className={`w-4 h-4 text-gray-400 transition-transform ${isExpanded ? 'rotate-180' : ''}`}
            fill="none" viewBox="0 0 24 24" stroke="currentColor"
          >
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
          </svg>
        </div>
      </div>

      {/* Expanded Content */}
      {isExpanded && (
        <div className="border-t border-gray-100">
          {/* Descrição + Foto */}
          <div className="px-5 py-4">
            <p className="text-xs font-medium text-gray-500 uppercase tracking-wider mb-2">Ocorrência</p>
            <p className="text-gray-700 text-sm leading-relaxed">{occ.description}</p>

            {occ.photo_url && (
              <div className="mt-4">
                <a href={occ.photo_url} target="_blank" rel="noopener noreferrer">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img
                    src={occ.photo_url}
                    alt="Foto da ocorrência"
                    className="w-full max-h-64 object-cover rounded-xl border border-gray-100 hover:opacity-90 transition-opacity cursor-zoom-in"
                  />
                </a>
                <p className="text-xs text-gray-400 mt-1">Clique para ampliar</p>
              </div>
            )}
          </div>

          {/* Seção de Resposta */}
          <div className={`px-5 pb-5 ${hasResponse ? 'bg-green-50/50' : 'bg-orange-50/30'}`}>
            {hasResponse && !isAdmin ? (
              // Morador lê a resposta
              <div className="border-t border-green-100 pt-4">
                <div className="flex items-center gap-2 mb-2">
                  <span className="text-green-600">✓</span>
                  <p className="text-xs font-medium text-green-700 uppercase tracking-wider">Resposta do Adm/Síndico</p>
                </div>
                <p className="text-gray-700 text-sm">{occ.admin_response}</p>
                <p className="text-xs text-gray-400 mt-2">Respondido em: {formatDate(occ.admin_response_at)}</p>
              </div>
            ) : isAdmin ? (
              // Admin responde
              <div className="border-t border-gray-100 pt-4">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wider mb-2">
                  {hasResponse ? 'Resposta enviada (editar)' : 'Responder ao morador'}
                </p>
                <textarea
                  value={responseText}
                  onChange={(e) => setResponseText(e.target.value)}
                  rows={3}
                  placeholder="Digite sua resposta para o morador..."
                  className="w-full border border-gray-200 rounded-xl px-4 py-3 text-sm text-gray-700 resize-none focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] transition-all bg-white"
                />
                <div className="flex items-center justify-between mt-3">
                  {saved ? (
                    <span className="text-sm text-green-600 font-medium">✓ Resposta enviada!</span>
                  ) : (
                    <span />
                  )}
                  <button
                    onClick={handleSave}
                    disabled={saving || !responseText.trim()}
                    className="bg-[#FC5931] text-white text-sm font-semibold px-5 py-2 rounded-xl hover:bg-[#D42F1D] transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
                  >
                    {saving ? 'Enviando...' : hasResponse ? 'Atualizar Resposta' : 'Enviar Resposta'}
                  </button>
                </div>
              </div>
            ) : (
              <div className="border-t border-gray-100 pt-4">
                <p className="text-xs text-gray-400 italic">Aguardando resposta da administração...</p>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  )
}

export default function OcorrenciasClient({
  initialOccurrences,
  isAdmin,
  userId,
  condoId,
}: {
  initialOccurrences: Occurrence[]
  isAdmin: boolean
  userId: string
  condoId: string
}) {
  const [occurrences, setOccurrences] = useState<Occurrence[]>(initialOccurrences)
  const [filter, setFilter] = useState<'all' | 'pending' | 'resolved'>(isAdmin ? 'pending' : 'all')
  const [showModal, setShowModal] = useState(false)
  const [creating, setCreating] = useState(false)
  const [form, setForm] = useState({ assunto: '', description: '', category: 'maintenance' })
  const [photoFile, setPhotoFile] = useState<File | null>(null)
  const [photoPreview, setPhotoPreview] = useState<string | null>(null)

  const handlePhotoChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0] ?? null
    setPhotoFile(file)
    if (file) setPhotoPreview(URL.createObjectURL(file))
    else setPhotoPreview(null)
  }

  const handleCreate = async () => {
    if (!form.assunto.trim() || !form.description.trim()) return
    setCreating(true)
    const supabase = createClient()

    // Use browser session's actual auth.uid() to match RLS policy
    const { data: { user: currentUser } } = await supabase.auth.getUser()
    const residentId = currentUser?.id ?? userId

    const now = new Date().toISOString()
    const id = crypto.randomUUID()

    // Upload photo if selected
    let photoUrl: string | null = null
    if (photoFile) {
      const ext = photoFile.name.split('.').pop()
      const path = `${residentId}/${id}.${ext}`
      const { error: uploadError } = await supabase.storage
        .from('ocorrencias-fotos')
        .upload(path, photoFile, { upsert: true })
      if (!uploadError) {
        const { data } = supabase.storage.from('ocorrencias-fotos').getPublicUrl(path)
        photoUrl = data.publicUrl
      }
    }

    const { error } = await supabase.from('ocorrencias').insert({
      id,
      resident_id: residentId,
      condominio_id: condoId,
      assunto: form.assunto.trim(),
      description: form.description.trim(),
      category: form.category,
      status: 'pending',
      photo_url: photoUrl,
      created_at: now,
      updated_at: now,
    })
    setCreating(false)
    if (!error) {
      setOccurrences(prev => [{
        id, resident_id: residentId, assunto: form.assunto.trim(),
        description: form.description.trim(), category: form.category,
        status: 'pending', photo_url: photoUrl, admin_response: null,
        admin_response_at: null, created_at: now, perfil: null,
      }, ...prev])
      setForm({ assunto: '', description: '', category: 'maintenance' })
      setPhotoFile(null)
      setPhotoPreview(null)
      setShowModal(false)
    }
  }

  const handleRespond = async (occurrenceId: string, response: string) => {
    const supabase = createClient()
    const now = new Date().toISOString()
    const { error } = await supabase
      .from('ocorrencias')
      .update({
        admin_response: response,
        admin_response_at: now,
        status: 'resolved',
        updated_at: now,
      })
      .eq('id', occurrenceId)

    if (!error) {
      setOccurrences(prev =>
        prev.map(o =>
          o.id === occurrenceId
            ? { ...o, admin_response: response, admin_response_at: now, status: 'resolved' }
            : o
        )
      )
    }
  }

  const filtered = occurrences.filter(o => {
    if (filter === 'pending') return o.status !== 'resolved' && o.status !== 'closed'
    if (filter === 'resolved') return o.status === 'resolved' || o.status === 'closed'
    return true
  })

  const pendingCount = occurrences.filter(o => o.status !== 'resolved' && o.status !== 'closed').length

  return (
    <div>
      {/* Header com botão */}
      <div className="flex items-center justify-between mb-5 flex-wrap gap-3">
        <div className="flex items-center gap-2 flex-wrap">
          {[
            { key: 'all', label: `Todas (${occurrences.length})` },
            { key: 'pending', label: `Pendentes${pendingCount > 0 ? ` (${pendingCount})` : ''}` },
            { key: 'resolved', label: 'Resolvidas' },
          ].map(({ key, label }) => (
            <button
              key={key}
              onClick={() => setFilter(key as typeof filter)}
              className={`text-sm font-medium px-4 py-2 rounded-xl border transition-all ${
                filter === key
                  ? 'bg-[#FC5931] text-white border-[#FC5931]'
                  : 'bg-white text-gray-600 border-gray-200 hover:border-[#FC5931] hover:text-[#FC5931]'
              }`}
            >
              {label}
            </button>
          ))}
        </div>
        {!isAdmin && (
          <button
            onClick={() => setShowModal(true)}
            className="flex items-center gap-2 bg-[#FC5931] text-white text-sm font-semibold px-5 py-2.5 rounded-xl hover:bg-[#D42F1D] transition-colors shadow-sm"
          >
            + Nova Ocorrência
          </button>
        )}
      </div>

      {/* Lista */}
      {filtered.length === 0 ? (
        <div className="text-center py-16 text-gray-400">
          <p className="text-5xl mb-4">📋</p>
          <p className="font-medium">Nenhuma ocorrência encontrada</p>
        </div>
      ) : (
        <div className="flex flex-col gap-3">
          {filtered.map((occ, index) => (
            <OccurrenceCard
              key={occ.id}
              occ={occ}
              number={filtered.length - index}
              isAdmin={isAdmin}
              onRespond={handleRespond}
            />
          ))}
        </div>
      )}

      {/* Modal Nova Ocorrência */}
      {showModal && (
        <div className="fixed inset-0 bg-black/40 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl shadow-xl w-full max-w-md">
            <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100">
              <h2 className="text-lg font-bold text-gray-900">Nova Ocorrência</h2>
              <button onClick={() => setShowModal(false)} className="text-gray-400 hover:text-gray-600 text-xl">✕</button>
            </div>
            <div className="px-6 py-5 flex flex-col gap-4">
              <div>
                <label className="text-xs font-medium text-gray-500 uppercase tracking-wider block mb-1.5">Assunto</label>
                <input
                  value={form.assunto}
                  onChange={e => setForm(f => ({ ...f, assunto: e.target.value }))}
                  placeholder="Ex: Lâmpada queimada no corredor"
                  className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931]"
                />
              </div>
              <div>
                <label className="text-xs font-medium text-gray-500 uppercase tracking-wider block mb-1.5">Categoria</label>
                <div className="flex gap-2 flex-wrap">
                  {[
                    { key: 'maintenance', label: 'Manutenção' },
                    { key: 'security', label: 'Segurança' },
                    { key: 'noise', label: 'Barulho' },
                    { key: 'others', label: 'Outros' },
                  ].map(({ key, label }) => (
                    <button
                      key={key}
                      onClick={() => setForm(f => ({ ...f, category: key }))}
                      className={`text-sm px-3 py-1.5 rounded-xl border font-medium transition-all ${
                        form.category === key
                          ? 'bg-[#FC5931] text-white border-[#FC5931]'
                          : 'bg-white text-gray-600 border-gray-200 hover:border-[#FC5931]'
                      }`}
                    >
                      {label}
                    </button>
                  ))}
                </div>
              </div>
              <div>
                <label className="text-xs font-medium text-gray-500 uppercase tracking-wider block mb-1.5">Descrição</label>
                <textarea
                  value={form.description}
                  onChange={e => setForm(f => ({ ...f, description: e.target.value }))}
                  rows={4}
                  placeholder="Descreva a ocorrência em detalhes..."
                  className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm resize-none focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931]"
                />
              </div>
              <div>
                <label className="text-xs font-medium text-gray-500 uppercase tracking-wider block mb-1.5">Foto (Opcional)</label>
                <label className="flex items-center gap-3 border border-dashed border-gray-300 rounded-xl px-4 py-3 cursor-pointer hover:border-[#FC5931] transition-colors">
                  <span className="text-2xl">📎</span>
                  <span className="text-sm text-gray-500">{photoFile ? photoFile.name : 'Clique para selecionar uma foto'}</span>
                  <input type="file" accept="image/*" onChange={handlePhotoChange} className="hidden" />
                </label>
                {photoPreview && (
                  <div className="mt-2 relative">
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img src={photoPreview} alt="Preview" className="w-full max-h-40 object-cover rounded-xl border border-gray-100" />
                    <button
                      onClick={() => { setPhotoFile(null); setPhotoPreview(null) }}
                      className="absolute top-2 right-2 bg-white rounded-full w-6 h-6 text-xs text-gray-600 shadow hover:bg-gray-100"
                    >✕</button>
                  </div>
                )}
              </div>
            </div>
            <div className="px-6 py-4 border-t border-gray-100 flex gap-3 justify-end">
              <button
                onClick={() => setShowModal(false)}
                className="text-sm font-medium px-4 py-2 rounded-xl border border-gray-200 text-gray-600 hover:bg-gray-50"
              >
                Cancelar
              </button>
              <button
                onClick={handleCreate}
                disabled={creating || !form.assunto.trim() || !form.description.trim()}
                className="bg-[#FC5931] text-white text-sm font-semibold px-5 py-2 rounded-xl hover:bg-[#D42F1D] transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
              >
                {creating ? 'Salvando...' : 'Registrar Ocorrência'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
