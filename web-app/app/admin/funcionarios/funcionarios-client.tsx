'use client'

import { useState, useRef } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { Plus, Edit2, Trash2, X, Badge, Camera, Trash } from 'lucide-react'

type Funcionario = {
  id: string
  condominio_id: string
  user_id: string | null
  celular: string | null
  foto: string | null
  funcao: string | null
  nome_do_funcionario: string | null
  observacao: string | null
  horario_de_trabalho: string | null
  mostrar_funcionarios: boolean | null
}

export default function FuncionariosClient({
  initialData,
  condominioId,
  userId
}: {
  initialData: Funcionario[]
  condominioId: string
  userId: string
}) {
  const router = useRouter()
  const supabase = createClient()
  const [funcionarios, setFuncionarios] = useState<Funcionario[]>(initialData)
  
  const [isModalOpen, setIsModalOpen] = useState(false)
  const [editingId, setEditingId] = useState<string | null>(null)
  
  const [formData, setFormData] = useState({
    nome_do_funcionario: '',
    funcao: '',
    celular: '',
    horario_de_trabalho: '',
    observacao: '',
    foto: '' as string | null
  })
  
  const [isUploading, setIsUploading] = useState(false)
  const [isSaving, setIsSaving] = useState(false)
  const [errorMsg, setErrorMsg] = useState('')
  const fileInputRef = useRef<HTMLInputElement>(null)

  const openNew = () => {
    setEditingId(null)
    setFormData({
      nome_do_funcionario: '',
      funcao: '',
      celular: '',
      horario_de_trabalho: '',
      observacao: '',
      foto: null
    })
    setErrorMsg('')
    setIsModalOpen(true)
  }

  const openEdit = (f: Funcionario) => {
    setEditingId(f.id)
    setFormData({
      nome_do_funcionario: f.nome_do_funcionario || '',
      funcao: f.funcao || '',
      celular: f.celular || '',
      horario_de_trabalho: f.horario_de_trabalho || '',
      observacao: f.observacao || '',
      foto: f.foto || null
    })
    setErrorMsg('')
    setIsModalOpen(true)
  }

  const handleDelete = async (id: string) => {
    if (!confirm('Deseja realmente excluir este funcionário?')) return
    
    const { error } = await supabase.from('funcionarios').delete().eq('id', id)
    if (error) {
      alert('Erro ao excluir: ' + error.message)
    } else {
      setFuncionarios(prev => prev.filter(f => f.id !== id))
      router.refresh()
    }
  }

  const handleImageUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return

    // Simple validation
    if (!file.type.startsWith('image/')) {
      alert('Por favor, selecione uma imagem.')
      return
    }

    if (file.size > 5 * 1024 * 1024) {
      alert('A imagem deve ter no máximo 5MB.')
      return
    }

    setIsUploading(true)
    setErrorMsg('')

    try {
      // Create a unique file name
      const fileExt = file.name.split('.').pop()
      const fileName = `${condominioId}/${Date.now()}-${Math.random()}.${fileExt}`
      const bucket = 'avatars' // using avatars bucket which is standard

      // Delete existing photo if replacing
      if (formData.foto && formData.foto.includes(bucket)) {
        try {
          const oldPath = formData.foto.split(`${bucket}/`)[1]
          if (oldPath) await supabase.storage.from(bucket).remove([oldPath])
        } catch {
          // ignore error removing old
        }
      }

      const { data, error } = await supabase.storage
        .from(bucket)
        .upload(fileName, file, { upsert: true })

      if (error) throw error

      if (data) {
        const { data: { publicUrl } } = supabase.storage.from(bucket).getPublicUrl(fileName)
        setFormData(prev => ({ ...prev, foto: publicUrl }))
      }
    } catch (err) {
      console.error(err)
      setErrorMsg('Erro ao fazer upload da foto. Verifique se o bucket "avatars" é público e aceita uploads.')
    } finally {
      setIsUploading(false)
    }
  }

  const handleRemovePhoto = async () => {
    if (!formData.foto) return
    const bucket = 'avatars'
    if (formData.foto.includes(bucket)) {
      try {
        const path = formData.foto.split(`${bucket}/`)[1]
        if (path) await supabase.storage.from(bucket).remove([path])
      } catch (err) {
        console.error('Failed to remove photo from storage', err)
      }
    }
    setFormData(prev => ({ ...prev, foto: null }))
  }

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault()
    setIsSaving(true)
    setErrorMsg('')

    try {
      const dataToSave = {
        condominio_id: condominioId,
        user_id: userId,
        nome_do_funcionario: formData.nome_do_funcionario,
        funcao: formData.funcao,
        celular: formData.celular,
        horario_de_trabalho: formData.horario_de_trabalho,
        observacao: formData.observacao,
        foto: formData.foto,
        quem_editou: userId,
        ...(editingId ? {} : { quem_registrou: userId, mostrar_funcionarios: true })
      }

      if (editingId) {
        const { error } = await supabase
          .from('funcionarios')
          .update(dataToSave)
          .eq('id', editingId)
          
        if (error) throw error
        
        setFuncionarios(prev => prev.map(f => f.id === editingId ? { ...f, ...dataToSave } as Funcionario : f))
      } else {
        const { data, error } = await supabase
          .from('funcionarios')
          .insert(dataToSave)
          .select()
          .single()
          
        if (error) throw error
        if (data) {
          setFuncionarios(prev => [...prev, data as Funcionario].sort((a,b) => (a.nome_do_funcionario || '').localeCompare(b.nome_do_funcionario || '')))
        }
      }
      
      setIsModalOpen(false)
      router.refresh()
    } catch (err: any) {
      console.error('Caught error in handleSave:', err)
      const msg = err?.message || (typeof err === 'string' ? err : 'Erro ao salvar.')
      setErrorMsg(msg)
    } finally {
      setIsSaving(false)
    }
  }

  const handleToggleVisibility = async (id: string, currentStatus: boolean) => {
    try {
      const newStatus = !currentStatus
      const { error } = await supabase
        .from('funcionarios')
        .update({ mostrar_funcionarios: newStatus })
        .eq('id', id)
        
      if (error) throw error
      
      setFuncionarios(prev => prev.map(f => f.id === id ? { ...f, mostrar_funcionarios: newStatus } : f))
    } catch (err) {
      console.error('Erro ao atualizar visibilidade:', err)
      alert('Não foi possível atualizar a visibilidade. Tente novamente.')
    }
  }

  const formatWhatsApp = (value: string) => {
    const v = value.replace(/\D/g, '')
    if (v.length <= 2) return v
    if (v.length <= 6) return `(${v.slice(0, 2)}) ${v.slice(2)}`
    if (v.length <= 10) return `(${v.slice(0, 2)}) ${v.slice(2, 6)}-${v.slice(6)}`
    return `(${v.slice(0, 2)}) ${v.slice(2, 7)}-${v.slice(7, 11)}`
  }

  return (
    <div className="p-4 md:p-8 max-w-6xl mx-auto">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-8">
        <div>
          <h1 className="text-2xl font-bold text-gray-800 flex items-center gap-2">
            <Badge size={28} className="text-[#FC5931]" />
            Funcionários
          </h1>
          <p className="text-gray-500 mt-1">Gerencie os funcionários e colaboradores do condomínio.</p>
        </div>
        <button
          onClick={openNew}
          className="bg-[#FC5931] hover:bg-[#D42F1D] text-white px-4 py-2 rounded-xl font-medium shadow-sm flex items-center justify-center gap-2 transition-colors"
        >
          <Plus size={18} />
          Inserir Funcionário
        </button>
      </div>

      {funcionarios.length === 0 ? (
        <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-12 flex flex-col items-center justify-center text-center">
          <div className="w-16 h-16 bg-[#FC5931]/10 rounded-full flex items-center justify-center mb-4">
            <Badge size={32} className="text-[#FC5931]" />
          </div>
          <h3 className="text-lg font-semibold text-gray-800 mb-2">Nenhum funcionário cadastrado</h3>
          <p className="text-gray-500 max-w-sm mb-6">Cadastre os funcionários para organizar a equipe e possibilitar a visualização pelos moradores.</p>
          <button
            onClick={openNew}
            className="text-[#FC5931] border border-[#FC5931] hover:bg-[#FC5931] hover:text-white px-6 py-2.5 rounded-xl font-medium transition-colors"
          >
            Cadastrar Primeiro
          </button>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {funcionarios.map(f => (
            <div key={f.id} className="bg-white rounded-2xl shadow-sm border border-gray-100 p-5 hover:shadow-md transition-shadow flex items-start gap-4">
              <div className="w-14 h-14 rounded-full bg-gray-100 border border-gray-200 flex items-center justify-center overflow-hidden shrink-0">
                {f.foto ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={f.foto} alt={f.nome_do_funcionario || ''} className="w-full h-full object-cover" />
                ) : (
                  <Badge size={24} className="text-gray-400" />
                )}
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex justify-between items-start">
                  <h3 className="font-bold text-gray-800 line-clamp-1 flex-1 pr-2 uppercase" title={f.nome_do_funcionario || ''}>
                    {f.nome_do_funcionario}
                  </h3>
                  <div className="flex items-center gap-1 shrink-0 -mt-1 -mr-1">
                    <button 
                      onClick={() => openEdit(f)}
                      className="p-1.5 text-gray-400 hover:text-blue-600 hover:bg-blue-50 rounded-lg transition-colors"
                      title="Editar"
                    >
                      <Edit2 size={16} />
                    </button>
                    <button 
                      onClick={() => handleDelete(f.id)}
                      className="p-1.5 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                      title="Excluir"
                    >
                      <Trash2 size={16} />
                    </button>
                  </div>
                </div>
                
                <div className="space-y-1 mt-1 text-sm text-gray-600">
                  {f.funcao && (
                    <p className="flex items-center gap-1"><span className="w-2 h-2 rounded-full bg-blue-500 shrink-0"></span> {f.funcao}</p>
                  )}
                  {f.celular && (
                    <p className="flex items-center gap-1"><span className="w-2 h-2 rounded-full bg-green-500 shrink-0"></span> {f.celular}</p>
                  )}
                  {f.horario_de_trabalho && (
                    <p className="text-xs text-gray-500 mt-1 bg-gray-50 p-1.5 rounded-lg border border-gray-100">{f.horario_de_trabalho}</p>
                  )}
                  
                  <div className="mt-3 pt-3 border-t border-gray-100 flex items-center justify-between">
                    <span className="text-xs font-medium text-gray-500">Visível ao morador?</span>
                    <button
                      type="button"
                      onClick={() => handleToggleVisibility(f.id, f.mostrar_funcionarios ?? true)}
                      className={`relative inline-flex h-5 w-9 shrink-0 cursor-pointer items-center justify-center rounded-full transition-colors duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-[#FC5931] focus:ring-offset-2 ${
                        (f.mostrar_funcionarios ?? true) ? 'bg-[#FC5931]' : 'bg-gray-200'
                      }`}
                      role="switch"
                      aria-checked={f.mostrar_funcionarios ?? true}
                    >
                      <span className="sr-only">Visível ao morador</span>
                      <span
                        aria-hidden="true"
                        className={`pointer-events-none inline-block h-3.5 w-3.5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out ${
                          (f.mostrar_funcionarios ?? true) ? 'translate-x-2' : '-translate-x-2'
                        }`}
                      />
                    </button>
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Modal / Dialog */}
      {isModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40 backdrop-blur-sm">
          <div className="bg-[#f5f5f5] w-full max-w-xl rounded-2xl shadow-xl overflow-hidden animate-in fade-in zoom-in-95 duration-200 max-h-[90vh] overflow-y-auto">
            {/* Header pattern */}
            <div className="bg-white border-b border-gray-200 px-6 py-4 flex items-center justify-between shadow-sm relative overflow-hidden">
               <div className="absolute inset-0 opacity-[0.03] pointer-events-none"></div>
              <h2 className="text-xl font-bold outline-none text-gray-800 relative z-10 flex items-center gap-2">
                <Badge size={24} className="text-[#FC5931]" />
                {editingId ? 'Editar Funcionário' : 'Inserir Funcionário'}
              </h2>
              <button 
                onClick={() => setIsModalOpen(false)}
                title="Fechar"
                aria-label="Fechar"
                className="text-gray-400 hover:text-gray-600 bg-gray-50 hover:bg-gray-100 p-1.5 rounded-full transition-colors relative z-10"
              >
                <X size={20} />
              </button>
            </div>
            
            <form onSubmit={handleSave} className="p-6">
              <div className="space-y-5">
                
                {/* Imagem Upload */}
                <div className="flex flex-col items-center mb-6">
                  <div className="relative group rounded-full overflow-hidden w-28 h-28 border-4 border-white shadow-md bg-gray-100 flex justify-center items-center">
                    {formData.foto ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img src={formData.foto} alt="Funcionario" className="w-full h-full object-cover" />
                    ) : (
                      <Camera size={40} className="text-gray-300" />
                    )}
                    
                    <div 
                      className="absolute inset-0 bg-black/40 flex flex-col items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity cursor-pointer"
                      onClick={() => fileInputRef.current?.click()}
                    >
                      <Camera size={24} className="text-white mb-1" />
                      <span className="text-white text-[10px] font-bold uppercase tracking-wider">{isUploading ? 'Enviando...' : 'Alterar Foto'}</span>
                    </div>

                    {formData.foto && (
                      <button
                        type="button"
                        onClick={(e) => {
                          e.stopPropagation();
                          handleRemovePhoto();
                        }}
                        className="absolute top-2 right-2 bg-red-500 rounded-full p-1 text-white opacity-0 group-hover:opacity-100 hover:bg-red-600 transition-all shadow-sm"
                        title="Remover foto"
                      >
                        <Trash size={12} />
                      </button>
                    )}
                  </div>
                  <input 
                    type="file" 
                    ref={fileInputRef} 
                    className="hidden" 
                    accept="image/*"
                    onChange={handleImageUpload}
                  />
                  <p className="text-xs text-gray-500 mt-3 font-medium">Foto do Funcionário / Colaborador</p>
                </div>

                {/* Form Fields */}
                <div className="grid grid-cols-1 gap-4">
                  <div>
                    <label className="text-gray-600 font-medium text-sm block mb-1">Nome do funcionário: <span className="text-red-500">*</span></label>
                    <input 
                      type="text"
                      required
                      value={formData.nome_do_funcionario}
                      onChange={e => setFormData({...formData, nome_do_funcionario: e.target.value})}
                      placeholder="Ex: João da Silva"
                      className="w-full border border-gray-300 rounded-xl px-4 py-2.5 bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] transition-all"
                    />
                  </div>
                  
                  <div>
                    <label className="text-gray-600 font-medium text-sm block mb-1">Função: <span className="text-gray-400 font-normal text-xs ml-1">(Opcional)</span></label>
                    <input 
                      type="text"
                      value={formData.funcao}
                      onChange={e => setFormData({...formData, funcao: e.target.value})}
                      placeholder="Ex: Zelador, Faxineira"
                      className="w-full border border-gray-300 rounded-xl px-4 py-2.5 bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] transition-all"
                    />
                  </div>

                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                    <div>
                      <label className="text-gray-600 font-medium text-sm block mb-1">Celular: <span className="text-gray-400 font-normal text-xs ml-1">(WhatsApp)</span></label>
                      <input 
                        type="text"
                        value={formData.celular}
                        onChange={e => setFormData({...formData, celular: formatWhatsApp(e.target.value)})}
                        placeholder="(00) 0 0000-0000"
                        maxLength={15}
                        className="w-full border border-gray-300 rounded-xl px-4 py-2.5 bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] transition-all"
                      />
                    </div>
                    
                    <div>
                      <label className="text-gray-600 font-medium text-sm block mb-1">Horário de trabalho: <span className="text-gray-400 font-normal text-xs ml-1">(Opcional)</span></label>
                      <input 
                        type="text"
                        value={formData.horario_de_trabalho}
                        onChange={e => setFormData({...formData, horario_de_trabalho: e.target.value})}
                        placeholder="Ex: Seg-Sex: 08:00 às 17:00"
                        className="w-full border border-gray-300 rounded-xl px-4 py-2.5 bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] transition-all"
                      />
                    </div>
                  </div>
                  
                  <div>
                    <label className="text-gray-600 font-medium text-sm block mb-1 mt-1">Observação:</label>
                    <textarea 
                      value={formData.observacao}
                      onChange={e => setFormData({...formData, observacao: e.target.value})}
                      placeholder="Escreva aqui uma descrição, endereço, detalhes..."
                      rows={4}
                      className="w-full border border-gray-300 rounded-xl px-4 py-2.5 bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] transition-all resize-none text-sm leading-relaxed"
                    />
                  </div>
                </div>
              </div>

              {errorMsg && (
                <div className="mt-5 p-3.5 bg-red-50 text-red-600 border border-red-100 rounded-xl text-sm flex items-start gap-2">
                  <AlertCircle size={18} className="shrink-0 mt-0.5" />
                  <span>{errorMsg}</span>
                </div>
              )}
              
              <div className="flex items-center justify-center gap-4 mt-8 pt-4 border-t border-gray-200/60">
                <button
                  type="submit"
                  disabled={isSaving || isUploading}
                  className="bg-[#FC5931] hover:bg-[#D42F1D] text-white px-8 py-2.5 rounded-2xl font-medium shadow-sm transition-colors w-full sm:w-auto min-w-[140px] disabled:opacity-50"
                >
                  {isSaving ? 'Salvando...' : 'Adicionar'}
                </button>
                <button
                  type="button"
                  onClick={() => setIsModalOpen(false)}
                  className="bg-white border border-gray-300 text-gray-700 hover:bg-gray-50 px-8 py-2.5 rounded-2xl font-medium shadow-sm transition-colors w-full sm:w-auto min-w-[140px]"
                >
                  Cancelar
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}

function AlertCircle({ size = 24, ...props }: React.SVGProps<SVGSVGElement> & { size?: number | string }) {
  return (
    <svg
      {...props}
      xmlns="http://www.w3.org/2000/svg"
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <circle cx="12" cy="12" r="10" />
      <line x1="12" x2="12" y1="8" y2="12" />
      <line x1="12" x2="12.01" y1="16" y2="16" />
    </svg>
  )
}
