'use client'

import { useState, useRef, useEffect, useCallback } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'
import type { UnitOption } from './page'
import {
  Camera, Package, CheckCircle2, ChevronLeft, Loader2,
  Box, Mail, ShoppingBag, FileText, X, RefreshCw, Video
} from 'lucide-react'

interface Props {
  condoId: string
  registeredById: string
  units: UnitOption[]
}

type TipoEncomenda = 'caixa' | 'envelope' | 'pacote' | 'notif_judicial'

const TIPOS: { value: TipoEncomenda; label: string; icon: React.ElementType }[] = [
  { value: 'caixa',          label: 'Caixa',            icon: Box },
  { value: 'envelope',       label: 'Envelope',         icon: Mail },
  { value: 'pacote',         label: 'Pacote',           icon: ShoppingBag },
  { value: 'notif_judicial', label: 'Notif. Judicial', icon: FileText },
]

export default function ParcelRegisterForm({ condoId, registeredById, units }: Props) {
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

  // Camera state
  const [cameraOpen, setCameraOpen] = useState(false)
  const [photoBlob, setPhotoBlob] = useState<Blob | null>(null)
  const [photoPreview, setPhotoPreview] = useState<string | null>(null)
  const [facingMode, setFacingMode] = useState<'environment' | 'user'>('environment')
  const [cameraError, setCameraError] = useState<string | null>(null)
  const videoRef = useRef<HTMLVideoElement>(null)
  const streamRef = useRef<MediaStream | null>(null)
  const canvasRef = useRef<HTMLCanvasElement>(null)

  // Derived lists from units
  const blocos = [...new Set(units.map(u => u.blocoNome))].sort((a, b) =>
    a.localeCompare(b, 'pt', { numeric: true })
  )
  const aptos = units
    .filter(u => !blocoSel || u.blocoNome === blocoSel)
    .map(u => u.aptoNumero)
  const uniqueAptos = [...new Set(aptos)].sort((a, b) =>
    a.localeCompare(b, 'pt', { numeric: true })
  )

  const selectedUnit = units.find(u => u.blocoNome === blocoSel && u.aptoNumero === aptoSel)

  // Reset apto when bloco changes
  useEffect(() => { setAptoSel('') }, [blocoSel])

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
    } catch (err: any) {
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
    }, 'image/jpeg', 0.92)
  }

  const clearPhoto = () => {
    setPhotoBlob(null)
    setPhotoPreview(null)
  }

  // ── Submit ──────────────────────────────────────────────────────────────────

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError(null)

    if (!blocoSel || !aptoSel) {
      setError('Selecione o Bloco e o Apto do destinatário.')
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
        })

      if (insertError) throw new Error(`Erro ao registrar: ${insertError.message}`)

      if (photoWarning) setWarning(photoWarning)
      setSuccess(true)
      setTimeout(() => router.push('/condo/encomendas-admin'), 3500)
    } catch (err: any) {
      setError(err.message ?? 'Erro inesperado.')
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
          Bloco {blocoSel} / Apto {aptoSel}
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
          <div className="grid grid-cols-2 gap-4 mb-3">
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1.5">Bloco</label>
              <select
                value={blocoSel}
                onChange={e => setBlocoSel(e.target.value)}
                required
                className="w-full px-3 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931] bg-gray-50"
              >
                <option value="">Selecione o Bloco</option>
                {blocos.map(b => (
                  <option key={b} value={b}>{b}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1.5">Apto</label>
              <select
                value={aptoSel}
                onChange={e => setAptoSel(e.target.value)}
                required
                disabled={!blocoSel}
                className="w-full px-3 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931] bg-gray-50 disabled:opacity-50"
              >
                <option value="">Selecione o Apto</option>
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
              <p className="text-sm text-gray-500">Sem morador cadastrado neste apto</p>
            </div>
          ) : null}
        </div>

        {/* Foto via Webcam */}
        <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-5">
          <p className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-3">
            Foto da Encomenda <span className="normal-case text-gray-400 font-normal">(recomendada)</span>
          </p>

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
              >
                <X size={14} className="text-white" />
              </button>
            </div>
          ) : (
            <button
              type="button"
              onClick={() => setCameraOpen(true)}
              className="flex flex-col items-center justify-center gap-3 w-full h-40 border-2 border-dashed border-gray-200 rounded-xl cursor-pointer hover:border-[#FC5931] hover:bg-[#FC5931]/5 transition-all group"
            >
              <div className="w-14 h-14 bg-gray-100 group-hover:bg-[#FC5931]/10 rounded-2xl flex items-center justify-center transition-colors">
                <Camera size={26} className="text-gray-400 group-hover:text-[#FC5931] transition-colors" />
              </div>
              <div className="text-center">
                <p className="text-sm font-medium text-gray-600 group-hover:text-[#FC5931] transition-colors">
                  Abrir câmera
                </p>
                <p className="text-xs text-gray-400 mt-0.5">Tire uma foto da encomenda</p>
              </div>
            </button>
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
