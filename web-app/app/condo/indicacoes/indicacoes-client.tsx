'use client'
import { useState, useRef } from 'react'
import { createClient } from '@/lib/supabase/client'
import { Star, Plus, X, Phone, MessageCircle, MapPin, User, Search, ChevronDown } from 'lucide-react'

const ESPECIALIDADES = [
  'Advocacia', 'Agronomia', 'Arquitetura', 'Chaveiro', 'Dedetização',
  'Eletricista', 'Encanador', 'Estética', 'Fisioterapeuta', 'Jardinagem',
  'Marceneiro', 'Mecânico', 'Médico', 'Nutricionista', 'Pedreiro',
  'Personal Trainer', 'Pintor', 'Psicólogo', 'Serralheiro',
  'TI / Informática', 'Outros',
]

const ESPECIALIDADE_EMOJI: Record<string, string> = {
  'Advocacia': '⚖️', 'Agronomia': '🌱', 'Arquitetura': '🏛️',
  'Chaveiro': '🔑', 'Dedetização': '🪲', 'Eletricista': '⚡',
  'Encanador': '🔧', 'Estética': '💅', 'Fisioterapeuta': '🦴',
  'Jardinagem': '🌿', 'Marceneiro': '🪵', 'Mecânico': '🔩',
  'Médico': '🩺', 'Nutricionista': '🥗', 'Pedreiro': '🧱',
  'Personal Trainer': '🏋️', 'Pintor': '🎨', 'Psicólogo': '🧠',
  'Serralheiro': '⛓️', 'TI / Informática': '💻', 'Outros': '🌟',
}

interface Indicacao {
  id: string
  nome: string
  whatsapp: string | null
  especialidade: string
  uf: string | null
  cidade: string | null
  observacoes: string | null
  foto_url: string | null
  created_at: string
  criador: { nome_completo: string } | null
}

interface Avaliacao {
  id: string
  indicacao_id: string
  usuario_id: string
  nota: number
  comentario: string | null
}

interface Props {
  indicacoes: Indicacao[]
  avaliacoes: Avaliacao[]
  condoId: string
  currentUserId: string
  currentUserName: string
}

function StarRow({ value, onChange, size = 24 }: { value: number; onChange?: (n: number) => void; size?: number }) {
  const [hovered, setHovered] = useState(0)
  return (
    <div className="flex gap-1">
      {[1,2,3,4,5].map(n => (
        <button
          key={n}
          type="button"
          onClick={() => onChange?.(n)}
          onMouseEnter={() => onChange && setHovered(n)}
          onMouseLeave={() => onChange && setHovered(0)}
          className={onChange ? 'cursor-pointer' : 'cursor-default'}
          title={`${n} estrela${n > 1 ? 's' : ''}`}
        >
          <Star
            size={size}
            className={`transition-colors ${(hovered || value) >= n ? 'fill-amber-400 text-amber-400' : 'fill-gray-200 text-gray-200'}`}
          />
        </button>
      ))}
    </div>
  )
}

function openWhatsApp(phone: string) {
  const cleaned = phone.replace(/\D/g, '')
  const num = cleaned.startsWith('55') ? cleaned : `55${cleaned}`
  window.open(`https://wa.me/${num}`, '_blank')
}

