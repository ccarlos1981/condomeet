'use client'

import { useState, useMemo } from 'react'
import { createClient } from '@/lib/supabase/client'
import { UserCheck, CheckCircle, AlertCircle } from 'lucide-react'
import { QRCodeSVG } from 'qrcode.react'

const VISITOR_TYPES = ['Uber ou Taxi', 'Delivery', 'Farmácia', 'Diarista', 'Visitante', 'Mat. Obra', 'Serviços', 'Hóspedes', 'Outros']

interface Props {
  condoId: string
  condoName: string
  currentUserId: string
  currentUserName: string
  blocos: string[]
  aptosMap: Record<string, string[]>
  residentsPerUnit: Record<string, { id: string; nome_completo: string }[]>
}

export default function AutorizarVisitantePortariaClient({
  condoId,
  condoName: _condoName,
  currentUserId: _currentUserId,
  currentUserName,
  blocos,
  aptosMap,
  residentsPerUnit,
}: Props) {
  // Form state
  const [visitorType, setVisitorType] = useState('')
  const [bloco, setBloco] = useState('')
  const [apto, setApto] = useState('')
  const [selectedResident, setSelectedResident] = useState('')
  const [manualResidentName, setManualResidentName] = useState('')
  const [manualResidentWhatsapp, setManualResidentWhatsapp] = useState('')
  const [validityDate, setValidityDate] = useState(new Date().toISOString().split('T')[0])
  const [guestName, setGuestName] = useState('')
  const [visitorWhatsapp, setVisitorWhatsapp] = useState('')
  const [observacao, setObservacao] = useState('')

  // UI state
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [successData, setSuccessData] = useState<{ code: string; guestName: string; visitorType: string; date: string } | null>(null)

  const today = new Date().toISOString().split('T')[0]
  const availableAptos = bloco ? (aptosMap[bloco] ?? []) : []
  const unitKey = bloco && apto ? `${bloco}__${apto}` : ''
  const unitResidents = useMemo(() => unitKey ? (residentsPerUnit[unitKey] ?? []) : [], [unitKey, residentsPerUnit])
  const hasResidents = unitResidents.length > 0

  async function handleSubmit() {
    // Validation
    if (!visitorType) { setError('Selecione o tipo de visitante.'); return }
    if (!bloco || !apto) { setError('Selecione o bloco e o apartamento.'); return }

    setError('')
    setSaving(true)

    try {
      const supabase = createClient()

      // Generate 3-char random alphanumeric code
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
      const code = Array.from({ length: 3 }, () => chars[Math.floor(Math.random() * chars.length)]).join('')

      // Determine resident_id
      let residentId: string | null = null
      let moradorNomeManual: string | null = null

      if (hasResidents && selectedResident && selectedResident !== '__none__') {
        residentId = selectedResident
      } else if (!hasResidents && manualResidentName.trim()) {
        moradorNomeManual = manualResidentName.trim()
      }
      // If selectedResident === '__none__' → no resident identified, residentId stays null

      const { error: insertError } = await supabase
        .from('convites')
        .insert({
          resident_id: residentId,
          condominio_id: condoId,
          guest_name: guestName.trim() || null,
          visitor_type: visitorType,
          validity_date: validityDate,
          qr_data: code,
          visitante_compareceu: false,
          status: 'active',
          whatsapp: visitorWhatsapp.trim() || null,
          observacao: observacao.trim() || null,
          criado_por_portaria: true,
          bloco_destino: bloco,
          apto_destino: apto,
          morador_nome_manual: moradorNomeManual,
        })

      if (insertError) {
        setError('Erro ao registrar autorização: ' + insertError.message)
        setSaving(false)
        return
      }

      // Success
      setSuccessData({
        code,
        guestName: guestName.trim() || 'Visitante',
        visitorType,
        date: validityDate,
      })

      // Reset form after 4 seconds
      setTimeout(() => {
        resetForm()
        setSuccessData(null)
      }, 4000)
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err)
      setError('Erro inesperado: ' + msg)
    }
    setSaving(false)
  }

  function resetForm() {
    setVisitorType('')
    setBloco('')
    setApto('')
    setSelectedResident('')
    setManualResidentName('')
    setManualResidentWhatsapp('')
    setValidityDate(today)
    setGuestName('')
    setVisitorWhatsapp('')
    setObservacao('')
    setError('')
  }

  // ── Success view ────────────────────────────────────────────────
  if (successData) {
    return (
      <div className="bg-white rounded-2xl border border-green-200 shadow-sm p-8 text-center max-w-md mx-auto">
        <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
          <CheckCircle size={32} className="text-green-600" />
        </div>
        <h2 className="text-xl font-bold text-gray-900 mb-2">Autorização Registrada!</h2>
        <p className="text-sm text-gray-500 mb-5">A autorização foi criada com sucesso.</p>

        <div className="bg-gray-50 rounded-xl p-5 mb-5 space-y-3">
          <div className="flex justify-center mb-4">
            <div className="bg-white border border-gray-200 rounded-xl p-3 shadow-sm">
              <QRCodeSVG value={successData.code} size={120} />
            </div>
          </div>
          <p className="text-2xl font-bold tracking-widest text-[#FC5931]">{successData.code}</p>
          <p className="text-sm text-gray-600">
            <span className="font-medium">Tipo:</span> {successData.visitorType}
          </p>
          <p className="text-sm text-gray-600">
            <span className="font-medium">Visitante:</span> {successData.guestName}
          </p>
          <p className="text-sm text-gray-600">
            <span className="font-medium">Data:</span> {new Date(successData.date + 'T00:00:00').toLocaleDateString('pt-BR')}
          </p>
        </div>

        <button
          onClick={() => { resetForm(); setSuccessData(null) }}
          className="bg-[#FC5931] text-white px-6 py-2.5 rounded-xl font-semibold hover:bg-[#D42F1D] transition-colors"
        >
          Nova Autorização
        </button>
      </div>
    )
  }

  // ── Form ────────────────────────────────────────────────────────
  return (
    <div className="max-w-lg mx-auto">
      <div className="bg-[#FC5931] text-white text-center font-bold py-3 rounded-t-xl text-lg">
        Solicitação de autorização de entrada — por {currentUserName}
      </div>
      <div className="bg-white rounded-b-xl border border-gray-100 border-t-0 p-6 space-y-5">

        {/* Tipo de visitante */}
        <div>
          <label className="block text-sm font-semibold text-gray-700 mb-1">Tipo de visitante *</label>
          <select
            value={visitorType}
            onChange={e => setVisitorType(e.target.value)}
            title="Tipo de visitante"
            className="w-full border border-gray-200 rounded-lg px-4 py-2.5 text-sm focus:outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931]/30 bg-white"
          >
            <option value="">Selecione o tipo de visitante</option>
            {VISITOR_TYPES.map(t => (
              <option key={t} value={t}>{t}</option>
            ))}
          </select>
        </div>

        {/* Bloco / Apto */}
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-semibold text-gray-700 mb-1">Bloco *</label>
            <select
              value={bloco}
              onChange={e => { setBloco(e.target.value); setApto(''); setSelectedResident('') }}
              title="Selecione o bloco"
              className="w-full border border-gray-200 rounded-lg px-4 py-2.5 text-sm focus:outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931]/30 bg-white"
            >
              <option value="">Bloco</option>
              {blocos.map(b => (
                <option key={b} value={b}>{b}</option>
              ))}
            </select>
          </div>
          <div>
            <label className="block text-sm font-semibold text-gray-700 mb-1">Apto *</label>
            <select
              value={apto}
              onChange={e => { setApto(e.target.value); setSelectedResident('') }}
              disabled={!bloco}
              title="Selecione o apartamento"
              className="w-full border border-gray-200 rounded-lg px-4 py-2.5 text-sm focus:outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931]/30 bg-white disabled:bg-gray-50 disabled:text-gray-400"
            >
              <option value="">Apto</option>
              {availableAptos.map(a => (
                <option key={a} value={a}>{a}</option>
              ))}
            </select>
          </div>
        </div>

        {/* Quem solicitou — show after selecting bloco + apto */}
        {bloco && apto && (
          <div>
            {hasResidents ? (
              <>
                <label className="block text-sm font-semibold text-gray-700 mb-1">
                  Quem solicitou? (Desejável)
                </label>
                <select
                  value={selectedResident}
                  onChange={e => setSelectedResident(e.target.value)}
                  title="Quem solicitou a autorização"
                  className="w-full border border-gray-200 rounded-lg px-4 py-2.5 text-sm focus:outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931]/30 bg-white"
                >
                  <option value="">Selecione o morador</option>
                  {unitResidents.map(r => (
                    <option key={r.id} value={r.id}>{r.nome_completo}</option>
                  ))}
                  <option value="__none__">Não se identificou</option>
                </select>
              </>
            ) : (
              <>
                <p className="text-xs text-amber-600 bg-amber-50 border border-amber-200 rounded-lg px-3 py-2 mb-3">
                  ⚠️ Nenhum morador cadastrado nesta unidade.
                </p>
                <div className="space-y-3">
                  <div>
                    <label className="block text-sm font-semibold text-gray-700 mb-1">Nome do morador não cadastrado</label>
                    <input
                      type="text"
                      value={manualResidentName}
                      onChange={e => setManualResidentName(e.target.value)}
                      placeholder="Nome do morador não cadastrado"
                      className="w-full border border-gray-200 rounded-lg px-4 py-2.5 text-sm focus:outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931]/30"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-semibold text-gray-700 mb-1">WhatsApp do morador</label>
                    <input
                      type="text"
                      value={manualResidentWhatsapp}
                      onChange={e => setManualResidentWhatsapp(e.target.value)}
                      placeholder="Whatsapp do morador: (62) 9 9999-9999"
                      className="w-full border border-gray-200 rounded-lg px-4 py-2.5 text-sm focus:outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931]/30"
                    />
                  </div>
                </div>
              </>
            )}
          </div>
        )}

        {/* Data */}
        <div className="text-center">
          <label className="block text-sm font-bold text-gray-700 mb-1">Data</label>
          <input
            type="date"
            min={today}
            value={validityDate}
            onChange={e => setValidityDate(e.target.value)}
            title="Data da visita"
            className="border border-gray-200 rounded-lg px-4 py-2.5 text-sm focus:outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931]/30 text-center"
          />
        </div>

        {/* Nome do visitante */}
        <div>
          <label className="block text-sm font-semibold text-gray-700 mb-1">Nome do visitante</label>
          <input
            type="text"
            value={guestName}
            onChange={e => setGuestName(e.target.value)}
            placeholder="Nome do visitante"
            className="w-full border border-gray-200 rounded-lg px-4 py-2.5 text-sm focus:outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931]/30"
          />
        </div>

        {/* WhatsApp do visitante */}
        <div>
          <label className="block text-sm font-semibold text-gray-700 mb-1">WhatsApp do visitante</label>
          <input
            type="text"
            value={visitorWhatsapp}
            onChange={e => setVisitorWhatsapp(e.target.value)}
            placeholder="Whatsapp do visitante: (62) 9 9999-9999"
            className="w-full border border-gray-200 rounded-lg px-4 py-2.5 text-sm focus:outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931]/30"
          />
        </div>

        {/* Observação */}
        <div>
          <label className="block text-sm font-semibold text-gray-700 mb-1">Observação</label>
          <textarea
            value={observacao}
            onChange={e => setObservacao(e.target.value)}
            rows={3}
            placeholder="Colocar observação"
            className="w-full border border-gray-200 rounded-lg px-4 py-2.5 text-sm focus:outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931]/30 resize-none"
          />
        </div>

        {/* Error */}
        {error && (
          <div className="flex items-center gap-2 text-red-600 text-sm bg-red-50 p-3 rounded-lg">
            <AlertCircle size={16} /> {error}
          </div>
        )}

        {/* Submit */}
        <button
          onClick={handleSubmit}
          disabled={saving}
          className="w-full bg-[#FC5931] text-white py-3 rounded-xl font-bold text-base hover:bg-[#D42F1D] transition-colors disabled:opacity-60 flex items-center justify-center gap-2"
        >
          {saving ? (
            <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
          ) : (
            <UserCheck size={20} />
          )}
          {saving ? 'Registrando...' : 'Registrar visita'}
        </button>
      </div>
    </div>
  )
}
