'use client'

import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { UserCheck, Plus, X, CheckCircle2, Clock, QrCode, ChevronDown } from 'lucide-react'

type Convite = {
  id: string
  qr_data: string | null
  guest_name: string | null
  visitor_type: string | null
  visitante_compareceu: boolean | number
  validity_date: string
  created_at: string
  liberado_em: string | null
  status: string | null
}

const VISITOR_TYPES = ['Visitante', 'Uber', 'Farmácia', 'Mat. de obra', 'Diarista', 'Serviços', 'Hóspede', 'Outros']

function formatDate(dateStr: string) {
  if (!dateStr) return '—'
  try {
    const d = new Date(dateStr + 'T00:00:00')
    if (isNaN(d.getTime())) return dateStr
    return d.toLocaleDateString('pt-BR', {
      day: '2-digit', month: '2-digit', year: 'numeric',
    })
  } catch {
    return dateStr
  }
}

function ConviteCard({ convite }: { convite: Convite }) {
  const chegou = Boolean(convite.visitante_compareceu)
  const validDate = new Date(convite.validity_date + 'T00:00:00')
  const isExpired = validDate < new Date() && !chegou
  const code = convite.qr_data ? convite.qr_data.toUpperCase() : '—'

  return (
    <div className={`bg-white rounded-2xl border shadow-sm overflow-hidden ${
      chegou ? 'border-green-200' : isExpired ? 'border-gray-200' : 'border-orange-100'
    }`}>
      <div className={`px-5 py-3 flex items-center justify-between ${
        chegou ? 'bg-emerald-500' : isExpired ? 'bg-gray-400' : 'bg-[#FC3951]'
      }`}>
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 bg-white/20 rounded-xl flex items-center justify-center">
            <span className="text-white font-bold text-xs">{code}</span>
          </div>
          <div>
            <p className="text-white font-semibold text-sm">{convite.guest_name || 'Visitante'}</p>
            <p className="text-white/70 text-xs">{convite.visitor_type || 'Tipo não informado'}</p>
          </div>
        </div>
        <div className="text-right">
          {chegou ? (
            <span className="flex items-center gap-1 text-white text-xs font-bold">
              <CheckCircle2 size={14} /> Entrou
            </span>
          ) : isExpired ? (
            <span className="text-white text-xs font-bold">Expirado</span>
          ) : (
            <span className="flex items-center gap-1 text-white text-xs font-bold">
              <Clock size={14} /> Aguardando
            </span>
          )}
        </div>
      </div>

      <div className="px-5 py-4 flex items-center justify-between">
        <div className="text-sm">
          <p className="text-gray-400 text-xs mb-0.5">Válido para</p>
          <p className="font-semibold text-gray-800">{formatDate(convite.validity_date)}</p>
        </div>
        <div className="flex items-center gap-1.5 bg-gray-50 border border-gray-200 px-3 py-1.5 rounded-xl">
          <QrCode size={14} className="text-gray-400" />
          <span className="text-xs font-bold text-gray-600 tracking-widest">{code}</span>
        </div>
      </div>
    </div>
  )
}

