'use client'
import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import {
  ArrowLeft, ArrowRight, Check, FileText, ListOrdered,
  Settings, Eye, PlusCircle, X, Trash2, GripVertical,
  Calendar, Globe, Building2, Video, Gavel, AlertTriangle,
  Vote, Users, Info, Youtube, Radio
} from 'lucide-react'

/* ================================================================
   Types
   ================================================================ */

interface Pauta {
  id: string
  ordem: number
  titulo: string
  descricao: string
  tipo: 'votacao' | 'informativo'
  quorum_tipo: 'simples' | 'dois_tercos' | 'unanimidade'
  opcoes_voto: string[]
  resultado_visivel: boolean
  modo_resposta: 'unica' | 'multipla'
  max_escolhas: number
}

interface FormData {
  // Step 1 - Informações Básicas
  nome: string
  tipo: 'AGO' | 'AGE' | 'AGI'
  modalidade: 'online' | 'presencial' | 'hibrida'
  tipo_transmissao: 'agora' | 'youtube'
  youtube_url: string
  dt_1a_convocacao: string
  dt_2a_convocacao: string
  local_presencial: string

  // Step 2 - Pautas
  pautas: Pauta[]

  // Step 3 - Configurações
  dt_inicio_votacao: string
  dt_fim_votacao: string
  eleicao_mesa: boolean
  presidente_mesa: string
  secretario_mesa: string
  peso_voto_tipo: 'unitario' | 'fracao_ideal'
  procuracao_exige_firma: boolean
}

/* ================================================================
   Helpers
   ================================================================ */

function generateId() {
  return `pauta_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`
}

const STEP_LABELS = [
  { label: 'Informações', icon: <FileText size={16} />, desc: 'Dados da assembleia' },
  { label: 'Pautas', icon: <ListOrdered size={16} />, desc: 'Itens de deliberação' },
  { label: 'Configurações', icon: <Settings size={16} />, desc: 'Votação e mesa' },
  { label: 'Revisão', icon: <Eye size={16} />, desc: 'Confirmar e salvar' },
]

const QUORUM_LABELS: Record<string, string> = {
  simples: 'Maioria Simples',
  dois_tercos: '2/3 dos Presentes',
  unanimidade: 'Unanimidade',
}

/* ================================================================
   Component
   ================================================================ */

