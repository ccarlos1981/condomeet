'use client'

import { useState, useEffect } from 'react'
import { X, Car, AlertCircle, Loader2 } from 'lucide-react'
import { adminCreateVehicle, adminUpdateVehicle } from '@/app/admin/actions'
import { VehicleData } from './[id]/resident-360-client'

interface VehicleModalProps {
  isOpen: boolean
  onClose: () => void
  profileId: string
  residentName: string
  activeUnits: Array<{
    id: string
    unidade_id: string
    bloco_nome?: string | null
    apto_numero?: string | null
  }>
  editingVehicle?: VehicleData | null
  onSuccess: () => void
}

const TIPOS_VEICULO = [
  { value: 'carro', label: 'Carro' },
  { value: 'moto', label: 'Moto' },
  { value: 'utilitario', label: 'Utilitário' },
  { value: 'outro', label: 'Outro' },
]

export default function VehicleModal({
  isOpen,
  onClose,
  profileId,
  residentName,
  activeUnits,
  editingVehicle,
  onSuccess,
}: VehicleModalProps) {
  const isEditing = Boolean(editingVehicle)

  // Form State
  const [placa, setPlaca] = useState('')
  const [tipo, setTipo] = useState('carro')
  const [marca, setMarca] = useState('')
  const [modelo, setModelo] = useState('')
  const [cor, setCor] = useState('')
  const [ano, setAno] = useState<string>('')
  const [vagaNumero, setVagaNumero] = useState('')
  const [observacao, setObservacao] = useState('')
  const [selectedUnitId, setSelectedUnitId] = useState('')

  // Submission State
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  // Initialize form on open
  useEffect(() => {
    if (!isOpen) return

    setError(null)
    setLoading(false)

    if (editingVehicle) {
      setPlaca(editingVehicle.placa || '')
      setTipo(editingVehicle.tipo || 'carro')
      setMarca(editingVehicle.marca || '')
      setModelo(editingVehicle.modelo || '')
      setCor(editingVehicle.cor || '')
      setAno(editingVehicle.ano ? String(editingVehicle.ano) : '')
      setVagaNumero(editingVehicle.vaga_numero || '')
      setObservacao(editingVehicle.observacao || '')
      setSelectedUnitId(editingVehicle.unidade_id || '')
    } else {
      setPlaca('')
      setTipo('carro')
      setMarca('')
      setModelo('')
      setCor('')
      setAno('')
      setVagaNumero('')
      setObservacao('')
      if (activeUnits.length === 1) {
        setSelectedUnitId(activeUnits[0].unidade_id)
      } else if (activeUnits.length > 1) {
        setSelectedUnitId(activeUnits[0].unidade_id)
      } else {
        setSelectedUnitId('')
      }
    }
  }, [isOpen, editingVehicle, activeUnits])

  if (!isOpen) return null

  const hasNoActiveUnit = !isEditing && activeUnits.length === 0

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (loading) return

    setError(null)

    if (hasNoActiveUnit) {
      setError('Este morador não possui vínculo residencial ativo.')
      return
    }

    if (!isEditing && !selectedUnitId) {
      setError('Selecione uma unidade residencial para o veículo.')
      return
    }

    if (!isEditing && !placa.trim()) {
      setError('A placa do veículo é obrigatória.')
      return
    }

    if (!marca.trim()) {
      setError('A marca do veículo é obrigatória.')
      return
    }

    if (!modelo.trim()) {
      setError('O modelo do veículo é obrigatório.')
      return
    }

    if (!cor.trim()) {
      setError('A cor do veículo é obrigatória.')
      return
    }

    const parsedAno = ano.trim() ? parseInt(ano.trim(), 10) : null
    if (parsedAno !== null && (isNaN(parsedAno) || parsedAno < 1900 || parsedAno > new Date().getFullYear() + 2)) {
      setError('Ano do veículo inválido.')
      return
    }

    setLoading(true)

    try {
      if (isEditing && editingVehicle) {
        const res = await adminUpdateVehicle({
          veiculoId: editingVehicle.id,
          profileId,
          tipo,
          marca: marca.trim(),
          modelo: modelo.trim(),
          cor: cor.trim(),
          ano: parsedAno,
          observacao: observacao.trim() || null,
          vagaNumero: vagaNumero.trim() || null,
        })

        if (res.error) {
          setError(res.error)
          setLoading(false)
          return
        }
      } else {
        const res = await adminCreateVehicle({
          profileId,
          unidadeId: selectedUnitId,
          placa: placa.trim(),
          tipo,
          marca: marca.trim(),
          modelo: modelo.trim(),
          cor: cor.trim(),
          ano: parsedAno,
          observacao: observacao.trim() || null,
          vagaNumero: vagaNumero.trim() || null,
        })

        if (res.error) {
          setError(res.error)
          setLoading(false)
          return
        }
      }

      onSuccess()
      onClose()
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Erro ao salvar veículo.')
      setLoading(false)
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-xs">
      <div className="bg-white rounded-2xl shadow-xl w-full max-w-lg max-h-[90vh] flex flex-col overflow-hidden animate-in fade-in zoom-in-95 duration-200">
        {/* Header */}
        <div className="p-6 border-b border-gray-100 flex items-center justify-between shrink-0">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-orange-50 text-[#FC5931] flex items-center justify-center">
              <Car size={20} />
            </div>
            <div>
              <h2 className="text-base font-bold text-gray-900">
                {isEditing ? 'Editar Veículo' : 'Adicionar Veículo'}
              </h2>
              <p className="text-xs text-gray-500">
                Morador: <span className="font-semibold text-gray-700">{residentName}</span>
              </p>
            </div>
          </div>
          <button
            type="button"
            onClick={onClose}
            disabled={loading}
            className="text-gray-400 hover:text-gray-600 p-1 rounded-lg hover:bg-gray-50 transition-colors"
          >
            <X size={18} />
          </button>
        </div>

        {/* Form Body */}
        <form onSubmit={handleSubmit} className="flex-1 overflow-y-auto p-6 space-y-4">
          {error && (
            <div className="p-3.5 rounded-xl bg-red-50 border border-red-200 flex items-start gap-2.5 text-xs text-red-700">
              <AlertCircle size={16} className="shrink-0 mt-0.5 text-red-600" />
              <span>{error}</span>
            </div>
          )}

          {hasNoActiveUnit && (
            <div className="p-3.5 rounded-xl bg-amber-50 border border-amber-200 flex items-start gap-2.5 text-xs text-amber-800">
              <AlertCircle size={16} className="shrink-0 mt-0.5 text-amber-600" />
              <span>
                Este morador não possui vínculo residencial ativo. Cadastre ou aprove um vínculo residencial antes de adicionar veículos.
              </span>
            </div>
          )}

          {/* Unidade Residencial */}
          <div>
            <label className="block text-xs font-semibold text-gray-700 mb-1">
              Unidade Residencial {isEditing ? '' : '*'}
            </label>
            {isEditing ? (
              <div className="px-3.5 py-2 rounded-xl bg-gray-50 border border-gray-200 text-xs text-gray-700">
                {editingVehicle?.unidade_bloco ? `Bloco ${editingVehicle.unidade_bloco} · ` : ''}
                {editingVehicle?.unidade_apto ? `Apto ${editingVehicle.unidade_apto}` : 'Unidade vinculada'}
              </div>
            ) : activeUnits.length === 1 ? (
              <div className="px-3.5 py-2 rounded-xl bg-emerald-50/70 border border-emerald-200/80 text-xs text-emerald-800 flex items-center justify-between">
                <span>
                  {activeUnits[0].bloco_nome ? `Bloco ${activeUnits[0].bloco_nome} · ` : ''}
                  {activeUnits[0].apto_numero ? `Apto ${activeUnits[0].apto_numero}` : 'Unidade ativa'}
                </span>
                <span className="text-[11px] font-semibold text-emerald-700">Vínculo Ativo</span>
              </div>
            ) : activeUnits.length > 1 ? (
              <select
                value={selectedUnitId}
                onChange={e => setSelectedUnitId(e.target.value)}
                disabled={loading}
                className="w-full text-xs rounded-xl border border-gray-200 p-2.5 bg-white text-gray-800 focus:outline-hidden focus:border-[#FC5931]"
              >
                {activeUnits.map(u => (
                  <option key={u.unidade_id} value={u.unidade_id}>
                    {u.bloco_nome ? `Bloco ${u.bloco_nome} · ` : ''}
                    {u.apto_numero ? `Apto ${u.apto_numero}` : u.unidade_id}
                  </option>
                ))}
              </select>
            ) : (
              <div className="text-xs text-gray-400 italic">Nenhum vínculo ativo encontrado.</div>
            )}
          </div>

          {/* Placa & Tipo */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-semibold text-gray-700 mb-1">
                Placa {isEditing ? '(Somente leitura)' : '*'}
              </label>
              {isEditing ? (
                <div className="px-3.5 py-2 rounded-xl bg-gray-100 border border-gray-200 font-mono text-xs font-bold text-gray-800">
                  {editingVehicle?.placa}
                </div>
              ) : (
                <input
                  type="text"
                  value={placa}
                  onChange={e => setPlaca(e.target.value.toUpperCase())}
                  disabled={loading || hasNoActiveUnit}
                  placeholder="Ex: ABC-1234 ou ABC1D23"
                  className="w-full text-xs rounded-xl border border-gray-200 p-2.5 font-mono uppercase bg-white text-gray-800 focus:outline-hidden focus:border-[#FC5931]"
                  maxLength={8}
                />
              )}
              {isEditing && (
                <p className="text-[11px] text-gray-400 mt-1">
                  Para retificar erro de placa, use a ação &quot;Corrigir placa&quot;.
                </p>
              )}
            </div>

            <div>
              <label className="block text-xs font-semibold text-gray-700 mb-1">
                Tipo *
              </label>
              <select
                value={tipo}
                onChange={e => setTipo(e.target.value)}
                disabled={loading || hasNoActiveUnit}
                className="w-full text-xs rounded-xl border border-gray-200 p-2.5 bg-white text-gray-800 focus:outline-hidden focus:border-[#FC5931]"
              >
                {TIPOS_VEICULO.map(t => (
                  <option key={t.value} value={t.value}>
                    {t.label}
                  </option>
                ))}
              </select>
            </div>
          </div>

          {/* Marca & Modelo */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-semibold text-gray-700 mb-1">
                Marca *
              </label>
              <input
                type="text"
                value={marca}
                onChange={e => setMarca(e.target.value)}
                disabled={loading || hasNoActiveUnit}
                placeholder="Ex: Toyota, Honda, Fiat"
                className="w-full text-xs rounded-xl border border-gray-200 p-2.5 bg-white text-gray-800 focus:outline-hidden focus:border-[#FC5931]"
              />
            </div>

            <div>
              <label className="block text-xs font-semibold text-gray-700 mb-1">
                Modelo *
              </label>
              <input
                type="text"
                value={modelo}
                onChange={e => setModelo(e.target.value)}
                disabled={loading || hasNoActiveUnit}
                placeholder="Ex: Corolla, Civic, Onix"
                className="w-full text-xs rounded-xl border border-gray-200 p-2.5 bg-white text-gray-800 focus:outline-hidden focus:border-[#FC5931]"
              />
            </div>
          </div>

          {/* Cor, Ano & Vaga */}
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
            <div>
              <label className="block text-xs font-semibold text-gray-700 mb-1">
                Cor *
              </label>
              <input
                type="text"
                value={cor}
                onChange={e => setCor(e.target.value)}
                disabled={loading || hasNoActiveUnit}
                placeholder="Ex: Prata, Preto"
                className="w-full text-xs rounded-xl border border-gray-200 p-2.5 bg-white text-gray-800 focus:outline-hidden focus:border-[#FC5931]"
              />
            </div>

            <div>
              <label className="block text-xs font-semibold text-gray-700 mb-1">
                Ano <span className="text-gray-400 font-normal">(opcional)</span>
              </label>
              <input
                type="number"
                value={ano}
                onChange={e => setAno(e.target.value)}
                disabled={loading || hasNoActiveUnit}
                placeholder="Ex: 2022"
                min={1900}
                max={new Date().getFullYear() + 2}
                className="w-full text-xs rounded-xl border border-gray-200 p-2.5 bg-white text-gray-800 focus:outline-hidden focus:border-[#FC5931]"
              />
            </div>

            <div>
              <label className="block text-xs font-semibold text-gray-700 mb-1">
                Vaga <span className="text-gray-400 font-normal">(opcional)</span>
              </label>
              <input
                type="text"
                value={vagaNumero}
                onChange={e => setVagaNumero(e.target.value)}
                disabled={loading || hasNoActiveUnit}
                placeholder="Ex: G1-01"
                className="w-full text-xs rounded-xl border border-gray-200 p-2.5 bg-white text-gray-800 focus:outline-hidden focus:border-[#FC5931]"
              />
            </div>
          </div>

          {/* Observação */}
          <div>
            <label className="block text-xs font-semibold text-gray-700 mb-1">
              Observação <span className="text-gray-400 font-normal">(opcional)</span>
            </label>
            <textarea
              value={observacao}
              onChange={e => setObservacao(e.target.value)}
              disabled={loading || hasNoActiveUnit}
              rows={2}
              placeholder="Notas internas da administração sobre o veículo..."
              className="w-full text-xs rounded-xl border border-gray-200 p-2.5 bg-white text-gray-800 focus:outline-hidden focus:border-[#FC5931]"
            />
          </div>

          {/* Footer Actions */}
          <div className="pt-2 flex items-center justify-end gap-2 border-t border-gray-100">
            <button
              type="button"
              onClick={onClose}
              disabled={loading}
              className="px-4 py-2 rounded-xl text-xs font-semibold text-gray-600 hover:bg-gray-100 transition-colors"
            >
              Cancelar
            </button>
            <button
              type="submit"
              disabled={loading || hasNoActiveUnit}
              className="inline-flex items-center gap-1.5 px-5 py-2.5 rounded-xl bg-[#FC5931] hover:bg-[#e04820] text-white text-xs font-semibold transition-colors disabled:opacity-50 disabled:cursor-not-allowed shadow-2xs"
            >
              {loading && <Loader2 size={14} className="animate-spin" />}
              {isEditing ? 'Salvar Alterações' : 'Cadastrar Veículo'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
