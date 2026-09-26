'use client'

import { useState, useEffect } from 'react'
import { X, User, AlertCircle, Loader2 } from 'lucide-react'
import { adminUpdateResidentGeneralData } from '@/app/admin/actions'

interface EditGeneralDataModalProps {
  open: boolean
  onClose: () => void
  residentId: string
  nomeCompleto: string
  whatsapp: string
  tipoMorador: string
  papelSistema: string
  onSaved: () => void
}

const STANDARD_TIPO_MORADOR = [
  'Proprietário (a)',
  'Inquilino (a)',
  'Morador(a)',
  'Cônjuge',
  'Dependente',
  'Família',
  'Funcionário',
  'Visitante Frequente',
]

const STANDARD_PAPEL_SISTEMA = [
  { value: 'Morador', label: 'Morador' },
  { value: 'Síndico', label: 'Síndico' },
  { value: 'Subsíndico', label: 'Subsíndico' },
  { value: 'Porteiro', label: 'Porteiro / Vigia' },
  { value: 'Zelador', label: 'Zelador / Limpeza' },
  { value: 'Admin', label: 'Administrador' },
]

function getInitialPapel(papel: string): string {
  const trimmed = papel?.trim() || 'Morador'
  const lower = trimmed.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '')
  if (lower === 'admin' || lower === 'administrador' || lower === 'administradora') return 'Admin'
  if (lower.startsWith('morador')) return 'Morador'
  if (lower.includes('subsindico')) return 'Subsíndico'
  if (lower.startsWith('sindico')) return 'Síndico'
  if (lower.startsWith('porteir')) return 'Porteiro'
  if (lower.startsWith('zelador')) return 'Zelador'
  return trimmed
}