export default function NovaAssembleiaClient({
  condominioId,
  condoNome,
  userId,
}: {
  condominioId: string
  condoNome: string
  userId: string
  tipoEstrutura?: string
}) {
  const router = useRouter()
  const supabase = createClient()
  const [step, setStep] = useState(0)
  const [saving, setSaving] = useState(false)
  const [errors, setErrors] = useState<Record<string, string>>({})

  const [form, setForm] = useState<FormData>({
    nome: '',
    tipo: 'AGO',
    modalidade: 'online',
    tipo_transmissao: 'youtube',
    youtube_url: '',
    dt_1a_convocacao: '',
    dt_2a_convocacao: '',
    local_presencial: '',
    pautas: [],
    dt_inicio_votacao: '',
    dt_fim_votacao: '',
    eleicao_mesa: false,
    presidente_mesa: '',
    secretario_mesa: '',
    peso_voto_tipo: 'unitario',
    procuracao_exige_firma: false,
  })

  // ── Form updater ──────────────────────────────────────
  function update<K extends keyof FormData>(key: K, value: FormData[K]) {
    setForm(prev => ({ ...prev, [key]: value }))
    setErrors(prev => {
      const next = { ...prev }
      delete next[key]
      return next
    })
  }

  // ── Pauta helpers ─────────────────────────────────────
  function addPauta() {
    const newPauta: Pauta = {
      id: generateId(),
      ordem: form.pautas.length + 1,
      titulo: '',
      descricao: '',
      tipo: 'votacao',
      quorum_tipo: 'simples',
      opcoes_voto: ['A favor', 'Contra', 'Abstenção'],
      resultado_visivel: false,
      modo_resposta: 'unica',
      max_escolhas: 1,
    }
    update('pautas', [...form.pautas, newPauta])
  }

  function updatePauta(id: string, changes: Partial<Pauta>) {
    update('pautas', form.pautas.map(p =>
      p.id === id ? { ...p, ...changes } : p
    ))
  }

  function removePauta(id: string) {
    const updated = form.pautas
      .filter(p => p.id !== id)
      .map((p, i) => ({ ...p, ordem: i + 1 }))
    update('pautas', updated)
  }

  function movePauta(id: string, dir: 'up' | 'down') {
    const idx = form.pautas.findIndex(p => p.id === id)
    if (idx < 0) return
    const newIdx = dir === 'up' ? idx - 1 : idx + 1
    if (newIdx < 0 || newIdx >= form.pautas.length) return
    const arr = [...form.pautas]
    ;[arr[idx], arr[newIdx]] = [arr[newIdx], arr[idx]]
    update('pautas', arr.map((p, i) => ({ ...p, ordem: i + 1 })))
  }

  // ── Validation ────────────────────────────────────────
  function validateStep(s: number): boolean {
    const errs: Record<string, string> = {}

    if (s === 0) {
      if (!form.nome.trim()) errs.nome = 'Nome é obrigatório'
      if (!form.dt_1a_convocacao) errs.dt_1a_convocacao = 'Data da 1ª convocação é obrigatória'
      if (form.modalidade !== 'online' && !form.local_presencial.trim()) {
        errs.local_presencial = 'Local presencial é obrigatório para esta modalidade'
      }
    }

    if (s === 1) {
      if (form.pautas.length === 0) errs.pautas = 'Adicione pelo menos uma pauta'
      form.pautas.forEach((p, i) => {
        if (!p.titulo.trim()) errs[`pauta_${i}_titulo`] = `Pauta ${i + 1}: título obrigatório`
      })
    }

    if (s === 2) {
      if (!form.dt_inicio_votacao) errs.dt_inicio_votacao = 'Data de início da votação é obrigatória'
      if (!form.dt_fim_votacao) errs.dt_fim_votacao = 'Data de fim da votação é obrigatória'
      if (form.dt_inicio_votacao && form.dt_fim_votacao) {
        if (new Date(form.dt_fim_votacao) <= new Date(form.dt_inicio_votacao)) {
          errs.dt_fim_votacao = 'Fim da votação deve ser após o início'
        }
      }
      if (!form.eleicao_mesa && !form.presidente_mesa.trim()) {
        errs.presidente_mesa = 'Informe o presidente da mesa ou ative eleição'
      }
    }

    setErrors(errs)
    return Object.keys(errs).length === 0
  }

  function handleNext() {
    if (validateStep(step)) setStep(s => s + 1)
  }

  function handleBack() {
    setStep(s => s - 1)
  }

  // ── Submit ────────────────────────────────────────────
  async function handleSubmit(publishNow: boolean) {
    if (!validateStep(2)) { setStep(2); return }
    setSaving(true)

    try {
      // 1. Create assembleia
      const { data: assembleia, error } = await supabase
        .from('assembleias')
        .insert({
          condominio_id: condominioId,
          nome: form.nome.trim(),
          tipo: form.tipo,
          modalidade: form.modalidade,
          tipo_transmissao: form.tipo_transmissao,
          youtube_url: form.tipo_transmissao === 'youtube' ? form.youtube_url.trim() || null : null,
          status: publishNow ? 'agendada' : 'rascunho',
          dt_1a_convocacao: form.dt_1a_convocacao || null,
          dt_2a_convocacao: form.dt_2a_convocacao || null,
          dt_inicio_votacao: form.dt_inicio_votacao || null,
          dt_fim_votacao: form.dt_fim_votacao || null,
          local_presencial: form.local_presencial || null,
          eleicao_mesa: form.eleicao_mesa,
          presidente_mesa: form.presidente_mesa || null,
          secretario_mesa: form.secretario_mesa || null,
          peso_voto_tipo: form.peso_voto_tipo,
          procuracao_exige_firma: form.procuracao_exige_firma,
          created_by: userId,
        })
        .select()
        .single()

      if (error || !assembleia) {
        alert('Erro ao criar assembleia: ' + (error?.message ?? 'Verifique as permissões.'))
        setSaving(false)
        return
      }

      // 2. Insert pautas
      if (form.pautas.length > 0) {
        const pautasData = form.pautas.map(p => ({
          assembleia_id: assembleia.id,
          ordem: p.ordem,
          titulo: p.titulo.trim(),
          descricao: p.descricao.trim() || null,
          tipo: p.tipo,
          quorum_tipo: p.quorum_tipo,
          opcoes_voto: p.opcoes_voto,
          resultado_visivel: p.resultado_visivel,
          modo_resposta: p.modo_resposta,
          max_escolhas: p.modo_resposta === 'multipla' ? p.max_escolhas : 1,
        }))

        const { error: pautaError } = await supabase
          .from('assembleia_pautas')
          .insert(pautasData)

        if (pautaError) {
          console.error('Erro ao inserir pautas:', pautaError)
        }
      }

      // 3. Insert audit log
      await supabase.from('assembleia_audit_log').insert({
        assembleia_id: assembleia.id,
        evento: publishNow ? 'publicou' : 'criou',
        dados: { status: publishNow ? 'agendada' : 'rascunho', pautas_count: form.pautas.length },
        user_id: userId,
      })

      // 4. Redirect
      router.push(`/admin/assembleias/${assembleia.id}`)

    } catch (e) {
      alert('Erro inesperado: ' + e)
    } finally {
      setSaving(false)
    }
  }

  // ════════════════════════════════════════════════════════════
  //  RENDER
  // ════════════════════════════════════════════════════════════

  return (
    <div className="max-w-4xl mx-auto px-4 py-8">

      {/* ── HEADER ──────────────────────────────────────── */}
      <div className="flex items-center gap-3 mb-8">
        <button
          onClick={() => router.push('/admin/assembleias')}
          className="p-2 rounded-lg hover:bg-gray-100 transition-colors"
        >
          <ArrowLeft size={20} className="text-gray-600" />
        </button>
        <div>
          <h1 className="text-2xl font-bold text-gray-800 flex items-center gap-3">
            <Gavel size={24} className="text-[#FC5931]" />
            Nova Assembleia
          </h1>
          <p className="text-sm text-gray-500">{condoNome}</p>
        </div>
      </div>

      {/* ── STEPPER ─────────────────────────────────────── */}
      <div className="flex items-center justify-between mb-8 bg-white rounded-2xl p-4 shadow-sm border border-gray-100">
        {STEP_LABELS.map((s, i) => (
          <div key={i} className="flex items-center gap-2 flex-1">
            <div
              className={`w-8 h-8 rounded-full flex items-center justify-center text-xs font-bold transition-colors ${
                i < step
                  ? 'bg-green-500 text-white'
                  : i === step
                  ? 'bg-[#FC5931] text-white shadow-lg shadow-[#FC5931]/30'
                  : 'bg-gray-100 text-gray-400'
              }`}
            >
              {i < step ? <Check size={14} /> : i + 1}
            </div>
            <div className="hidden sm:block">
              <p className={`text-xs font-semibold ${i === step ? 'text-gray-800' : 'text-gray-400'}`}>
                {s.label}
              </p>
              <p className="text-[10px] text-gray-400">{s.desc}</p>
            </div>
            {i < STEP_LABELS.length - 1 && (
              <div className={`flex-1 h-0.5 mx-2 rounded-full ${i < step ? 'bg-green-300' : 'bg-gray-200'}`} />
            )}
          </div>
        ))}
      </div>

      {/* ── STEP CONTENT ────────────────────────────────── */}
      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6 min-h-[400px]">

        {/* ═══ STEP 0: Informações Básicas ═════════════════ */}
        {step === 0 && (
          <div className="space-y-6">
            <h2 className="text-lg font-bold text-gray-800 flex items-center gap-2">
              <FileText size={20} className="text-[#FC5931]" />
              Informações Básicas
            </h2>

            {/* Nome da assembleia */}
            <div>
              <label className="block text-sm font-medium text-gray-600 mb-1">
                Nome da Assembleia *
              </label>
              <input
                type="text"
                value={form.nome}
                onChange={e => update('nome', e.target.value)}
                placeholder="Ex: Assembleia Geral Ordinária 2026"
                className={`w-full px-4 py-3 rounded-xl border ${errors.nome ? 'border-red-300 ring-2 ring-red-100' : 'border-gray-200'} focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] outline-none text-sm`}
              />
              {errors.nome && <p className="text-xs text-red-500 mt-1">{errors.nome}</p>}
            </div>

            {/* Tipo */}
            <div>
              <label className="block text-sm font-medium text-gray-600 mb-2">Tipo *</label>
              <div className="flex gap-3">
                {[
                  { value: 'AGO', label: 'AGO', desc: 'Assembleia Geral Ordinária' },
                  { value: 'AGE', label: 'AGE', desc: 'Assembleia Geral Extraordinária' },
                  { value: 'AGI', label: 'AGI', desc: 'Assembleia Geral de Instalação' },
                ].map(t => (
                  <label
                    key={t.value}
                    className={`flex-1 p-4 rounded-xl border-2 cursor-pointer transition-all ${
                      form.tipo === t.value
                        ? 'border-[#FC5931] bg-[#FC5931]/5'
                        : 'border-gray-200 hover:border-gray-300'
                    }`}
                  >
                    <input
                      type="radio"
                      name="tipo"
                      checked={form.tipo === t.value}
                      onChange={() => update('tipo', t.value as 'AGO' | 'AGE')}
                      className="sr-only"
                    />
                    <p className="text-sm font-semibold text-gray-800">{t.value}</p>
                    <p className="text-xs text-gray-500 mt-1">{t.desc}</p>
                  </label>
                ))}
              </div>
            </div>

            {/* Modalidade */}
            <div>
              <label className="block text-sm font-medium text-gray-600 mb-2">Modalidade *</label>
              <div className="flex gap-3">
                {[
                  { value: 'online', label: 'Online', icon: <Globe size={18} />, desc: 'Totalmente virtual' },
                  { value: 'presencial', label: 'Presencial', icon: <Building2 size={18} />, desc: 'No condomínio' },
                  { value: 'hibrida', label: 'Híbrida', icon: <Video size={18} />, desc: 'Online + presencial' },
                ].map(m => (
                  <label
                    key={m.value}
                    className={`flex-1 p-4 rounded-xl border-2 cursor-pointer transition-all text-center ${
                      form.modalidade === m.value
                        ? 'border-[#FC5931] bg-[#FC5931]/5'
                        : 'border-gray-200 hover:border-gray-300'
                    }`}
                  >
                    <input
                      type="radio"
                      name="modalidade"
                      checked={form.modalidade === m.value}
                      onChange={() => update('modalidade', m.value as FormData['modalidade'])}
                      className="sr-only"
                    />
                    <div className="flex flex-col items-center gap-1">
                      <span className={form.modalidade === m.value ? 'text-[#FC5931]' : 'text-gray-400'}>{m.icon}</span>
                      <p className="text-sm font-semibold text-gray-800">{m.label}</p>
                      <p className="text-[10px] text-gray-400">{m.desc}</p>
                    </div>
                  </label>
                ))}
              </div>
            </div>

            {/* Datas de convocação */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-600 mb-1">
                  Data 1ª Convocação *
                </label>
                <input
                  type="datetime-local"
                  value={form.dt_1a_convocacao}
                  onChange={e => update('dt_1a_convocacao', e.target.value)}
                  className={`w-full px-4 py-3 rounded-xl border ${errors.dt_1a_convocacao ? 'border-red-300' : 'border-gray-200'} focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] outline-none text-sm`}
                />
                {errors.dt_1a_convocacao && <p className="text-xs text-red-500 mt-1">{errors.dt_1a_convocacao}</p>}
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-600 mb-1">
                  Data 2ª Convocação <span className="text-gray-400">(opcional)</span>
                </label>
                <input
                  type="datetime-local"
                  value={form.dt_2a_convocacao}
                  onChange={e => update('dt_2a_convocacao', e.target.value)}
                  className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] outline-none text-sm"
                />
              </div>
            </div>

            {/* Local presencial */}
            {form.modalidade !== 'online' && (
              <div>
                <label className="block text-sm font-medium text-gray-600 mb-1">
                  Local Presencial *
                </label>
                <input
                  type="text"
                  value={form.local_presencial}
                  onChange={e => update('local_presencial', e.target.value)}
                  placeholder="Ex: Salão de Festas do Condomínio"
                  className={`w-full px-4 py-3 rounded-xl border ${errors.local_presencial ? 'border-red-300' : 'border-gray-200'} focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] outline-none text-sm`}
                />
                {errors.local_presencial && <p className="text-xs text-red-500 mt-1">{errors.local_presencial}</p>}
              </div>
            )}

            {/* ── Tipo de Transmissão ── */}
            <div>
              <label className="block text-sm font-medium text-gray-600 mb-2">
                Transmissão de Vídeo *
              </label>
              <div className="flex gap-3">
                {[
                  { value: 'youtube', label: 'YouTube Live', icon: <Youtube size={18} />, desc: '✅ Gratuito · Ilimitado', badge: 'GRÁTIS', badgeColor: 'bg-green-100 text-green-700' },
                  { value: 'agora', label: 'Agora.io (Direto)', icon: <Radio size={18} />, desc: '💰 Pago · Até 20 pessoas', badge: 'PAGO', badgeColor: 'bg-amber-100 text-amber-700' },
                ].map(t => (
                  <label
                    key={t.value}
                    className={`flex-1 p-4 rounded-xl border-2 cursor-pointer transition-all ${
                      form.tipo_transmissao === t.value
                        ? 'border-[#FC5931] bg-[#FC5931]/5'
                        : 'border-gray-200 hover:border-gray-300'
                    }`}
                  >
                    <input
                      type="radio"
                      name="tipo_transmissao"
                      checked={form.tipo_transmissao === t.value}
                      onChange={() => update('tipo_transmissao', t.value as FormData['tipo_transmissao'])}
                      className="sr-only"
                    />
                    <div className="flex flex-col items-center gap-1.5 text-center">
                      <span className={form.tipo_transmissao === t.value ? 'text-[#FC5931]' : 'text-gray-400'}>{t.icon}</span>
                      <p className="text-sm font-semibold text-gray-800">{t.label}</p>
                      <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${t.badgeColor}`}>
                        {t.badge}
                      </span>
                      <p className="text-[10px] text-gray-400">{t.desc}</p>
                    </div>
                  </label>
                ))}
              </div>

              {/* YouTube instructions */}
              {form.tipo_transmissao === 'youtube' && (
                <div className="mt-4 space-y-3">
                  <div className="flex items-start gap-2 p-3 bg-green-50 rounded-xl text-xs text-green-700">
                    <Info size={16} className="mt-0.5 flex-shrink-0" />
                    <div>
                      <p className="font-semibold">Como usar o YouTube Live:</p>
                      <ol className="mt-1 ml-3 space-y-0.5 list-decimal">
                        <li>Acesse <strong>youtube.com/live_dashboard</strong> no seu navegador</li>
                        <li>Crie uma transmissão ao vivo como <strong>&quot;Não Listado&quot;</strong></li>
                        <li>Cole o link da live aqui abaixo (pode adicionar depois)</li>
                        <li>O vídeo ficará acessível <strong>somente dentro do app</strong></li>
                      </ol>
                    </div>
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-600 mb-1">
                      Link do YouTube Live <span className="text-gray-400">(pode adicionar depois)</span>
                    </label>
                    <input
                      type="url"
                      value={form.youtube_url}
                      onChange={e => update('youtube_url', e.target.value)}
                      placeholder="https://www.youtube.com/watch?v=... ou https://youtu.be/..."
                      className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] outline-none text-sm"
                    />
                  </div>
                </div>
              )}

              {/* Agora warning */}
              {form.tipo_transmissao === 'agora' && (
                <div className="mt-3 flex items-start gap-2 p-3 bg-amber-50 rounded-xl text-xs text-amber-700">
                  <AlertTriangle size={16} className="mt-0.5 flex-shrink-0" />
                  <div>
                    <p className="font-semibold">Atenção: Custo por uso</p>
                    <p className="mt-0.5">O Agora.io cobra por minuto de cada participante. Recomendado para assembleias pequenas (até 20 pessoas). Para assembleias maiores, use o YouTube Live (gratuito).</p>
                  </div>
                </div>
              )}
            </div>
          </div>
        )}

        {/* ═══ STEP 1: Pautas ══════════════════════════════ */}
        {step === 1 && (
          <div className="space-y-6">
            <div className="flex items-center justify-between">
              <h2 className="text-lg font-bold text-gray-800 flex items-center gap-2">
                <ListOrdered size={20} className="text-[#FC5931]" />
                Pautas da Assembleia
              </h2>
              <button
                onClick={addPauta}
                className="flex items-center gap-2 px-4 py-2 bg-[#FC5931] text-white rounded-xl text-sm font-medium hover:bg-[#e04a2a] transition-colors"
              >
                <PlusCircle size={16} />
                Adicionar Pauta
              </button>
            </div>

            {errors.pautas && (
              <div className="flex items-center gap-2 p-3 bg-red-50 rounded-xl text-red-600 text-sm">
                <AlertTriangle size={16} />
                {errors.pautas}
              </div>
            )}

            {form.pautas.length === 0 ? (
              <div className="text-center py-12 text-gray-400">
                <ListOrdered size={48} className="mx-auto mb-3 opacity-30" />
                <p className="text-sm">Nenhuma pauta adicionada.</p>
                <p className="text-xs mt-1">Clique em &quot;Adicionar Pauta&quot; para começar.</p>
              </div>
            ) : (
              <div className="space-y-4">
                {form.pautas.map((pauta, idx) => (
                  <div
                    key={pauta.id}
                    className="bg-gray-50 rounded-xl p-5 border border-gray-100 space-y-4"
                  >
                    {/* Pauta header */}
                    <div className="flex items-center gap-3">
                      <div className="flex flex-col gap-0.5 text-gray-300">
                        <button
                          onClick={() => movePauta(pauta.id, 'up')}
                          disabled={idx === 0}
                          className="hover:text-gray-500 disabled:opacity-30"
                          title="Mover para cima"
                        >
                          <GripVertical size={14} />
                        </button>
                      </div>
                      <span className="w-7 h-7 rounded-full bg-[#FC5931] text-white text-xs font-bold flex items-center justify-center">
                        {pauta.ordem}
                      </span>
                      <input
                        type="text"
                        value={pauta.titulo}
                        onChange={e => updatePauta(pauta.id, { titulo: e.target.value })}
                        placeholder="Título da pauta"
                        className={`flex-1 px-3 py-2 rounded-lg border ${errors[`pauta_${idx}_titulo`] ? 'border-red-300' : 'border-gray-200'} focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] outline-none text-sm font-medium`}
                      />
                      <button
                        onClick={() => removePauta(pauta.id)}
                        className="p-2 rounded-lg text-red-400 hover:bg-red-50 hover:text-red-600 transition-colors"
                        title="Remover pauta"
                      >
                        <Trash2 size={16} />
                      </button>
                    </div>
                    {errors[`pauta_${idx}_titulo`] && (
                      <p className="text-xs text-red-500 ml-12">{errors[`pauta_${idx}_titulo`]}</p>
                    )}

                    {/* Descrição */}
                    <textarea
                      value={pauta.descricao}
                      onChange={e => updatePauta(pauta.id, { descricao: e.target.value })}
                      placeholder="Descrição detalhada (opcional)"
                      rows={2}
                      className="w-full px-3 py-2 rounded-lg border border-gray-200 focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] outline-none text-sm resize-none"
                    />

                    {/* Tipo + Quórum */}
                    <div className="flex gap-4 flex-wrap">
                      <div>
                        <label className="block text-xs font-medium text-gray-500 mb-1">Tipo da Pauta</label>
                        <select
                          value={pauta.tipo}
                          onChange={e => updatePauta(pauta.id, { tipo: e.target.value as 'votacao' | 'informativo' })}
                          className="px-3 py-2 rounded-lg border border-gray-200 text-sm outline-none"
                        >
                          <option value="votacao">🗳️ Votação</option>
                          <option value="informativo">ℹ️ Informativo</option>
                        </select>
                      </div>

                      {pauta.tipo === 'votacao' && (
                        <>
                          <div>
                            <label className="block text-xs font-medium text-gray-500 mb-1">Quórum</label>
                            <select
                              value={pauta.quorum_tipo}
                              onChange={e => updatePauta(pauta.id, { quorum_tipo: e.target.value as Pauta['quorum_tipo'] })}
                              className="px-3 py-2 rounded-lg border border-gray-200 text-sm outline-none"
                              title="Tipo de quórum"
                            >
                              <option value="simples">Maioria Simples</option>
                              <option value="dois_tercos">2/3 dos Presentes</option>
                              <option value="unanimidade">Unanimidade</option>
                            </select>
                          </div>

                          <div>
                            <label className="block text-xs font-medium text-gray-500 mb-1">Modo de Resposta</label>
                            <select
                              value={pauta.modo_resposta}
                              onChange={e => {
                                const modo = e.target.value as 'unica' | 'multipla'
                                updatePauta(pauta.id, {
                                  modo_resposta: modo,
                                  opcoes_voto: modo === 'unica'
                                    ? ['A favor', 'Contra', 'Abstenção']
                                    : [],
                                  max_escolhas: modo === 'unica' ? 1 : 2,
                                })
                              }}
                              className="px-3 py-2 rounded-lg border border-gray-200 text-sm outline-none"
                              title="Modo de resposta"
                            >
                              <option value="unica">🔘 Resposta Única</option>
                              <option value="multipla">☑️ Múltipla Escolha</option>
                            </select>
                          </div>

                          {pauta.modo_resposta === 'multipla' && (
                            <div>
                              <label className="block text-xs font-medium text-gray-500 mb-1">Máx. Escolhas</label>
                              <input
                                type="number"
                                min={1}
                                max={pauta.opcoes_voto.length}
                                value={pauta.max_escolhas}
                                onChange={e => updatePauta(pauta.id, { max_escolhas: parseInt(e.target.value) || 1 })}
                                className="w-20 px-3 py-2 rounded-lg border border-gray-200 text-sm outline-none text-center"
                                title="Quantidade máxima de escolhas"
                              />
                            </div>
                          )}

                          <div className="flex items-center gap-2 mt-5">
                            <input
                              type="checkbox"
                              id={`resultado_${pauta.id}`}
                              checked={pauta.resultado_visivel}
                              onChange={e => updatePauta(pauta.id, { resultado_visivel: e.target.checked })}
                              className="w-4 h-4 text-[#FC5931] rounded"
                            />
                            <label htmlFor={`resultado_${pauta.id}`} className="text-xs text-gray-600">
                              Exibir resultado durante votação
                            </label>
                          </div>
                        </>
                      )}
                    </div>

                    {/* Opções de voto */}
                    {pauta.tipo === 'votacao' && (
                      <div>
                        <label className="block text-xs font-medium text-gray-500 mb-2">
                          Opções de Voto
                          {pauta.modo_resposta === 'multipla' && pauta.opcoes_voto.length > 0 && (
                            <span className="ml-2 text-blue-500 font-normal">
                              ({pauta.opcoes_voto.length} opções)
                            </span>
                          )}
                        </label>

                        {/* Resposta Única: badges fixos */}
                        {pauta.modo_resposta === 'unica' && (
                          <div className="flex flex-wrap gap-2">
                            {pauta.opcoes_voto.map((op, opIdx) => (
                              <span
                                key={opIdx}
                                className="inline-flex items-center gap-1 px-3 py-1.5 bg-green-50 rounded-lg border border-green-200 text-xs font-medium text-green-700"
                              >
                                🔘 {op}
                              </span>
                            ))}
                          </div>
                        )}

                        {/* Múltipla Escolha: input para adicionar opções */}
                        {pauta.modo_resposta === 'multipla' && (
                          <div className="space-y-3">
                            {/* Dica */}
                            <div className="flex items-start gap-2 p-2.5 bg-amber-50 rounded-lg text-xs text-amber-700">
                              <Info size={14} className="mt-0.5 shrink-0" />
                              <span>Digite as opções que os moradores poderão escolher. Cada morador poderá selecionar até <strong>{pauta.max_escolhas}</strong> opção(ões).</span>
                            </div>

                            {/* Lista de opções adicionadas */}
                            {pauta.opcoes_voto.length > 0 && (
                              <div className="flex flex-wrap gap-2">
                                {pauta.opcoes_voto.map((op, opIdx) => (
                                  <span
                                    key={opIdx}
                                    className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-blue-50 rounded-lg border border-blue-200 text-xs font-medium text-blue-700"
                                  >
                                    ☑️ {op}
                                    <button
                                      onClick={() => {
                                        const newOps = pauta.opcoes_voto.filter((_, i) => i !== opIdx)
                                        updatePauta(pauta.id, {
                                          opcoes_voto: newOps,
                                          max_escolhas: Math.min(pauta.max_escolhas, Math.max(newOps.length, 1)),
                                        })
                                      }}
                                      className="text-blue-400 hover:text-red-500 transition-colors"
                                      title={`Remover "${op}"`}
                                    >
                                      <X size={12} />
                                    </button>
                                  </span>
                                ))}
                              </div>
                            )}

                            {/* Input para nova opção */}
                            <div className="flex gap-2">
                              <input
                                type="text"
                                placeholder="Ex: Churrasqueira, Pintura, etc."
                                className="flex-1 px-3 py-2 rounded-lg border border-gray-200 text-sm outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400"
                                onKeyDown={e => {
                                  if (e.key === 'Enter') {
                                    e.preventDefault()
                                    const input = e.currentTarget
                                    const val = input.value.trim()
                                    if (val && !pauta.opcoes_voto.includes(val)) {
                                      updatePauta(pauta.id, {
                                        opcoes_voto: [...pauta.opcoes_voto, val],
                                      })
                                      input.value = ''
                                    }
                                  }
                                }}
                                id={`add_opcao_${pauta.id}`}
                              />
                              <button
                                type="button"
                                onClick={() => {
                                  const input = document.getElementById(`add_opcao_${pauta.id}`) as HTMLInputElement
                                  const val = input?.value.trim()
                                  if (val && !pauta.opcoes_voto.includes(val)) {
                                    updatePauta(pauta.id, {
                                      opcoes_voto: [...pauta.opcoes_voto, val],
                                    })
                                    input.value = ''
                                    input.focus()
                                  }
                                }}
                                className="px-4 py-2 bg-blue-500 text-white rounded-lg text-sm font-medium hover:bg-blue-600 transition-colors flex items-center gap-1.5"
                              >
                                <PlusCircle size={14} />
                                Adicionar
                              </button>
                            </div>
                          </div>
                        )}
                      </div>
                    )}
                  </div>
                ))}
              </div>
            )}
          </div>
        )}

        {/* ═══ STEP 2: Configurações ═══════════════════════ */}
        {step === 2 && (
          <div className="space-y-6">
            <h2 className="text-lg font-bold text-gray-800 flex items-center gap-2">
              <Settings size={20} className="text-[#FC5931]" />
              Configurações de Votação e Mesa
            </h2>

            {/* Período de votação */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-600 mb-1">
                  Início da Votação *
                </label>
                <input
                  type="datetime-local"
                  value={form.dt_inicio_votacao}
                  onChange={e => update('dt_inicio_votacao', e.target.value)}
                  className={`w-full px-4 py-3 rounded-xl border ${errors.dt_inicio_votacao ? 'border-red-300' : 'border-gray-200'} focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] outline-none text-sm`}
                />
                {errors.dt_inicio_votacao && <p className="text-xs text-red-500 mt-1">{errors.dt_inicio_votacao}</p>}
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-600 mb-1">
                  Fim da Votação *
                </label>
                <input
                  type="datetime-local"
                  value={form.dt_fim_votacao}
                  onChange={e => update('dt_fim_votacao', e.target.value)}
                  className={`w-full px-4 py-3 rounded-xl border ${errors.dt_fim_votacao ? 'border-red-300' : 'border-gray-200'} focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] outline-none text-sm`}
                />
                {errors.dt_fim_votacao && <p className="text-xs text-red-500 mt-1">{errors.dt_fim_votacao}</p>}
              </div>
            </div>

            <div className="flex items-start gap-3 p-3 bg-blue-50 rounded-xl text-xs text-blue-700">
              <Info size={16} className="mt-0.5 flex-shrink-0" />
              <p>A votação pode ser aberta durante ou após a sessão ao vivo, estendendo-se por até 3 dias para permitir que moradores ausentes votem.</p>
            </div>

            {/* Mesa diretora */}
            <div className="border-t border-gray-100 pt-6 space-y-4">
              <h3 className="text-sm font-bold text-gray-700 flex items-center gap-2">
                <Users size={16} /> Mesa Diretora
              </h3>

              <div className="flex items-center gap-3">
                <input
                  type="checkbox"
                  id="eleicao_mesa"
                  checked={form.eleicao_mesa}
                  onChange={e => update('eleicao_mesa', e.target.checked)}
                  className="w-4 h-4 text-[#FC5931] rounded"
                />
                <label htmlFor="eleicao_mesa" className="text-sm text-gray-700">
                  Eleger mesa durante a assembleia (Presidente + Secretário serão votados)
                </label>
              </div>

              {!form.eleicao_mesa && (
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-600 mb-1">
                      Presidente da Mesa *
                    </label>
                    <input
                      type="text"
                      value={form.presidente_mesa}
                      onChange={e => update('presidente_mesa', e.target.value)}
                      placeholder="Nome do presidente"
                      className={`w-full px-4 py-3 rounded-xl border ${errors.presidente_mesa ? 'border-red-300' : 'border-gray-200'} focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] outline-none text-sm`}
                    />
                    {errors.presidente_mesa && <p className="text-xs text-red-500 mt-1">{errors.presidente_mesa}</p>}
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-600 mb-1">
                      Secretário(a) <span className="text-gray-400">(opcional)</span>
                    </label>
                    <input
                      type="text"
                      value={form.secretario_mesa}
                      onChange={e => update('secretario_mesa', e.target.value)}
                      placeholder="Nome do secretário"
                      className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] outline-none text-sm"
                    />
                  </div>
                </div>
              )}
            </div>

            {/* Peso do voto + Procuração */}
            <div className="border-t border-gray-100 pt-6 space-y-4">
              <h3 className="text-sm font-bold text-gray-700 flex items-center gap-2">
                <Vote size={16} /> Configurações de Voto
              </h3>

              <div>
                <label className="block text-sm font-medium text-gray-600 mb-2">Peso do Voto</label>
                <div className="flex gap-4">
                  {[
                    { value: 'unitario', label: '1 unidade = 1 voto', desc: 'Todos votam com peso igual' },
                    { value: 'fracao_ideal', label: 'Fração Ideal', desc: 'Peso proporcional à fração ideal' },
                  ].map(p => (
                    <label
                      key={p.value}
                      className={`flex-1 p-3 rounded-xl border-2 cursor-pointer transition-all ${
                        form.peso_voto_tipo === p.value
                          ? 'border-[#FC5931] bg-[#FC5931]/5'
                          : 'border-gray-200'
                      }`}
                    >
                      <input
                        type="radio"
                        name="peso_voto"
                        checked={form.peso_voto_tipo === p.value}
                        onChange={() => update('peso_voto_tipo', p.value as FormData['peso_voto_tipo'])}
                        className="sr-only"
                      />
                      <p className="text-sm font-medium text-gray-800">{p.label}</p>
                      <p className="text-xs text-gray-400 mt-1">{p.desc}</p>
                    </label>
                  ))}
                </div>
              </div>

              <div className="flex items-center gap-3">
                <input
                  type="checkbox"
                  id="procuracao_firma"
                  checked={form.procuracao_exige_firma}
                  onChange={e => update('procuracao_exige_firma', e.target.checked)}
                  className="w-4 h-4 text-[#FC5931] rounded"
                />
                <label htmlFor="procuracao_firma" className="text-sm text-gray-700">
                  Exigir firma reconhecida na procuração
                </label>
              </div>
            </div>
          </div>
        )}

        {/* ═══ STEP 3: Revisão ═════════════════════════════ */}
        {step === 3 && (
          <div className="space-y-6">
            <h2 className="text-lg font-bold text-gray-800 flex items-center gap-2">
              <Eye size={20} className="text-[#FC5931]" />
              Revisão da Assembleia
            </h2>

            {/* Info summary */}
            <div className="bg-gray-50 rounded-xl p-5 space-y-3">
              <h3 className="text-sm font-bold text-gray-700">📋 Informações Gerais</h3>
              <div className="grid grid-cols-2 gap-y-2 text-sm">
                <span className="text-gray-500">Nome:</span>
                <span className="text-gray-800 font-medium">{form.nome}</span>

                <span className="text-gray-500">Tipo:</span>
                <span className="text-gray-800">{form.tipo}</span>

                <span className="text-gray-500">Modalidade:</span>
                <span className="text-gray-800 capitalize">{form.modalidade}</span>

                <span className="text-gray-500">Transmissão:</span>
                <span className="text-gray-800">
                  {form.tipo_transmissao === 'youtube'
                    ? '📺 YouTube Live (Gratuito)'
                    : '📡 Agora.io (Pago)'}
                </span>

                <span className="text-gray-500">1ª Convocação:</span>
                <span className="text-gray-800">{form.dt_1a_convocacao ? new Date(form.dt_1a_convocacao).toLocaleString('pt-BR') : '—'}</span>

                {form.dt_2a_convocacao && (
                  <>
                    <span className="text-gray-500">2ª Convocação:</span>
                    <span className="text-gray-800">{new Date(form.dt_2a_convocacao).toLocaleString('pt-BR')}</span>
                  </>
                )}

                {form.local_presencial && (
                  <>
                    <span className="text-gray-500">Local:</span>
                    <span className="text-gray-800">{form.local_presencial}</span>
                  </>
                )}
              </div>
            </div>

            {/* Pautas summary */}
            <div className="bg-gray-50 rounded-xl p-5 space-y-3">
              <h3 className="text-sm font-bold text-gray-700">📝 Pautas ({form.pautas.length})</h3>
              {form.pautas.map(p => (
                <div key={p.id} className="flex items-start gap-3 bg-white rounded-lg p-3 border border-gray-100">
                  <span className="w-6 h-6 rounded-full bg-[#FC5931] text-white text-xs font-bold flex items-center justify-center flex-shrink-0">
                    {p.ordem}
                  </span>
                  <div className="flex-1">
                    <p className="text-sm font-medium text-gray-800">{p.titulo}</p>
                    <p className="text-xs text-gray-500 mt-0.5">
                      {p.tipo === 'votacao'
                        ? `🗳️ Votação · ${QUORUM_LABELS[p.quorum_tipo]} · ${p.opcoes_voto.join(', ')}`
                        : 'ℹ️ Informativo'}
                    </p>
                  </div>
                </div>
              ))}
            </div>

            {/* Votação summary */}
            <div className="bg-gray-50 rounded-xl p-5 space-y-3">
              <h3 className="text-sm font-bold text-gray-700">⚙️ Configurações</h3>
              <div className="grid grid-cols-2 gap-y-2 text-sm">
                <span className="text-gray-500">Votação:</span>
                <span className="text-gray-800">
                  {form.dt_inicio_votacao ? new Date(form.dt_inicio_votacao).toLocaleString('pt-BR') : '—'}
                  {' → '}
                  {form.dt_fim_votacao ? new Date(form.dt_fim_votacao).toLocaleString('pt-BR') : '—'}
                </span>

                <span className="text-gray-500">Mesa:</span>
                <span className="text-gray-800">
                  {form.eleicao_mesa
                    ? 'Eleição durante assembleia'
                    : `${form.presidente_mesa}${form.secretario_mesa ? ` / ${form.secretario_mesa}` : ''}`}
                </span>

                <span className="text-gray-500">Peso do Voto:</span>
                <span className="text-gray-800">{form.peso_voto_tipo === 'unitario' ? '1 unidade = 1 voto' : 'Fração Ideal'}</span>

                <span className="text-gray-500">Procuração:</span>
                <span className="text-gray-800">{form.procuracao_exige_firma ? 'Exige firma reconhecida' : 'Simples (sem firma)'}</span>
              </div>
            </div>

            {/* Actions */}
            <div className="flex gap-4 pt-4">
              <button
                onClick={() => handleSubmit(false)}
                disabled={saving}
                className="flex-1 py-3 bg-gray-100 text-gray-700 rounded-xl font-semibold hover:bg-gray-200 transition-colors text-sm disabled:opacity-40"
              >
                {saving ? 'Salvando...' : '💾 Salvar como Rascunho'}
              </button>
              <button
                onClick={() => handleSubmit(true)}
                disabled={saving}
                className="flex-1 py-3 bg-[#FC5931] text-white rounded-xl font-semibold hover:bg-[#e04a2a] transition-all shadow-lg shadow-[#FC5931]/20 text-sm disabled:opacity-40"
              >
                {saving ? 'Publicando...' : '🚀 Publicar Assembleia'}
              </button>
            </div>
          </div>
        )}
      </div>

      {/* ── NAVIGATION BUTTONS ──────────────────────────── */}
      {step < 3 && (
        <div className="flex justify-between mt-6">
          <button
            onClick={handleBack}
            disabled={step === 0}
            className="flex items-center gap-2 px-6 py-2.5 text-gray-600 hover:bg-gray-100 rounded-xl transition-colors text-sm font-medium disabled:opacity-30"
          >
            <ArrowLeft size={16} />
            Voltar
          </button>
          <button
            onClick={handleNext}
            className="flex items-center gap-2 px-6 py-2.5 bg-[#FC5931] text-white rounded-xl font-medium hover:bg-[#e04a2a] transition-all shadow-lg shadow-[#FC5931]/20 text-sm"
          >
            Próximo
            <ArrowRight size={16} />
          </button>
        </div>
      )}
    </div>
  )
}
