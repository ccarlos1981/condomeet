'use client'

import { useState, useRef, useEffect, useCallback } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'
import type { UnitOption } from './page'
import {
  Camera, Package, CheckCircle2, ChevronLeft, Loader2,
  Box, Mail, ShoppingBag, FileText, X, RefreshCw, Video, Upload
} from 'lucide-react'
import { getBlocoLabel, getAptoLabel } from '@/lib/labels'

interface Props {
  condoId: string
  registeredById: string
  units: UnitOption[]
  tipoEstrutura?: string
  allBlocos?: string[]
  allAptos?: string[]
  redirectTo?: string
}

type TipoEncomenda = 'caixa' | 'envelope' | 'pacote' | 'notif_judicial'

const TIPOS: { value: TipoEncomenda; label: string; icon: React.ElementType }[] = [
  { value: 'caixa',          label: 'Caixa',            icon: Box },
  { value: 'envelope',       label: 'Envelope',         icon: Mail },
  { value: 'pacote',         label: 'Pacote',           icon: ShoppingBag },
  { value: 'notif_judicial', label: 'Notif. Judicial', icon: FileText },
]

export default function ParcelRegisterForm({ condoId, registeredById, units, tipoEstrutura, allBlocos, allAptos, redirectTo }: Props) {
  const router = useRouter()
  const supabase = createClient()

  // Form state
  const [tipo, setTipo] = useState<TipoEncomenda>('pacote')
  const [blocoSel, setBlocoSel] = useState('')
  const [aptoSel, setAptoSel] = useState('')
  const [trackingCode, setTrackingCode] = useState('')
  const [observacao, setObservacao] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [success, setSuccess] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [warning, setWarning] = useState<string | null>(null)

  // AI OCR state
  const [isAnalyzingPhoto, setIsAnalyzingPhoto] = useState(false)
  const [aiFeedbackMessage, setAiFeedbackMessage] = useState<string | null>(null)
  const [aiFeedbackSuccess, setAiFeedbackSuccess] = useState(false)
  const analysisRequestId = useRef(0)

  // Camera state
  const [cameraOpen, setCameraOpen] = useState(false)
  const [photoBlob, setPhotoBlob] = useState<Blob | null>(null)
  const [photoPreview, setPhotoPreview] = useState<string | null>(null)
  const [facingMode, setFacingMode] = useState<'environment' | 'user'>('environment')
  const [cameraError, setCameraError] = useState<string | null>(null)
  const videoRef = useRef<HTMLVideoElement>(null)
  const streamRef = useRef<MediaStream | null>(null)
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const fileInputRef = useRef<HTMLInputElement>(null)

  // Derived lists from units and structural tables
  const blocos = allBlocos && allBlocos.length > 0
    ? [...allBlocos].sort((a, b) => a.localeCompare(b, 'pt', { numeric: true }))
    : [...new Set(units.map(u => u.blocoNome))].sort((a, b) => a.localeCompare(b, 'pt', { numeric: true }))

  const aptosList = allAptos && allAptos.length > 0
    ? allAptos
    : units.filter(u => (!blocoSel || u.blocoNome === blocoSel)).map(u => u.aptoNumero)

  const uniqueAptos = [...new Set(aptosList)].sort((a, b) => a.localeCompare(b, 'pt', { numeric: true }))

  const selectedUnit = units.find(u => u.blocoNome === blocoSel && u.aptoNumero === aptoSel)

  // ── AI Extraction ───────────────────────────────────────────────────────────

  const blobToBase64 = (blob: Blob): Promise<string> => {
    return new Promise((resolve, reject) => {
      const reader = new FileReader()
      reader.onloadend = () => {
        const result = reader.result as string
        const base64 = result.includes(',') ? result.split(',')[1] : result
        resolve(base64)
      }
      reader.onerror = reject
      reader.readAsDataURL(blob)
    })
  }

  const analyzePhotoWithAi = async (blob: Blob) => {
    const hasBloco = !!blocoSel.trim()
    const hasApto = !!aptoSel.trim()

    // CENÁRIO 1: Ambos já preenchidos manualmente -> NÃO chamar Edge Function / IA. Custo ZERO.
    if (hasBloco && hasApto) {
      return
    }

    const currentReqId = ++analysisRequestId.current
    setIsAnalyzingPhoto(true)
    setAiFeedbackMessage('Analisando a foto...')
    setAiFeedbackSuccess(false)

    try {
      const base64Image = await blobToBase64(blob)

      const { data, error: invokeError } = await supabase.functions.invoke('parcel-ai-extract', {
        body: { image_base64: base64Image },
      })

      // Race condition check
      if (currentReqId !== analysisRequestId.current) return

      if (invokeError || !data) {
        setIsAnalyzingPhoto(false)
        setAiFeedbackMessage('⚠️ Não foi possível identificar a unidade pela foto. Preencha Bloco e Apartamento manualmente.')
        setAiFeedbackSuccess(false)
        return
      }

      const leituraOk = data.leitura_ok === true
      const rawBloco = data.bloco ? String(data.bloco).trim() : null
      const rawApto = data.apartamento ? String(data.apartamento).trim() : null

      if (!leituraOk || (!rawBloco && !rawApto)) {
        setIsAnalyzingPhoto(false)
        setAiFeedbackMessage('⚠️ Não foi possível identificar a unidade pela foto. Preencha manualmente.')
        setAiFeedbackSuccess(false)
        return
      }

      // CENÁRIO 2: Bloco preenchido manualmente, Apto vazio
      if (hasBloco && !hasApto) {
        if (rawApto) {
          const availableAptos = units
            .filter(u => u.blocoNome.toLowerCase() === blocoSel.toLowerCase())
            .map(u => u.aptoNumero)

          const matchingApto = availableAptos.find(
            a => a.trim().toLowerCase() === rawApto.toLowerCase()
          )

          if (matchingApto) {
            setAptoSel(matchingApto)
            setIsAnalyzingPhoto(false)
            setAiFeedbackMessage('✓ Apartamento identificado automaticamente pela foto')
            setAiFeedbackSuccess(true)
          } else {
            setIsAnalyzingPhoto(false)
            setAiFeedbackMessage('⚠️ O apartamento identificado na foto não foi encontrado para o bloco selecionado. Confira os dados manualmente.')
            setAiFeedbackSuccess(false)
          }
        } else {
          setIsAnalyzingPhoto(false)
          setAiFeedbackMessage('⚠️ Não foi possível identificar o apartamento pela foto. Selecione manualmente.')
          setAiFeedbackSuccess(false)
        }
        return
      }

      // CENÁRIO 3: Bloco vazio, Apartamento preenchido manualmente
      if (!hasBloco && hasApto) {
        if (rawBloco) {
          const matchingBloco = blocos.find(
            b => b.trim().toLowerCase() === rawBloco.toLowerCase()
          )

          if (matchingBloco) {
            const availableAptos = units
              .filter(u => u.blocoNome.toLowerCase() === matchingBloco.toLowerCase())
              .map(u => u.aptoNumero)

            const aptoExistsInBloco = availableAptos.some(
              a => a.trim().toLowerCase() === aptoSel.trim().toLowerCase()
            )

            if (aptoExistsInBloco) {
              setBlocoSel(matchingBloco)
              setIsAnalyzingPhoto(false)
              setAiFeedbackMessage('✓ Bloco identificado automaticamente pela foto')
              setAiFeedbackSuccess(true)
            } else {
              setIsAnalyzingPhoto(false)
              setAiFeedbackMessage('⚠️ O bloco identificado na foto não foi encontrado para o apartamento selecionado. Confira os dados manualmente.')
              setAiFeedbackSuccess(false)
            }
          } else {
            setIsAnalyzingPhoto(false)
            setAiFeedbackMessage('⚠️ O bloco identificado na foto não foi encontrado neste condomínio. Confira os dados manualmente.')
            setAiFeedbackSuccess(false)
          }
        } else {
          setIsAnalyzingPhoto(false)
          setAiFeedbackMessage(`⚠️ Não foi possível identificar o ${getBlocoLabel(tipoEstrutura).toLowerCase()} pela foto. Selecione manualmente.`)
          setAiFeedbackSuccess(false)
        }
        return
      }

      // CENÁRIO 4: Ambos vazios (!hasBloco && !hasApto)
      if (!rawBloco && rawApto) {
        setIsAnalyzingPhoto(false)
        setAiFeedbackMessage(`⚠️ Apartamento ${rawApto} identificado, mas o ${getBlocoLabel(tipoEstrutura).toLowerCase()} não está visível na foto. Selecione o ${getBlocoLabel(tipoEstrutura).toLowerCase()} manualmente.`)
        setAiFeedbackSuccess(false)
        return
      }

      const matchingBloco = blocos.find(
        b => b.trim().toLowerCase() === rawBloco!.toLowerCase()
      )

      if (!matchingBloco) {
        setIsAnalyzingPhoto(false)
        setAiFeedbackMessage('⚠️ A unidade identificada na foto não foi encontrada neste condomínio. Confira os dados manualmente.')
        setAiFeedbackSuccess(false)
        return
      }

      setBlocoSel(matchingBloco)

      if (rawApto) {
        const availableAptos = units
          .filter(u => u.blocoNome.toLowerCase() === matchingBloco.toLowerCase())
          .map(u => u.aptoNumero)

        const matchingApto = availableAptos.find(
          a => a.trim().toLowerCase() === rawApto.toLowerCase()
        )

        if (matchingApto) {
          setAptoSel(matchingApto)
          setIsAnalyzingPhoto(false)
          setAiFeedbackMessage('✓ Unidade identificada automaticamente pela foto')
          setAiFeedbackSuccess(true)
        } else {
          setIsAnalyzingPhoto(false)
          setAiFeedbackMessage('⚠️ A unidade identificada na foto não foi encontrada neste condomínio. Confira os dados manualmente.')
          setAiFeedbackSuccess(false)
        }
      } else {
        setIsAnalyzingPhoto(false)
        setAiFeedbackMessage(`✓ ${getBlocoLabel(tipoEstrutura)} identificado. Selecione o ${getAptoLabel(tipoEstrutura).toLowerCase()} manualmente.`)
        setAiFeedbackSuccess(false)
      }
    } catch {
      if (currentReqId !== analysisRequestId.current) return
      setIsAnalyzingPhoto(false)
      setAiFeedbackMessage('⚠️ Não foi possível identificar a unidade pela foto. Preencha Bloco e Apartamento manualmente.')
      setAiFeedbackSuccess(false)
    }
  }

  // ── Camera helpers ──────────────────────────────────────────────────────────

  const stopStream = useCallback(() => {
    streamRef.current?.getTracks().forEach(t => t.stop())
    streamRef.current = null
  }, [])

  const startCamera = useCallback(async (facing: 'environment' | 'user') => {
    setCameraError(null)
    stopStream()
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: facing, width: { ideal: 1280 }, height: { ideal: 720 } },
        audio: false,
      })
      streamRef.current = stream
      if (videoRef.current) {
        videoRef.current.srcObject = stream
        videoRef.current.play()
      }
    } catch {
      setCameraError('Não foi possível acessar a câmera. Verifique as permissões do navegador.')
    }
  }, [stopStream])

  useEffect(() => {
    if (cameraOpen) startCamera(facingMode)
    else stopStream()
    return () => stopStream()
  }, [cameraOpen, facingMode, startCamera, stopStream])

  const flipCamera = () => {
    const next = facingMode === 'environment' ? 'user' : 'environment'
    setFacingMode(next)
  }

  const takePhoto = () => {
    if (!videoRef.current || !canvasRef.current) return
    const video = videoRef.current
    const canvas = canvasRef.current
    canvas.width = video.videoWidth
    canvas.height = video.videoHeight
    canvas.getContext('2d')?.drawImage(video, 0, 0)
    canvas.toBlob(blob => {
      if (!blob) return
      setPhotoBlob(blob)
      setPhotoPreview(URL.createObjectURL(blob))
      setCameraOpen(false)
      analyzePhotoWithAi(blob)
    }, 'image/jpeg', 0.92)
  }

  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return
    setPhotoBlob(file)
    setPhotoPreview(URL.createObjectURL(file))
    analyzePhotoWithAi(file)
  }

  const clearPhoto = () => {
    setPhotoBlob(null)
    setPhotoPreview(null)
    setAiFeedbackMessage(null)
    setAiFeedbackSuccess(false)
    analysisRequestId.current++
  }

  // ── Submit ──────────────────────────────────────────────────────────────────

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError(null)

    if (!blocoSel || !aptoSel) {
      setError(`Selecione o ${getBlocoLabel(tipoEstrutura)} e o ${getAptoLabel(tipoEstrutura)} do destinatário.`)
      return
    }

    setSubmitting(true)

    try {
      let photoUrl: string | null = null
      let photoWarning: string | null = null

      // Upload photo if captured (non-blocking — registration continues even if upload fails)
      if (photoBlob) {
        try {
          const path = `${condoId}/${Date.now()}_${Math.random().toString(36).slice(2)}.jpg`
          const { error: uploadError } = await supabase.storage
            .from('parcel-photos')
            .upload(path, photoBlob, { contentType: 'image/jpeg', upsert: false })

          if (uploadError) {
            photoWarning = `Foto não enviada (bucket não encontrado). Crie o bucket 'parcel-photos' no Supabase.`
          } else {
            const { data: urlData } = supabase.storage.from('parcel-photos').getPublicUrl(path)
            photoUrl = urlData.publicUrl
          }
        } catch {
          photoWarning = 'Foto não enviada, encomenda registrada sem foto.'
        }
      }

      // Insert parcel record
      const { error: insertError } = await supabase
        .from('encomendas')
        .insert({
          resident_id: selectedUnit?.residentId ?? null,
          condominio_id: condoId,
          registered_by: registeredById,
          status: 'pending',
          arrival_time: new Date().toISOString(),
          tipo,
          tracking_code: trackingCode || null,
          observacao: observacao || null,
          photo_url: photoUrl,
          bloco: blocoSel,
          apto: aptoSel,
        })

      if (insertError) throw new Error(`Erro ao registrar: ${insertError.message}`)

      if (photoWarning) setWarning(photoWarning)
      setSuccess(true)
      setTimeout(() => router.push(redirectTo || '/condo/encomendas-admin'), 3500)
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Erro inesperado.')
      setSubmitting(false)
    }
  }

  // ── Success ─────────────────────────────────────────────────────────────────

  if (success) {
    return (
      <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-12 text-center">
        <div className="w-20 h-20 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-5">
          <CheckCircle2 className="text-green-500" size={44} />
        </div>
        <h2 className="text-2xl font-bold text-gray-900 mb-2">Encomenda Registrada!</h2>
        <p className="text-gray-500 text-sm">
          {getBlocoLabel(tipoEstrutura)} {blocoSel} / {getAptoLabel(tipoEstrutura)} {aptoSel}
          {selectedUnit?.residentName && ` — ${selectedUnit.residentName}`}
        </p>
        {warning && (
          <div className="mt-4 bg-amber-50 border border-amber-200 rounded-xl px-4 py-3 text-xs text-amber-700 text-left">
            ⚠️ {warning}
          </div>
        )}
        <p className="text-gray-400 text-xs mt-4">Redirecionando para a lista...</p>
      </div>
    )
  }

  // ── Camera modal ─────────────────────────────────────────────────────────────

  const CameraModal = () => (
    <div className="fixed inset-0 bg-black z-50" style={{ display: 'flex', flexDirection: 'column' }}>

      {/* TOP BAR — fixed height */}
      <div style={{ flexShrink: 0 }} className="flex items-center justify-between px-4 py-3 bg-black/90 border-b border-white/10">
        <button onClick={() => setCameraOpen(false)} className="text-white p-2 rounded-xl hover:bg-white/10 active:bg-white/20">
          <X size={22} />
        </button>
        <p className="text-white font-semibold text-sm tracking-wide">📷 Foto da Encomenda</p>
        <button onClick={flipCamera} className="text-white p-2 rounded-xl hover:bg-white/10 active:bg-white/20" title="Virar câmera">
          <RefreshCw size={20} />
        </button>
      </div>

      {/* VIDEO — fills remaining space */}
      <div style={{ flex: 1, position: 'relative', overflow: 'hidden', background: '#000', minHeight: 0 }}>
        {cameraError ? (
          <div className="absolute inset-0 flex flex-col items-center justify-center text-center px-8">
            <Video size={48} className="text-white/30 mb-3" />
            <p className="text-white/70 text-sm">{cameraError}</p>
          </div>
        ) : (
          <video
            ref={videoRef}
            autoPlay
            playsInline
            muted
            style={{ width: '100%', height: '100%', objectFit: 'cover' }}
          />
        )}
        {/* Viewfinder */}
        <div className="absolute inset-0 pointer-events-none flex items-center justify-center">
          <div className="border-2 border-white/50 rounded-2xl" style={{ width: 260, height: 180 }} />
        </div>
      </div>

      {/* Hidden canvas */}
      <canvas ref={canvasRef} className="hidden" />

      {/* SHUTTER BAR — fixed height, always visible */}
      <div
        style={{ flexShrink: 0, height: 120 }}
        className="bg-black/90 flex items-center justify-center border-t border-white/10"
      >
        <button
          onClick={takePhoto}
          disabled={!!cameraError}
          aria-label="Tirar foto"
          style={{ width: 80, height: 80 }}
          className="rounded-full border-[5px] border-white bg-white/20 hover:bg-white/30 active:scale-95 disabled:opacity-40 transition-all flex items-center justify-center shadow-lg"
        >
          <div style={{ width: 60, height: 60 }} className="rounded-full bg-white" />
        </button>
      </div>
    </div>
  )

  // ── Main form ────────────────────────────────────────────────────────────────

  return (
    <>
      {cameraOpen && <CameraModal />}

      <form onSubmit={handleSubmit} className="space-y-6">

        {/* Tipo */}
        <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-5">
          <p className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-4">
            Tipo da Encomenda
          </p>
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
            {TIPOS.map(t => {
              const Icon = t.icon
              const active = tipo === t.value
              return (
                <button
                  key={t.value}
                  type="button"
                  onClick={() => setTipo(t.value)}
                  className={`flex flex-col items-center gap-2 p-4 rounded-xl border-2 transition-all duration-150 ${
                    active
                      ? 'border-[#FC5931] bg-[#FC5931]/5 text-[#FC5931]'
                      : 'border-gray-100 bg-gray-50 text-gray-500 hover:border-gray-200'
                  }`}
                >
                  <Icon size={22} />
                  <span className="text-xs font-semibold text-center leading-tight">{t.label}</span>
                </button>
              )
            })}
          </div>
        </div>

        {/* Destinatário */}
        <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-5">
          <p className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-4">
            Destinatário
          </p>

          {/* AI Extraction Feedback Banner */}
          {isAnalyzingPhoto ? (
            <div className="flex items-center gap-3 bg-[#FC5931]/10 border border-[#FC5931]/20 rounded-xl px-4 py-3 text-sm text-[#FC5931] font-medium mb-4">
              <Loader2 size={16} className="animate-spin text-[#FC5931] flex-shrink-0" />
              <span>Analisando a foto...</span>
            </div>
          ) : aiFeedbackMessage ? (
            <div className={`flex items-center gap-3 rounded-xl px-4 py-3 text-sm font-medium border mb-4 ${
              aiFeedbackSuccess
                ? 'bg-emerald-50 border-emerald-200 text-emerald-800'
                : 'bg-amber-50 border-amber-200 text-amber-900'
            }`}>
              {aiFeedbackSuccess ? (
                <CheckCircle2 size={18} className="text-emerald-600 flex-shrink-0" />
              ) : (
                <span className="text-base flex-shrink-0">⚠️</span>
              )}
              <span>{aiFeedbackMessage}</span>
            </div>
          ) : null}

          <div className="grid grid-cols-2 gap-4 mb-3">
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1.5">{getBlocoLabel(tipoEstrutura)}</label>
              <select
                value={blocoSel}
                onChange={e => {
                  setBlocoSel(e.target.value)
                  setAptoSel('')
                }}
                required
                className="w-full px-3 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931] bg-gray-50"
              >
                <option value="">Selecione o {getBlocoLabel(tipoEstrutura)}</option>
                {blocos.map(b => (
                  <option key={b} value={b}>{b}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1.5">{getAptoLabel(tipoEstrutura)}</label>
              <select
                value={aptoSel}
                onChange={e => setAptoSel(e.target.value)}
                required
                disabled={!blocoSel}
                className="w-full px-3 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931] bg-gray-50 disabled:opacity-50"
              >
                <option value="">Selecione o {getAptoLabel(tipoEstrutura)}</option>
                {uniqueAptos.map(a => (
                  <option key={a} value={a}>{a}</option>
                ))}
              </select>
            </div>
          </div>

          {/* Resident preview */}
          {selectedUnit?.residentName ? (
            <div className="flex items-center gap-3 bg-[#FC5931]/5 border border-[#FC5931]/20 rounded-xl px-4 py-3">
              <div className="w-9 h-9 rounded-xl bg-[#FC5931]/10 flex items-center justify-center flex-shrink-0">
                <span className="text-[#FC5931] font-bold text-sm">
                  {selectedUnit.residentName[0].toUpperCase()}
                </span>
              </div>
              <p className="text-sm font-medium text-gray-800">{selectedUnit.residentName}</p>
            </div>
          ) : aptoSel ? (
            <div className="flex items-center gap-3 bg-gray-50 border border-gray-200 rounded-xl px-4 py-3">
              <div className="w-9 h-9 rounded-xl bg-gray-200 flex items-center justify-center flex-shrink-0">
                <span className="text-gray-500 font-bold text-sm">?</span>
              </div>
              <p className="text-sm text-gray-500">Não existe morador cadastrado na unidade</p>
            </div>
          ) : null}
        </div>

        {/* Foto da Encomenda */}
        <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-5">
          <p className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-3">
            Foto da Encomenda <span className="normal-case text-gray-400 font-normal">(recomendada para leitura de Bloco/Apto via IA)</span>
          </p>

          <input
            ref={fileInputRef}
            type="file"
            accept="image/*"
            className="hidden"
            onChange={handleFileUpload}
          />

          {photoPreview ? (
            <div className="relative">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={photoPreview}
                alt="Foto da encomenda"
                className="w-full h-52 object-cover rounded-xl border border-gray-100"
              />
              <button
                type="button"
                onClick={clearPhoto}
                className="absolute top-2 right-2 w-8 h-8 bg-black/60 hover:bg-black/80 rounded-full flex items-center justify-center transition-colors"
                title="Remover foto"
              >
                <X size={14} className="text-white" />
              </button>
            </div>
          ) : (
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <button
                type="button"
                onClick={() => setCameraOpen(true)}
                className="flex flex-col items-center justify-center gap-2 p-5 border-2 border-dashed border-gray-200 rounded-xl cursor-pointer hover:border-[#FC5931] hover:bg-[#FC5931]/5 transition-all group"
              >
                <div className="w-12 h-12 bg-gray-100 group-hover:bg-[#FC5931]/10 rounded-xl flex items-center justify-center transition-colors">
                  <Camera size={22} className="text-gray-400 group-hover:text-[#FC5931] transition-colors" />
                </div>
                <div className="text-center">
                  <p className="text-sm font-medium text-gray-700 group-hover:text-[#FC5931] transition-colors">
                    Tirar Foto (Câmera)
                  </p>
                  <p className="text-xs text-gray-400 mt-0.5">Leitura automática por IA</p>
                </div>
              </button>

              <button
                type="button"
                onClick={() => fileInputRef.current?.click()}
                className="flex flex-col items-center justify-center gap-2 p-5 border-2 border-dashed border-gray-200 rounded-xl cursor-pointer hover:border-[#FC5931] hover:bg-[#FC5931]/5 transition-all group"
              >
                <div className="w-12 h-12 bg-gray-100 group-hover:bg-[#FC5931]/10 rounded-xl flex items-center justify-center transition-colors">
                  <Upload size={22} className="text-gray-400 group-hover:text-[#FC5931] transition-colors" />
                </div>
                <div className="text-center">
                  <p className="text-sm font-medium text-gray-700 group-hover:text-[#FC5931] transition-colors">
                    Escolher Arquivo
                  </p>
                  <p className="text-xs text-gray-400 mt-0.5">JPG, PNG ou WebP</p>
                </div>
              </button>
            </div>
          )}
        </div>

        {/* Código de Rastreio */}
        <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-5">
          <label className="block text-xs font-semibold text-gray-500 uppercase tracking-wider mb-3">
            Código de Rastreio <span className="normal-case text-gray-400 font-normal">(opcional)</span>
          </label>
          <input
            type="text"
            value={trackingCode}
            onChange={e => setTrackingCode(e.target.value)}
            placeholder="Ex: BR123456789BR"
            className="w-full px-3 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931] bg-gray-50 font-mono tracking-wide"
          />
        </div>

        {/* Observação */}
        <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-5">
          <label className="block text-xs font-semibold text-gray-500 uppercase tracking-wider mb-3">
            Observação <span className="normal-case text-gray-400 font-normal">(opcional)</span>
          </label>
          <textarea
            value={observacao}
            onChange={e => setObservacao(e.target.value)}
            placeholder="Ex: Pacote danificado, remetente Riachuelo..."
            rows={3}
            className="w-full px-3 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931] bg-gray-50 resize-none"
          />
        </div>

        {/* Error */}
        {error && (
          <div className="bg-red-50 border border-red-200 rounded-xl px-4 py-3 text-sm text-red-700">
            {error}
          </div>
        )}

        {/* Actions */}
        <div className="flex gap-3 pb-8">
          <button
            type="button"
            onClick={() => router.back()}
            disabled={submitting}
            className="flex items-center gap-2 px-5 py-3 border border-gray-200 text-gray-600 text-sm font-semibold rounded-xl hover:bg-gray-50 transition-colors disabled:opacity-50"
          >
            <ChevronLeft size={16} />
            Voltar
          </button>
          <button
            type="submit"
            disabled={submitting}
            className="flex-1 flex items-center justify-center gap-2 bg-[#FC5931] text-white text-sm font-semibold py-3 rounded-xl hover:bg-[#D42F1D] transition-colors disabled:opacity-60 shadow-sm"
          >
            {submitting ? (
              <>
                <Loader2 size={16} className="animate-spin" />
                {photoBlob ? 'Enviando foto...' : 'Registrando...'}
              </>
            ) : (
              <>
                <Package size={16} />
                Registrar Encomenda
              </>
            )}
          </button>
        </div>
      </form>
    </>
  )
}
