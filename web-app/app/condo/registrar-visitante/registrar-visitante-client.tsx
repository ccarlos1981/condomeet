'use client'
import { useState, useTransition, useRef, useCallback, useEffect } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'
import {
  Camera, UserPlus, Clock,
  CheckCircle, AlertCircle, ChevronLeft, X, Video
} from 'lucide-react'

interface Visitante {
  id: string
  nome: string
  cpf_rg: string | null
  whatsapp: string | null
  tipo_visitante: string | null
  empresa: string | null
  bloco: string | null
  apto: string | null
  observacao: string | null
  foto_url: string | null
  entrada_at: string
  saida_at: string | null
  registrado_por: string | null
  created_at: string
}

interface Props {
  visitantes: Visitante[]
  condoId: string
  currentUserId: string
  currentUserName: string
  blocos: string[]
  aptosMap: Record<string, string[]>
}

const TIPOS_VISITANTE = [
  'Visitante',
  'Prestador de Serviço',
  'Entregador',
  'Funcionário Terceirizado',
  'Outros',
]

export default function RegistrarVisitanteClient({
  visitantes: initialVisitantes,
  condoId,
  currentUserId,
  currentUserName,
  blocos,
  aptosMap,
}: Props) {
  const router = useRouter()
  const supabase = createClient()
  const [isPending, startTransition] = useTransition()

  // View state
  const [view, setView] = useState<'form' | 'history'>('form')

  // Form state
  const [cpfRg, setCpfRg] = useState('')
  const [nome, setNome] = useState('')
  const [whatsapp, setWhatsapp] = useState('')
  const [tipoVisitante, setTipoVisitante] = useState('')
  const [empresa, setEmpresa] = useState('')
  const [bloco, setBloco] = useState('')
  const [apto, setApto] = useState('')
  const [observacao, setObservacao] = useState('')
  const [fotoPreview, setFotoPreview] = useState<string | null>(null)
  const [fotoBlob, setFotoBlob] = useState<Blob | null>(null)
  const [lastVisit, setLastVisit] = useState<Visitante | null>(null)
  const [saved, setSaved] = useState(false)
  const [error, setError] = useState('')

  // CPF auto-search state
  const [cpfSuggestions, setCpfSuggestions] = useState<Visitante[]>([])
  const [showSuggestions, setShowSuggestions] = useState(false)
  const searchTimerRef = useRef<NodeJS.Timeout | null>(null)

  // Webcam state
  const [showWebcam, setShowWebcam] = useState(false)
  const videoRef = useRef<HTMLVideoElement>(null)
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const streamRef = useRef<MediaStream | null>(null)

  // Available aptos based on selected bloco
  const availableAptos = bloco ? (aptosMap[bloco] ?? []) : []

  // Visitor list
  const [visitantes, setVisitantes] = useState(initialVisitantes)

  // ── CPF/RG Auto-search (debounced) ─────────────────────────
  const handleCpfChange = useCallback((value: string) => {
    const cleaned = value.replace(/\D/g, '')
    setCpfRg(cleaned)

    if (searchTimerRef.current) clearTimeout(searchTimerRef.current)

    if (cleaned.length >= 3) {
      searchTimerRef.current = setTimeout(async () => {
        const { data } = await supabase
          .from('visitante_registros')
          .select('*')
          .eq('condominio_id', condoId)
          .ilike('cpf_rg', `${cleaned}%`)
          .order('entrada_at', { ascending: false })
          .limit(5)

        // Deduplicate by cpf_rg (keep most recent)
        const seen = new Set<string>()
        const unique = (data ?? []).filter(v => {
          if (!v.cpf_rg || seen.has(v.cpf_rg)) return false
          seen.add(v.cpf_rg)
          return true
        })
        setCpfSuggestions(unique)
        setShowSuggestions(unique.length > 0)
      }, 300)
    } else {
      setCpfSuggestions([])
      setShowSuggestions(false)
      // Clear auto-filled fields when CPF is erased
      if (lastVisit) {
        setNome(''); setWhatsapp(''); setTipoVisitante('')
        setEmpresa(''); setBloco(''); setApto('')
        setFotoPreview(null); setFotoBlob(null); setLastVisit(null)
      }
    }
  }, [condoId, supabase])

  function selectSuggestion(v: Visitante) {
    setCpfRg(v.cpf_rg || '')
    setNome(v.nome || '')
    setWhatsapp(v.whatsapp || '')
    setTipoVisitante(v.tipo_visitante || '')
    setEmpresa(v.empresa || '')
    setBloco(v.bloco || '')
    setApto(v.apto || '')
    setLastVisit(v)
    if (v.foto_url) setFotoPreview(v.foto_url)
    setShowSuggestions(false)
  }

  // ── Webcam capture ─────────────────────────────────────────
  const [videoReady, setVideoReady] = useState(false)

  // Ref callback: assigns stream when video element mounts
  const videoRefCallback = useCallback((node: HTMLVideoElement | null) => {
    (videoRef as React.MutableRefObject<HTMLVideoElement | null>).current = node
    if (node && streamRef.current) {
      node.srcObject = streamRef.current
      node.onloadeddata = () => setVideoReady(true)
    }
  }, [])

  async function startWebcam() {
    setVideoReady(false)
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: 'user', width: 640, height: 480 }
      })
      streamRef.current = stream
      // Show modal AFTER we have the stream
      setShowWebcam(true)
    } catch {
      setError('Não foi possível acessar a câmera.')
    }
  }

  function capturePhoto() {
    if (!videoRef.current || !canvasRef.current) return
    const video = videoRef.current
    const canvas = canvasRef.current
    canvas.width = video.videoWidth
    canvas.height = video.videoHeight
    const ctx = canvas.getContext('2d')
    if (!ctx) return
    ctx.drawImage(video, 0, 0)
    // Wait for blob before stopping webcam
    canvas.toBlob(blob => {
      if (blob) {
        setFotoBlob(blob)
        setFotoPreview(URL.createObjectURL(blob))
      }
      stopWebcam()
    }, 'image/jpeg', 0.85)
  }

  function stopWebcam() {
    if (streamRef.current) {
      streamRef.current.getTracks().forEach(t => t.stop())
      streamRef.current = null
    }
    setShowWebcam(false)
    setVideoReady(false)
  }

  // Cleanup webcam on unmount
  useEffect(() => {
    return () => {
      if (streamRef.current) {
        streamRef.current.getTracks().forEach(t => t.stop())
      }
    }
  }, [])

  // ── Save visitor ───────────────────────────────────────────
  async function handleSave() {
    if (!nome.trim()) { setError('Informe o nome do visitante.'); return }
    if (!tipoVisitante) { setError('Selecione o tipo de visitante.'); return }
    setError('')

    startTransition(async () => {
      let fotoUrl: string | null = null

      // Upload photo blob (from webcam)
      if (fotoBlob) {
        const path = `${condoId}/${Date.now()}.jpg`
        const { error: uploadError } = await supabase.storage
          .from('visitor-photos')
          .upload(path, fotoBlob, { contentType: 'image/jpeg', upsert: true })

        if (uploadError) {
          console.error('Upload error:', uploadError)
          // Continue without photo — don't block the registration
        } else {
          const { data: urlData } = supabase.storage
            .from('visitor-photos')
            .getPublicUrl(path)
          fotoUrl = urlData.publicUrl
        }
      } else if (fotoPreview && !fotoPreview.startsWith('blob:')) {
        // Reuse existing photo URL from a returning visitor (not a blob)
        fotoUrl = fotoPreview
      }

      const { data: newVisitor, error: insertError } = await supabase
        .from('visitante_registros')
        .insert({
          condominio_id: condoId,
          nome: nome.trim(),
          cpf_rg: cpfRg || null,
          whatsapp: whatsapp.trim() || null,
          tipo_visitante: tipoVisitante,
          empresa: empresa.trim() || null,
          bloco: bloco.trim() || null,
          apto: apto.trim() || null,
          observacao: observacao.trim() || null,
          foto_url: fotoUrl || null,
          registrado_por: currentUserId,
        })
        .select()
        .single()

      if (insertError) { setError('Erro ao salvar: ' + insertError.message); return }

      // Add to local state immediately so sidebar updates
      if (newVisitor) {
        setVisitantes(prev => [newVisitor, ...prev])
      }

      setSaved(true)
      setTimeout(() => { setSaved(false); resetForm(); router.refresh() }, 2000)
    })
  }

  function resetForm() {
    setCpfRg(''); setNome(''); setWhatsapp(''); setTipoVisitante('')
    setEmpresa(''); setBloco(''); setApto(''); setObservacao('')
    setFotoPreview(null); setFotoBlob(null); setLastVisit(null)
  }

  // ── Register exit ──────────────────────────────────────────
  async function handleRegistrarSaida(id: string) {
    startTransition(async () => {
      await supabase
        .from('visitante_registros')
        .update({ saida_at: new Date().toISOString() })
        .eq('id', id)
      router.refresh()
      setVisitantes(prev =>
        prev.map(v => v.id === id ? { ...v, saida_at: new Date().toISOString() } : v)
      )
    })
  }

  // ── Helpers ────────────────────────────────────────────────
  function fmtDate(iso: string) {
    const d = new Date(iso)
    return d.toLocaleDateString('pt-BR') + ' – ' + d.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' }) + 'h'
  }

  const pendentes = visitantes.filter(v => !v.saida_at)

  // ══════════════════════════════════════════════════════════
  // HISTORY VIEW
  // ══════════════════════════════════════════════════════════
  if (view === 'history') {
    return (
      <div>
        <div className="flex items-center gap-4 mb-6">
          <button
            onClick={() => setView('form')}
            className="flex items-center gap-1.5 text-[#FC5931] font-semibold hover:underline"
            title="Voltar ao formulário"
          >
            <ChevronLeft size={18} />
            VOLTAR
          </button>
          <h1 className="text-xl font-bold text-gray-800">Histórico dos visitantes</h1>
        </div>

        <div className="space-y-4">
          {visitantes.map(v => (
            <div key={v.id} className="bg-white rounded-xl border border-gray-100 p-5 flex items-start gap-5">
              <div className="w-16 h-16 rounded-full bg-gray-200 overflow-hidden flex-shrink-0">
                {v.foto_url ? (
                  <img src={v.foto_url} alt={v.nome} className="w-full h-full object-cover" />
                ) : (
                  <div className="w-full h-full flex items-center justify-center text-gray-400 text-xl">👤</div>
                )}
              </div>
              <div className="flex-1 min-w-0">
                <p className="font-bold text-gray-800">Visitante: {v.nome}</p>
                {(v.bloco || v.apto) && (
                  <p className="text-sm text-gray-500">Bloco: {v.bloco || '−'} / Apto: {v.apto || '−'}</p>
                )}
                <p className="text-sm text-gray-500">
                  <span className="font-medium">Entrada:</span> {fmtDate(v.entrada_at)}
                </p>
                {v.saida_at && (
                  <p className="text-sm text-gray-500">
                    <span className="font-medium">Saída:</span> {fmtDate(v.saida_at)}
                  </p>
                )}
              </div>
              <div className="flex-shrink-0">
                {!v.saida_at ? (
                  <button
                    onClick={() => handleRegistrarSaida(v.id)}
                    disabled={isPending}
                    title="Registrar saída do visitante"
                    className="bg-red-500 hover:bg-red-600 text-white px-4 py-2 rounded-lg font-semibold text-sm transition-colors disabled:opacity-60"
                  >
                    Registrar Saída
                  </button>
                ) : (
                  <div className="bg-green-500 text-white px-4 py-2 rounded-lg text-sm font-semibold text-center">
                    <div>Saída Registrada</div>
                    <div className="text-xs opacity-90">{new Date(v.saida_at).toLocaleDateString('pt-BR')}</div>
                  </div>
                )}
              </div>
            </div>
          ))}
          {visitantes.length === 0 && (
            <p className="text-gray-400 text-center py-12">Nenhum visitante registrado.</p>
          )}
        </div>
      </div>
    )
  }

  // ══════════════════════════════════════════════════════════
  // FORM VIEW
  // ══════════════════════════════════════════════════════════
  return (
    <div className="flex flex-col lg:flex-row gap-6">
      {/* ── LEFT: Registration Form ─────────────────────────── */}
      <div className="flex-1">
        <div className="bg-[#FC5931] text-white text-center font-bold py-3 rounded-t-xl text-lg">
          Registrar Visitante
        </div>
        <div className="bg-white rounded-b-xl border border-gray-100 border-t-0 p-6 space-y-5">

          {/* CPF/RG with auto-search */}
          <div className="relative">
            <label className="block text-sm font-semibold text-gray-700 text-center mb-2">CPF ou RG (Digite somente número)</label>
            <input
              type="text"
              value={cpfRg}
              onChange={e => handleCpfChange(e.target.value)}
              onFocus={() => cpfSuggestions.length > 0 && setShowSuggestions(true)}
              onBlur={() => setTimeout(() => setShowSuggestions(false), 200)}
              placeholder="Digite o CPF ou RG"
              className="w-full border border-gray-200 rounded-lg px-4 py-2.5 text-sm focus:outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931]/30"
            />

            {/* Auto-suggestions dropdown */}
            {showSuggestions && cpfSuggestions.length > 0 && (
              <div className="absolute z-20 top-full left-0 right-0 mt-1 bg-white border border-gray-200 rounded-lg shadow-lg max-h-60 overflow-y-auto">
                {cpfSuggestions.map(v => (
                  <button
                    key={v.id}
                    type="button"
                    onMouseDown={() => selectSuggestion(v)}
                    className="w-full text-left px-4 py-3 hover:bg-gray-50 transition-colors border-b border-gray-50 last:border-0 flex items-center gap-3"
                  >
                    <div className="w-10 h-10 rounded-full bg-gray-200 overflow-hidden flex-shrink-0">
                      {v.foto_url ? (
                        <img src={v.foto_url} alt="" className="w-full h-full object-cover" />
                      ) : (
                        <div className="w-full h-full flex items-center justify-center text-gray-400 text-sm">👤</div>
                      )}
                    </div>
                    <div>
                      <p className="font-semibold text-gray-800 text-sm">{v.nome}</p>
                      <p className="text-xs text-gray-400">
                        CPF/RG: {v.cpf_rg} · Última: {fmtDate(v.entrada_at)}
                      </p>
                    </div>
                  </button>
                ))}
              </div>
            )}
          </div>

          {/* Returning visitor — Large photo for confirmation */}
          {lastVisit && (
            <div className="bg-gray-50 rounded-xl p-5 text-center space-y-3">
              {/* Large photo */}
              <div className="w-[280px] h-[280px] mx-auto rounded-xl bg-gray-200 overflow-hidden border-2 border-gray-300">
                {(fotoPreview && !fotoPreview.startsWith('blob:')) || lastVisit.foto_url ? (
                  <img
                    src={fotoPreview && !fotoPreview.startsWith('blob:') ? fotoPreview : (lastVisit.foto_url ?? '')}
                    alt={lastVisit.nome}
                    className="w-full h-full object-cover"
                  />
                ) : fotoPreview && fotoPreview.startsWith('blob:') ? (
                  <img
                    src={fotoPreview}
                    alt="Nova foto"
                    className="w-full h-full object-cover"
                  />
                ) : (
                  <div className="w-full h-full flex items-center justify-center text-gray-400 text-6xl">👤</div>
                )}
              </div>

              {/* Visitor info */}
              <p className="font-bold text-gray-800 text-lg">{lastVisit.nome}</p>
              <p className="text-sm text-gray-500">
                🔄 Última visita: {fmtDate(lastVisit.entrada_at)}
                {lastVisit.bloco && ` — Bloco ${lastVisit.bloco}`}
                {lastVisit.apto && ` / Apto ${lastVisit.apto}`}
              </p>

              {/* Option to retake photo */}
              <button
                onClick={startWebcam}
                type="button"
                className="bg-[#FC5931] hover:bg-[#D42F1D] text-white px-5 py-2.5 rounded-lg text-sm font-semibold transition-colors inline-flex items-center gap-2"
              >
                <Camera size={16} /> Capturar outra foto
              </button>

              {/* Show new photo preview if captured */}
              {fotoBlob && fotoPreview && (
                <div className="mt-2">
                  <p className="text-xs text-green-600 font-semibold mb-1">✅ Nova foto capturada:</p>
                  <div className="w-[120px] h-[120px] mx-auto rounded-lg overflow-hidden border-2 border-green-400">
                    <img src={fotoPreview} alt="Nova foto" className="w-full h-full object-cover" />
                  </div>
                  <button
                    onClick={() => { setFotoPreview(lastVisit.foto_url); setFotoBlob(null) }}
                    type="button"
                    className="mt-2 text-xs text-gray-400 hover:text-red-500 underline"
                  >
                    Descartar e manter foto original
                  </button>
                </div>
              )}
            </div>
          )}

          {/* Bloco / Apto — Dropdowns */}
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-semibold text-gray-700 mb-1">Bloco*</label>
              <select
                value={bloco}
                onChange={e => { setBloco(e.target.value); setApto('') }}
                title="Selecione o bloco"
                className="w-full border border-gray-200 rounded-lg px-4 py-2.5 text-sm focus:outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931]/30 bg-white"
              >
                <option value="">Selecione o bloco</option>
                {blocos.map(b => (
                  <option key={b} value={b}>{b}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="block text-sm font-semibold text-gray-700 mb-1">Apto*</label>
              <select
                value={apto}
                onChange={e => setApto(e.target.value)}
                disabled={!bloco}
                title="Selecione o apartamento"
                className="w-full border border-gray-200 rounded-lg px-4 py-2.5 text-sm focus:outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931]/30 bg-white disabled:bg-gray-50 disabled:text-gray-400"
              >
                <option value="">Selecione o apto</option>
                {availableAptos.map(a => (
                  <option key={a} value={a}>{a}</option>
                ))}
              </select>
            </div>
          </div>

          {/* Nome */}
          <div>
            <label className="block text-sm font-semibold text-gray-700 mb-1">Primeiro e último nome do visitante*</label>
            <input
              type="text"
              value={nome}
              onChange={e => setNome(e.target.value)}
              placeholder="Nome do visitante"
              className="w-full border border-gray-200 rounded-lg px-4 py-2.5 text-sm focus:outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931]/30"
            />
          </div>

          {/* WhatsApp */}
          <div>
            <label className="block text-sm font-semibold text-gray-700 mb-1">WhatsApp do visitante</label>
            <input
              type="text"
              value={whatsapp}
              onChange={e => setWhatsapp(e.target.value)}
              placeholder="(00) 00000-0000"
              className="w-full border border-gray-200 rounded-lg px-4 py-2.5 text-sm focus:outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931]/30"
            />
          </div>

          {/* Tipo */}
          <div>
            <label className="block text-sm font-semibold text-gray-700 mb-1">Tipo de visitante*</label>
            <select
              value={tipoVisitante}
              onChange={e => setTipoVisitante(e.target.value)}
              title="Tipo de visitante"
              className="w-full border border-gray-200 rounded-lg px-4 py-2.5 text-sm focus:outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931]/30 bg-white"
            >
              <option value="">Selecione o tipo de visitante</option>
              {TIPOS_VISITANTE.map(t => (
                <option key={t} value={t}>{t}</option>
              ))}
            </select>
          </div>

          {/* Empresa */}
          <div>
            <label className="block text-sm font-semibold text-gray-700 mb-1">Nome da empresa do visitante</label>
            <input
              type="text"
              value={empresa}
              onChange={e => setEmpresa(e.target.value)}
              placeholder="Empresa (opcional)"
              className="w-full border border-gray-200 rounded-lg px-4 py-2.5 text-sm focus:outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931]/30"
            />
          </div>

          {/* Webcam modal — global, used by both new and returning visitors */}
          {showWebcam && (
            <div className="fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4">
              <div className="bg-white rounded-2xl p-5 max-w-lg w-full">
                <div className="flex items-center justify-between mb-4">
                  <h3 className="font-bold text-gray-800">📷 Capturar foto</h3>
                  <button onClick={stopWebcam} title="Fechar câmera" className="text-gray-400 hover:text-gray-600">
                    <X size={20} />
                  </button>
                </div>
                <video
                  ref={videoRefCallback}
                  autoPlay
                  playsInline
                  muted
                  className="w-full rounded-lg bg-black aspect-video"
                />
                <canvas ref={canvasRef} className="hidden" />
                <button
                  onClick={capturePhoto}
                  disabled={!videoReady}
                  className="mt-4 w-full bg-[#FC5931] text-white py-3 rounded-xl font-bold hover:bg-[#D42F1D] transition-colors flex items-center justify-center gap-2 disabled:opacity-50"
                >
                  <Camera size={20} /> {videoReady ? 'Capturar' : 'Carregando câmera...'}
                </button>
              </div>
            </div>
          )}

          {/* Photo — only for NEW visitors (returning visitors have photo above) */}
          {!lastVisit && (
          <div>
            <label className="block text-sm font-semibold text-gray-700 mb-2">Foto do visitante</label>

            <div className="flex items-center gap-4">
              {/* Preview */}
              <div className="w-20 h-20 rounded-xl bg-gray-100 overflow-hidden border-2 border-dashed border-gray-300 flex items-center justify-center">
                {fotoPreview ? (
                  <img src={fotoPreview} alt="Foto" className="w-full h-full object-cover" />
                ) : (
                  <Camera size={24} className="text-gray-400" />
                )}
              </div>

              {/* Webcam button */}
              <button
                onClick={startWebcam}
                type="button"
                className="bg-[#FC5931] hover:bg-[#D42F1D] text-white px-4 py-2 rounded-lg text-sm font-medium transition-colors flex items-center gap-2"
              >
                <Video size={16} /> Tirar foto
              </button>

              {/* Remove photo */}
              {fotoPreview && (
                <button
                  onClick={() => { setFotoPreview(null); setFotoBlob(null) }}
                  type="button"
                  title="Remover foto"
                  className="text-gray-400 hover:text-red-500 transition-colors"
                >
                  <X size={18} />
                </button>
              )}
            </div>
          </div>
          )}

          {/* Observação */}
          <div>
            <label className="block text-sm font-semibold text-gray-700 mb-1">Observação sobre o visitante</label>
            <textarea
              value={observacao}
              onChange={e => setObservacao(e.target.value)}
              rows={3}
              placeholder="Escreva uma observação (Opcional)"
              className="w-full border border-gray-200 rounded-lg px-4 py-2.5 text-sm focus:outline-none focus:border-[#FC5931] focus:ring-1 focus:ring-[#FC5931]/30 resize-none"
            />
          </div>

          {/* Error */}
          {error && (
            <div className="flex items-center gap-2 text-red-600 text-sm bg-red-50 p-3 rounded-lg">
              <AlertCircle size={16} /> {error}
            </div>
          )}

          {/* Save */}
          <button
            onClick={handleSave}
            disabled={isPending || saved}
            className="w-full bg-[#FC5931] text-white py-3 rounded-xl font-bold text-base hover:bg-[#D42F1D] transition-colors disabled:opacity-60 flex items-center justify-center gap-2"
          >
            {isPending ? (
              'Registrando...'
            ) : saved ? (
              <><CheckCircle size={20} /> Visitante Registrado!</>
            ) : (
              <><UserPlus size={20} /> Registrar Entrada</>
            )}
          </button>
        </div>
      </div>

      {/* ── RIGHT: Visitor History Sidebar ───────────────────── */}
      <div className="w-full lg:w-[380px] flex-shrink-0">
        <div className="bg-[#FC5931] text-white text-center font-bold py-3 rounded-t-xl">
          Histórico de visitas
        </div>
        <div className="bg-white rounded-b-xl border border-gray-100 border-t-0 p-4 space-y-3 max-h-[700px] overflow-y-auto">
          {visitantes.slice(0, 20).map(v => (
            <div
              key={v.id}
              className="bg-gray-50 rounded-lg p-3 flex items-start gap-3 hover:bg-gray-100 transition-colors"
            >
              <div className="w-12 h-12 rounded-full bg-gray-200 overflow-hidden flex-shrink-0">
                {v.foto_url ? (
                  <img src={v.foto_url} alt={v.nome} className="w-full h-full object-cover" />
                ) : (
                  <div className="w-full h-full flex items-center justify-center text-gray-400 text-sm">👤</div>
                )}
              </div>
              <div className="flex-1 min-w-0">
                <p className="font-bold text-gray-800 text-sm truncate">{v.nome}</p>
                <p className="text-xs text-gray-500">
                  <span className="font-medium">Entrada:</span> {fmtDate(v.entrada_at)}
                </p>
                {v.saida_at && (
                  <p className="text-xs text-gray-500">
                    <span className="font-medium">Saída:</span> {fmtDate(v.saida_at)}
                  </p>
                )}
                {(v.bloco || v.apto) && (
                  <p className="text-xs text-gray-400">Bloco {v.bloco || '−'} / Apto: {v.apto || '−'}</p>
                )}
                {!v.saida_at && (
                  <button
                    onClick={() => handleRegistrarSaida(v.id)}
                    className="mt-1 bg-yellow-400 text-yellow-900 text-xs font-bold px-3 py-1 rounded-md hover:bg-yellow-500 transition-colors"
                  >
                    Saída pendente
                  </button>
                )}
              </div>
            </div>
          ))}
          {visitantes.length === 0 && (
            <p className="text-gray-400 text-center py-8 text-sm">Nenhum visitante registrado.</p>
          )}
        </div>

        {visitantes.length > 0 && (
          <button
            onClick={() => setView('history')}
            className="w-full mt-3 text-[#FC5931] font-semibold text-sm hover:underline py-2"
          >
            Ver histórico completo →
          </button>
        )}

        {pendentes.length > 0 && (
          <div className="mt-3 bg-yellow-50 border border-yellow-200 rounded-lg p-3 text-center">
            <Clock size={18} className="inline mr-1.5 text-yellow-600" />
            <span className="text-sm font-semibold text-yellow-700">
              {pendentes.length} saída{pendentes.length > 1 ? 's' : ''} pendente{pendentes.length > 1 ? 's' : ''}
            </span>
          </div>
        )}
      </div>
    </div>
  )
}
