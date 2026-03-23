'use client'

import { useState, useEffect, useRef } from 'react'
import { Heart, MessageCircle, Eye, ChevronLeft, ChevronRight, Send, X, Reply, Trash2 } from 'lucide-react'

type TipoEvento = 'evento' | 'manutencao' | 'reuniao' | 'outros'

interface AlbumImage {
  id: string
  imagem_url: string
  ordem: number
}

interface Reacao {
  id: string
  user_id: string
  emoji: string
}

interface Comentario {
  id: string
  conteudo: string
  created_at: string
  parent_id: string | null
  perfil: { id: string; nome_completo: string }
}

interface Album {
  id: string
  titulo: string
  descricao: string
  tipo_evento: TipoEvento
  data_evento: string | null
  created_at: string
  autor_nome: string
  imagens: AlbumImage[]
  reacoes: Reacao[]
  comentarios: Comentario[]
  visualizacoes_count: number
}

interface Props {
  albums: Album[]
  userId: string
  userName: string
}

const EMOJIS = ['❤️', '👏', '😍', '🎉']

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

export default function AlbumFotosCondoClient({ albums: initial, userId, userName }: Props) {
  const [albums, setAlbums] = useState<Album[]>(initial)
  const [carouselIndex, setCarouselIndex] = useState<Record<string, number>>({})
  const [commentModalAlbumId, setCommentModalAlbumId] = useState<string | null>(null)
  const [commentText, setCommentText] = useState('')
  const [replyTo, setReplyTo] = useState<{ id: string; name: string } | null>(null)
  const [sending, setSending] = useState(false)
  const [showEmojiPicker, setShowEmojiPicker] = useState<string | null>(null)
  const commentInputRef = useRef<HTMLInputElement>(null)

  // Mark albums as viewed on mount
  useEffect(() => {
    albums.forEach(album => {
      fetch('/api/album-fotos/visualizacoes', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ album_id: album.id }),
      }).catch(() => {})
    })
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  function getCarouselIdx(albumId: string) {
    return carouselIndex[albumId] ?? 0
  }

  function setCarouselIdx(albumId: string, idx: number) {
    setCarouselIndex(prev => ({ ...prev, [albumId]: idx }))
  }

  async function handleReaction(albumId: string, emoji: string) {
    const res = await fetch('/api/album-fotos/reacoes', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ album_id: albumId, emoji }),
    })
    if (!res.ok) return
    const { action, previous_emoji } = await res.json()

    setAlbums(prev => prev.map(a => {
      if (a.id !== albumId) return a
      let reacoes = [...a.reacoes]
      if (action === 'added') {
        reacoes.push({ id: crypto.randomUUID(), user_id: userId, emoji })
      } else if (action === 'removed') {
        reacoes = reacoes.filter(r => !(r.user_id === userId && r.emoji === emoji))
      } else if (action === 'replaced') {
        reacoes = reacoes.filter(r => !(r.user_id === userId && r.emoji === previous_emoji))
        reacoes.push({ id: crypto.randomUUID(), user_id: userId, emoji })
      }
      return { ...a, reacoes }
    }))
    setShowEmojiPicker(null)
  }

  async function handleComment(albumId: string) {
    if (!commentText.trim()) return
    setSending(true)

    const res = await fetch('/api/album-fotos/comentarios', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        album_id: albumId,
        conteudo: commentText.trim(),
        parent_id: replyTo?.id || null,
      }),
    })

    if (res.ok) {
      const comment = await res.json()
      setAlbums(prev => prev.map(a => {
        if (a.id !== albumId) return a
        return {
          ...a,
          comentarios: [...a.comentarios, {
            ...comment,
            perfil: comment.perfil || { id: userId, nome_completo: userName },
          }],
        }
      }))
      setCommentText('')
      setReplyTo(null)
    }
    setSending(false)
  }

  async function handleDeleteComment(albumId: string, commentId: string) {
    const res = await fetch(`/api/album-fotos/comentarios?id=${commentId}`, { method: 'DELETE' })
    if (res.ok) {
      setAlbums(prev => prev.map(a => {
        if (a.id !== albumId) return a
        return { ...a, comentarios: a.comentarios.filter(c => c.id !== commentId) }
      }))
    }
  }

  function getReactionCounts(reacoes: Reacao[]) {
    const counts: Record<string, number> = {}
    for (const r of reacoes) {
      counts[r.emoji] = (counts[r.emoji] ?? 0) + 1
    }
    return counts
  }

  function hasUserReacted(reacoes: Reacao[], emoji: string) {
    return reacoes.some(r => r.user_id === userId && r.emoji === emoji)
  }

  // Build threaded comments
  function buildCommentTree(comments: Comentario[]) {
    const rootComments = comments.filter(c => !c.parent_id)
    const replies = comments.filter(c => c.parent_id)
    return rootComments.map(root => ({
      ...root,
      replies: replies.filter(r => r.parent_id === root.id),
    }))
  }

  const commentAlbum = albums.find(a => a.id === commentModalAlbumId)

  return (
    <div className="max-w-2xl mx-auto">
      <h1 className="text-2xl font-bold text-gray-900 mb-6 text-center">Álbum de Fotos</h1>

      {albums.length === 0 && (
        <div className="text-center py-16 text-gray-400">
          <Eye size={40} className="mx-auto mb-3 opacity-30" />
          <p className="text-sm">Nenhum álbum de fotos ainda</p>
        </div>
      )}

      <div className="space-y-6">
        {albums.map(album => {
          const idx = getCarouselIdx(album.id)
          const reactionCounts = getReactionCounts(album.reacoes)
          const totalReactions = album.reacoes.length

          return (
            <div key={album.id} className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
              {/* Header */}
              <div className="px-5 pt-4 pb-2">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="font-bold text-gray-900 text-base">{album.titulo}</p>
                    <div className="flex items-center gap-2 mt-0.5">
                      <span className={`text-[10px] uppercase font-bold px-2 py-0.5 rounded-full ${TIPO_COLORS[album.tipo_evento]}`}>
                        {TIPO_LABELS[album.tipo_evento]}
                      </span>
                      <span className="text-xs text-gray-400">
                        por {album.autor_nome}
                      </span>
                    </div>
                  </div>
                  {album.data_evento && (
                    <span className="text-sm font-medium text-gray-500">
                      {new Date(album.data_evento + 'T12:00:00').toLocaleDateString('pt-BR', { month: 'long', year: 'numeric' })}
                    </span>
                  )}
                </div>
                {album.descricao && (
                  <p className="text-sm text-gray-600 mt-2">{album.descricao}</p>
                )}
              </div>

              {/* Photo carousel */}
              {album.imagens.length > 0 && (
                <div className="relative">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img
                    src={album.imagens[idx]?.imagem_url ?? album.imagens[0]?.imagem_url}
                    alt={`${album.titulo} - foto ${idx + 1}`}
                    className="w-full h-80 object-cover"
                    onDoubleClick={() => handleReaction(album.id, '❤️')}
                  />
                  {album.imagens.length > 1 && (
                    <>
                      <button
                        onClick={() => setCarouselIdx(album.id, (idx - 1 + album.imagens.length) % album.imagens.length)}
                        className="absolute left-2 top-1/2 -translate-y-1/2 w-8 h-8 bg-black/40 text-white rounded-full flex items-center justify-center hover:bg-black/60 transition-colors"
                        title="Foto anterior"
                      >
                        <ChevronLeft size={16} />
                      </button>
                      <button
                        onClick={() => setCarouselIdx(album.id, (idx + 1) % album.imagens.length)}
                        className="absolute right-2 top-1/2 -translate-y-1/2 w-8 h-8 bg-black/40 text-white rounded-full flex items-center justify-center hover:bg-black/60 transition-colors"
                        title="Próxima foto"
                      >
                        <ChevronRight size={16} />
                      </button>
                      <div className="absolute bottom-2 left-1/2 -translate-x-1/2 flex gap-1.5">
                        {album.imagens.map((_, i) => (
                          <button
                            key={i}
                            onClick={() => setCarouselIdx(album.id, i)}
                            className={`w-2 h-2 rounded-full transition-all ${i === idx ? 'bg-white scale-125' : 'bg-white/50'}`}
                            title={`Foto ${i + 1}`}
                          />
                        ))}
                      </div>
                      <span className="absolute top-3 right-3 text-xs bg-black/50 text-white px-2 py-0.5 rounded-full">
                        {idx + 1}/{album.imagens.length}
                      </span>
                    </>
                  )}
                </div>
              )}

              {/* Reactions bar */}
              <div className="px-5 py-3 border-t border-gray-50">
                <div className="flex items-center justify-between">
                  {/* Reaction counts */}
                  <div className="flex items-center gap-2">
                    {Object.entries(reactionCounts).map(([emoji, count]) => (
                      <button
                        key={emoji}
                        onClick={() => handleReaction(album.id, emoji)}
                        className={`flex items-center gap-1 px-2 py-1 rounded-full text-sm transition-all ${
                          hasUserReacted(album.reacoes, emoji)
                            ? 'bg-red-50 border border-red-200'
                            : 'bg-gray-50 border border-gray-100 hover:bg-gray-100'
                        }`}
                      >
                        <span>{emoji}</span>
                        <span className="text-xs font-medium text-gray-600">{count}</span>
                      </button>
                    ))}
                    {totalReactions === 0 && (
                      <span className="text-xs text-gray-400">Nenhuma reação ainda</span>
                    )}
                  </div>

                  {/* View count */}
                  <span className="flex items-center gap-1 text-xs text-gray-400">
                    <Eye size={14} />
                    {album.visualizacoes_count}
                  </span>
                </div>

                {/* Action buttons */}
                <div className="flex items-center gap-1 mt-2 pt-2 border-t border-gray-50">
                  {/* Emoji reaction picker toggle */}
                  <div className="relative">
                    <button
                      onClick={() => setShowEmojiPicker(showEmojiPicker === album.id ? null : album.id)}
                      className="flex items-center gap-1.5 px-3 py-2 rounded-xl text-sm text-gray-600 hover:bg-gray-50 transition-colors"
                      title="Reagir"
                    >
                      <Heart size={18} className={totalReactions > 0 ? 'text-red-500 fill-red-500' : ''} />
                      <span>Reagir</span>
                    </button>
                    {showEmojiPicker === album.id && (
                      <div className="absolute bottom-full mb-1 left-0 bg-white rounded-xl shadow-lg border border-gray-100 p-2 flex gap-1 z-10">
                        {EMOJIS.map(emoji => (
                          <button
                            key={emoji}
                            onClick={() => handleReaction(album.id, emoji)}
                            className={`text-xl p-1.5 rounded-lg hover:bg-gray-100 transition-colors ${
                              hasUserReacted(album.reacoes, emoji) ? 'bg-red-50' : ''
                            }`}
                            title={`Reagir com ${emoji}`}
                          >
                            {emoji}
                          </button>
                        ))}
                      </div>
                    )}
                  </div>

                  <button
                    onClick={() => {
                      setCommentModalAlbumId(album.id)
                      setReplyTo(null)
                      setCommentText('')
                    }}
                    className="flex items-center gap-1.5 px-3 py-2 rounded-xl text-sm text-gray-600 hover:bg-gray-50 transition-colors"
                    title="Comentar"
                  >
                    <MessageCircle size={18} />
                    <span>Comentar</span>
                    {album.comentarios.length > 0 && (
                      <span className="text-xs text-gray-400">({album.comentarios.length})</span>
                    )}
                  </button>
                </div>
              </div>
            </div>
          )
        })}
      </div>

      {/* Comments Modal */}
      {commentModalAlbumId && commentAlbum && (
        <div className="fixed inset-0 z-50 flex items-center justify-center">
          <div className="absolute inset-0 bg-black/50 backdrop-blur-sm" onClick={() => setCommentModalAlbumId(null)} />
          <div className="relative bg-white rounded-2xl shadow-2xl w-full max-w-lg mx-4 max-h-[80vh] flex flex-col">
            {/* Modal header */}
            <div className="flex items-center justify-between px-5 py-4 border-b border-gray-100">
              <h3 className="font-bold text-gray-900">Comentários</h3>
              <button onClick={() => setCommentModalAlbumId(null)} className="text-gray-400 hover:text-gray-600" title="Fechar">
                <X size={20} />
              </button>
            </div>

            {/* Comments list */}
            <div className="flex-1 overflow-y-auto px-5 py-4 space-y-4">
              {commentAlbum.comentarios.length === 0 && (
                <p className="text-center text-sm text-gray-400 py-8">Nenhum comentário ainda. Seja o primeiro!</p>
              )}

              {buildCommentTree(commentAlbum.comentarios).map(comment => (
                <div key={comment.id}>
                  {/* Root comment */}
                  <div className="flex gap-3">
                    <div className="w-8 h-8 rounded-full bg-[#FC5931]/10 flex items-center justify-center text-[#FC5931] text-sm font-bold shrink-0">
                      {comment.perfil?.nome_completo?.charAt(0)?.toUpperCase() ?? '?'}
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2">
                        <span className="font-semibold text-sm text-gray-900">{comment.perfil?.nome_completo}</span>
                        <span className="text-[10px] text-gray-400">
                          {new Date(comment.created_at).toLocaleDateString('pt-BR', {
                            day: '2-digit', month: '2-digit', year: '2-digit',
                          })} – {new Date(comment.created_at).toLocaleTimeString('pt-BR', {
                            hour: '2-digit', minute: '2-digit',
                          })}
                        </span>
                      </div>
                      <p className="text-sm text-gray-700 mt-0.5">{comment.conteudo}</p>
                      <div className="flex items-center gap-3 mt-1">
                        <button
                          onClick={() => {
                            setReplyTo({ id: comment.id, name: comment.perfil?.nome_completo })
                            commentInputRef.current?.focus()
                          }}
                          className="text-xs text-gray-400 hover:text-[#FC5931] flex items-center gap-1 transition-colors"
                        >
                          <Reply size={12} /> Responder
                        </button>
                        {comment.perfil?.id === userId && (
                          <button
                            onClick={() => handleDeleteComment(commentAlbum.id, comment.id)}
                            className="text-xs text-gray-400 hover:text-red-500 flex items-center gap-1 transition-colors"
                          >
                            <Trash2 size={12} /> Excluir
                          </button>
                        )}
                      </div>
                    </div>
                  </div>

                  {/* Replies */}
                  {comment.replies.length > 0 && (
                    <div className="ml-11 mt-2 space-y-3 border-l-2 border-gray-100 pl-4">
                      {comment.replies.map(reply => (
                        <div key={reply.id} className="flex gap-3">
                          <div className="w-6 h-6 rounded-full bg-gray-100 flex items-center justify-center text-gray-500 text-xs font-bold shrink-0">
                            {reply.perfil?.nome_completo?.charAt(0)?.toUpperCase() ?? '?'}
                          </div>
                          <div className="flex-1 min-w-0">
                            <div className="flex items-center gap-2">
                              <span className="font-semibold text-xs text-gray-900">{reply.perfil?.nome_completo}</span>
                              <span className="text-[10px] text-gray-400">
                                {new Date(reply.created_at).toLocaleDateString('pt-BR', {
                                  day: '2-digit', month: '2-digit', year: '2-digit',
                                })} – {new Date(reply.created_at).toLocaleTimeString('pt-BR', {
                                  hour: '2-digit', minute: '2-digit',
                                })}
                              </span>
                            </div>
                            <p className="text-sm text-gray-700 mt-0.5">{reply.conteudo}</p>
                            {reply.perfil?.id === userId && (
                              <button
                                onClick={() => handleDeleteComment(commentAlbum.id, reply.id)}
                                className="text-xs text-gray-400 hover:text-red-500 flex items-center gap-1 mt-1 transition-colors"
                              >
                                <Trash2 size={12} /> Excluir
                              </button>
                            )}
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              ))}
            </div>

            {/* Comment input */}
            <div className="border-t border-gray-100 px-5 py-3">
              {replyTo && (
                <div className="flex items-center gap-2 mb-2 text-xs text-gray-500">
                  <Reply size={12} />
                  <span>Respondendo a <strong>{replyTo.name}</strong></span>
                  <button onClick={() => setReplyTo(null)} className="ml-auto text-gray-400 hover:text-gray-600">
                    <X size={14} />
                  </button>
                </div>
              )}
              <div className="flex items-center gap-2">
                <MessageCircle size={18} className="text-gray-300 shrink-0" />
                <input
                  ref={commentInputRef}
                  type="text"
                  value={commentText}
                  onChange={e => setCommentText(e.target.value)}
                  onKeyDown={e => {
                    if (e.key === 'Enter' && !e.shiftKey) {
                      e.preventDefault()
                      handleComment(commentAlbum.id)
                    }
                  }}
                  placeholder="Digite aqui seu comentário"
                  maxLength={500}
                  className="flex-1 border-0 focus:outline-none text-sm text-gray-700 placeholder-gray-400"
                />
                <button
                  onClick={() => handleComment(commentAlbum.id)}
                  disabled={sending || !commentText.trim()}
                  className="text-[#FC5931] hover:text-[#D42F1D] disabled:text-gray-300 transition-colors"
                  title="Enviar comentário"
                >
                  <Send size={18} />
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