export default function EditGeneralDataModal({
  open,
  onClose,
  residentId,
  nomeCompleto,
  whatsapp,
  tipoMorador,
  papelSistema,
  onSaved,
}: EditGeneralDataModalProps) {
  const [nome, setNome] = useState('')
  const [telefone, setTelefone] = useState('')
  const [tipo, setTipo] = useState('')
  const [papel, setPapel] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (open) {
      setNome(nomeCompleto || '')
      setTelefone(whatsapp || '')
      setTipo(tipoMorador || STANDARD_TIPO_MORADOR[0])
      setPapel(getInitialPapel(papelSistema))
      setError(null)
      setLoading(false)
    }
  }, [open, nomeCompleto, whatsapp, tipoMorador, papelSistema])

  if (!open) return null

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (loading) return

    setLoading(true)
    setError(null)

    try {
      const res = await adminUpdateResidentGeneralData({
        residentId,
        nome_completo: nome,
        whatsapp: telefone,
        tipo_morador: tipo,
        papel_sistema: papel,
      })

      if (res?.error) {
        setError(res.error)
      } else if (res?.success) {
        onSaved()
        onClose()
      } else {
        setError('Ocorreu um erro inesperado ao salvar os dados.')
      }
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Falha ao comunicar com o servidor.'
      setError(msg)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-gray-900/40 backdrop-blur-xs animate-in fade-in duration-200">
      <div className="bg-white rounded-3xl w-full max-w-lg shadow-2xl overflow-hidden flex flex-col max-h-[90vh] animate-in zoom-in-95 duration-200">
        {/* Header */}
        <div className="px-6 py-5 border-b border-gray-100 flex items-center justify-between sticky top-0 bg-white z-10">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-2xl bg-[#FC5931]/10 flex items-center justify-center shrink-0">
              <User size={20} className="text-[#FC5931]" />
            </div>
            <div>
              <h2 className="text-xl font-bold text-gray-900">Editar dados do morador</h2>
              <p className="text-xs text-gray-500 mt-0.5">
                Atualize apenas os dados cadastrais permitidos. E-mail e vínculo com a unidade possuem fluxos próprios.
              </p>
            </div>
          </div>
          <button
            type="button"
            onClick={onClose}
            disabled={loading}
            className="p-2 text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded-xl transition-colors disabled:opacity-50"
            aria-label="Fechar"
          >
            <X size={20} />
          </button>
        </div>

        {/* Form Body */}
        <form onSubmit={handleSubmit} className="flex flex-col flex-1 overflow-hidden">
          <div className="p-6 space-y-4 overflow-y-auto flex-1">
            {error && (
              <div className="p-3 bg-red-50 border border-red-200 rounded-xl text-red-700 text-xs flex items-start gap-2 animate-in fade-in">
                <AlertCircle size={15} className="shrink-0 mt-0.5" />
                <span>{error}</span>
              </div>
            )}

            <div>
              <label className="block text-sm font-semibold text-gray-700 mb-1.5">
                Nome completo <span className="text-red-500">*</span>
              </label>
              <input
                type="text"
                required
                value={nome}
                onChange={e => setNome(e.target.value)}
                disabled={loading}
                placeholder="Ex: João da Silva"
                className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931] transition-all bg-gray-50/50 text-sm text-gray-900 disabled:opacity-50"
              />
            </div>

            <div>
              <label className="block text-sm font-semibold text-gray-700 mb-1.5">
                WhatsApp <span className="text-red-500">*</span>
              </label>
              <input
                type="text"
                required
                value={telefone}
                onChange={e => setTelefone(e.target.value)}
                disabled={loading}
                placeholder="Ex: (11) 99999-9999 ou +5511999999999"
                className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931] transition-all bg-gray-50/50 text-sm text-gray-900 disabled:opacity-50"
              />
              <p className="text-[11px] text-gray-400 mt-1">
                Normalizado automaticamente para o formato internacional (+55).
              </p>
            </div>

            <div>
              <label className="block text-sm font-semibold text-gray-700 mb-1.5">
                Tipo de morador <span className="text-red-500">*</span>
              </label>
              <select
                value={tipo}
                onChange={e => setTipo(e.target.value)}
                disabled={loading}
                className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931] transition-all bg-gray-50/50 text-sm text-gray-900 disabled:opacity-50"
              >
                {tipo && !STANDARD_TIPO_MORADOR.includes(tipo) && (
                  <option value={tipo}>{tipo}</option>
                )}
                {STANDARD_TIPO_MORADOR.map(opt => (
                  <option key={opt} value={opt}>
                    {opt}
                  </option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-sm font-semibold text-gray-700 mb-1.5">
                Papel no sistema <span className="text-red-500">*</span>
              </label>
              <select
                value={papel}
                onChange={e => setPapel(e.target.value)}
                disabled={loading}
                className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931] transition-all bg-gray-50/50 text-sm text-gray-900 disabled:opacity-50"
              >
                {papel && !STANDARD_PAPEL_SISTEMA.some(p => p.value === papel) && (
                  <option value={papel}>{papel}</option>
                )}
                {STANDARD_PAPEL_SISTEMA.map(opt => (
                  <option key={opt.value} value={opt.value}>
                    {opt.label}
                  </option>
                ))}
              </select>
            </div>
          </div>

          {/* Footer */}
          <div className="px-6 py-4 border-t border-gray-100 bg-gray-50 flex items-center justify-end gap-3 rounded-b-3xl">
            <button
              type="button"
              onClick={onClose}
              disabled={loading}
              className="px-5 py-2.5 text-sm font-semibold text-gray-600 hover:bg-gray-200/60 rounded-xl transition-colors disabled:opacity-50"
            >
              Cancelar
            </button>
            <button
              type="submit"
              disabled={loading}
              className="px-5 py-2.5 text-sm font-semibold text-white bg-[#FC5931] hover:bg-[#e64720] rounded-xl shadow-sm transition-colors flex items-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {loading ? (
                <>
                  <Loader2 size={16} className="animate-spin" />
                  <span>Salvando...</span>
                </>
              ) : (
                <span>Salvar alterações</span>
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
