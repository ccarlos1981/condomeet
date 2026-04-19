'use client'

import { useState } from 'react'
import { X, User, Save, Bell, Key } from 'lucide-react'
import { adminUpdateProfile, adminResetPassword } from '@/app/admin/actions'

export type EditProfileData = {
  id: string
  nome_completo: string | null
  email: string | null
  whatsapp: string | null
  bloco_txt: string | null
  apto_txt: string | null
  papel_sistema: string | null
}

export default function EditProfileModal({
  profile,
  onClose,
  blocoLabel = 'Bloco',
  aptoLabel = 'Apto',
}: {
  profile: EditProfileData
  onClose: () => void
  blocoLabel?: string
  aptoLabel?: string
}) {
  const [loading, setLoading] = useState(false)
  const [resetting, setResetting] = useState(false)
  const [confirmReset, setConfirmReset] = useState(false)
  const [error, setError] = useState('')
  const [successMsg, setSuccessMsg] = useState('')
  const [formData, setFormData] = useState({
    nome_completo: profile.nome_completo ?? '',
    email: profile.email ?? '',
    whatsapp: profile.whatsapp ?? '',
    bloco_txt: profile.bloco_txt ?? '',
    apto_txt: profile.apto_txt ?? '',
    papel_sistema: profile.papel_sistema ?? 'Morador',
  })

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    setSuccessMsg('')
    setLoading(true)

    try {
      const res = await adminUpdateProfile({
        id: profile.id,
        nome_completo: formData.nome_completo,
        email: formData.email,
        whatsapp: formData.whatsapp,
        bloco_txt: formData.bloco_txt,
        apto_txt: formData.apto_txt,
        papel_sistema: formData.papel_sistema,
      })
      
      if (res?.error) {
        setError(res.error)
      } else {
        onClose()
      }
    } catch (err: any) {
      setError(err.message || 'Erro ao atualizar morador.')
    } finally {
      setLoading(false)
    }
  }

  async function handleResetPassword() {
    if (!confirmReset) {
      setConfirmReset(true)
      return
    }
    
    setError('')
    setSuccessMsg('')
    setResetting(true)
    try {
      const res = await adminResetPassword(profile.id)
      if (res?.error) {
        setError(res.error)
      } else {
        setSuccessMsg('Senha resetada com sucesso para 123456.')
        setConfirmReset(false)
      }
    } catch (err: any) {
      setError(err.message || 'Erro ao resetar senha.')
    } finally {
      setResetting(false)
    }
  }


  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-gray-900/40 backdrop-blur-sm animate-in fade-in duration-200">
      <div 
        className="bg-white rounded-3xl w-full max-w-lg shadow-2xl overflow-hidden flex flex-col max-h-[90vh] animate-in zoom-in-95 duration-200"
      >
        <div className="px-6 py-5 border-b border-gray-100 flex items-center justify-between sticky top-0 bg-white z-10">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-2xl bg-[#FC5931]/10 flex items-center justify-center">
              <User size={20} className="text-[#FC5931]" />
            </div>
            <div>
              <h2 className="text-xl font-bold text-gray-900">Editar Morador</h2>
              <p className="text-xs text-gray-500 mt-0.5">Ajuste os dados cadastrais livremente</p>
            </div>
          </div>
          <button 
            onClick={onClose}
            className="p-2 text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded-xl transition-colors"
          >
            <X size={20} />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-6 overflow-y-auto flex-1">
          {error && (
            <div className="p-3 mb-5 bg-red-50 text-red-600 text-sm font-medium rounded-xl">
              {error}
            </div>
          )}
          {successMsg && (
            <div className="p-3 mb-5 bg-emerald-50 text-emerald-700 text-sm font-medium rounded-xl">
              {successMsg}
            </div>
          )}

          <div className="space-y-4">
            <div>
              <label className="block text-sm font-semibold text-gray-700 mb-1.5">Nome Completo</label>
              <input 
                required
                type="text"
                value={formData.nome_completo}
                onChange={e => setFormData({ ...formData, nome_completo: e.target.value })}
                className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931] transition-all bg-gray-50/50"
                placeholder="Ex: João da Silva"
              />
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-semibold text-gray-700 mb-1.5">E-mail (Contato)</label>
                <input 
                  type="email"
                  value={formData.email}
                  onChange={e => setFormData({ ...formData, email: e.target.value })}
                  className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931] transition-all bg-gray-50/50"
                  placeholder="Ex: joao@email.com"
                />
              </div>
              <div>
                <label className="block text-sm font-semibold text-gray-700 mb-1.5">WhatsApp / Telefone</label>
                <input 
                  type="text"
                  value={formData.whatsapp}
                  onChange={e => setFormData({ ...formData, whatsapp: e.target.value })}
                  className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931] transition-all bg-gray-50/50"
                  placeholder="Apenas números"
                />
              </div>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-semibold text-gray-700 mb-1.5">{blocoLabel}</label>
                <input 
                  type="text"
                  value={formData.bloco_txt}
                  onChange={e => setFormData({ ...formData, bloco_txt: e.target.value })}
                  className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931] transition-all bg-gray-50/50"
                  placeholder="Ex: 1, A, Norte"
                />
              </div>
              <div>
                <label className="block text-sm font-semibold text-gray-700 mb-1.5">{aptoLabel}</label>
                <input 
                  type="text"
                  value={formData.apto_txt}
                  onChange={e => setFormData({ ...formData, apto_txt: e.target.value })}
                  className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931] transition-all bg-gray-50/50"
                  placeholder="Ex: 101, 12, Casa 5"
                />
              </div>
            </div>

            <div>
              <label className="block text-sm font-semibold text-gray-700 mb-1.5">Papel no Sistema</label>
              <select
                value={formData.papel_sistema}
                onChange={e => setFormData({ ...formData, papel_sistema: e.target.value })}
                className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931] transition-all bg-gray-50/50"
              >
                <option value="Morador">Morador</option>
                <option value="Síndico">Síndico</option>
                <option value="Porteiro">Porteiro / Vigia</option>
                <option value="Zelador">Zelador / Limpeza</option>
                <option value="Admin">Administrador</option>
              </select>
            </div>
            
            <div className="bg-blue-50/50 border border-blue-100 rounded-xl p-3 flex gap-3 text-blue-700 mt-4">
              <Bell size={16} className="mt-0.5 shrink-0" />
              <p className="text-xs/5 opacity-80">
                Lembre-se: O <strong>histórico não é apagado</strong>. Modificar o {blocoLabel}/{aptoLabel} ajusta a casa e os futuros envios sem excluir ocorrências antigas.
              </p>
            </div>
          </div>
        </form>

        <div className="p-4 border-t border-gray-100 bg-gray-50 flex items-center justify-between rounded-b-3xl">
          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={handleResetPassword}
              disabled={resetting || loading}
              className={`flex items-center gap-1.5 px-4 py-2.5 text-sm font-semibold rounded-xl transition-colors disabled:opacity-50 ${
                confirmReset 
                  ? 'bg-rose-600 text-white hover:bg-rose-700 shadow-sm' 
                  : 'text-rose-600 hover:bg-rose-50'
              }`}
              title="A senha do usuário será definida para 123456"
            >
              <Key size={16} />
              {resetting 
                ? 'Resetando...' 
                : confirmReset 
                  ? 'Tem certeza? (123456)' 
                  : 'Resetar Senha (123456)'
              }
            </button>
            {confirmReset && !resetting && (
              <button
                type="button"
                onClick={() => setConfirmReset(false)}
                className="p-2 text-gray-400 hover:text-gray-600 hover:bg-gray-200/50 rounded-xl transition-colors"
                title="Cancelar reset"
              >
                <X size={16} />
              </button>
            )}
          </div>
          <div className="flex justify-end gap-3">
            <button
              type="button"
              onClick={onClose}
              className="px-5 py-2.5 text-sm font-semibold text-gray-600 hover:bg-gray-200/50 rounded-xl transition-colors"
            >
              Cancelar
            </button>
          <button
            onClick={handleSubmit}
            disabled={loading}
            className="px-5 py-2.5 text-sm font-semibold text-white bg-[#FC5931] hover:bg-[#e64720] rounded-xl shadow-sm transition-colors flex items-center gap-2 disabled:opacity-50"
          >
            <Save size={16} />
            {loading ? 'Salvando...' : 'Salvar Alterações'}
          </button>
          </div>
        </div>
      </div>
    </div>
  )
}