export default function VisitantesResidentClient({
  initialConvites,
  userId,
  condoId,
  residentName,
  bloco,
  apto,
}: {
  initialConvites: Convite[]
  userId: string
  condoId: string
  residentName: string
  bloco: string
  apto: string
}) {
  const [convites, setConvites] = useState<Convite[]>(initialConvites)
  const [showModal, setShowModal] = useState(false)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [filter, setFilter] = useState<'todos' | 'pendente' | 'entrou'>('todos')
  const [loadedAll, setLoadedAll] = useState(initialConvites.length < 5)
  const [loadingMore, setLoadingMore] = useState(false)

  const [form, setForm] = useState({
    guest_name: '',
    visitor_type: '',
    validity_date: '',
    whatsapp: '',
    observacao: '',
  })

  const filtered = convites.filter(c => {
    if (filter === 'pendente') return !Boolean(c.visitante_compareceu)
    if (filter === 'entrou') return Boolean(c.visitante_compareceu)
    return true
  })

  async function handleCreate() {
    if (!form.visitor_type || !form.validity_date) {
      setError('Escolha o tipo de visitante e a data de validade.')
      return
    }
    setSaving(true)
    setError('')
    const supabase = createClient()
    const { data: { user: cu } } = await supabase.auth.getUser()

    // Generate 3-char random alphanumeric code
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    const code = Array.from({ length: 3 }, () => chars[Math.floor(Math.random() * chars.length)]).join('')
    const now = new Date().toISOString()

    const { data: inserted, error: insertError } = await supabase
      .from('convites')
      .insert({
        resident_id: cu?.id ?? userId,
        condominio_id: condoId,
        guest_name: form.guest_name.trim() || null,
        visitor_type: form.visitor_type,
        validity_date: form.validity_date,
        qr_data: code,
        visitante_compareceu: false,
        status: 'pending',
        created_at: now,
        whatsapp: form.whatsapp.trim() || null,
        observacao: form.observacao.trim() || null,
      })
      .select()
      .single()

    if (insertError) {
      setError('Erro ao criar autorização. Tente novamente.')
    } else if (inserted) {
      setConvites(prev => [inserted, ...prev])
      setShowModal(false)
      setForm({ guest_name: '', visitor_type: '', validity_date: '', whatsapp: '', observacao: '' })
    }
    setSaving(false)
  }

  // Min date = today
  const today = new Date().toISOString().split('T')[0]

  async function handleLoadMore() {
    setLoadingMore(true)
    const supabase = createClient()
    const { data } = await supabase
      .from('convites')
      .select('id, qr_data, guest_name, visitor_type, visitante_compareceu, validity_date, created_at, liberado_em, status')
      .eq('resident_id', userId)
      .eq('condominio_id', condoId)
      .order('created_at', { ascending: false })
    if (data) setConvites(data)
    setLoadedAll(true)
    setLoadingMore(false)
  }

  return (
    <div>
      {/* Toolbar */}
      <div className="flex items-center justify-between mb-5 gap-3 flex-wrap">
        <div className="flex items-center gap-2">
          {[
            { key: 'todos',    label: `Todos (${convites.length})` },
            { key: 'pendente', label: 'Aguardando' },
            { key: 'entrou',   label: 'Entraram' },
          ].map(({ key, label }) => (
            <button
              key={key}
              onClick={() => setFilter(key as typeof filter)}
              className={`text-sm font-medium px-4 py-2 rounded-xl border transition-all ${
                filter === key
                  ? 'bg-[#FC3951] text-white border-[#FC3951] shadow-sm'
                  : 'bg-white text-gray-600 border-gray-200 hover:border-[#FC3951]/50 hover:text-[#FC3951]'
              }`}
            >
              {label}
            </button>
          ))}
        </div>
        <button
          onClick={() => setShowModal(true)}
          className="flex items-center gap-2 bg-[#FC3951] text-white text-sm font-semibold px-5 py-2.5 rounded-xl hover:bg-[#D4253D] transition-colors shadow-sm shadow-[#FC3951]/30"
        >
          <Plus size={16} />
          Nova Autorização
        </button>
      </div>

      {/* List */}
      {filtered.length === 0 ? (
        <div className="text-center py-20 text-gray-400">
          <UserCheck size={40} className="mx-auto mb-3 opacity-30" />
          <p className="font-medium text-gray-500 mb-1">Nenhuma autorização</p>
          <p className="text-sm">Clique em "Nova Autorização" para liberar um visitante</p>
        </div>
      ) : (
        <div className="grid sm:grid-cols-2 gap-4">
          {filtered.map(c => (
            <ConviteCard key={c.id} convite={c} />
          ))}
        </div>
      )}

      {/* Load more */}
      {!loadedAll && filter === 'todos' && (
        <div className="flex justify-center mt-4">
          <button
            onClick={handleLoadMore}
            disabled={loadingMore}
            className="flex items-center gap-2 px-5 py-2.5 text-sm font-semibold text-[#FC3951] bg-[#FC3951]/10 rounded-xl hover:bg-[#FC3951]/20 transition-colors disabled:opacity-50"
          >
            {loadingMore ? (
              <div className="w-4 h-4 border-2 border-[#FC3951]/30 border-t-[#FC3951] rounded-full animate-spin" />
            ) : (
              <ChevronDown size={14} />
            )}
            {loadingMore ? 'Carregando...' : 'Ver mais autorizações'}
          </button>
        </div>
      )}

      {/* Modal */}
      {showModal && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-3xl shadow-2xl w-full max-w-sm overflow-hidden"
            style={{ animation: 'modalIn 0.2s ease-out' }}>
            <style>{`@keyframes modalIn { from { opacity:0; transform: scale(0.96) translateY(8px) } to { opacity:1; transform: scale(1) translateY(0) } }`}</style>

            <div className="flex items-center justify-between px-6 py-5 border-b border-gray-100">
              <div>
                <h2 className="text-lg font-bold text-gray-900">Nova Autorização</h2>
                <p className="text-xs text-gray-400 mt-0.5">{bloco && `Bloco ${bloco} / Apto ${apto}`}</p>
              </div>
              <button onClick={() => setShowModal(false)}
                className="w-8 h-8 rounded-xl flex items-center justify-center text-gray-400 hover:bg-gray-100">
                <X size={16} />
              </button>
            </div>

            <div className="px-6 py-5 flex flex-col gap-4">
              <div>
                <label className="text-xs font-semibold text-gray-500 uppercase tracking-wider block mb-2">
                  Tipo de visitante *
                </label>
                <select
                  value={form.visitor_type}
                  onChange={e => setForm(f => ({ ...f, visitor_type: e.target.value }))}
                  title="Tipo de visitante"
                  className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC3951]/30 focus:border-[#FC3951] transition-all bg-white"
                >
                  <option value="">Escolha o tipo de visitante</option>
                  {VISITOR_TYPES.map(type => (
                    <option key={type} value={type}>{type}</option>
                  ))}
                </select>
              </div>

              <div>
                <label className="text-xs font-semibold text-gray-500 uppercase tracking-wider block mb-2">
                  Data de validade *
                </label>
                <input
                  type="date"
                  min={today}
                  value={form.validity_date}
                  onChange={e => setForm(f => ({ ...f, validity_date: e.target.value }))}
                  title="Data de validade"
                  className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC3951]/30 focus:border-[#FC3951] transition-all"
                />
              </div>

              <p className="text-xs text-gray-400 mt-1">Envie a autorização para seu visitante (Opcional):</p>

              <div>
                <label className="text-xs font-semibold text-gray-500 uppercase tracking-wider block mb-2">
                  Nome do visitante
                </label>
                <input
                  value={form.guest_name}
                  onChange={e => setForm(f => ({ ...f, guest_name: e.target.value }))}
                  placeholder="Nome do visitante"
                  className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC3951]/30 focus:border-[#FC3951] transition-all"
                />
              </div>

              <div>
                <label className="text-xs font-semibold text-gray-500 uppercase tracking-wider block mb-2">
                  WhatsApp
                </label>
                <input
                  value={form.whatsapp}
                  onChange={e => setForm(f => ({ ...f, whatsapp: e.target.value }))}
                  placeholder="(00) 0 0000-0000"
                  className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC3951]/30 focus:border-[#FC3951] transition-all"
                />
              </div>

              <div>
                <label className="text-xs font-semibold text-gray-500 uppercase tracking-wider block mb-2">
                  Observação
                </label>
                <input
                  value={form.observacao}
                  onChange={e => setForm(f => ({ ...f, observacao: e.target.value }))}
                  placeholder="Observação (Opcional)"
                  className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC3951]/30 focus:border-[#FC3951] transition-all"
                />
              </div>

              {error && (
                <p className="text-sm text-red-600 bg-red-50 px-4 py-2.5 rounded-xl border border-red-100">{error}</p>
              )}
            </div>

            <div className="px-6 py-4 border-t border-gray-100 flex gap-3 justify-end">
              <button
                onClick={() => setShowModal(false)}
                className="text-sm font-medium px-4 py-2.5 rounded-xl border border-gray-200 text-gray-600 hover:bg-gray-50"
              >
                Cancelar
              </button>
              <button
                onClick={handleCreate}
                disabled={saving}
                className="flex items-center gap-2 bg-[#FC3951] text-white text-sm font-semibold px-6 py-2.5 rounded-xl hover:bg-[#D4253D] transition-colors disabled:opacity-40 shadow-sm shadow-[#FC3951]/30"
              >
                {saving
                  ? <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                  : <UserCheck size={15} />
                }
                {saving ? 'Gerando...' : 'Registrar visita'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
