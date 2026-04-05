'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { Plus, Edit2, Trash2, X, Briefcase } from 'lucide-react'

type Fornecedor = {
  id: string
  condominio_id: string
  tipo: string
  documento: string
  nome: string
  telefone: string
  observacoes: string
}

export default function FornecedoresClient({
  initialData,
  condominioId
}: {
  initialData: Fornecedor[]
  condominioId: string
}) {
  const router = useRouter()
  const supabase = createClient()
  const [fornecedores, setFornecedores] = useState<Fornecedor[]>(initialData)
  
  const [isModalOpen, setIsModalOpen] = useState(false)
  const [editingId, setEditingId] = useState<string | null>(null)
  
  const [formData, setFormData] = useState({
    tipo: 'Pessoa Física',
    documento: '',
    nome: '',
    telefone: '',
    observacoes: ''
  })
  
  const [isSaving, setIsSaving] = useState(false)
  const [errorMsg, setErrorMsg] = useState('')

  useEffect(() => {
    if (typeof window !== 'undefined') {
      const params = new URLSearchParams(window.location.search)
      if (params.get('action') === 'new') {
        openNew()
        window.history.replaceState(null, '', '/admin/fornecedores')
      }
    }
  }, [])

  const openNew = () => {
    setEditingId(null)
    setFormData({
      tipo: 'Pessoa Física',
      documento: '',
      nome: '',
      telefone: '',
      observacoes: ''
    })
    setErrorMsg('')
    setIsModalOpen(true)
  }

  const openEdit = (f: Fornecedor) => {
    setEditingId(f.id)
    setFormData({
      tipo: f.tipo || 'Pessoa Física',
      documento: f.documento || '',
      nome: f.nome || '',
      telefone: f.telefone || '',
      observacoes: f.observacoes || ''
    })
    setErrorMsg('')
    setIsModalOpen(true)
  }

  const handleDelete = async (id: string) => {
    if (!confirm('Deseja realmente excluir este fornecedor?')) return
    
    const { error } = await supabase.from('fornecedores').delete().eq('id', id)
    if (error) {
      alert('Erro ao excluir: ' + error.message)
    } else {
      setFornecedores(prev => prev.filter(f => f.id !== id))
      router.refresh()
    }
  }

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault()
    setIsSaving(true)
    setErrorMsg('')

    try {
      if (editingId) {
        const { error } = await supabase
          .from('fornecedores')
          .update(formData)
          .eq('id', editingId)
          
        if (error) throw error
        
        setFornecedores(prev => prev.map(f => f.id === editingId ? { ...f, ...formData } : f))
      } else {
        const { data, error } = await supabase
          .from('fornecedores')
          .insert({
            condominio_id: condominioId,
            ...formData
          })
          .select()
          .single()
          
        if (error) throw error
        if (data) {
          setFornecedores(prev => [...prev, data].sort((a,b) => a.nome.localeCompare(b.nome)))
        }
      }
      
      setIsModalOpen(false)
      router.refresh()
    } catch (err) {
      setErrorMsg(err instanceof Error ? err.message : 'Erro ao salvar.')
    } finally {
      setIsSaving(false)
    }
  }

  return (
    <div className="p-4 md:p-8 max-w-6xl mx-auto">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-8">
        <div>
          <h1 className="text-2xl font-bold text-gray-800 flex items-center gap-2">
            <Briefcase size={28} className="text-[#FC5931]" />
            Fornecedores
          </h1>
          <p className="text-gray-500 mt-1">Gerencie os fornecedores do condomínio.</p>
        </div>
        <button
          onClick={openNew}
          className="bg-[#FC5931] hover:bg-[#D42F1D] text-white px-4 py-2 rounded-xl font-medium shadow-sm flex items-center justify-center gap-2 transition-colors"
        >
          <Plus size={18} />
          Novo Fornecedor
        </button>
      </div>

      {fornecedores.length === 0 ? (
        <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-12 flex flex-col items-center justify-center text-center">
          <div className="w-16 h-16 bg-[#FC5931]/10 rounded-full flex items-center justify-center mb-4">
            <Briefcase size={32} className="text-[#FC5931]" />
          </div>
          <h3 className="text-lg font-semibold text-gray-800 mb-2">Nenhum fornecedor cadastrado</h3>
          <p className="text-gray-500 max-w-sm mb-6">Cadastre os fornecedores que prestam serviços para o condomínio.</p>
          <button
            onClick={openNew}
            className="text-[#FC5931] border border-[#FC5931] hover:bg-[#FC5931] hover:text-white px-6 py-2.5 rounded-xl font-medium transition-colors"
          >
            Cadastrar Primeiro
          </button>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {fornecedores.map(f => (
            <div key={f.id} className="bg-white rounded-2xl shadow-sm border border-gray-100 p-5 hover:shadow-md transition-shadow">
              <div className="flex justify-between items-start mb-3">
                <h3 className="font-bold text-gray-800 line-clamp-1 flex-1 pr-2" title={f.nome}>
                  {f.nome}
                </h3>
                <div className="flex items-center gap-1">
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
              
              <div className="space-y-1.5 text-sm text-gray-600">
                {f.documento && (
                  <p><span className="font-medium text-gray-500">Doc:</span> {f.documento} ({f.tipo})</p>
                )}
                {f.telefone && (
                  <p><span className="font-medium text-gray-500">Tel:</span> {f.telefone}</p>
                )}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Modal / Dialog */}
      {isModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40 backdrop-blur-sm">
          <div className="bg-[#f5f5f5] w-full max-w-xl rounded-2xl shadow-xl overflow-hidden animate-in fade-in zoom-in-95 duration-200">
            {/* Header pattern from screenshot */}
            <div className="bg-white border-b border-gray-200 px-6 py-4 flex items-center justify-between shadow-sm relative overflow-hidden">
               {/* Just a slight pattern hint */}
               <div className="absolute inset-0 opacity-[0.03] pointer-events-none"></div>
              <h2 className="text-xl font-bold outline-none text-gray-800 relative z-10">
                {editingId ? 'Editar Fornecedor' : 'Inserir Fornecedor'}
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
              <div className="space-y-4">
                
                <div className="grid grid-cols-[150px_1fr] items-center gap-4">
                  <label className="text-gray-600 font-medium">Tipo:</label>
                  <select 
                    value={formData.tipo}
                    title="Tipo de Fornecedor"
                    aria-label="Tipo de Fornecedor"
                    onChange={e => setFormData({...formData, tipo: e.target.value})}
                    className="w-full border border-gray-300 rounded-xl px-4 py-2 bg-gray-50 focus:bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] transition-all"
                  >
                    <option value="Pessoa Física">Pessoa Física</option>
                    <option value="Pessoa Jurídica">Pessoa Jurídica</option>
                  </select>
                </div>
                
                <div className="grid grid-cols-[150px_1fr] items-center gap-4">
                  <label className="text-gray-600 font-medium">Documento (CPF/CNPJ):</label>
                  <input 
                    type="text"
                    value={formData.documento}
                    onChange={e => setFormData({...formData, documento: e.target.value})}
                    placeholder={formData.tipo === 'Pessoa Física' ? '000.000.000-00' : '00.000.000/0000-00'}
                    className="w-full border border-gray-300 rounded-xl px-4 py-2 bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] transition-all"
                  />
                </div>
                
                <div className="grid grid-cols-[150px_1fr] items-center gap-4">
                  <label className="text-gray-600 font-medium">Nome:</label>
                  <input 
                    type="text"
                    required
                    value={formData.nome}
                    onChange={e => setFormData({...formData, nome: e.target.value})}
                    placeholder="Nome"
                    className="w-full border border-gray-300 rounded-xl px-4 py-2 bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] transition-all"
                  />
                </div>
                
                <div className="grid grid-cols-[150px_1fr] items-center gap-4">
                  <label className="text-gray-600 font-medium">Telefone:</label>
                  <input 
                    type="text"
                    value={formData.telefone}
                    onChange={e => setFormData({...formData, telefone: e.target.value})}
                    placeholder="(00) 0 0000-0000"
                    className="w-full border border-gray-300 rounded-xl px-4 py-2 bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] transition-all"
                  />
                </div>
                
                <div className="grid grid-cols-[150px_1fr] items-start gap-4">
                  <label className="text-gray-600 font-medium mt-2">Observações:</label>
                  <textarea 
                    value={formData.observacoes}
                    onChange={e => setFormData({...formData, observacoes: e.target.value})}
                    placeholder="Escreva aqui uma Observação"
                    rows={4}
                    className="w-full border border-gray-300 rounded-xl px-4 py-2 bg-white focus:outline-none focus:ring-2 focus:ring-[#FC5931]/30 focus:border-[#FC5931] transition-all resize-none"
                  />
                </div>
              </div>

              {errorMsg && (
                <div className="mt-4 p-3 bg-red-50 text-red-600 border border-red-100 rounded-xl text-sm">
                  {errorMsg}
                </div>
              )}
              
              {!editingId && (
                <p className="mt-6 text-sm text-gray-500">
                  Para cadastrar mais dados, vá em editar Fornecedor, depois que salvar...
                </p>
              )}

              <div className="flex items-center justify-center gap-4 mt-8">
                <button
                  type="submit"
                  disabled={isSaving}
                  className="bg-[#FC5931] hover:bg-[#D42F1D] text-white px-8 py-2.5 rounded-2xl font-medium shadow-sm transition-colors w-32 disabled:opacity-50"
                >
                  {isSaving ? 'Salvando...' : 'Salvar'}
                </button>
                <button
                  type="button"
                  onClick={() => setIsModalOpen(false)}
                  className="bg-white border border-gray-300 text-gray-700 hover:bg-gray-50 px-8 py-2.5 rounded-2xl font-medium shadow-sm transition-colors w-32"
                >
                  Voltar
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}
