'use client'

import React, { useState, useEffect, useRef, useCallback } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { AssembleiaVideoStream } from '@/components/assembleias/AssembleiaVideoStream'
import { 
  Video, Mic, MicOff, VideoOff, Settings, 
  MessageSquare, BarChart3, Users, Play, Power, 
  CheckCircle2, AlertTriangle, Eye, EyeOff, XCircle,
  Maximize, Minimize, VolumeX, Volume2, MessageCircleOff, 
  MessageCircle, Circle, Square, Download, FileText, Loader2,
  ChevronDown, CloudOff, Cloud, ExternalLink, Trash2,
  Monitor, MonitorOff, DollarSign
} from 'lucide-react'

interface Pauta {
  id: string
  titulo: string
  descricao: string | null
  status?: string // 'fechada' | 'aberta' | 'encerrada'
  opcoes_voto: string[]
  resultado_visivel: boolean
}

interface LiveDashboardProps {
  assembleia: any
  pautas: Pauta[]
  userId: string
  totalUnidades?: number
}

interface ChatMessage {
  id: string
  user_id: string
  mensagem: string
  tipo: string
  created_at: string
  user_name?: string
  is_admin?: boolean
}

interface ParticipantInfo {
  user_id: string
  name: string
  unitId: string
  is_admin: boolean
  online_at: string
}

interface SavedRecording {
  url: string
  signedUrl?: string
  path: string
  size: number
  created_at: string
}

// Custos cobrados ao cliente (3x markup sobre custo real)
const STORAGE_COST_PER_GB_BRL = 0.60   // Armazenamento: base ~R$0.10/GB → cobrado R$0.60/GB/mês
const AI_ATA_COST_PER_HOUR_BRL = 15.00 // Transcrição IA: base ~R$2.50/h → cobrado R$15.00/hora
const ESTIMATED_MB_PER_HOUR = 500      // ~500 MB por hora de gravação para estimar duração

const CircularProgress = ({ value, max, color, label }: { value: number, max: number, color: string, label: string }) => {
  const percentage = max > 0 ? Math.min(100, (value / max) * 100) : 0
  const radius = 30
  const circumference = 2 * Math.PI * radius
  const strokeDashoffset = circumference - (percentage / 100) * circumference
  return (
    <div className="flex flex-col items-center">
      <div className="relative w-24 h-24 flex items-center justify-center">
        <svg className="w-full h-full transform -rotate-90">
          <circle cx="48" cy="48" r={radius} stroke="currentColor" strokeWidth="8" fill="transparent" className="text-gray-100" />
          <circle cx="48" cy="48" r={radius} stroke="currentColor" strokeWidth="8" fill="transparent" strokeDasharray={circumference} strokeDashoffset={strokeDashoffset} className={`${color} transition-all duration-1000 ease-out`} strokeLinecap="round" />
        </svg>
        <div className="absolute flex flex-col items-center justify-center">
          <span className="text-xl font-black text-gray-800">{value}</span>
        </div>
      </div>
      <span className="mt-1 text-[10px] font-bold text-gray-600 text-center max-w-[100px] leading-tight uppercase tracking-wider">{label}</span>
    </div>
  )
}

