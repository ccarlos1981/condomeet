'use client'

import { useState, useEffect, useRef } from 'react'
import {
  X,
  UploadCloud,
  AlertCircle,
  Loader2,
  Trash2,
  Camera,
  PawPrint,
  Car,
  User,
  Image as ImageIcon,
  CheckCircle,
} from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import {
  adminSavePetPhoto,
  adminRemovePetPhoto,
  adminSaveVehiclePhoto,
  adminRemoveVehiclePhoto,
  adminSaveResidentPhoto,
  adminRemoveResidentPhoto,
} from '@/app/admin/actions'

// ==============================================================================
// 1. PROCESSAMENTO DE IMAGEM CLIENT-SIDE (CANVAS)
// ==============================================================================

export async function processImageForUpload(
  file: File
): Promise<{ blob: Blob; previewUrl: string; width: number; height: number }> {
  const fileName = file.name.toLowerCase()
  const isHeic =
    /\.(heic|heif)$/i.test(fileName) ||
    file.type.includes('heic') ||
    file.type.includes('heif')

  if (isHeic) {
    throw new Error(
      'Este formato de imagem ainda não é suportado nesta versão. Escolha uma foto em JPEG, PNG ou WebP.'
    )
  }

  const validTypes = ['image/jpeg', 'image/png', 'image/webp']
  if (!validTypes.includes(file.type)) {
    throw new Error(
      'Formato de arquivo inválido. Escolha uma foto em formato JPEG, PNG ou WebP.'
    )
  }

  if (file.size > 15 * 1024 * 1024) {
    throw new Error(
      'Arquivo original muito grande. O tamanho máximo permitido para envio é 15 MB.'
    )
  }

  return new Promise((resolve, reject) => {
    const objectUrl = URL.createObjectURL(file)
    const img = new Image()

    img.onload = () => {
      URL.revokeObjectURL(objectUrl)
      try {
        const MAX_DIM = 1200
        let { width, height } = img

        if (width > MAX_DIM || height > MAX_DIM) {
          if (width > height) {
            height = Math.round((height * MAX_DIM) / width)
            width = MAX_DIM
          } else {
            width = Math.round((width * MAX_DIM) / height)
            height = MAX_DIM
          }
        }

        const canvas = document.createElement('canvas')
        canvas.width = width
        canvas.height = height

        const ctx = canvas.getContext('2d')
        if (!ctx) {
          reject(new Error('Não foi possível inicializar o processador gráfico da imagem.'))
          return
        }

        // Desenha imagem redimensionada
        ctx.drawImage(img, 0, 0, width, height)

        canvas.toBlob(
          (blob) => {
            if (!blob) {
              reject(new Error('Falha ao processar e comprimir a imagem.'))
              return
            }
            if (blob.size > 5 * 1024 * 1024) {
              reject(new Error('A imagem processada excede o limite máximo de 5 MB do condomínio.'))
              return
            }
            const previewUrl = URL.createObjectURL(blob)
            resolve({ blob, previewUrl, width, height })
          },
          'image/jpeg',
          0.82
        )
      } catch {
        reject(new Error('Falha ao converter e otimizar imagem no navegador.'))
      }
    }

    img.onerror = () => {
      URL.revokeObjectURL(objectUrl)
      if (isHeic) {
        reject(
          new Error(
            'Este formato de imagem ainda não é suportado nesta versão. Escolha uma foto em JPEG, PNG ou WebP.'
          )
        )
      } else {
        reject(
          new Error(
            'Não foi possível decodificar o arquivo de imagem. Escolha uma foto válida em JPEG, PNG ou WebP.'
          )
        )
      }
    }

    img.src = objectUrl
  })
}

// ==============================================================================
// 2. MODAL DE UPLOAD / SUBSTITUIÇÃO DE FOTO
// ==============================================================================

