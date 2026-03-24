'use client'

import { useState, useRef, useEffect } from 'react'
import { Camera, Trash2, Pencil, X, Send, Image, Heart, MessageCircle, Eye, ChevronLeft, ChevronRight } from 'lucide-react'

type TipoEvento = 'evento' | 'manutencao' | 'reuniao' | 'outros'

interface AlbumImage {
  id: string
  imagem_url: string
  ordem: number
}

interface Album {
  id: string
  titulo: string
  descricao: string
  tipo_evento: TipoEvento
  data_evento: string | null
  created_at: string
  imagens: AlbumImage[]
  reacoes_count: number
  comentarios_count: number
  visualizacoes_count: number
}

interface Props {
  condominioId: string
  albums: Album[]
}

const TIPO_LABELS: Record<TipoEvento, string> = {
  evento: 'Evento',
  manutencao: 'Manutenção',
  reuniao: 'Reunião',
  outros: 'Outros',
}

const TIPO_COLORS: Record<TipoEvento, string> = {
  evento: 'bg-blue-100 text-blue-700',
  manutencao: 'bg-amber-100 text-amber-700',
  reuniao: 'bg-purple-100 text-purple-700',
  outros: 'bg-gray-100 text-gray-700',
}

export default function AlbumFotosAdminClient({ condominioId, albums: initial }: Props) {
  const [albums, setAlbums] = useState<Album[]>(initial)
  const [titulo, setTitulo] = useState('')
  const [descricao, setDescricao] = useState('')
  const [tipoEvento, setTipoEvento] = useState<TipoEvento>('evento')
  const [dataEvento, setDataEvento] = useState('')
  const [files, setFiles] = useState<File[]>([])
  const [previews, setPreviews] = useState<string[]>([])
  const [sending, setSending] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const fileInputRef = useRef<HTMLInputElement>(null)

  // Sync albums when server props change (after router.refresh)
  useEffect(() => {
    setAlbums(initial)
  }, [initial])

  // Edit state
  const [editingId, setEditingId] = useState<string | null>(null)
  const [editTitulo, setEditTitulo] = useState('')
  const [editDescricao, setEditDescricao] = useState('')
  const [editTipoEvento, setEditTipoEvento] = useState<TipoEvento>('evento')
  const [editDataEvento, setEditDataEvento] = useState('')
  const [editRemovedImageIds, setEditRemovedImageIds] = useState<string[]>([])
  const [editNewFiles, setEditNewFiles] = useState<File[]>([])
  const [editNewPreviews, setEditNewPreviews] = useState<string[]>([])
  const editFileInputRef = useRef<HTMLInputElement>(null)

  // Carousel state
  const [carouselIndex, setCarouselIndex] = useState<Record<string, number>>({})

  function handleFileChange(e: React.ChangeEvent<HTMLInputElement>) {
    const selected = Array.from(e.target.files ?? [])
    if (files.length + selected.length > 5) {
      setError('Máximo de 5 fotos por álbum')
      return
    }
    setFiles(prev => [...prev, ...selected])
    const newPreviews = selected.map(f => URL.createObjectURL(f))
    setPreviews(prev => [...prev, ...newPreviews])
    setError(null)
  }

  function removeFile(index: number) {
    setFiles(prev => prev.filter((_, i) => i !== index))
    setPreviews(prev => {
      URL.revokeObjectURL(prev[index])
      return prev.filter((_, i) => i !== index)
    })
  }

  async function handleCreate() {
    if (!titulo.trim()) { setError('Informe o título do álbum'); return }
    if (files.length === 0) { setError('Adicione pelo menos uma foto'); return }

    setSending(true)
    setError(null)

    const formData = new FormData()
    formData.append('titulo', titulo.trim())
    formData.append('descricao', descricao.trim())
    formData.append('tipo_evento', tipoEvento)
    formData.append('data_evento', dataEvento)
    formData.append('condominio_id', condominioId)
    files.forEach(f => formData.append('fotos', f))

    const res = await fetch('/api/album-fotos', { method: 'POST', body: formData })
    if (!res.ok) {
      const data = await res.json()
      setError(data.error ?? 'Erro ao criar álbum')
      setSending(false)
      return
    }

    // Reset form & refresh
    setTitulo('')
    setDescricao('')
    setTipoEvento('evento')
    setDataEvento('')
    setFiles([])
    previews.forEach(p => URL.revokeObjectURL(p))
    setPreviews([])
    setSending(false)

    // Force full page reload to get fresh data from server
    window.location.reload()
  }

  async function handleDelete(id: string) {
    if (!confirm('Excluir este álbum e todas as fotos?')) return
    const res = await fetch(`/api/album-fotos?id=${id}`, { method: 'DELETE' })
    if (res.ok) setAlbums(albums.filter(a => a.id !== id))
  }

  function startEdit(album: Album) {
    setEditingId(album.id)
    setEditTitulo(album.titulo)
    setEditDescricao(album.descricao)
    setEditTipoEvento(album.tipo_evento)
    setEditDataEvento(album.data_evento ?? '')
    setEditRemovedImageIds([])
    setEditNewFiles([])
    setEditNewPreviews([])
  }

  function cancelEdit() {
    setEditingId(null)
    editNewPreviews.forEach(p => URL.revokeObjectURL(p))
  }

  function handleEditFileChange(e: React.ChangeEvent<HTMLInputElement>) {
    const selected = Array.from(e.target.files ?? [])
    const album = albums.find(a => a.id === editingId)
    const currentCount = (album?.imagens.length ?? 0) - editRemovedImageIds.length + editNewFiles.length
    if (currentCount + selected.length > 5) {
      setError('Máximo de 5 fotos por álbum')
      return
    }
    setEditNewFiles(prev => [...prev, ...selected])
    setEditNewPreviews(prev => [...prev, ...selected.map(f => URL.createObjectURL(f))])
    setError(null)
  }

  async function handleSaveEdit() {
    if (!editingId) return
    setSending(true)
    setError(null)

    const formData = new FormData()
    formData.append('album_id', editingId)
    formData.append('titulo', editTitulo.trim())
    formData.append('descricao', editDescricao.trim())
    formData.append('tipo_evento', editTipoEvento)
    formData.append('data_evento', editDataEvento)
    formData.append('condominio_id', condominioId)
    formData.append('removed_image_ids', JSON.stringify(editRemovedImageIds))
    editNewFiles.forEach(f => formData.append('fotos', f))

    const res = await fetch('/api/album-fotos', { method: 'PUT', body: formData })
    if (!res.ok) {
      const data = await res.json()
      setError(data.error ?? 'Erro ao atualizar álbum')
      setSending(false)
      return
    }

    cancelEdit()
    setSending(false)

    // Force full page reload to get fresh data from server
    window.location.reload()
  }

  function getCarouselIdx(albumId: string) {
    return carouselIndex[albumId] ?? 0
  }

  function setCarouselIdx(albumId: string, idx: number) {
    setCarouselIndex(prev => ({ ...prev, [albumId]: idx }))
  }

  return (
    <div className="max-w-4xl">
      {/* Header */}
      <div className="mb-8">
        <div className="flex items-center gap-3 mb-1">
          <Camera size={22} className="text-[#FC5931]" />
          <h1 className="text-2xl font-bold text-gray-900">Álbum de Fotos</h1>
        </div>
        <p className="text-sm text-gray-500">Crie álbuns de fotos para compartilhar com os moradores do condomínio.</p>
      </div>

      {/* Create form */}
      <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6 mb-8">
        <p className="text-sm font-semibold text-gray-700 mb-4">Criar novo álbum</p>

        {/* Title */}
        <input
          type="text"
          maxLength={100}
          placeholder="Nome do Evento ou demanda"
          value={titulo}
          onChange={e => setTitulo(e.target.value)}
          className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm mb-3 focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931]"
        />

        {/* Type */}
        <div className="mb-3">
          <p className="text-xs text-gray-500 mb-2 font-medium">Tipo do Evento:</p>
          <div className="flex flex-wrap gap-3">
            {(Object.keys(TIPO_LABELS) as TipoEvento[]).map(tipo => (
              <label key={tipo} className="flex items-center gap-1.5 cursor-pointer">
                <input
                  type="radio"
                  name="tipo_evento"
                  value={tipo}
                  checked={tipoEvento === tipo}
                  onChange={() => setTipoEvento(tipo)}
                  className="accent-[#FC5931]"
                />
                <span className="text-sm text-gray-700">{TIPO_LABELS[tipo]}</span>
              </label>
            ))}
          </div>
        </div>

        {/* Description */}
        <textarea
          placeholder="Descrição sobre o Evento"
          value={descricao}
          onChange={e => setDescricao(e.target.value)}
          rows={3}
          className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm mb-3 focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] resize-none"
        />

        {/* Date */}
        <input
          type="date"
          value={dataEvento}
          onChange={e => setDataEvento(e.target.value)}
          placeholder="Escolha a data aqui"
          className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm mb-4 focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931]"
        />

        {/* Photo upload */}
        <div className="mb-4">
          <div
            onClick={() => fileInputRef.current?.click()}
            className="border-2 border-dashed border-gray-200 rounded-xl p-6 text-center cursor-pointer hover:border-[#FC5931]/40 transition-colors"
          >
            <Camera size={32} className="mx-auto mb-2 text-[#FC5931]/60" />
            <p className="text-sm text-gray-500">Insira aqui as fotos do Álbum</p>
            <p className="text-xs text-gray-400 mt-1">Máximo de 5 imagens por Álbum</p>
          </div>
          <input
            ref={fileInputRef}
            type="file"
            accept="image/*"
            multiple
            onChange={handleFileChange}
            className="hidden"
          />
        </div>

        {/* Previews */}
        {previews.length > 0 && (
          <div className="flex gap-2 flex-wrap mb-4">
            {previews.map((p, i) => (
              <div key={i} className="relative group">
                <img src={p} alt="" className="w-20 h-20 object-cover rounded-xl border border-gray-200" />
                <button
                  onClick={() => removeFile(i)}
                  className="absolute -top-2 -right-2 w-5 h-5 bg-red-500 text-white rounded-full flex items-center justify-center text-xs opacity-0 group-hover:opacity-100 transition-opacity"
                >
                  <X size={12} />
                </button>
              </div>
            ))}
          </div>
        )}

        {error && <p className="text-red-500 text-xs mb-3">{error}</p>}

        <button
          onClick={handleCreate}
          disabled={sending}
          className="flex items-center gap-2 bg-[#FC5931] hover:bg-[#D42F1D] text-white px-6 py-2.5 rounded-full text-sm font-semibold transition-colors disabled:opacity-50"
        >
          <Send size={14} />
          {sending ? 'Enviando...' : 'Inserir Álbum'}
        </button>
      </div>

      {/* Albums list */}
      <div className="space-y-4">
        {albums.length === 0 && (
          <div className="text-center py-10 text-gray-400 bg-white rounded-2xl border border-gray-100">
            <Camera size={32} className="mx-auto mb-2 opacity-30" />
            <p className="text-sm">Nenhum álbum criado ainda</p>
          </div>
        )}

        {albums.map(album => {
          const isEditing = editingId === album.id
          const currentImages = isEditing
            ? album.imagens.filter(img => !editRemovedImageIds.includes(img.id))
            : album.imagens
          const idx = getCarouselIdx(album.id)

          return (
            <div key={album.id} className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
              {isEditing ? (
                /* Edit mode */
                <div className="p-5 space-y-3">
                  <div className="flex items-center justify-between mb-2">
                    <p className="text-sm font-semibold text-gray-700">Editar Álbum</p>
                    <button onClick={cancelEdit} className="text-gray-400 hover:text-gray-600">
                      <X size={18} />
                    </button>
                  </div>

                  <input
                    type="text"
                    maxLength={100}
                    value={editTitulo}
                    onChange={e => setEditTitulo(e.target.value)}
                    className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30"
                  />

                  <div className="flex flex-wrap gap-3">
                    {(Object.keys(TIPO_LABELS) as TipoEvento[]).map(tipo => (
                      <label key={tipo} className="flex items-center gap-1.5 cursor-pointer">
                        <input
                          type="radio"
                          value={tipo}
                          checked={editTipoEvento === tipo}
                          onChange={() => setEditTipoEvento(tipo)}
                          className="accent-[#FC5931]"
                        />
                        <span className="text-sm text-gray-700">{TIPO_LABELS[tipo]}</span>
                      </label>
                    ))}
                  </div>

                  <textarea
                    value={editDescricao}
                    onChange={e => setEditDescricao(e.target.value)}
                    rows={2}
                    className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 resize-none"
                  />

                  <input
                    type="date"
                    value={editDataEvento}
                    onChange={e => setEditDataEvento(e.target.value)}
                    className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30"
                  />

                  {/* Current images */}
                  <div className="flex gap-2 flex-wrap">
                    {currentImages.map(img => (
                      <div key={img.id} className="relative group">
                        <img src={img.imagem_url} alt="" className="w-20 h-20 object-cover rounded-xl border" />
                        <button
                          onClick={() => setEditRemovedImageIds(prev => [...prev, img.id])}
                          className="absolute -top-2 -right-2 w-5 h-5 bg-red-500 text-white rounded-full flex items-center justify-center text-xs opacity-0 group-hover:opacity-100 transition-opacity"
                        >
                          <X size={12} />
                        </button>
                      </div>
                    ))}
                    {editNewPreviews.map((p, i) => (
                      <div key={`new-${i}`} className="relative group">
                        <img src={p} alt="" className="w-20 h-20 object-cover rounded-xl border border-green-300" />
                        <button
                          onClick={() => {
                            URL.revokeObjectURL(p)
                            setEditNewFiles(prev => prev.filter((_, j) => j !== i))
                            setEditNewPreviews(prev => prev.filter((_, j) => j !== i))
                          }}
                          className="absolute -top-2 -right-2 w-5 h-5 bg-red-500 text-white rounded-full flex items-center justify-center text-xs opacity-0 group-hover:opacity-100 transition-opacity"
                        >
                          <X size={12} />
                        </button>
                      </div>
                    ))}
                    {currentImages.length + editNewFiles.length < 5 && (
                      <button
                        onClick={() => editFileInputRef.current?.click()}
                        className="w-20 h-20 border-2 border-dashed border-gray-200 rounded-xl flex items-center justify-center text-gray-400 hover:border-[#FC5931]/40 hover:text-[#FC5931] transition-colors"
                      >
                        <Image size={20} />
                      </button>
                    )}
                  </div>
                  <input
                    ref={editFileInputRef}
                    type="file"
                    accept="image/*"
                    multiple
                    onChange={handleEditFileChange}
                    className="hidden"
                  />

                  <div className="flex gap-2 pt-2">
                    <button
                      onClick={handleSaveEdit}
                      disabled={sending}
                      className="bg-[#FC5931] hover:bg-[#D42F1D] text-white px-5 py-2 rounded-full text-sm font-semibold transition-colors disabled:opacity-50"
                    >
                      {sending ? 'Salvando...' : 'Salvar'}
                    </button>
                    <button
                      onClick={cancelEdit}
                      className="border border-gray-200 text-gray-600 px-5 py-2 rounded-full text-sm font-medium hover:bg-gray-50 transition-colors"
                    >
                      Cancelar
                    </button>
                  </div>
                </div>
              ) : (
                /* View mode */
                <>
                  <div className="px-5 pt-4 pb-2">
                    <div className="flex items-start justify-between gap-4">
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2 mb-1">
                          <span className={`text-[10px] uppercase font-bold px-2 py-0.5 rounded-full ${TIPO_COLORS[album.tipo_evento]}`}>
                            {TIPO_LABELS[album.tipo_evento]}
                          </span>
                          {album.data_evento && (
                            <span className="text-xs text-gray-400">
                              {new Date(album.data_evento + 'T12:00:00').toLocaleDateString('pt-BR', { month: 'long', year: 'numeric' })}
                            </span>
                          )}
                        </div>
                        <p className="font-semibold text-gray-900 text-sm">
                          Nome do Evento: {album.titulo}
                        </p>
                        {album.descricao && (
                          <p className="text-xs text-gray-500 mt-0.5">
                            Descrição do Evento: {album.descricao}
                          </p>
                        )}
                      </div>
                      <div className="flex items-center gap-1 shrink-0">
                        <button
                          onClick={() => startEdit(album)}
                          className="p-1.5 rounded-lg text-gray-400 hover:bg-gray-50 hover:text-gray-600 transition-colors"
                          title="Editar"
                        >
                          <Pencil size={16} />
                        </button>
                        <button
                          onClick={() => handleDelete(album.id)}
                          className="p-1.5 rounded-lg text-red-400 hover:bg-red-50 hover:text-red-600 transition-colors"
                          title="Excluir"
                        >
                          <Trash2 size={16} />
                        </button>
                      </div>
                    </div>
                  </div>

                  {/* Photo carousel */}
                  {album.imagens.length > 0 && (
                    <div className="relative mx-5 mb-3 rounded-xl overflow-hidden bg-gray-50">
                      <img
                        src={album.imagens[idx]?.imagem_url ?? album.imagens[0]?.imagem_url}
                        alt=""
                        className="w-full max-h-[500px] object-contain"
                      />
                      {album.imagens.length > 1 && (
                        <>
                          <button
                            onClick={() => setCarouselIdx(album.id, (idx - 1 + album.imagens.length) % album.imagens.length)}
                            className="absolute left-2 top-1/2 -translate-y-1/2 w-8 h-8 bg-black/40 text-white rounded-full flex items-center justify-center hover:bg-black/60 transition-colors"
                          >
                            <ChevronLeft size={16} />
                          </button>
                          <button
                            onClick={() => setCarouselIdx(album.id, (idx + 1) % album.imagens.length)}
                            className="absolute right-2 top-1/2 -translate-y-1/2 w-8 h-8 bg-black/40 text-white rounded-full flex items-center justify-center hover:bg-black/60 transition-colors"
                          >
                            <ChevronRight size={16} />
                          </button>
                          <div className="absolute bottom-2 left-1/2 -translate-x-1/2 flex gap-1">
                            {album.imagens.map((_, i) => (
                              <span
                                key={i}
                                className={`w-2 h-2 rounded-full transition-colors ${i === idx ? 'bg-white' : 'bg-white/40'}`}
                              />
                            ))}
                          </div>
                        </>
                      )}
                    </div>
                  )}

                  {/* Stats */}
                  <div className="px-5 pb-4 flex items-center gap-4 text-xs text-gray-500">
                    <span className="flex items-center gap-1">
                      <Heart size={14} className="text-red-400" />
                      {album.reacoes_count} reações
                    </span>
                    <span className="flex items-center gap-1">
                      <MessageCircle size={14} className="text-blue-400" />
                      {album.comentarios_count} comentários
                    </span>
                    <span className="flex items-center gap-1">
                      <Eye size={14} className="text-gray-400" />
                      {album.visualizacoes_count} visualizações
                    </span>
                    <span className="flex items-center gap-1 ml-auto">
                      <Image size={14} /> {album.imagens.length}/5 fotos
                    </span>
                  </div>
                </>
              )}
            </div>
          )
        })}
      </div>
    </div>
  )
}
