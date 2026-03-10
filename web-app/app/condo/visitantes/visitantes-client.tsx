'use client'

import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { UserCheck, Plus, X, CheckCircle2, Clock, QrCode } from 'lucide-react'

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

const VISITOR_TYPES = ['Familiar', 'Amigo', 'Prestador de serviço', 'Médico', 'Outros']

function formatDate(dateStr: string) {
  return new Date(dateStr + 'T00:00:00').toLocaleDateString('pt-BR', {
    day: '2-digit', month: '2-digit', year: 'numeric',
  })
}

function ConviteCard({ convite }: { convite: Convite }) {
  const chegou = Boolean(convite.visitante_compareceu)
  const validDate = new Date(convite.validity_date + 'T00:00:00')
  const isExpired = validDate < new Date() && !chegou
  const code = convite.qr_data ? convite.qr_data.slice(-4).toUpperCase() : '—'

  return (
    <div className={`bg-white rounded-2xl border shadow-sm overflow-hidden ${
      chegou ? 'border-green-200' : isExpired ? 'border-gray-200' : 'border-orange-100'
    }`}>
      <div className={`px-5 py-3 flex items-center justify-between ${
        chegou ? 'bg-emerald-500' : isExpired ? 'bg-gray-400' : 'bg-[#E85D26]'
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

  const [form, setForm] = useState({
    guest_name: '',
    visitor_type: 'Familiar',
    validity_date: '',
  })

  const filtered = convites.filter(c => {
    if (filter === 'pendente') return !Boolean(c.visitante_compareceu)
    if (filter === 'entrou') return Boolean(c.visitante_compareceu)
    return true
  })

  async function handleCreate() {
    if (!form.guest_name.trim() || !form.validity_date) {
      setError('Preencha o nome do visitante e a data de validade.')
      return
    }
    setSaving(true)
    setError('')
    const supabase = createClient()
    const { data: { user: cu } } = await supabase.auth.getUser()

    // Generate code
    const code = Math.random().toString(36).substring(2, 8).toUpperCase()
    const now = new Date().toISOString()

    const { data: inserted, error: insertError } = await supabase
      .from('convites')
      .insert({
        resident_id: cu?.id ?? userId,
        condominio_id: condoId,
        guest_name: form.guest_name.trim(),
        visitor_type: form.visitor_type,
        validity_date: form.validity_date,
        qr_data: code,
        visitante_compareceu: false,
        status: 'pending',
        created_at: now,
      })
      .select()
      .single()

    if (insertError) {
      setError('Erro ao criar autorização. Tente novamente.')
    } else if (inserted) {
      setConvites(prev => [inserted, ...prev])
      setShowModal(false)
      setForm({ guest_name: '', visitor_type: 'Familiar', validity_date: '' })
    }
    setSaving(false)
  }

  // Min date = today
  const today = new Date().toISOString().split('T')[0]

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
                  ? 'bg-[#E85D26] text-white border-[#E85D26] shadow-sm'
                  : 'bg-white text-gray-600 border-gray-200 hover:border-[#E85D26]/50 hover:text-[#E85D26]'
              }`}
            >
              {label}
            </button>
          ))}
        </div>
        <button
          onClick={() => setShowModal(true)}
          className="flex items-center gap-2 bg-[#E85D26] text-white text-sm font-semibold px-5 py-2.5 rounded-xl hover:bg-[#c44d1e] transition-colors shadow-sm shadow-[#E85D26]/30"
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
                  Nome do visitante
                </label>
                <input
                  value={form.guest_name}
                  onChange={e => setForm(f => ({ ...f, guest_name: e.target.value }))}
                  placeholder="Ex: João Silva"
                  className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-[#E85D26]/30 focus:border-[#E85D26] transition-all"
                />
              </div>

              <div>
                <label className="text-xs font-semibold text-gray-500 uppercase tracking-wider block mb-2">
                  Tipo de visitante
                </label>
                <div className="flex flex-wrap gap-2">
                  {VISITOR_TYPES.map(type => (
                    <button
                      key={type}
                      onClick={() => setForm(f => ({ ...f, visitor_type: type }))}
                      className={`text-sm px-3 py-1.5 rounded-xl border font-medium transition-all ${
                        form.visitor_type === type
                          ? 'bg-[#E85D26] text-white border-[#E85D26]'
                          : 'bg-gray-50 text-gray-600 border-gray-200 hover:border-gray-300'
                      }`}
                    >
                      {type}
                    </button>
                  ))}
                </div>
              </div>

              <div>
                <label className="text-xs font-semibold text-gray-500 uppercase tracking-wider block mb-2">
                  Data de validade
                </label>
                <input
                  type="date"
                  min={today}
                  value={form.validity_date}
                  onChange={e => setForm(f => ({ ...f, validity_date: e.target.value }))}
                  className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-[#E85D26]/30 focus:border-[#E85D26] transition-all"
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
                className="flex items-center gap-2 bg-[#E85D26] text-white text-sm font-semibold px-6 py-2.5 rounded-xl hover:bg-[#c44d1e] transition-colors disabled:opacity-40 shadow-sm shadow-[#E85D26]/30"
              >
                {saving
                  ? <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                  : <UserCheck size={15} />
                }
                {saving ? 'Gerando...' : 'Gerar Autorização'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