export interface PhotoUploadModalProps {
  isOpen: boolean
  onClose: () => void
  type: 'pet' | 'veiculo' | 'morador'
  entityId: string
  entityName: string
  condominioId: string
  currentPhotoPath?: string | null
  profileId: string
  onSuccess: () => void
}

export function PhotoUploadModal({
  isOpen,
  onClose,
  type,
  entityId,
  entityName,
  condominioId,
  currentPhotoPath,
  profileId,
  onSuccess,
}: PhotoUploadModalProps) {
  const [selectedFile, setSelectedFile] = useState<File | null>(null)
  const [processedBlob, setProcessedBlob] = useState<Blob | null>(null)
  const [previewUrl, setPreviewUrl] = useState<string | null>(null)
  const [imageMeta, setImageMeta] = useState<{ width: number; height: number; sizeKb: number } | null>(null)
  const [processing, setProcessing] = useState(false)
  const [uploading, setUploading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [isDragOver, setIsDragOver] = useState(false)
  const fileInputRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    if (!isOpen) {
      if (previewUrl) {
        URL.revokeObjectURL(previewUrl)
      }
      setSelectedFile(null)
      setProcessedBlob(null)
      setPreviewUrl(null)
      setImageMeta(null)
      setError(null)
      setProcessing(false)
      setUploading(false)
      setIsDragOver(false)
    }
  }, [isOpen])

  if (!isOpen) return null

  const isReplacing = Boolean(currentPhotoPath)
  const isPet = type === 'pet'
  const isMorador = type === 'morador'
  const entityLabel = isPet ? 'Pet' : isMorador ? 'Morador' : 'Veículo'

  async function handleFileSelected(file: File) {
    setError(null)
    setProcessing(true)

    if (previewUrl) {
      URL.revokeObjectURL(previewUrl)
      setPreviewUrl(null)
    }

    try {
      const result = await processImageForUpload(file)
      setSelectedFile(file)
      setProcessedBlob(result.blob)
      setPreviewUrl(result.previewUrl)
      setImageMeta({
        width: result.width,
        height: result.height,
        sizeKb: Math.round(result.blob.size / 1024),
      })
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Falha ao processar a imagem selecionada.'
      setError(msg)
      setSelectedFile(null)
      setProcessedBlob(null)
      setPreviewUrl(null)
      setImageMeta(null)
    } finally {
      setProcessing(false)
    }
  }

  function handleDrop(e: React.DragEvent<HTMLDivElement>) {
    e.preventDefault()
    setIsDragOver(false)
    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
      handleFileSelected(e.dataTransfer.files[0])
    }
  }

  async function handleConfirmUpload() {
    if (!processedBlob || !condominioId || !entityId) return

    setUploading(true)
    setError(null)

    const supabase = createClient()
    const timestamp = Date.now()
    const uniqueId = typeof crypto !== 'undefined' && crypto.randomUUID ? crypto.randomUUID() : Math.random().toString(36).substring(2, 15)
    const entityFolder = isPet ? 'pets' : isMorador ? 'moradores' : 'veiculos'
    const newPath = `${condominioId}/${entityFolder}/${entityId}/${timestamp}_${uniqueId}.jpg`

    let uploadSucceeded = false

    try {
      // 1. Upload físico para o Supabase Storage no bucket privado
      const { error: uploadError } = await supabase.storage
        .from('base-cadastral-media')
        .upload(newPath, processedBlob, {
          contentType: 'image/jpeg',
          upsert: false,
        })

      if (uploadError) {
        throw new Error(`Falha no upload para o Storage: ${uploadError.message}`)
      }

      uploadSucceeded = true

      // 2. Chamar RPC via Server Action transacional
      let res: { success?: boolean; error?: string; result?: any }
      if (isPet) {
        res = await adminSavePetPhoto({
          petId: entityId,
          fotoPath: newPath,
          profileId,
        })
      } else if (isMorador) {
        res = await adminSaveResidentPhoto({
          residentId: entityId,
          fotoPath: newPath,
        })
      } else {
        res = await adminSaveVehiclePhoto({
          veiculoId: entityId,
          fotoPath: newPath,
          profileId,
        })
      }

      // 3. Rollback caso o banco rejeite a transação
      if (res.error) {
        if (uploadSucceeded) {
          try {
            await supabase.storage.from('base-cadastral-media').remove([newPath])
          } catch (rollbackErr) {
            console.error('[StorageRollback] Falha ao desfazer arquivo órfão:', rollbackErr)
          }
        }
        throw new Error(res.error)
      }

      // 4. Se o banco confirmou com sucesso, remover foto anterior se houver (apenas path relativo)
      const oldPath = res.result?.foto_path_anterior
      if (
        oldPath &&
        oldPath !== newPath &&
        !oldPath.startsWith('http://') &&
        !oldPath.startsWith('https://')
      ) {
        try {
          await supabase.storage.from('base-cadastral-media').remove([oldPath])
        } catch (cleanupErr) {
          console.error('[StorageCleanup] Falha ao remover foto anterior após banco confirmado:', cleanupErr)
        }
      }

      onSuccess()
      onClose()
    } catch (err: unknown) {
      console.error('[PhotoUploadModal] Erro:', err)
      const msg = err instanceof Error ? err.message : 'Erro ao enviar a foto.'
      setError(msg)
    } finally {
      setUploading(false)
    }
  }

  return (
    <div className="fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4 backdrop-blur-xs">
      <div className="bg-white rounded-2xl max-w-md w-full shadow-2xl border border-gray-100 overflow-hidden animate-in fade-in zoom-in-95 duration-150">
        {/* Header */}
        <div className="p-6 border-b border-gray-100 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-orange-50 border border-orange-100 flex items-center justify-center text-[#FC5931]">
              {isPet ? <PawPrint size={20} /> : isMorador ? <User size={20} /> : <Car size={20} />}
            </div>
            <div>
              <h2 className="text-base font-bold text-gray-900">
                {isReplacing ? `Alterar Foto do ${entityLabel}` : `Adicionar Foto ao ${entityLabel}`}
              </h2>
              <p className="text-xs text-gray-500">
                {entityLabel}: <strong className="text-gray-700">{entityName}</strong>
              </p>
            </div>
          </div>
          <button
            type="button"
            onClick={onClose}
            disabled={uploading || processing}
            className="w-8 h-8 rounded-lg flex items-center justify-center text-gray-400 hover:text-gray-600 hover:bg-gray-100 transition-colors"
          >
            <X size={18} />
          </button>
        </div>

        {/* Content */}
        <div className="p-6 space-y-4">
          {error && (
            <div className="p-3.5 rounded-xl bg-red-50 border border-red-200 flex items-start gap-2.5 text-xs text-red-700">
              <AlertCircle size={16} className="shrink-0 mt-0.5 text-red-600" />
              <span>{error}</span>
            </div>
          )}

          {/* Área de Seleção / Dropzone */}
          {!previewUrl ? (
            <div
              onDragOver={(e) => {
                e.preventDefault()
                setIsDragOver(true)
              }}
              onDragLeave={() => setIsDragOver(false)}
              onDrop={handleDrop}
              onClick={() => fileInputRef.current?.click()}
              className={`p-6 border-2 border-dashed rounded-2xl flex flex-col items-center justify-center text-center cursor-pointer transition-all ${
                isDragOver
                  ? 'border-[#FC5931] bg-orange-50/50'
                  : 'border-gray-200 bg-gray-50/50 hover:bg-gray-50 hover:border-gray-300'
              }`}
            >
              <input
                ref={fileInputRef}
                type="file"
                accept="image/jpeg,image/png,image/webp"
                className="hidden"
                onChange={(e) => {
                  if (e.target.files && e.target.files[0]) {
                    handleFileSelected(e.target.files[0])
                  }
                }}
              />

              {processing ? (
                <div className="py-6 flex flex-col items-center gap-2">
                  <Loader2 size={32} className="animate-spin text-[#FC5931]" />
                  <p className="text-xs font-semibold text-gray-700">Otimizando e preparando imagem...</p>
                  <p className="text-[11px] text-gray-400">Redimensionando para até 1200px</p>
                </div>
              ) : (
                <>
                  <div className="w-12 h-12 rounded-2xl bg-white shadow-xs border border-gray-100 flex items-center justify-center text-gray-400 mb-3">
                    <UploadCloud size={24} className="text-[#FC5931]" />
                  </div>
                  <p className="text-xs font-bold text-gray-800">
                    Clique para selecionar ou arraste o arquivo aqui
                  </p>
                  <p className="text-[11px] text-gray-400 mt-1">
                    Formatos aceitos: JPEG, PNG ou WebP (máx. 5 MB)
                  </p>
                  <p className="text-[10px] text-gray-400 mt-0.5">
                    A imagem será automaticamente otimizada para carregamento rápido.
                  </p>
                </>
              )}
            </div>
          ) : (
            /* Preview da Imagem */
            <div className="space-y-3">
              <div className="relative rounded-2xl overflow-hidden border border-gray-200 bg-zinc-950 aspect-video flex items-center justify-center">
                <img
                  src={previewUrl}
                  alt="Prévia da foto"
                  className="max-h-full max-w-full object-contain"
                />
              </div>

              {imageMeta && (
                <div className="flex items-center justify-between text-[11px] text-gray-500 bg-gray-50 p-2.5 rounded-xl border border-gray-100">
                  <span>
                    Resolução: <strong>{imageMeta.width} × {imageMeta.height} px</strong>
                  </span>
                  <span>
                    Tamanho otimizado: <strong>{imageMeta.sizeKb} KB</strong> (JPEG)
                  </span>
                </div>
              )}

              <div className="flex justify-end">
                <button
                  type="button"
                  onClick={() => fileInputRef.current?.click()}
                  disabled={uploading}
                  className="text-xs font-semibold text-[#FC5931] hover:underline cursor-pointer"
                >
                  Escolher outra foto
                </button>
                <input
                  ref={fileInputRef}
                  type="file"
                  accept="image/jpeg,image/png,image/webp"
                  className="hidden"
                  onChange={(e) => {
                    if (e.target.files && e.target.files[0]) {
                      handleFileSelected(e.target.files[0])
                    }
                  }}
                />
              </div>
            </div>
          )}

          {isReplacing && (
            <p className="text-[11px] text-amber-700 bg-amber-50 p-2.5 rounded-xl border border-amber-200">
              A foto atual será substituída pela nova imagem e o histórico de auditoria registrará a alteração.
            </p>
          )}
        </div>

        {/* Footer */}
        <div className="p-6 border-t border-gray-100 flex items-center justify-end gap-2 bg-gray-50/50">
          <button
            type="button"
            onClick={onClose}
            disabled={uploading || processing}
            className="px-4 py-2 rounded-xl text-xs font-semibold text-gray-600 hover:bg-gray-200 transition-colors"
          >
            Cancelar
          </button>
          <button
            type="button"
            onClick={handleConfirmUpload}
            disabled={!processedBlob || uploading || processing}
            className="inline-flex items-center gap-1.5 px-5 py-2.5 rounded-xl bg-[#FC5931] hover:bg-[#e04820] text-white text-xs font-semibold transition-colors disabled:opacity-50 shadow-2xs cursor-pointer"
          >
            {uploading ? (
              <>
                <Loader2 size={14} className="animate-spin" />
                <span>Enviando foto...</span>
              </>
            ) : (
              <>
                <Camera size={14} />
                <span>{isReplacing ? 'Confirmar Substituição' : 'Salvar Foto'}</span>
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  )
}

// ==============================================================================
// 3. MODAL DE REMOÇÃO DE FOTO
// ==============================================================================

export interface PhotoRemoveModalProps {
  isOpen: boolean
  onClose: () => void
  type: 'pet' | 'veiculo' | 'morador'
  entityId: string
  entityName: string
  condominioId: string
  currentPhotoPath: string
  profileId: string
  onSuccess: () => void
}

export function PhotoRemoveModal({
  isOpen,
  onClose,
  type,
  entityId,
  entityName,
  currentPhotoPath,
  profileId,
  onSuccess,
}: PhotoRemoveModalProps) {
  const [motivo, setMotivo] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!isOpen) {
      setMotivo('')
      setError(null)
      setLoading(false)
    }
  }, [isOpen])

  if (!isOpen) return null

  const isPet = type === 'pet'
  const isMorador = type === 'morador'
  const entityLabel = isPet ? 'Pet' : isMorador ? 'Morador' : 'Veículo'

  async function handleConfirmRemove() {
    setLoading(true)
    setError(null)

    const supabase = createClient()

    try {
      // 1. Chamar RPC transacional no banco
      let res: { success?: boolean; error?: string; result?: any }
      if (isPet) {
        res = await adminRemovePetPhoto({
          petId: entityId,
          motivo: motivo.trim() || null,
          profileId,
        })
      } else if (isMorador) {
        res = await adminRemoveResidentPhoto({
          residentId: entityId,
          motivo: motivo.trim() || null,
        })
      } else {
        res = await adminRemoveVehiclePhoto({
          veiculoId: entityId,
          motivo: motivo.trim() || null,
          profileId,
        })
      }

      if (res.error) {
        throw new Error(res.error)
      }

      // 2. Se o banco confirmou foto_path = NULL, remover arquivo físico do Storage (apenas se for path relativo privado)
      const oldPath = res.result?.foto_path_anterior || currentPhotoPath
      if (
        oldPath &&
        typeof oldPath === 'string' &&
        !oldPath.startsWith('http://') &&
        !oldPath.startsWith('https://')
      ) {
        try {
          await supabase.storage.from('base-cadastral-media').remove([oldPath])
        } catch (cleanupErr) {
          console.error('[StorageCleanup] Falha ao remover arquivo do storage após confirmação no banco:', cleanupErr)
        }
      }

      onSuccess()
      onClose()
    } catch (err: unknown) {
      console.error('[PhotoRemoveModal] Erro:', err)
      const msg = err instanceof Error ? err.message : 'Erro ao remover a foto.'
      setError(msg)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4 backdrop-blur-xs">
      <div className="bg-white rounded-2xl max-w-md w-full shadow-2xl border border-gray-100 overflow-hidden animate-in fade-in zoom-in-95 duration-150">
        {/* Header */}
        <div className="p-6 border-b border-gray-100 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-red-50 border border-red-100 flex items-center justify-center text-red-600">
              <Trash2 size={20} />
            </div>
            <div>
              <h2 className="text-base font-bold text-gray-900">Remover Foto do {entityLabel}</h2>
              <p className="text-xs text-gray-500">
                {entityLabel}: <strong className="text-gray-700">{entityName}</strong>
              </p>
            </div>
          </div>
          <button
            type="button"
            onClick={onClose}
            disabled={loading}
            className="w-8 h-8 rounded-lg flex items-center justify-center text-gray-400 hover:text-gray-600 hover:bg-gray-100 transition-colors"
          >
            <X size={18} />
          </button>
        </div>

        {/* Content */}
        <div className="p-6 space-y-4">
          {error && (
            <div className="p-3.5 rounded-xl bg-red-50 border border-red-200 flex items-start gap-2.5 text-xs text-red-700">
              <AlertCircle size={16} className="shrink-0 mt-0.5 text-red-600" />
              <span>{error}</span>
            </div>
          )}

          <div className="p-4 rounded-xl bg-red-50/70 border border-red-200/80 text-xs text-red-800 space-y-1">
            <p className="font-semibold">Tem certeza que deseja remover esta foto?</p>
            <p className="text-[11px] text-red-700 leading-relaxed">
              O arquivo será removido do cadastro e o histórico administrativo registrará o evento de remoção.
            </p>
          </div>

          <div>
            <label className="block text-xs font-semibold text-gray-700 mb-1">
              Motivo da Remoção (opcional)
            </label>
            <input
              type="text"
              value={motivo}
              onChange={(e) => setMotivo(e.target.value)}
              disabled={loading}
              placeholder="Ex: Foto desatualizada, imagem incorreta..."
              className="w-full text-xs rounded-xl border border-gray-200 p-2.5 bg-white text-gray-800 focus:outline-hidden focus:border-[#FC5931]"
            />
          </div>
        </div>

        {/* Footer */}
        <div className="p-6 border-t border-gray-100 flex items-center justify-end gap-2 bg-gray-50/50">
          <button
            type="button"
            onClick={onClose}
            disabled={loading}
            className="px-4 py-2 rounded-xl text-xs font-semibold text-gray-600 hover:bg-gray-200 transition-colors"
          >
            Cancelar
          </button>
          <button
            type="button"
            onClick={handleConfirmRemove}
            disabled={loading}
            className="inline-flex items-center gap-1.5 px-5 py-2.5 rounded-xl bg-red-600 hover:bg-red-700 text-white text-xs font-semibold transition-colors disabled:opacity-50 shadow-2xs cursor-pointer"
          >
            {loading ? (
              <>
                <Loader2 size={14} className="animate-spin" />
                <span>Removendo foto...</span>
              </>
            ) : (
              <>
                <Trash2 size={14} />
                <span>Confirmar Remoção</span>
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  )
}

// ==============================================================================
// 4. LIGHTBOX / VISUALIZADOR DE FOTO EM ALTA RESOLUÇÃO
// ==============================================================================

export interface PhotoViewerModalProps {
  isOpen: boolean
  onClose: () => void
  imageUrl: string | null
  title: string
}

export function PhotoViewerModal({
  isOpen,
  onClose,
  imageUrl,
  title,
}: PhotoViewerModalProps) {
  useEffect(() => {
    function handleKeyDown(e: KeyboardEvent) {
      if (e.key === 'Escape') onClose()
    }
    if (isOpen) {
      window.addEventListener('keydown', handleKeyDown)
    }
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [isOpen, onClose])

  if (!isOpen || !imageUrl) return null

  return (
    <div
      onClick={onClose}
      className="fixed inset-0 bg-black/80 z-50 flex items-center justify-center p-4 backdrop-blur-sm animate-in fade-in duration-150"
    >
      <div
        onClick={(e) => e.stopPropagation()}
        className="relative bg-zinc-950 rounded-2xl max-w-3xl w-full overflow-hidden shadow-2xl border border-zinc-800 flex flex-col"
      >
        {/* Header */}
        <div className="p-4 px-6 flex items-center justify-between border-b border-zinc-800 bg-zinc-900/60">
          <h3 className="text-sm font-semibold text-white truncate">{title}</h3>
          <button
            type="button"
            onClick={onClose}
            className="w-8 h-8 rounded-lg flex items-center justify-center text-zinc-400 hover:text-white hover:bg-zinc-800 transition-colors"
          >
            <X size={18} />
          </button>
        </div>

        {/* Imagem */}
        <div className="p-4 flex items-center justify-center bg-black min-h-[300px] max-h-[75vh]">
          <img
            src={imageUrl}
            alt={title}
            className="max-h-[70vh] max-w-full object-contain rounded-lg shadow-md"
          />
        </div>
      </div>
    </div>
  )
}