export default function IndicacoesClient({
  indicacoes: initialIndicacoes,
  avaliacoes: initialAvaliacoes,
  condoId,
  currentUserId,
  currentUserName,
}: Props) {
  const supabase = createClient()
  const [indicacoes, setIndicacoes] = useState(initialIndicacoes)
  const [avaliacoes, setAvaliacoes] = useState(initialAvaliacoes)

  // ── Filters ──────────────────────────────────────────────────────────────
  const [filterEsp, setFilterEsp] = useState('')
  const [filterSearch, setFilterSearch] = useState('')

  const filtered = indicacoes.filter(i => {
    const matchEsp = !filterEsp || i.especialidade === filterEsp
    const matchSearch = !filterSearch || i.nome.toLowerCase().includes(filterSearch.toLowerCase())
    return matchEsp && matchSearch
  })

  // ── Rating modal ─────────────────────────────────────────────────────────
  const [ratingTarget, setRatingTarget] = useState<Indicacao | null>(null)
  const [ratingStars, setRatingStars] = useState(0)
  const [ratingComment, setRatingComment] = useState('')
  const [ratingLoading, setRatingLoading] = useState(false)

  function openRatingModal(ind: Indicacao) {
    const myAv = avaliacoes.find(a => a.indicacao_id === ind.id && a.usuario_id === currentUserId)
    setRatingStars(myAv?.nota ?? 0)
    setRatingComment(myAv?.comentario ?? '')
    setRatingTarget(ind)
  }

  async function submitRating() {
    if (!ratingTarget || ratingStars === 0) return
    setRatingLoading(true)
    const { error } = await supabase
      .from('indicacoes_avaliacoes')
      .upsert({
        indicacao_id: ratingTarget.id,
        usuario_id: currentUserId,
        nota: ratingStars,
        comentario: ratingComment.trim() || null,
      }, { onConflict: 'indicacao_id,usuario_id' })
    if (!error) {
      // refresh local state
      const { data: fresh } = await supabase
        .from('indicacoes_avaliacoes')
        .select('*')
        .in('indicacao_id', indicacoes.map(i => i.id))
      setAvaliacoes(fresh ?? [])
      setRatingTarget(null)
    }
    setRatingLoading(false)
  }

  // ── New indicação modal ───────────────────────────────────────────────────
  const [showNew, setShowNew] = useState(false)
  const [newNome, setNewNome] = useState('')
  const [newWhatsapp, setNewWhatsapp] = useState('')
  const [newUf, setNewUf] = useState('')
  const [newCidade, setNewCidade] = useState('')
  const [newEsp, setNewEsp] = useState('')
  const [newEspSearch, setNewEspSearch] = useState('')
  const [showEspDropdown, setShowEspDropdown] = useState(false)
  const [newObs, setNewObs] = useState('')
  const [newFotoFile, setNewFotoFile] = useState<File | null>(null)
  const [newFotoPreview, setNewFotoPreview] = useState('')
  const [newLoading, setNewLoading] = useState(false)
  const [newError, setNewError] = useState('')
  const fileRef = useRef<HTMLInputElement>(null)

  const filteredEsps = ESPECIALIDADES.filter(e =>
    e.toLowerCase().includes(newEspSearch.toLowerCase())
  )

  function resetNew() {
    setShowNew(false); setNewNome(''); setNewWhatsapp(''); setNewUf(''); setNewCidade('')
    setNewEsp(''); setNewEspSearch(''); setNewObs(''); setNewFotoFile(null)
    setNewFotoPreview(''); setNewError('')
  }

  async function handleCreate() {
    if (!newNome.trim()) { setNewError('Informe o nome do profissional.'); return }
    if (!newEsp) { setNewError('Selecione a especialidade.'); return }
    setNewError(''); setNewLoading(true)

    let foto_url: string | null = null
    if (newFotoFile) {
      const ext = newFotoFile.name.split('.').pop()
      const path = `indicacoes/${condoId}/${Date.now()}.${ext}`
      const { error: upErr } = await supabase.storage.from('community').upload(path, newFotoFile)
      if (!upErr) {
        const { data: pub } = supabase.storage.from('community').getPublicUrl(path)
        foto_url = pub.publicUrl
      }
    }

    const { data: inserted, error } = await supabase
      .from('indicacoes_servico')
      .insert({
        condominio_id: condoId,
        criado_por: currentUserId,
        nome: newNome.trim(),
        whatsapp: newWhatsapp.trim() || null,
        especialidade: newEsp,
        uf: newUf.trim() || null,
        cidade: newCidade.trim() || null,
        observacoes: newObs.trim() || null,
        foto_url,
      })
      .select('*, criador:perfil!criado_por(nome_completo)')
      .single()

    if (error) { setNewError('Erro: ' + error.message); setNewLoading(false); return }

    // Push notification
    try {
      const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
      const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
      if (supabaseUrl && anonKey) {
        fetch(`${supabaseUrl}/functions/v1/indicacoes-notify`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${anonKey}` },
          body: JSON.stringify({ condominio_id: condoId, indicacao_id: inserted.id }),
        }).catch(console.error)
      }
    } catch (_) { /* silent */ }

    setIndicacoes(prev => [inserted, ...prev])
    resetNew()
    setNewLoading(false)
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  function getAvgRating(id: string) {
    const avs = avaliacoes.filter(a => a.indicacao_id === id)
    if (!avs.length) return null
    return { avg: avs.reduce((s, a) => s + a.nota, 0) / avs.length, count: avs.length }
  }

  function getMyRating(id: string) {
    return avaliacoes.find(a => a.indicacao_id === id && a.usuario_id === currentUserId)
  }

  // ── Render ────────────────────────────────────────────────────────────────
  return (
    <div className="max-w-4xl mx-auto">
      {/* Header */}
      <div className="mb-6 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
            🌟 Indicações de Serviço
          </h1>
          <p className="text-sm text-gray-500 mt-1">Profissionais, lojas e empresas recomendados pelos moradores</p>
        </div>
        <button
          onClick={() => setShowNew(true)}
          className="flex items-center gap-2 bg-[#FC5931] text-white px-5 py-2.5 rounded-xl font-semibold text-sm hover:bg-[#D42F1D] transition-all shadow-lg shadow-[#FC5931]/20"
        >
          <Plus size={18} /> Indicar
        </button>
      </div>

      {/* Filters */}
      <div className="flex flex-wrap gap-3 mb-6">
        <div className="relative flex-1 min-w-[200px]">
          <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input
            type="text"
            value={filterSearch}
            onChange={e => setFilterSearch(e.target.value)}
            placeholder="Buscar por nome..."
            className="w-full border border-gray-200 rounded-xl pl-9 pr-3 py-2.5 text-sm focus:outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931]/30"
          />
        </div>
        <select
          value={filterEsp}
          onChange={e => setFilterEsp(e.target.value)}
          className="border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:border-[#FC5931] bg-white min-w-[160px]"
          title="Filtrar por especialidade"
        >
          <option value="">Todas especialidades</option>
          {ESPECIALIDADES.map(e => <option key={e} value={e}>{ESPECIALIDADE_EMOJI[e]} {e}</option>)}
        </select>
      </div>

      {/* Cards */}
      <div className="space-y-4">
        {filtered.length === 0 ? (
          <div className="bg-white rounded-2xl border border-gray-100 p-14 text-center shadow-sm">
            <div className="text-5xl mb-3">🌟</div>
            <p className="text-gray-400 font-medium">Nenhuma indicação ainda</p>
            <p className="text-gray-300 text-sm mt-1">Seja o primeiro a indicar um profissional!</p>
          </div>
        ) : (
          filtered.map(ind => {
            const rating = getAvgRating(ind.id)
            const myRating = getMyRating(ind.id)
            const emoji = ESPECIALIDADE_EMOJI[ind.especialidade] ?? '🌟'

            return (
              <div key={ind.id} className="bg-white rounded-2xl border border-gray-100 shadow-sm hover:shadow-md transition-shadow overflow-hidden">
                <div className="p-5">
                  <div className="flex gap-4">
                    {/* Photo */}
                    <div className="flex-shrink-0">
                      {ind.foto_url ? (
                        <img src={ind.foto_url} alt={ind.nome} className="w-16 h-16 rounded-2xl object-cover border-2 border-gray-100" />
                      ) : (
                        <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-[#FC5931]/10 to-[#FC5931]/20 flex items-center justify-center border-2 border-[#FC5931]/10 text-2xl">
                          {emoji}
                        </div>
                      )}
                    </div>

                    {/* Info */}
                    <div className="flex-1 min-w-0">
                      <div className="flex items-start justify-between gap-2 flex-wrap">
                        <div>
                          <h3 className="font-bold text-gray-900 text-base">{ind.nome}</h3>
                          <span className="inline-flex items-center gap-1 text-xs font-semibold px-2.5 py-0.5 rounded-full bg-[#FC5931]/10 text-[#FC5931] mt-1">
                            {emoji} {ind.especialidade}
                          </span>
                        </div>
                        {ind.whatsapp && (
                          <button
                            onClick={() => openWhatsApp(ind.whatsapp!)}
                            className="flex items-center gap-1.5 bg-green-500 hover:bg-green-600 text-white text-xs font-semibold px-3 py-1.5 rounded-xl transition-colors shadow-sm shadow-green-500/30"
                            title="Falar com o indicado via WhatsApp"
                          >
                            <MessageCircle size={14} /> WhatsApp
                          </button>
                        )}
                      </div>

                      {/* Location */}
                      {(ind.uf || ind.cidade) && (
                        <p className="flex items-center gap-1 text-sm text-gray-500 mt-2">
                          <MapPin size={13} className="text-gray-400 flex-shrink-0" />
                          {[ind.uf, ind.cidade].filter(Boolean).join(' / ')}
                        </p>
                      )}

                      {/* Obs */}
                      {ind.observacoes && (
                        <p className="text-sm text-gray-500 mt-1.5 line-clamp-2">{ind.observacoes}</p>
                      )}

                      {/* Who recommended */}
                      <p className="flex items-center gap-1 text-xs text-gray-400 mt-2">
                        <User size={11} />
                        Indicado por <span className="font-medium text-gray-600 ml-0.5">{ind.criador?.nome_completo ?? 'Morador'}</span>
                      </p>
                    </div>
                  </div>

                  {/* Rating section */}
                  <div className="mt-4 pt-4 border-t border-gray-50 flex items-center justify-between flex-wrap gap-3">
                    <div className="space-y-1">
                      <div className="flex items-center gap-2">
                        <span className="text-xs text-gray-400 font-medium w-28">Minha avaliação:</span>
                        <StarRow value={myRating?.nota ?? 0} size={16} />
                      </div>
                      <div className="flex items-center gap-2">
                        <span className="text-xs text-gray-400 font-medium w-28">Avaliação geral:</span>
                        <StarRow value={rating ? Math.round(rating.avg) : 0} size={16} />
                        {rating && (
                          <span className="text-xs text-gray-400">
                            {rating.avg.toFixed(1)} ({rating.count})
                          </span>
                        )}
                      </div>
                    </div>
                    <button
                      onClick={() => openRatingModal(ind)}
                      className="flex items-center gap-1.5 border-2 border-[#FC5931] text-[#FC5931] hover:bg-[#FC5931] hover:text-white text-sm font-semibold px-4 py-1.5 rounded-xl transition-all"
                    >
                      <Star size={14} />
                      {myRating ? 'Reavaliar' : 'Avaliar'}
                    </button>
                  </div>
                </div>
              </div>
            )
          })
        )}
      </div>

      {/* ── Rating Modal ──────────────────────────────────────── */}
      {ratingTarget && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4 backdrop-blur-sm">
          <div className="bg-white rounded-2xl w-full max-w-sm shadow-2xl">
            <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100">
              <h2 className="text-base font-bold text-gray-900">Avaliar indicação</h2>
              <button onClick={() => setRatingTarget(null)} className="text-gray-400 hover:text-gray-600" title="Fechar">
                <X size={20} />
              </button>
            </div>
            <div className="p-6 space-y-4">
              <p className="font-semibold text-gray-700">{ratingTarget.nome}</p>
              <div>
                <p className="text-sm text-gray-500 mb-2">Sua avaliação</p>
                <StarRow value={ratingStars} onChange={setRatingStars} size={32} />
              </div>
              <textarea
                value={ratingComment}
                onChange={e => setRatingComment(e.target.value)}
                placeholder="Opcional: Escreva aqui seu comentário."
                rows={4}
                className="w-full border border-gray-200 rounded-xl px-4 py-3 text-sm focus:outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931]/30 resize-none"
              />
              <button
                onClick={submitRating}
                disabled={ratingStars === 0 || ratingLoading}
                className="w-full bg-[#FC5931] hover:bg-[#D42F1D] text-white font-bold py-3 rounded-xl transition-all disabled:opacity-50"
              >
                {ratingLoading ? 'Salvando...' : 'Avaliar'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ── New Indicação Modal ───────────────────────────────── */}
      {showNew && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4 backdrop-blur-sm">
          <div className="bg-white rounded-2xl w-full max-w-lg shadow-2xl max-h-[90vh] overflow-y-auto">
            <div className="bg-[#FC5931] text-white px-6 py-4 rounded-t-2xl flex items-center justify-between">
              <h2 className="text-lg font-bold">Nova Indicação</h2>
              <button onClick={resetNew} className="text-white/80 hover:text-white" title="Fechar"><X size={22} /></button>
            </div>
            <div className="p-6 space-y-4">
              {/* Photo */}
              <div className="flex flex-col items-center">
                <button
                  type="button"
                  onClick={() => fileRef.current?.click()}
                  className="w-24 h-24 rounded-2xl border-2 border-dashed border-gray-300 hover:border-[#FC5931] transition-colors flex flex-col items-center justify-center gap-1 overflow-hidden"
                >
                  {newFotoPreview ? (
                    <img src={newFotoPreview} alt="preview" className="w-full h-full object-cover" />
                  ) : (
                    <>
                      <span className="text-2xl">📷</span>
                      <span className="text-xs text-gray-400">Foto (opcional)</span>
                    </>
                  )}
                </button>
                <input
                  ref={fileRef}
                  type="file"
                  accept="image/*"
                  className="hidden"
                  onChange={e => {
                    const f = e.target.files?.[0] ?? null
                    setNewFotoFile(f)
                    setNewFotoPreview(f ? URL.createObjectURL(f) : '')
                  }}
                />
              </div>

              {/* Nome */}
              <div>
                <label className="block text-sm font-semibold text-gray-700 mb-1">Nome do profissional / Loja *</label>
                <input
                  type="text"
                  value={newNome}
                  onChange={e => setNewNome(e.target.value)}
                  placeholder="Ex: João Eletricista"
                  className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931]/30"
                />
              </div>

              {/* WhatsApp */}
              <div>
                <label className="block text-sm font-semibold text-gray-700 mb-1">
                  WhatsApp <span className="font-normal text-gray-400">(para os vizinhos contatarem)</span>
                </label>
                <div className="relative">
                  <Phone size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
                  <input
                    type="tel"
                    value={newWhatsapp}
                    onChange={e => setNewWhatsapp(e.target.value)}
                    placeholder="(XX) 9 9999-9999"
                    className="w-full border border-gray-200 rounded-xl pl-9 pr-4 py-2.5 text-sm focus:outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931]/30"
                  />
                </div>
              </div>

              {/* UF + Cidade */}
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm font-semibold text-gray-700 mb-1">UF</label>
                  <input
                    type="text"
                    value={newUf}
                    onChange={e => setNewUf(e.target.value.toUpperCase().slice(0, 2))}
                    placeholder="SP"
                    maxLength={2}
                    className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931]/30"
                  />
                </div>
                <div>
                  <label className="block text-sm font-semibold text-gray-700 mb-1">Cidade</label>
                  <input
                    type="text"
                    value={newCidade}
                    onChange={e => setNewCidade(e.target.value)}
                    placeholder="São Paulo"
                    className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931]/30"
                  />
                </div>
              </div>

              {/* Especialidade typeahead */}
              <div className="relative">
                <label className="block text-sm font-semibold text-gray-700 mb-1">Especialidade *</label>
                <div className="relative">
                  <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
                  <input
                    type="text"
                    value={newEsp || newEspSearch}
                    onChange={e => {
                      setNewEsp('')
                      setNewEspSearch(e.target.value)
                      setShowEspDropdown(true)
                    }}
                    onFocus={() => setShowEspDropdown(true)}
                    placeholder="Escolha ou busque uma especialidade..."
                    className="w-full border border-gray-200 rounded-xl pl-9 pr-9 py-2.5 text-sm focus:outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931]/30"
                  />
                  <ChevronDown size={14} className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none" />
                </div>
                {showEspDropdown && filteredEsps.length > 0 && (
                  <div className="absolute z-10 w-full mt-1 bg-white border border-gray-200 rounded-xl shadow-lg max-h-48 overflow-y-auto">
                    {filteredEsps.map(e => (
                      <button
                        key={e}
                        type="button"
                        onClick={() => {
                          setNewEsp(e)
                          setNewEspSearch(e)
                          setShowEspDropdown(false)
                        }}
                        className={`w-full text-left px-4 py-2.5 text-sm hover:bg-[#FC5931]/5 transition-colors ${newEsp === e ? 'bg-[#FC5931]/10 text-[#FC5931] font-semibold' : 'text-gray-700'}`}
                      >
                        {ESPECIALIDADE_EMOJI[e]} {e}
                      </button>
                    ))}
                  </div>
                )}
              </div>

              {/* Observações */}
              <div>
                <label className="block text-sm font-semibold text-gray-700 mb-1">Observações <span className="font-normal text-gray-400">(opcional)</span></label>
                <textarea
                  value={newObs}
                  onChange={e => setNewObs(e.target.value)}
                  placeholder="Conte sua experiência com este profissional..."
                  rows={3}
                  className="w-full border border-gray-200 rounded-xl px-4 py-3 text-sm focus:outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931]/30 resize-none"
                />
              </div>

              {newError && (
                <p className="text-sm text-red-600 bg-red-50 px-4 py-2.5 rounded-xl">{newError}</p>
              )}

              <button
                onClick={handleCreate}
                disabled={newLoading}
                className="w-full bg-[#FC5931] hover:bg-[#D42F1D] text-white font-bold py-3.5 rounded-xl transition-all disabled:opacity-60 shadow-lg shadow-[#FC5931]/20"
              >
                {newLoading ? 'Publicando...' : '🌟 Publicar Indicação'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
