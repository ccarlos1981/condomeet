'use client'

import { useState, useEffect, useRef } from 'react'
import { createClient } from '@/lib/supabase/client'

interface Condominio { id: string; nome: string }
interface PropagandaFoto { id: string; foto_url: string; ordem: number }
interface Propaganda {
  id: string
  condominio_id: string
  nome: string
  especialidade: string | null
  endereco: string | null
  whatsapp: string | null
  celular: string | null
  site: string | null
  email: string | null
  logo_url: string | null
  instagram: string | null
  facebook: string | null
  youtube: string | null
  tiktok: string | null
  twitter: string | null
  linkedin: string | null
  ordem: number
  ativo: boolean
  fotos?: PropagandaFoto[]
}

const EMPTY_FORM: Omit<Propaganda, 'id' | 'fotos'> = {
  condominio_id: '',
  nome: '',
  especialidade: '',
  endereco: '',
  whatsapp: '',
  celular: '',
  site: '',
  email: '',
  logo_url: '',
  instagram: '',
  facebook: '',
  youtube: '',
  tiktok: '',
  twitter: '',
  linkedin: '',
  ordem: 0,
  ativo: true,
}

export default function PropagandaClient({ condominios }: { condominios: Condominio[]; superAdminEmail: string }) {
  const supabase = createClient()
  const [selectedCondo, setSelectedCondo] = useState(condominios[0]?.id ?? '')
  const [list, setList] = useState<Propaganda[]>([])
  const [loading, setLoading] = useState(false)
  const [showForm, setShowForm] = useState(false)
  const [editing, setEditing] = useState<Propaganda | null>(null)
  const [form, setForm] = useState(EMPTY_FORM)
  const [saving, setSaving] = useState(false)
  const [uploadingLogo, setUploadingLogo] = useState(false)
  const [uploadingFoto, setUploadingFoto] = useState(false)
  const [fotos, setFotos] = useState<PropagandaFoto[]>([])
  const logoInputRef = useRef<HTMLInputElement>(null)
  const fotoInputRef = useRef<HTMLInputElement>(null)

  // ── "Como começar" guide state ────────────────────
  const [showGuide, setShowGuide] = useState(() => {
    if (typeof window !== 'undefined') {
      return localStorage.getItem('propaganda_admin_guide_dismissed') !== 'true'
    }
    return true
  })

  const dismissGuide = () => {
    setShowGuide(false)
    localStorage.setItem('propaganda_admin_guide_dismissed', 'true')
  }

  const reopenGuide = () => {
    setShowGuide(true)
    localStorage.removeItem('propaganda_admin_guide_dismissed')
  }

  const guideSteps = [
    { num: 1, title: 'Selecione o condomínio', desc: 'Escolha o condomínio para gerenciar', done: !!selectedCondo },
    { num: 2, title: 'Crie um anunciante', desc: 'Clique em "+ Novo Anunciante" para começar', done: list.length > 0 },
    { num: 3, title: 'Adicione logo e fotos', desc: 'Envie a identidade visual da empresa', done: list.some(p => !!p.logo_url) },
    { num: 4, title: 'Ative o anúncio', desc: 'O anúncio aparecerá no app para os moradores', done: list.some(p => p.ativo) },
  ]

  const loadList = async () => {
    setLoading(true)
    const { data } = await supabase
      .from('propaganda')
      .select('*, propaganda_fotos(*)')
      .eq('condominio_id', selectedCondo)
      .order('ordem')
    setList((data ?? []).map(d => ({ ...d, fotos: d.propaganda_fotos ?? [] })))
    setLoading(false)
  }

  // eslint-disable-next-line react-hooks/exhaustive-deps
  useEffect(() => { if (selectedCondo) { ;(async () => { await loadList() })() } }, [selectedCondo])

  function openNew() {
    setEditing(null)
    setForm({ ...EMPTY_FORM, condominio_id: selectedCondo })
    setFotos([])
    setShowForm(true)
  }

  function openEdit(p: Propaganda) {
    setEditing(p)
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    const { fotos: _fotos, ...rest } = p
    setForm(rest)
    setFotos(p.fotos ?? [])
    setShowForm(true)
  }

  async function uploadFile(file: File, folder: string): Promise<string | null> {
    const ext = file.name.split('.').pop()
    const path = `${folder}/${Date.now()}.${ext}`
    const { error } = await supabase.storage.from('propaganda').upload(path, file, { upsert: true })
    if (error) { alert('Erro no upload: ' + error.message); return null }
    const { data } = supabase.storage.from('propaganda').getPublicUrl(path)
    return data.publicUrl
  }

  async function handleLogoUpload(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    if (!file) return
    setUploadingLogo(true)
    const url = await uploadFile(file, 'logos')
    if (url) setForm(f => ({ ...f, logo_url: url }))
    setUploadingLogo(false)
  }

  async function handleFotoUpload(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    if (!file) return
    setUploadingFoto(true)
    const url = await uploadFile(file, 'fotos')
    if (url) {
      if (editing) {
        // save immediately
        const { data } = await supabase.from('propaganda_fotos').insert({
          propaganda_id: editing.id, foto_url: url, ordem: fotos.length
        }).select().single()
        if (data) setFotos(f => [...f, data])
      } else {
        setFotos(f => [...f, { id: crypto.randomUUID(), foto_url: url, ordem: f.length }])
      }
    }
    setUploadingFoto(false)
  }

  async function deleteFoto(foto: PropagandaFoto) {
    if (editing) {
      await supabase.from('propaganda_fotos').delete().eq('id', foto.id)
    }
    setFotos(f => f.filter(x => x.id !== foto.id))
  }

  async function handleSave() {
    if (!form.nome.trim()) { alert('Nome é obrigatório'); return }
    setSaving(true)
    if (editing) {
      // eslint-disable-next-line @typescript-eslint/no-unused-vars
      const { fotos: _f, ...update } = form as typeof form & { fotos?: unknown }
      await supabase.from('propaganda').update(update).eq('id', editing.id)
    } else {
      const { data: newP } = await supabase.from('propaganda').insert(form).select().single()
      if (newP && fotos.length > 0) {
        await supabase.from('propaganda_fotos').insert(
          fotos.map((f, i) => ({ propaganda_id: newP.id, foto_url: f.foto_url, ordem: i }))
        )
      }
    }
    setSaving(false)
    setShowForm(false)
    loadList()
  }

  async function handleDelete(id: string) {
    if (!confirm('Excluir este anunciante?')) return
    await supabase.from('propaganda').delete().eq('id', id)
    loadList()
  }

  async function toggleAtivo(p: Propaganda) {
    await supabase.from('propaganda').update({ ativo: !p.ativo }).eq('id', p.id)
    loadList()
  }

  const f = (k: keyof typeof form) => (e: React.ChangeEvent<HTMLInputElement>) =>
    setForm(prev => ({ ...prev, [k]: e.target.value }))

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-5xl mx-auto p-6">
        {/* Header */}
        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">📢 Empresas Parceiras</h1>
            <p className="text-sm text-gray-500 mt-1">Gerencie os anunciantes por condomínio</p>
          </div>
          <div className="flex items-center gap-2">
            {!showGuide && (
              <button onClick={reopenGuide}
                className="text-sm px-3 py-2 rounded-lg border border-blue-200 text-blue-600 hover:bg-blue-50 transition">
                💡 Como começar
              </button>
            )}
            <button onClick={openNew}
              className="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg font-medium transition">
              + Novo Anunciante
            </button>
          </div>
        </div>

        {/* Como começar guide */}
        {showGuide && (
          <div className="mb-6 rounded-xl border border-amber-200 bg-linear-to-r from-amber-50 to-orange-50 p-5">
            <div className="flex items-center justify-between mb-3">
              <div className="flex items-center gap-2">
                <span className="text-lg">🚀</span>
                <h3 className="font-bold text-gray-900 text-sm">Como começar</h3>
              </div>
              <button onClick={dismissGuide} className="text-gray-400 hover:text-gray-600 text-lg" title="Fechar guia">×</button>
            </div>
            <div className="space-y-2.5">
              {guideSteps.map(step => (
                <div key={step.num} className="flex items-start gap-3">
                  <div className={`w-6 h-6 rounded-full flex items-center justify-center shrink-0 text-xs font-bold ${
                    step.done ? 'bg-green-500 text-white' : 'bg-gray-200 text-gray-500'
                  }`}>
                    {step.done ? '✓' : step.num}
                  </div>
                  <div>
                    <p className={`text-sm font-medium ${step.done ? 'text-gray-400 line-through' : 'text-gray-800'}`}>{step.title}</p>
                    <p className="text-xs text-gray-400">{step.desc}</p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Condomínio selector */}
        <div className="mb-6">
          <label className="block text-sm font-medium text-gray-700 mb-1">Condomínio</label>
          <select value={selectedCondo} onChange={e => setSelectedCondo(e.target.value)} title="Selecionar condomínio"
            className="border border-gray-300 rounded-lg px-3 py-2 w-72 focus:outline-none focus:ring-2 focus:ring-blue-500">
            {condominios.map(c => <option key={c.id} value={c.id}>{c.nome}</option>)}
          </select>
        </div>

        {/* List */}
        {loading ? (
          <div className="text-center py-12 text-gray-400">Carregando...</div>
        ) : list.length === 0 ? (
          <div className="text-center py-12 text-gray-400">
            <div className="text-4xl mb-2">🏢</div>
            <p>Nenhum anunciante cadastrado neste condomínio</p>
          </div>
        ) : (
          <div className="grid gap-4">
            {list.map(p => (
              <div key={p.id} className={`bg-white rounded-xl shadow-sm border p-4 flex gap-4 items-start ${!p.ativo ? 'opacity-50' : ''}`}>
                {p.logo_url
                  ? (
                    /* eslint-disable-next-line @next/next/no-img-element */
                    <img src={p.logo_url} alt={p.nome} className="w-16 h-16 rounded-xl object-cover border" />
                  )
                  : <div className="w-16 h-16 rounded-xl bg-gray-200 flex items-center justify-center text-2xl">🏷</div>
                }
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2">
                    <h3 className="font-bold text-gray-900 truncate">{p.nome}</h3>
                    <span className={`text-xs px-2 py-0.5 rounded-full ${p.ativo ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-500'}`}>
                      {p.ativo ? 'Ativo' : 'Inativo'}
                    </span>
                    <span className="text-xs text-gray-400">Ordem: {p.ordem}</span>
                  </div>
                  {p.especialidade && <p className="text-sm text-gray-500">{p.especialidade}</p>}
                  <div className="flex gap-3 mt-1 text-xs text-gray-400 flex-wrap">
                    {p.whatsapp && <span>📱 {p.whatsapp}</span>}
                    {p.site && <span>🌐 {p.site}</span>}
                    {p.fotos && p.fotos.length > 0 && <span>🖼 {p.fotos.length} foto(s)</span>}
                  </div>
                </div>
                <div className="flex gap-2 shrink-0">
                  <button onClick={() => toggleAtivo(p)}
                    className="text-xs px-3 py-1 rounded-lg border border-gray-300 hover:bg-gray-50">
                    {p.ativo ? 'Desativar' : 'Ativar'}
                  </button>
                  <button onClick={() => openEdit(p)}
                    className="text-xs px-3 py-1 rounded-lg bg-blue-50 text-blue-600 hover:bg-blue-100">
                    Editar
                  </button>
                  <button onClick={() => handleDelete(p.id)}
                    className="text-xs px-3 py-1 rounded-lg bg-red-50 text-red-600 hover:bg-red-100">
                    Excluir
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Modal form */}
      {showForm && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl w-full max-w-2xl max-h-[90vh] overflow-y-auto">
            <div className="p-6 border-b sticky top-0 bg-white z-10 flex justify-between items-center">
              <h2 className="text-xl font-bold">{editing ? 'Editar Anunciante' : 'Novo Anunciante'}</h2>
              <button onClick={() => setShowForm(false)} className="text-gray-400 hover:text-gray-600 text-2xl">×</button>
            </div>

            <div className="p-6 space-y-4">
              {/* Logo */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Logo da empresa</label>
                <div className="flex items-center gap-4">
                  {form.logo_url
                    ? (
                      /* eslint-disable-next-line @next/next/no-img-element */
                      <img src={form.logo_url} alt="logo" className="w-20 h-20 rounded-xl object-cover border" />
                    )
                    : <div className="w-20 h-20 rounded-xl bg-gray-100 flex items-center justify-center text-3xl">🏷</div>
                  }
                  <button onClick={() => logoInputRef.current?.click()}
                    disabled={uploadingLogo}
                    className="px-4 py-2 border rounded-lg text-sm hover:bg-gray-50">
                    {uploadingLogo ? 'Enviando...' : 'Escolher logo'}
                  </button>
                  <input ref={logoInputRef} type="file" accept="image/*" className="hidden" onChange={handleLogoUpload} title="Upload logo" />
                </div>
              </div>

              {/* Dados básicos */}
              <div className="grid grid-cols-2 gap-4">
                <div className="col-span-2">
                  <label className="block text-sm font-medium text-gray-700 mb-1">Nome da marca *</label>
                  <input value={form.nome} onChange={f('nome')} placeholder="Nome da empresa"
                    className="w-full border rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Especialidade</label>
                  <input value={form.especialidade ?? ''} onChange={f('especialidade')}
                    placeholder="Ex: Planilhas financeiras"
                    className="w-full border rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Ordem no carrossel</label>
                  <input type="number" value={form.ordem} onChange={e => setForm(v => ({ ...v, ordem: +e.target.value }))} placeholder="0" title="Ordem no carrossel"
                    className="w-full border rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500" />
                </div>
                <div className="col-span-2">
                  <label className="block text-sm font-medium text-gray-700 mb-1">Endereço</label>
                  <input value={form.endereco ?? ''} onChange={f('endereco')} placeholder="Endereço completo"
                    className="w-full border rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500" />
                </div>
              </div>

              {/* Contatos */}
              <div>
                <p className="text-sm font-semibold text-gray-700 mb-2">📞 Contatos</p>
                <div className="grid grid-cols-2 gap-3">
                  {[
                    { label: 'WhatsApp', key: 'whatsapp' },
                    { label: 'Celular', key: 'celular' },
                    { label: 'Site', key: 'site' },
                    { label: 'Email', key: 'email' },
                  ].map(({ label, key }) => (
                    <div key={key}>
                      <label className="block text-xs text-gray-500 mb-1">{label}</label>
                      <input value={(form as unknown as Record<string, string>)[key] ?? ''} onChange={f(key as keyof typeof form)} placeholder={label}
                        className="w-full border rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
                    </div>
                  ))}
                </div>
              </div>

              {/* Redes sociais */}
              <div>
                <p className="text-sm font-semibold text-gray-700 mb-2">🌐 Redes Sociais</p>
                <div className="grid grid-cols-2 gap-3">
                  {[
                    { label: '📷 Instagram', key: 'instagram' },
                    { label: '👍 Facebook', key: 'facebook' },
                    { label: '▶️ YouTube', key: 'youtube' },
                    { label: '🎵 TikTok', key: 'tiktok' },
                    { label: '🐦 Twitter/X', key: 'twitter' },
                    { label: '💼 LinkedIn', key: 'linkedin' },
                  ].map(({ label, key }) => (
                    <div key={key}>
                      <label className="block text-xs text-gray-500 mb-1">{label}</label>
                      <input value={(form as unknown as Record<string, string>)[key] ?? ''} onChange={f(key as keyof typeof form)}
                        className="w-full border rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
                    </div>
                  ))}
                </div>
              </div>

              {/* Fotos do espaço */}
              <div>
                <div className="flex items-center justify-between mb-2">
                  <p className="text-sm font-semibold text-gray-700">🖼 Fotos do espaço</p>
                  <button onClick={() => fotoInputRef.current?.click()} disabled={uploadingFoto}
                    className="text-sm px-3 py-1 bg-gray-100 hover:bg-gray-200 rounded-lg">
                    {uploadingFoto ? 'Enviando...' : '+ Adicionar foto'}
                  </button>
                  <input ref={fotoInputRef} type="file" accept="image/*" className="hidden" onChange={handleFotoUpload} title="Upload foto" />
                </div>
                {fotos.length > 0 ? (
                  <div className="grid grid-cols-3 gap-2">
                    {fotos.sort((a, b) => a.ordem - b.ordem).map(foto => (
                      <div key={foto.id} className="relative group">
                        {/* eslint-disable-next-line @next/next/no-img-element */}
                        <img src={foto.foto_url} alt="" className="w-full h-24 object-cover rounded-lg" />
                        <button onClick={() => deleteFoto(foto)}
                          className="absolute top-1 right-1 bg-red-500 text-white rounded-full w-6 h-6 text-xs hidden group-hover:flex items-center justify-center">
                          ×
                        </button>
                      </div>
                    ))}
                  </div>
                ) : (
                  <p className="text-sm text-gray-400 text-center py-4 border-2 border-dashed rounded-lg">
                    Nenhuma foto adicionada
                  </p>
                )}
              </div>

              {/* Ativo toggle */}
              <div className="flex items-center gap-3">
                <input type="checkbox" id="ativo" checked={form.ativo}
                  onChange={e => setForm(v => ({ ...v, ativo: e.target.checked }))}
                  className="w-4 h-4 accent-blue-600" />
                <label htmlFor="ativo" className="text-sm font-medium text-gray-700">Anúncio ativo (visível no app)</label>
              </div>
            </div>

            <div className="p-6 border-t flex gap-3 justify-end sticky bottom-0 bg-white">
              <button onClick={() => setShowForm(false)}
                className="px-6 py-2 border rounded-lg text-gray-600 hover:bg-gray-50">
                Cancelar
              </button>
              <button onClick={handleSave} disabled={saving}
                className="px-6 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg font-medium disabled:opacity-50">
                {saving ? 'Salvando...' : 'Salvar'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