export default function LiveDashboard({ assembleia, pautas: initialPautas, userId, totalUnidades = 0 }: LiveDashboardProps) {
  const router = useRouter()
  const supabase = createClient()
  const [activeTab, setActiveTab] = useState<'votacao' | 'chat' | 'participantes'>('votacao')
  const [micOn, setMicOn] = useState(true)
  const [videoOn, setVideoOn] = useState(true)
  const [isBroadcasting, setIsBroadcasting] = useState(false)

  const [pautas, setPautas] = useState<Pauta[]>(initialPautas)
  const [messages, setMessages] = useState<ChatMessage[]>([])
  const [newMessage, setNewMessage] = useState('')
  const [participants, setParticipants] = useState<ParticipantInfo[]>([])
  const [voteStats, setVoteStats] = useState<Record<string, { total: number, stats: Record<string, number> }>>({})
  const [unidadesVotantesCount, setUnidadesVotantesCount] = useState(0)
  
  // NEW: Moderation & Controls
  const [isFullscreen, setIsFullscreen] = useState(false)
  const [isMuteAll, setIsMuteAll] = useState(false)
  const [isChatBlocked, setIsChatBlocked] = useState(false)
  const [showSettings, setShowSettings] = useState(false)
  
  // NEW: Recording
  const [isRecording, setIsRecording] = useState(false)
  const [recordingTime, setRecordingTime] = useState(0)
  const [isUploading, setIsUploading] = useState(false)
  const [recordingBlob, setRecordingBlob] = useState<Blob | null>(null)
  const [recordingStartTime, setRecordingStartTime] = useState<Date | null>(null)
  const [recordingEndTime, setRecordingEndTime] = useState<Date | null>(null)
  const [savedRecordings, setSavedRecordings] = useState<SavedRecording[]>([])
  const [loadingRecordings, setLoadingRecordings] = useState(true)
  const mediaRecorderRef = useRef<MediaRecorder | null>(null)
  const recordedChunksRef = useRef<Blob[]>([])
  const recordingTimerRef = useRef<NodeJS.Timeout | null>(null)

  // NEW: Screen Sharing
  const [isScreenSharing, setIsScreenSharing] = useState(false)
  const screenStreamRef = useRef<MediaStream | null>(null)
  const screenVideoRef = useRef<HTMLVideoElement>(null)

  // NEW: Live Captions (Web Speech API)
  const [captionsOn, setCaptionsOn] = useState(false)
  const [captionText, setCaptionText] = useState('')
  const [captionInterim, setCaptionInterim] = useState('')
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const recognitionRef = useRef<any>(null)

  // NEW: Device Settings
  const [devices, setDevices] = useState<{ cameras: MediaDeviceInfo[], mics: MediaDeviceInfo[] }>({ cameras: [], mics: [] })
  const [selectedCamera, setSelectedCamera] = useState<string>('')
  const [selectedMic, setSelectedMic] = useState<string>('')

  const messagesEndRef = useRef<HTMLDivElement>(null)
  const videoContainerRef = useRef<HTMLDivElement>(null)

  // ─── LIVE CAPTIONS (Web Speech API) ────────────
  const startCaptions = useCallback(() => {
    const SpeechRecognition = (window as unknown as Record<string, unknown>).SpeechRecognition || (window as unknown as Record<string, unknown>).webkitSpeechRecognition
    if (!SpeechRecognition) {
      alert('Seu navegador não suporta legendas ao vivo. Use Chrome ou Edge.')
      return
    }
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const recognition = new (SpeechRecognition as any)()
    recognition.lang = 'pt-BR'
    recognition.continuous = true
    recognition.interimResults = true
    recognition.maxAlternatives = 1

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    recognition.onresult = (event: any) => {
      let final = ''
      let interim = ''
      for (let i = event.resultIndex; i < event.results.length; i++) {
        const transcript = event.results[i][0].transcript
        if (event.results[i].isFinal) {
          final += transcript
        } else {
          interim += transcript
        }
      }
      if (final) {
        setCaptionText(final)
        setCaptionInterim('')
        // Auto-clear final caption after 6s
        setTimeout(() => setCaptionText(prev => prev === final ? '' : prev), 6000)
      }
      if (interim) {
        setCaptionInterim(interim)
      }
    }

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    recognition.onerror = (event: any) => {
      console.warn('Speech recognition error:', event.error)
      if (event.error !== 'no-speech') {
        setCaptionsOn(false)
      }
    }

    recognition.onend = () => {
      // Auto-restart if still enabled
      if (recognitionRef.current) {
        try { recognitionRef.current.start() } catch { /* already started */ }
      }
    }

    recognitionRef.current = recognition
    recognition.start()
    setCaptionsOn(true)
  }, [])

  const stopCaptions = useCallback(() => {
    if (recognitionRef.current) {
      recognitionRef.current.onend = null // prevent restart
      recognitionRef.current.stop()
      recognitionRef.current = null
    }
    setCaptionsOn(false)
    setCaptionText('')
    setCaptionInterim('')
  }, [])

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (recognitionRef.current) {
        recognitionRef.current.onend = null
        recognitionRef.current.stop()
        recognitionRef.current = null
      }
    }
  }, [])

  // ─── INITIAL LOAD ───────────────────────────────
  useEffect(() => {
    const fetchInitialData = async () => {
      const { data: chatData } = await supabase
        .from('assembleia_chat')
        .select(`*, perfil:user_id(nome, papel_sistema)`)
        .eq('assembleia_id', assembleia.id)
        .order('created_at', { ascending: true })
      
      if (chatData) {
        setMessages(chatData.map((msg: Record<string, unknown>) => ({
          id: msg.id as string,
          user_id: msg.user_id as string,
          mensagem: msg.mensagem as string,
          tipo: msg.tipo as string,
          created_at: msg.created_at as string,
          user_name: (msg.perfil as Record<string, string>)?.nome || 'Usuário',
          is_admin: ['Síndico', 'Síndico (a)', 'ADMIN', 'admin'].includes((msg.perfil as Record<string, string>)?.papel_sistema)
        })))
      }

      const { data: voteData } = await supabase
        .from('assembleia_votos')
        .select('pauta_id, voto')
        .eq('assembleia_id', assembleia.id)
      
      if (voteData) {
        const stats: Record<string, { total: number, stats: Record<string, number> }> = {}
        voteData.forEach((v: { pauta_id: string, voto: string }) => {
          if (!stats[v.pauta_id]) stats[v.pauta_id] = { total: 0, stats: {} }
          stats[v.pauta_id].total += 1
          stats[v.pauta_id].stats[v.voto] = (stats[v.pauta_id].stats[v.voto] || 0) + 1
        })
        setVoteStats(stats)
      }

      // Load saved recordings from Storage
      await loadSavedRecordings()
    }

    fetchInitialData()
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [assembleia.id, supabase])

  // ─── LOAD SAVED RECORDINGS FROM STORAGE ─────────
  const loadSavedRecordings = useCallback(async () => {
    setLoadingRecordings(true)
    try {
      const folderPath = `assembleias/${assembleia.condominio_id}/${assembleia.id}`
      const { data: files, error } = await supabase.storage
        .from('assembleia-recordings')
        .list(folderPath, { sortBy: { column: 'created_at', order: 'desc' } })

      if (error || !files || files.length === 0) {
        setSavedRecordings([])
        setLoadingRecordings(false)
        return
      }

      const recordings: SavedRecording[] = []
      for (const file of files) {
        if (file.name === '.emptyFolderPlaceholder') continue
        const filePath = `${folderPath}/${file.name}`
        const { data: signedData } = await supabase.storage
          .from('assembleia-recordings')
          .createSignedUrl(filePath, 3600) // 1 hour
        
        recordings.push({
          url: signedData?.signedUrl || '',
          signedUrl: signedData?.signedUrl || '',
          path: filePath,
          size: file.metadata?.size || 0,
          created_at: file.created_at || new Date().toISOString(),
        })
      }

      setSavedRecordings(recordings)
    } catch (err) {
      console.error('Erro ao carregar gravações salvas:', err)
    } finally {
      setLoadingRecordings(false)
    }
  }, [assembleia.id, assembleia.condominio_id, supabase])

  // ─── SCREEN SHARING ─────────────────────────────
  const handleToggleScreenShare = useCallback(async () => {
    if (isScreenSharing) {
      // Stop screen share
      screenStreamRef.current?.getTracks().forEach(t => t.stop())
      screenStreamRef.current = null
      if (screenVideoRef.current) screenVideoRef.current.srcObject = null
      setIsScreenSharing(false)
      return
    }

    try {
      const stream = await navigator.mediaDevices.getDisplayMedia({
        video: { cursor: 'always' } as MediaTrackConstraints,
        audio: false,
      })
      screenStreamRef.current = stream
      if (screenVideoRef.current) {
        screenVideoRef.current.srcObject = stream
      }
      setIsScreenSharing(true)

      // Auto-stop when user clicks "Stop sharing" in browser chrome
      stream.getVideoTracks()[0].addEventListener('ended', () => {
        screenStreamRef.current = null
        if (screenVideoRef.current) screenVideoRef.current.srcObject = null
        setIsScreenSharing(false)
      })
    } catch (err) {
      console.error('Erro ao compartilhar tela:', err)
    }
  }, [isScreenSharing])

  // Cleanup screen share on unmount
  useEffect(() => {
    return () => {
      screenStreamRef.current?.getTracks().forEach(t => t.stop())
    }
  }, [])

  // ─── STORAGE COST HELPERS ───────────────────────
  const getTotalStorageSize = useCallback((): number => {
    return savedRecordings.reduce((acc, r) => acc + r.size, 0)
  }, [savedRecordings])

  // ─── REALTIME SUBSCRIPTIONS ─────────────────────
  useEffect(() => {
    const channel = supabase.channel(`assembleia_${assembleia.id}`)

    channel
      .on('presence', { event: 'sync' }, () => {
        const state = channel.presenceState()
        const onlineUsers = Object.values(state).flatMap((users) => (users as unknown as ParticipantInfo[]))
        const uniqueUsers = Array.from(new Map(onlineUsers.map(item => [item.user_id, item])).values())
        setParticipants(uniqueUsers)
      })

    channel.on(
      'postgres_changes',
      { event: 'INSERT', schema: 'public', table: 'assembleia_chat', filter: `assembleia_id=eq.${assembleia.id}` },
      async (payload) => {
        const newMsg = payload.new as ChatMessage
        const { data } = await supabase.from('perfil').select('nome, papel_sistema').eq('id', newMsg.user_id).single()
        setMessages(prev => [...prev, { 
          ...newMsg, 
          user_name: data?.nome || 'Usuário',
          is_admin: data ? ['Síndico', 'Síndico (a)', 'ADMIN', 'admin'].includes(data.papel_sistema) : false
        }])
      }
    )

    channel.on(
      'postgres_changes',
      { event: 'UPDATE', schema: 'public', table: 'assembleia_pautas', filter: `assembleia_id=eq.${assembleia.id}` },
      (payload) => {
        const updated = payload.new as Pauta
        setPautas(prev => prev.map(p => p.id === updated.id ? updated : p))
      }
    )

    channel.on(
      'postgres_changes',
      { event: 'INSERT', schema: 'public', table: 'assembleia_votos', filter: `assembleia_id=eq.${assembleia.id}` },
      (payload) => {
        const newVote = payload.new as { pauta_id: string, voto: string }
        const pautaId = newVote.pauta_id
        const voto = newVote.voto
        
        setVoteStats(prev => {
          const pautaStats = prev[pautaId] || { total: 0, stats: {} }
          return {
            ...prev,
            [pautaId]: {
              total: pautaStats.total + 1,
              stats: {
                ...pautaStats.stats,
                [voto]: (pautaStats.stats[voto] || 0) + 1
              }
            }
          }
        })
      }
    )

    channel.on(
      'postgres_changes',
      { event: 'UPDATE', schema: 'public', table: 'assembleia_votos', filter: `assembleia_id=eq.${assembleia.id}` },
      () => {
        loadVoteStats()
      }
    )

    const loadVoteStats = async () => {
      const { data } = await supabase.from('assembleia_votos').select('pauta_id, voto').eq('assembleia_id', assembleia.id)
      if (data) {
        const stats: Record<string, { total: number, stats: Record<string, number> }> = {}
        data.forEach((v: { pauta_id: string, voto: string }) => {
          if (!stats[v.pauta_id]) stats[v.pauta_id] = { total: 0, stats: {} }
          stats[v.pauta_id].total += 1
          stats[v.pauta_id].stats[v.voto] = (stats[v.pauta_id].stats[v.voto] || 0) + 1
        })
        setVoteStats(stats)
      }
    }

    channel.subscribe(async (status) => {
      if (status === 'SUBSCRIBED') {
        const { data: profile } = await supabase.from('perfil').select('nome, unit_id').eq('id', userId).single()
        await channel.track({
          user_id: userId,
          name: profile?.nome || 'Admin',
          unitId: profile?.unit_id,
          online_at: new Date().toISOString(),
          is_admin: true
        })
      }
    })

    return () => {
      supabase.removeChannel(channel)
    }
  }, [assembleia.id, supabase, userId])

  useEffect(() => {
    const fetchUniqueVoters = async () => {
      const { data } = await supabase
        .from('assembleia_votos')
        .select('unidades(bloco, apartamento)')
        .eq('assembleia_id', assembleia.id)
      
      if (data) {
        const uniqueUnitsSet = new Set<string>()
        data.forEach(voto => {
          const votoUnidades = voto.unidades as { bloco?: { nome_ou_numero?: string }, apartamento?: { numero?: string } }
          const bloco = (votoUnidades?.bloco?.nome_ou_numero as string) || ''
          const apto = (votoUnidades?.apartamento?.numero as string) || ''
          const unidadeNome = `${bloco}-${apto}`
          if (bloco && apto) uniqueUnitsSet.add(unidadeNome)
        })
        setUnidadesVotantesCount(uniqueUnitsSet.size)
      }
    }
    fetchUniqueVoters()
  }, [assembleia.id, voteStats, supabase])

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages, activeTab])

  // ─── DEVICE ENUMERATION ─────────────────────────
  useEffect(() => {
    const loadDevices = async () => {
      try {
        // Request permission first
        await navigator.mediaDevices.getUserMedia({ audio: true, video: true })
        const allDevices = await navigator.mediaDevices.enumerateDevices()
        const cameras = allDevices.filter(d => d.kind === 'videoinput')
        const mics = allDevices.filter(d => d.kind === 'audioinput')
        setDevices({ cameras, mics })
        if (cameras.length > 0 && !selectedCamera) setSelectedCamera(cameras[0].deviceId)
        if (mics.length > 0 && !selectedMic) setSelectedMic(mics[0].deviceId)
      } catch {
        console.warn('Não foi possível listar dispositivos de mídia')
      }
    }
    loadDevices()
  }, [selectedCamera, selectedMic])

  // ─── FULLSCREEN ─────────────────────────────────
  const handleToggleFullscreen = useCallback(() => {
    if (!videoContainerRef.current) return
    if (!document.fullscreenElement) {
      videoContainerRef.current.requestFullscreen()
      setIsFullscreen(true)
    } else {
      document.exitFullscreen()
      setIsFullscreen(false)
    }
  }, [])

  useEffect(() => {
    const handleFullscreenChange = () => {
      setIsFullscreen(!!document.fullscreenElement)
    }
    document.addEventListener('fullscreenchange', handleFullscreenChange)
    return () => document.removeEventListener('fullscreenchange', handleFullscreenChange)
  }, [])

  // ─── RECORDING (MediaRecorder) ──────────────────
  const handleStartRecording = useCallback(async () => {
    try {
      // Capture the video element's stream from the container
      const videoEl = videoContainerRef.current?.querySelector('video')
      if (!videoEl) {
        alert('Nenhuma fonte de vídeo disponível. Inicie a transmissão primeiro.')
        return
      }

      // captureStream from video element
      const stream = (videoEl as HTMLVideoElement & { captureStream: () => MediaStream }).captureStream()

      // Also capture microphone audio
      try {
        const audioStream = await navigator.mediaDevices.getUserMedia({ audio: true })
        audioStream.getAudioTracks().forEach(track => stream.addTrack(track))
      } catch {
        console.warn('Áudio do microfone não capturado para a gravação')
      }

      const mediaRecorder = new MediaRecorder(stream, { 
        mimeType: 'video/webm;codecs=vp8,opus'
      })
      
      recordedChunksRef.current = []
      
      mediaRecorder.ondataavailable = (e) => {
        if (e.data.size > 0) {
          recordedChunksRef.current.push(e.data)
        }
      }

      mediaRecorder.onstop = () => {
        const blob = new Blob(recordedChunksRef.current, { type: 'video/webm' })
        setRecordingBlob(blob)
        if (recordingTimerRef.current) clearInterval(recordingTimerRef.current)
      }

      mediaRecorder.start(1000)
      mediaRecorderRef.current = mediaRecorder
      setIsRecording(true)
      setRecordingTime(0)
      setRecordingStartTime(new Date())
      setRecordingEndTime(null)
      
      recordingTimerRef.current = setInterval(() => {
        setRecordingTime(prev => prev + 1)
      }, 1000)

    } catch (err) {
      console.error('Erro ao iniciar gravação:', err)
      alert('Não foi possível iniciar a gravação. Verifique as permissões do navegador.')
    }
  }, [])

  const handleStopRecording = useCallback(() => {
    if (mediaRecorderRef.current && mediaRecorderRef.current.state !== 'inactive') {
      mediaRecorderRef.current.stop()
    }
    setIsRecording(false)
    setRecordingEndTime(new Date())
    if (recordingTimerRef.current) clearInterval(recordingTimerRef.current)
  }, [])

  const handleDownloadRecording = useCallback(() => {
    if (!recordingBlob) return
    const url = URL.createObjectURL(recordingBlob)
    const a = document.createElement('a')
    a.href = url
    a.download = `assembleia_${assembleia.id}_${new Date().toISOString().slice(0,10)}.webm`
    a.click()
    URL.revokeObjectURL(url)
  }, [recordingBlob, assembleia.id])

  // Auto-upload recording to Supabase Storage + save URL in DB
  const handleUploadToSupabase = useCallback(async () => {
    if (!recordingBlob) return
    setIsUploading(true)
    try {
      const timestamp = Date.now()
      const fileName = `assembleias/${assembleia.condominio_id}/${assembleia.id}/gravacao_${timestamp}.webm`
      
      const { error } = await supabase.storage
        .from('assembleia-recordings')
        .upload(fileName, recordingBlob, {
          contentType: 'video/webm',
          upsert: false
        })
      
      if (error) {
        if (error.message?.includes('not found') || error.message?.includes('Bucket')) {
          alert('O bucket de armazenamento "assembleia-recordings" precisa ser criado no Supabase Storage. Vou tentar salvar localmente.')
          handleDownloadRecording()
        } else {
          throw error
        }
      } else {
        // Save the storage path to the assembleias table
        await supabase
          .from('assembleias')
          .update({ gravacao_url: fileName })
          .eq('id', assembleia.id)

        // Clear local blob and reload saved recordings from Storage
        setRecordingBlob(null)
        await loadSavedRecordings()
      }
    } catch (err) {
      console.error('Erro ao fazer upload:', err)
      alert('Erro ao salvar no Supabase. Faça o download manualmente.')
    } finally {
      setIsUploading(false)
    }
  }, [recordingBlob, assembleia.id, assembleia.condominio_id, supabase, handleDownloadRecording, loadSavedRecordings])

  // Auto-upload after recording stops
  useEffect(() => {
    if (recordingBlob && !isRecording && !isUploading) {
      // Auto-upload after a short delay to let the UI update
      const timer = setTimeout(() => {
        handleUploadToSupabase()
      }, 500)
      return () => clearTimeout(timer)
    }
  }, [recordingBlob, isRecording, isUploading, handleUploadToSupabase])

  const handleDeleteRecording = useCallback(async (path: string) => {
    if (!confirm('Excluir esta gravação permanentemente?')) return
    try {
      const { error } = await supabase.storage
        .from('assembleia-recordings')
        .remove([path])
      
      if (error) throw error

      // If this was the last recording, clear gravacao_url in DB
      const remaining = savedRecordings.filter(r => r.path !== path)
      if (remaining.length === 0) {
        await supabase
          .from('assembleias')
          .update({ gravacao_url: null })
          .eq('id', assembleia.id)
      }

      setSavedRecordings(remaining)
    } catch (err) {
      console.error('Erro ao excluir gravação:', err)
      alert('Erro ao excluir gravação.')
    }
  }, [supabase, assembleia.id, savedRecordings])

  const handleGenerateAta = useCallback(async () => {
    // Navigates securely to the ATA screen where generation happens
    router.push(`/admin/assembleias/${assembleia.id}/ata`)
  }, [router, assembleia.id])

  // ─── FORMAT HELPERS ─────────────────────────────
  const formatTime = (isoString: string) => {
    return new Date(isoString).toLocaleTimeString('pt-BR', { hour: '2-digit', minute:'2-digit' })
  }

  const formatRecordingTime = (seconds: number) => {
    const h = Math.floor(seconds / 3600)
    const m = Math.floor((seconds % 3600) / 60)
    const s = seconds % 60
    return `${h > 0 ? h.toString().padStart(2,'0') + ':' : ''}${m.toString().padStart(2,'0')}:${s.toString().padStart(2,'0')}`
  }

  // ─── ACTION HANDLERS ───────────────────────────
  const handleSendMessage = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!newMessage.trim()) return
    const txt = newMessage.trim()
    setNewMessage('')
    
    await supabase.from('assembleia_chat').insert({
      assembleia_id: assembleia.id,
      user_id: userId,
      mensagem: txt,
      tipo: 'sistema'
    })
  }

  const handleTogglePauta = async (pauta: Pauta) => {
    const newStatus = pauta.status === 'aberta' ? 'encerrada' : 'aberta'
    setPautas(prev => prev.map(p => p.id === pauta.id ? { ...p, status: newStatus } : p))
    await supabase.from('assembleia_pautas')
      .update({ status: newStatus })
      .eq('id', pauta.id)
  }

  const handleToggleVisibility = async (pauta: Pauta) => {
    const newVal = !pauta.resultado_visivel
    await supabase.from('assembleia_pautas')
      .update({ resultado_visivel: newVal })
      .eq('id', pauta.id)
  }

  const handleToggleMuteAll = () => {
    setIsMuteAll(!isMuteAll)
    // Send system message to notify participants
    supabase.from('assembleia_chat').insert({
      assembleia_id: assembleia.id,
      user_id: userId,
      mensagem: !isMuteAll 
        ? '🔇 O administrador silenciou todos os participantes.'
        : '🔊 O administrador reativou o áudio dos participantes.',
      tipo: 'sistema'
    })
  }

  const handleToggleChatBlock = () => {
    setIsChatBlocked(!isChatBlocked)
    supabase.from('assembleia_chat').insert({
      assembleia_id: assembleia.id,
      user_id: userId,
      mensagem: !isChatBlocked 
        ? '🔒 O chat foi bloqueado pelo administrador.'
        : '🔓 O chat foi desbloqueado pelo administrador.',
      tipo: 'sistema'
    })
  }

  const AnyPautaOpen = pautas.some(p => p.status === 'aberta')

  return (
    <div className="w-full flex flex-col xl:flex-row gap-6 animate-in fade-in zoom-in-95 duration-500">
      
      {/* LEFT STAGE: Video Feed */}
      <div className="flex-1 flex flex-col gap-4">
        {/* Video Player Box */}
        <div ref={videoContainerRef} className="relative w-full aspect-video bg-gray-900 rounded-3xl overflow-hidden shadow-2xl ring-1 ring-gray-900/10 flex flex-col">
          
          {/* Header Video Overlay */}
          <div className="absolute top-0 w-full p-6 flex justify-between items-center z-10 bg-linear-to-b from-black/80 via-black/40 to-transparent">
            <div className="flex items-center gap-3">
              {isBroadcasting && (
                <>
                  <span className="flex h-3 w-3 relative">
                    <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-red-400 opacity-75"></span>
                    <span className="relative inline-flex rounded-full h-3 w-3 bg-red-500"></span>
                  </span>
                  <span className="text-white font-semibold text-sm tracking-widest uppercase shadow-sm">AO VIVO</span>
                </>
              )}
              {isRecording && (
                <span className="ml-2 flex items-center gap-2 bg-red-600/80 backdrop-blur-md text-white text-xs font-bold px-3 py-1.5 rounded-full border border-red-400/30">
                  <Circle size={8} className="fill-white animate-pulse" />
                  REC {formatRecordingTime(recordingTime)}
                </span>
              )}
            </div>
            <div className="flex items-center gap-2">
              {/* Fullscreen Button */}
              <button 
                onClick={handleToggleFullscreen}
                className="w-10 h-10 flex items-center justify-center bg-black/40 backdrop-blur-md rounded-xl text-white/90 hover:bg-white/20 transition-all border border-white/10"
                title={isFullscreen ? 'Sair da Tela Cheia' : 'Tela Cheia'}
              >
                {isFullscreen ? <Minimize size={18} /> : <Maximize size={18} />}
              </button>
              <div className="flex items-center gap-2 bg-black/40 backdrop-blur-md px-4 py-2 rounded-xl text-white/90 text-sm font-bold border border-white/10 shadow-lg">
                <Users size={16} className="text-[#FC5931]" /> {participants.length} Presentes
              </div>
            </div>
          </div>

          {/* Live Video Feed Center */}
          <div className="flex-1 flex items-center justify-center relative overflow-hidden bg-black">
            {/* Screen Share takes over main view when active */}
            {isScreenSharing && (
              <video
                ref={screenVideoRef}
                autoPlay
                playsInline
                className="absolute inset-0 w-full h-full object-contain z-10 bg-black"
              />
            )}
            {/* Camera feed → PiP when screen sharing, full when not */}
            <div className={isScreenSharing 
              ? 'absolute bottom-4 right-4 w-48 h-36 rounded-xl overflow-hidden shadow-2xl ring-2 ring-white/20 z-20 bg-gray-900' 
              : 'w-full h-full'
            }>
              <AssembleiaVideoStream 
                assembleiaId={assembleia.id}
                isBroadcasting={isBroadcasting}
                micOn={micOn}
                videoOn={videoOn}
              />
            </div>
            {/* Screen share badge */}
            {isScreenSharing && (
              <div className="absolute top-4 left-4 z-20 flex items-center gap-2 bg-blue-600/90 backdrop-blur-md text-white text-xs font-bold px-3 py-1.5 rounded-full border border-blue-400/30">
                <Monitor size={12} />
                Compartilhando Tela
              </div>
            )}
            {/* Live Captions Overlay */}
            {captionsOn && (captionText || captionInterim) && (
              <div className="absolute bottom-6 left-1/2 -translate-x-1/2 z-30 max-w-[85%] pointer-events-none">
                <div className="bg-black/80 backdrop-blur-md rounded-xl px-5 py-3 text-center shadow-2xl border border-white/10">
                  {captionText && (
                    <p className="text-white text-sm font-medium leading-relaxed">{captionText}</p>
                  )}
                  {captionInterim && (
                    <p className="text-white/60 text-sm italic leading-relaxed">{captionInterim}</p>
                  )}
                </div>
              </div>
            )}
          </div>

          {/* Presenter Controls */}
          <div className="bg-black/80 backdrop-blur-3xl p-5 flex justify-between items-center z-20 border-t border-white/5">
            <div className="flex items-center gap-3 pl-2">
              {/* Mic */}
              <button 
                onClick={() => setMicOn(!micOn)}
                className={`w-12 h-12 flex items-center justify-center rounded-2xl transition-all ${
                  micOn ? 'bg-white/10 hover:bg-white/20 text-white' : 'bg-red-500 hover:bg-red-600 text-white shadow-lg shadow-red-500/20'
                }`}
                title="Microfone"
              >
                {micOn ? <Mic size={22} /> : <MicOff size={22} />}
              </button>
              
              {/* Video */}
              <button 
                onClick={() => setVideoOn(!videoOn)}
                className={`w-12 h-12 flex items-center justify-center rounded-2xl transition-all ${
                  videoOn ? 'bg-white/10 hover:bg-white/20 text-white' : 'bg-red-500 hover:bg-red-600 text-white shadow-lg shadow-red-500/20'
                }`}
                title="Câmera"
              >
                {videoOn ? <Video size={22} /> : <VideoOff size={22} />}
              </button>

              {/* Divider */}
              <div className="w-px h-8 bg-white/10 mx-1"></div>

              {/* Mute All (Audience) */}
              <button 
                onClick={handleToggleMuteAll}
                className={`w-12 h-12 flex items-center justify-center rounded-2xl transition-all ${
                  isMuteAll ? 'bg-amber-500 hover:bg-amber-600 text-white shadow-lg shadow-amber-500/20' : 'bg-white/10 hover:bg-white/20 text-white'
                }`}
                title={isMuteAll ? 'Reativar Áudio de Todos' : 'Silenciar Todos'}
              >
                {isMuteAll ? <VolumeX size={22} /> : <Volume2 size={22} />}
              </button>

              {/* Block Chat */}
              <button 
                onClick={handleToggleChatBlock}
                className={`w-12 h-12 flex items-center justify-center rounded-2xl transition-all ${
                  isChatBlocked ? 'bg-amber-500 hover:bg-amber-600 text-white shadow-lg shadow-amber-500/20' : 'bg-white/10 hover:bg-white/20 text-white'
                }`}
                title={isChatBlocked ? 'Desbloquear Chat' : 'Bloquear Chat'}
              >
                {isChatBlocked ? <MessageCircleOff size={22} /> : <MessageCircle size={22} />}
              </button>

              {/* Divider */}
              <div className="w-px h-8 bg-white/10 mx-1"></div>

              {/* Recording */}
              <button 
                onClick={isRecording ? handleStopRecording : handleStartRecording}
                className={`w-12 h-12 flex items-center justify-center rounded-2xl transition-all ${
                  isRecording ? 'bg-red-600 hover:bg-red-700 text-white shadow-lg shadow-red-500/30 animate-pulse' : 'bg-white/10 hover:bg-white/20 text-white'
                }`}
                title={isRecording ? 'Parar Gravação' : 'Iniciar Gravação'}
              >
                {isRecording ? <Square size={18} className="fill-white" /> : <Circle size={22} className="text-red-400" />}
              </button>

              {/* Screen Share */}
              <button 
                onClick={handleToggleScreenShare}
                className={`w-12 h-12 flex items-center justify-center rounded-2xl transition-all ${
                  isScreenSharing 
                    ? 'bg-blue-600 hover:bg-blue-700 text-white shadow-lg shadow-blue-500/30 ring-2 ring-blue-400/40' 
                    : 'bg-white/10 hover:bg-white/20 text-white'
                }`}
                title={isScreenSharing ? 'Parar Compartilhamento de Tela' : 'Compartilhar Tela (Apresentação)'}
              >
                {isScreenSharing ? <MonitorOff size={20} /> : <Monitor size={20} />}
              </button>

              {/* Live Captions */}
              <button 
                onClick={captionsOn ? stopCaptions : startCaptions}
                className={`w-12 h-12 flex items-center justify-center rounded-2xl transition-all ${
                  captionsOn
                    ? 'bg-yellow-500 hover:bg-yellow-600 text-black shadow-lg shadow-yellow-500/30 ring-2 ring-yellow-300/40' 
                    : 'bg-white/10 hover:bg-white/20 text-white'
                }`}
                title={captionsOn ? 'Desativar Legendas ao Vivo' : 'Ativar Legendas ao Vivo'}
              >
                <span className="text-xs font-black tracking-tight">CC</span>
              </button>

              {/* Settings */}
              <div className="relative">
                <button 
                  onClick={() => setShowSettings(!showSettings)}
                  className="w-12 h-12 border border-white/10 flex items-center justify-center rounded-2xl bg-transparent hover:bg-white/10 text-white transition-all" 
                  title="Configurações (Dispositivos)"
                >
                  <Settings size={20} />
                </button>

                {/* Settings Dropdown */}
                {showSettings && (
                  <div className="absolute bottom-16 left-1/2 -translate-x-1/2 bg-gray-900 border border-white/10 rounded-2xl p-5 shadow-2xl z-50 w-80 backdrop-blur-xl">
                    <h4 className="text-white font-bold text-sm mb-4 flex items-center gap-2">
                      <Settings size={16} className="text-[#FC5931]" /> Dispositivos
                    </h4>
                    
                    {/* Camera Selection */}
                    <div className="mb-4">
                      <label className="text-gray-400 text-xs font-bold uppercase tracking-wider mb-2 block">Câmera</label>
                      <div className="relative">
                        <select 
                          value={selectedCamera} 
                          onChange={e => setSelectedCamera(e.target.value)}
                          title="Selecionar câmera"
                          className="w-full bg-white/10 border border-white/10 text-white text-sm rounded-xl px-4 py-3 appearance-none focus:outline-none focus:ring-2 focus:ring-[#FC5931]/50 cursor-pointer"
                        >
                          {devices.cameras.map(cam => (
                            <option key={cam.deviceId} value={cam.deviceId} className="bg-gray-900 text-white">
                              {cam.label || `Câmera ${devices.cameras.indexOf(cam) + 1}`}
                            </option>
                          ))}
                        </select>
                        <ChevronDown size={16} className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none" />
                      </div>
                    </div>

                    {/* Mic Selection */}
                    <div className="mb-2">
                      <label className="text-gray-400 text-xs font-bold uppercase tracking-wider mb-2 block">Microfone</label>
                      <div className="relative">
                        <select 
                          value={selectedMic}
                          onChange={e => setSelectedMic(e.target.value)}
                          title="Selecionar microfone"
                          className="w-full bg-white/10 border border-white/10 text-white text-sm rounded-xl px-4 py-3 appearance-none focus:outline-none focus:ring-2 focus:ring-[#FC5931]/50 cursor-pointer"
                        >
                          {devices.mics.map(mic => (
                            <option key={mic.deviceId} value={mic.deviceId} className="bg-gray-900 text-white">
                              {mic.label || `Microfone ${devices.mics.indexOf(mic) + 1}`}
                            </option>
                          ))}
                        </select>
                        <ChevronDown size={16} className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none" />
                      </div>
                    </div>

                    <button 
                      onClick={() => setShowSettings(false)}
                      className="w-full mt-3 py-2.5 bg-white/10 hover:bg-white/20 text-white text-sm font-bold rounded-xl transition-all"
                    >
                      Fechar
                    </button>
                  </div>
                )}
              </div>
            </div>

            <button 
              onClick={() => setIsBroadcasting(!isBroadcasting)}
              className={`flex items-center gap-3 text-white px-8 py-4 rounded-2xl font-bold transition-transform hover:scale-105 active:scale-95 border ${
                isBroadcasting 
                  ? 'bg-red-600 hover:bg-red-700 border-red-500/50 shadow-xl shadow-red-600/30' 
                  : 'bg-emerald-600 hover:bg-emerald-700 border-emerald-500/50 shadow-xl shadow-emerald-600/30'
              }`}
            >
              {isBroadcasting ? (
                <>
                  <Power size={20} />
                  Encerrar Sessão
                </>
              ) : (
                <>
                  <Play size={20} />
                  Iniciar Sessão
                </>
              )}
            </button>
          </div>
        </div>

        {/* Upload in Progress Bar */}
        {isUploading && (
          <div className="flex items-center gap-3 p-4 bg-blue-50 border border-blue-200 rounded-2xl animate-in fade-in slide-in-from-bottom-4 duration-300">
            <Loader2 size={22} className="text-blue-600 animate-spin shrink-0" />
            <div className="flex-1">
              <span className="text-sm font-bold text-blue-800 block">Salvando gravação na nuvem...</span>
              <span className="text-xs text-blue-600 mt-0.5 block">O envio está em andamento. Não feche a página.</span>
            </div>
          </div>
        )}

        {/* Post-Recording Actions Bar (local blob not yet uploaded) */}
        {recordingBlob && !isRecording && !isUploading && (
          <div className="flex flex-col gap-3 p-4 bg-amber-50 border border-amber-200 rounded-2xl animate-in fade-in slide-in-from-bottom-4 duration-300">
            <div className="flex items-center gap-3">
              <CloudOff size={22} className="text-amber-600 shrink-0" />
              <div className="flex-1">
                <span className="text-sm font-bold text-amber-800 block">Gravação pendente de envio ({(recordingBlob.size / (1024 * 1024)).toFixed(1)} MB)</span>
                <span className="text-xs text-amber-600 mt-0.5 block">
                  {recordingStartTime && <>Início: {recordingStartTime.toLocaleString('pt-BR', { day:'2-digit', month:'2-digit', year:'numeric', hour:'2-digit', minute:'2-digit', second:'2-digit' })}</>}
                  {recordingEndTime && <> — Fim: {recordingEndTime.toLocaleString('pt-BR', { hour:'2-digit', minute:'2-digit', second:'2-digit' })}</>}
                  {recordingStartTime && recordingEndTime && <> (Duração: {formatRecordingTime(Math.round((recordingEndTime.getTime() - recordingStartTime.getTime()) / 1000))})</>}
                </span>
              </div>
            </div>
            <div className="flex items-center gap-3 ml-9">
              <button 
                onClick={handleDownloadRecording}
                className="flex items-center gap-2 px-4 py-2.5 bg-white text-gray-800 border border-gray-200 rounded-xl text-sm font-bold hover:bg-gray-50 transition-all shadow-sm"
              >
                <Download size={16} /> Baixar
              </button>
              <button 
                onClick={handleUploadToSupabase}
                className="flex items-center gap-2 px-4 py-2.5 bg-[#FC5931] text-white rounded-xl text-sm font-bold hover:bg-[#e04f2c] transition-all shadow-sm"
              >
                <Cloud size={16} /> Salvar na Nuvem
              </button>
            </div>
          </div>
        )}

        {/* Saved Recordings (persisted in Storage - survive F5) */}
        {savedRecordings.length > 0 && (
          <div className="flex flex-col gap-3 p-4 bg-emerald-50 border border-emerald-200 rounded-2xl animate-in fade-in slide-in-from-bottom-4 duration-300">
            <div className="flex items-center gap-3">
              <CheckCircle2 size={22} className="text-emerald-600 shrink-0" />
              <div className="flex-1">
                <span className="text-sm font-bold text-emerald-800 block">
                  {savedRecordings.length === 1 ? 'Gravação salva na nuvem ☁️' : `${savedRecordings.length} gravações salvas na nuvem ☁️`}
                </span>
              </div>
            </div>
            <div className="space-y-2 ml-9">
              {savedRecordings.map((rec, idx) => (
                <div key={rec.path} className="flex items-center gap-3 p-3 bg-white rounded-xl border border-emerald-100 shadow-sm">
                  <div className="flex-1 min-w-0">
                    <span className="text-sm font-semibold text-gray-800 block truncate">Gravação {idx + 1}</span>
                    <span className="text-xs text-gray-500">
                      {new Date(rec.created_at).toLocaleString('pt-BR', { day:'2-digit', month:'2-digit', year:'numeric', hour:'2-digit', minute:'2-digit' })}
                      {rec.size > 0 && <> · {(rec.size / (1024 * 1024)).toFixed(1)} MB</>}
                    </span>
                  </div>
                  <div className="flex items-center gap-2 shrink-0">
                    {rec.signedUrl && (
                      <a 
                        href={rec.signedUrl}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="flex items-center gap-1.5 px-3 py-2 bg-emerald-100 text-emerald-700 rounded-lg text-xs font-bold hover:bg-emerald-200 transition-colors"
                      >
                        <ExternalLink size={14} /> Abrir
                      </a>
                    )}
                    <button
                      onClick={handleGenerateAta}
                      className="flex items-center gap-1.5 px-3 py-2 bg-blue-100 text-blue-700 rounded-lg text-xs font-bold hover:bg-blue-200 transition-colors"
                    >
                      <FileText size={14} /> ATA (IA)
                    </button>
                    <button
                      onClick={() => handleDeleteRecording(rec.path)}
                      title="Excluir gravação"
                      className="flex items-center gap-1.5 px-3 py-2 bg-red-50 text-red-500 rounded-lg text-xs font-bold hover:bg-red-100 transition-colors"
                    >
                      <Trash2 size={14} />
                    </button>
                  </div>
                </div>
              ))}
            </div>
            {/* Total cost summary - actual spent costs */}
            {(() => {
              const totalMB = getTotalStorageSize() / (1024 * 1024)
              const estimatedHours = totalMB / ESTIMATED_MB_PER_HOUR
              const storageCost = (getTotalStorageSize() / (1024 * 1024 * 1024)) * STORAGE_COST_PER_GB_BRL
              const aiCost = estimatedHours * AI_ATA_COST_PER_HOUR_BRL
              const fmtBRL = (v: number) => v < 0.01 ? '< R$ 0,01' : `R$ ${v.toFixed(2).replace('.', ',')}`
              const durationLabel = estimatedHours < 1 
                ? `${Math.max(1, Math.round(estimatedHours * 60))} min` 
                : `${estimatedHours.toFixed(1).replace('.', ',')}h`
              return (
                <div className="space-y-1.5 ml-9 mt-1">
                  <div className="flex items-center gap-2 p-2.5 bg-emerald-100/60 rounded-xl border border-emerald-200/60">
                    <DollarSign size={14} className="text-emerald-700 shrink-0" />
                    <span className="text-xs font-bold text-emerald-800">
                      Armazenamento: {totalMB.toFixed(1)} MB · {fmtBRL(storageCost)}/mês
                    </span>
                  </div>
                  <div className="flex items-center gap-2 p-2.5 bg-blue-50/80 rounded-xl border border-blue-200/60">
                    <FileText size={14} className="text-blue-600 shrink-0" />
                    <span className="text-xs font-bold text-blue-700">
                      Transcrição IA (ATA): {fmtBRL(aiCost)} · {durationLabel} de gravação
                    </span>
                  </div>
                </div>
              )
            })()}
          </div>
        )}


        {/* Loading recordings indicator */}
        {loadingRecordings && savedRecordings.length === 0 && !recordingBlob && (
          <div className="flex items-center gap-3 p-4 bg-gray-50 border border-gray-200 rounded-2xl">
            <Loader2 size={18} className="text-gray-400 animate-spin" />
            <span className="text-sm text-gray-500">Verificando gravações salvas...</span>
          </div>
        )}
      </div>

      {/* RIGHT STAGE: Control Panel (Chat/Polls) */}
      <div className="w-full xl:w-[380px] xl:min-w-[380px] shrink-0 flex flex-col bg-white rounded-3xl shadow-[0_8px_30px_rgb(0,0,0,0.06)] border border-gray-100 overflow-hidden h-full xl:max-h-[min(85vh,900px)]">
        
        {/* Panel Tabs */}
        <div className="flex w-full border-b border-gray-100 bg-gray-50/80 p-2 gap-1 relative z-10 shadow-sm shrink-0">
          <button 
            onClick={() => setActiveTab('votacao')}
            className={`flex-1 flex flex-col items-center gap-2 py-3 rounded-2xl transition-all ${activeTab === 'votacao' ? 'bg-white shadow-[0_2px_10px_rgb(0,0,0,0.04)] ring-1 ring-gray-100 text-[#FC5931] font-bold' : 'text-gray-500 hover:text-gray-800 hover:bg-white/60 font-medium'}`}
          >
            <BarChart3 size={20} />
            <span className="text-[11px] uppercase tracking-widest font-bold">Pautas</span>
          </button>
          <button 
            onClick={() => setActiveTab('chat')}
             className={`flex-1 flex flex-col items-center gap-2 py-3 rounded-2xl transition-all relative ${activeTab === 'chat' ? 'bg-white shadow-[0_2px_10px_rgb(0,0,0,0.04)] ring-1 ring-gray-100 text-[#FC5931] font-bold' : 'text-gray-500 hover:text-gray-800 hover:bg-white/60 font-medium'}`}
          >
            <MessageSquare size={20} />
            <span className="text-[11px] uppercase tracking-widest font-bold">Chat</span>
            {isChatBlocked && (
              <span className="absolute top-1.5 right-3 w-2.5 h-2.5 bg-amber-500 rounded-full border-2 border-white"></span>
            )}
          </button>
          <button 
            onClick={() => setActiveTab('participantes')}
             className={`flex-1 flex flex-col items-center gap-2 py-3 rounded-2xl transition-all ${activeTab === 'participantes' ? 'bg-white shadow-[0_2px_10px_rgb(0,0,0,0.04)] ring-1 ring-gray-100 text-[#FC5931] font-bold' : 'text-gray-500 hover:text-gray-800 hover:bg-white/60 font-medium'}`}
          >
            <Users size={20} />
            <span className="text-[11px] uppercase tracking-widest font-bold">Público</span>
          </button>
        </div>

        {/* Panel Content Area */}
        <div className="flex-1 overflow-y-auto p-5 bg-white flex flex-col min-h-0">
          
          {/* TAB: VOTACAO */}
          {activeTab === 'votacao' && (
            <div className="flex flex-col gap-4 animate-in fade-in slide-in-from-right-4 duration-300 pb-8 min-h-0">
              {!AnyPautaOpen && (
                <div className="bg-orange-50 border border-orange-100 text-orange-800 p-4 rounded-2xl text-sm flex gap-4 items-start shadow-inner">
                  <AlertTriangle size={24} className="text-orange-500 shrink-0 mt-0.5" />
                  <p className="leading-relaxed">Nenhuma votação está aberta no momento. Libere uma pauta para os moradores opinarem em tempo real.</p>
                </div>
              )}

              {pautas.map((p, idx) => {
                const isOpen = p.status === 'aberta'
                const isClosed = p.status === 'encerrada'
                const stats = voteStats[p.id] || { total: 0, stats: {} }

                return (
                  <div key={p.id} className={`border rounded-3xl p-5 shadow-sm transition-all mt-2 ${isOpen ? 'bg-[#FC5931]/5 border-[#FC5931]/30 ring-2 ring-[#FC5931]/10' : 'bg-white border-gray-100 hover:shadow-md'}`}>
                    <div className="flex justify-between items-start mb-4">
                      <span className={`text-xs font-black uppercase tracking-[0.2em] ${isOpen ? 'text-[#FC5931]' : 'text-gray-400'}`}>Pauta {idx + 1}</span>
                      
                      {isOpen && <span className="bg-red-100 text-red-600 text-[10px] uppercase font-black px-3 py-1.5 rounded-lg border border-red-200 animate-pulse">Aberta</span>}
                      {isClosed && <span className="bg-gray-100 text-gray-500 text-[10px] uppercase font-black px-3 py-1.5 rounded-lg border border-gray-200">Encerrada</span>}
                      {p.status === 'fechada' && <span className="bg-blue-50 text-blue-500 text-[10px] uppercase font-black px-3 py-1.5 rounded-lg border border-blue-100">Aguardando</span>}
                    </div>
                    
                    <h3 className="text-lg font-bold text-gray-900 mb-2 leading-tight">{p.titulo}</h3>
                    {p.descricao && <p className="text-sm text-gray-500 mb-6 leading-relaxed line-clamp-3">{p.descricao}</p>}
                    
                    {/* Contagem de Votos ao Vivo */}
                    {(isOpen || isClosed || stats.total > 0) && (
                      <div className="mb-6 bg-white rounded-xl border border-gray-100 p-4 shadow-sm">
                        <div className="flex justify-between items-center mb-3">
                          <span className="text-xs font-bold text-gray-700">Progresso ao Vivo</span>
                          <span className="text-xs font-bold bg-gray-100 text-gray-600 px-2 py-1 rounded-md">{stats.total} votos contabilizados</span>
                        </div>
                        
                        <div className="space-y-3">
                          {p.opcoes_voto.map(opcao => {
                            const count = stats.stats[opcao] || 0
                            const percentage = stats.total > 0 ? Math.round((count / stats.total) * 100) : 0
                            
                            return (
                              <div key={opcao} className="relative w-full h-8 bg-gray-50 rounded-lg border border-gray-100 overflow-hidden">
                                <div 
                                  className="absolute top-0 left-0 h-full bg-blue-100 transition-all duration-500" 
                                  style={{ width: `${percentage}%` }}
                                ></div>
                                <div className="absolute inset-0 flex items-center justify-between px-3 text-xs">
                                  <span className="font-bold text-gray-800 z-10">{opcao}</span>
                                  <span className="font-bold text-gray-500 z-10">{count} ({percentage}%)</span>
                                </div>
                              </div>
                            )
                          })}
                        </div>
                        
                        <div className="flex items-center gap-2 mt-4 pt-3 border-t border-gray-100">
                          <button 
                            onClick={() => handleToggleVisibility(p)}
                            className="text-xs font-medium text-gray-500 hover:text-gray-800 flex items-center gap-1.5 w-full justify-center transition-colors"
                          >
                            {p.resultado_visivel ? (
                              <><Eye size={14} className="text-blue-500" /> Moradores estão vendo a parcial</>
                            ) : (
                              <><EyeOff size={14} /> Moradores NÃO veem este resultado agora</>
                            )}
                          </button>
                        </div>
                      </div>
                    )}
                    
                    {!isClosed && (
                      <button 
                        onClick={() => handleTogglePauta(p)}
                        className={`w-full flex items-center justify-center gap-2 py-3.5 rounded-xl font-bold transition-all group ${
                          isOpen 
                            ? 'bg-red-50 text-red-600 hover:bg-red-100 border border-red-200'
                            : 'bg-[#FC5931]/10 text-[#FC5931] hover:bg-[#FC5931] hover:text-white border border-[#FC5931]/20'
                        }`}
                      >
                        {isOpen ? (
                          <><XCircle size={18} /> Encerrar Votação desta Pauta</>
                        ) : (
                          <><Play size={18} className="group-hover:scale-110 transition-transform" /> Iniciar Votação na Tela de Todos</>
                        )}
                      </button>
                    )}
                  </div>
                )
              })}
            </div>
          )}

          {/* TAB: CHAT */}
          {activeTab === 'chat' && (
            <div className="flex flex-col flex-1 animate-in fade-in slide-in-from-right-4 duration-300 relative min-h-0">

               {/* Chat Blocked Banner */}
               {isChatBlocked && (
                 <div className="bg-amber-50 border border-amber-200 text-amber-800 p-3 rounded-xl text-sm flex gap-3 items-center mb-4 shrink-0">
                   <MessageCircleOff size={18} className="text-amber-500 shrink-0" />
                   <span className="font-bold text-xs">Chat bloqueado — Moradores não conseguem enviar mensagens</span>
                 </div>
               )}

               <div className="flex-1 flex flex-col gap-4 overflow-y-auto pr-2 pb-6 min-h-0">
                 
                 <div className="flex justify-center my-2">
                    <span className="bg-gray-50 text-gray-400 border border-gray-100 text-[10px] font-bold uppercase tracking-wider px-3 py-1 rounded-full">
                       Sessão Iniciada às {formatTime(assembleia.created_at)}
                    </span>
                 </div>

                 {messages.length === 0 && (
                   <div className="text-center text-gray-400 mt-10 text-sm">
                     Nenhuma mensagem ainda. Seja o primeiro a falar!
                   </div>
                 )}

                 {messages.map((msg) => {
                   const isMe = msg.user_id === userId
                   
                   return (
                    <div key={msg.id} className={`flex flex-col animate-in fade-in slide-in-from-bottom-2 ${isMe ? 'self-end items-end' : 'self-start items-start'}`}>
                      <span className={`text-[10px] uppercase tracking-widest font-black mb-1 ${isMe || msg.tipo === 'sistema' || msg.is_admin ? 'text-[#FC5931] text-right' : 'text-gray-500 ml-1'}`}>
                        {msg.user_name} {msg.is_admin && <span className="opacity-50">(Admin)</span>}
                        <span className="font-medium ml-1 text-gray-400">{formatTime(msg.created_at)}</span>
                      </span>
                      <div className={`${isMe || msg.is_admin ? 'bg-[#FC5931] text-white rounded-tr-sm' : 'bg-gray-100 border border-gray-200/60 text-gray-800 rounded-tl-sm'} p-3.5 px-4 rounded-2xl w-fit max-w-[90%] text-sm shadow-sm leading-relaxed whitespace-pre-wrap`}>
                        {msg.mensagem}
                      </div>
                    </div>
                  )
                 })}
                 <div ref={messagesEndRef} />
               </div>

               {/* Chat input */}
               <form onSubmit={handleSendMessage} className="mt-auto border-t border-gray-100 pt-4 relative bg-white pb-2">
                 <input 
                   type="text" 
                   value={newMessage}
                   onChange={e => setNewMessage(e.target.value)}
                   placeholder="Envie uma mensagem (Aviso Admin)..." 
                   className="w-full bg-gray-50 hover:bg-gray-100 border border-gray-200 rounded-2xl py-4 px-5 pr-14 text-sm font-medium focus:outline-none focus:bg-white focus:border-[#FC5931] focus:ring-4 focus:ring-[#FC5931]/10 transition-all placeholder:text-gray-400" 
                 />
                 <button 
                  type="submit"
                  disabled={!newMessage.trim()}
                  title="Enviar mensagem"
                  className="absolute right-3 top-6 w-10 h-10 flex items-center justify-center bg-[#FC5931] disabled:bg-gray-300 disabled:shadow-none text-white rounded-xl hover:bg-[#e04f2c] shadow-lg shadow-[#FC5931]/20 active:scale-95 transition-all"
                >
                   <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"><path d="m22 2-7 20-4-9-9-4Z"/><path d="M22 2 11 13"/></svg>
                 </button>
               </form>
            </div>
          )}

          {/* TAB: PARTICIPANTES */}
          {activeTab === 'participantes' && (
            <div className="flex flex-col gap-3 animate-in fade-in slide-in-from-right-4 duration-300">
               {(() => {
                 const unidadesOnline = new Set(participants.filter(p => !p.is_admin && p.unitId).map(p => p.unitId)).size
                 const ausentes = Math.max(0, totalUnidades - unidadesOnline)
                 
                 return (
                   <div className="bg-gray-50/50 rounded-2xl p-4 border border-gray-100 mb-2">
                     <h4 className="text-sm font-black text-gray-800 uppercase tracking-widest mb-4 flex items-center gap-2">
                       <BarChart3 size={16} className="text-[#FC5931]" /> Painel de Engajamento
                     </h4>
                     <div className="flex flex-wrap justify-center gap-4">
                       <CircularProgress value={totalUnidades} max={totalUnidades} color="text-amber-400" label="Aptos Cadastrados" />
                       <CircularProgress value={unidadesOnline} max={totalUnidades} color="text-blue-500" label="Aptos Presentes" />
                       <CircularProgress value={unidadesVotantesCount} max={totalUnidades} color="text-emerald-500" label="Aptos que Votaram" />
                       <CircularProgress value={ausentes} max={totalUnidades} color="text-red-500" label="Aptos Ausentes" />
                     </div>
                   </div>
                 )
               })()}

               <div className="flex justify-between items-center mb-2 px-1 mt-2">
                 <h4 className="text-sm font-black text-gray-800 uppercase tracking-widest">Lista de Presença</h4>
                 <span className="bg-blue-50 text-blue-600 font-bold px-3 py-1 text-xs rounded-full border border-blue-100">{participants.length} ONLINE</span>
               </div>
               
               {participants.length === 0 && (
                 <div className="text-center text-gray-400 mt-10 text-sm border border-dashed border-gray-200 rounded-2xl py-10">
                   Nenhum participante conectado ainda.
                 </div>
               )}

               {participants.map((p) => (
                 <div key={p.user_id} className="group flex items-center gap-4 p-3.5 bg-white border border-gray-100 rounded-2xl hover:border-blue-200 hover:bg-blue-50/30 hover:shadow-sm transition-all animate-in fade-in slide-in-from-bottom-2">
                   <div className="w-11 h-11 shrink-0 rounded-full bg-linear-to-tr from-gray-100 to-white flex items-center justify-center text-gray-600 font-black border border-gray-200 shadow-inner group-hover:from-blue-100 group-hover:text-blue-600 group-hover:border-blue-200 transition-colors uppercase">
                     {p.name?.charAt(0) || '?'}
                   </div>
                   <div className="flex-1 min-w-0">
                     <p className="font-bold text-gray-900 text-sm truncate leading-tight group-hover:text-blue-900">{p.name || 'Usuário Desconhecido'}</p>
                     <p className="text-xs text-gray-500 font-medium transition-colors group-hover:text-blue-600">{p.unitId || 'Sem Unidade'}</p>
                   </div>
                   {p.is_admin ? (
                     <span className="text-[9px] font-black uppercase tracking-widest bg-orange-100 text-orange-600 px-2.5 py-1.5 rounded-lg border border-orange-200">Admin</span>
                   ) : (
                     <div title="Presente e Apto a votar" className="w-8 h-8 rounded-full bg-emerald-50 flex items-center justify-center border border-emerald-100">
                       <CheckCircle2 size={16} className="text-emerald-500" />
                     </div>
                   )}
                 </div>
               ))}
            </div>
          )}
          
        </div>
      </div>

    </div>
  )
}
