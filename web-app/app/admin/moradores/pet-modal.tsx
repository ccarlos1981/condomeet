'use client'

import { useState, useEffect } from 'react'
import { X, PawPrint, AlertCircle, Loader2 } from 'lucide-react'
import { adminCreatePet, adminUpdatePet } from '@/app/admin/actions'
import { PetData } from './[id]/resident-360-client'

interface PetModalProps {
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
  editingPet?: PetData | null
  onSuccess: () => void
}

export const ESPECIES_PET = [
  { value: 'cao', label: 'Cão' },
  { value: 'gato', label: 'Gato' },
  { value: 'ave', label: 'Ave' },
  { value: 'roedor', label: 'Roedor' },
  { value: 'reptil', label: 'Réptil' },
  { value: 'peixe', label: 'Peixe' },
  { value: 'outro', label: 'Outro' },
]

export const SEXOS_PET = [
  { value: '', label: 'Não informado' },
  { value: 'macho', label: 'Macho' },
  { value: 'femea', label: 'Fêmea' },
]

export const PORTES_PET = [
  { value: '', label: 'Não informado' },
  { value: 'pequeno', label: 'Pequeno' },
  { value: 'medio', label: 'Médio' },
  { value: 'grande', label: 'Grande' },
  { value: 'nao_se_aplica', label: 'Não se aplica' },
]

export default function PetModal({
  isOpen,
  onClose,
  profileId,
  residentName,
  activeUnits,
  editingPet,
  onSuccess,
}: PetModalProps) {
  const isEditing = Boolean(editingPet)

  // Form State
  const [selectedUnitId, setSelectedUnitId] = useState('')
  const [nome, setNome] = useState('')
  const [especie, setEspecie] = useState('cao')
  const [raca, setRaca] = useState('')
  const [sexo, setSexo] = useState('')
  const [porte, setPorte] = useState('')
  const [cor, setCor] = useState('')
  const [dataNascimento, setDataNascimento] = useState('')
  const [castrado, setCastrado] = useState<'null' | 'true' | 'false'>('null')
  const [vacinado, setVacinado] = useState<'null' | 'true' | 'false'>('null')
  const [observacao, setObservacao] = useState('')

  // Submission State
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const todayStr = new Date().toISOString().split('T')[0]

  useEffect(() => {
    if (!isOpen) return

    setError(null)
    setLoading(false)

    if (editingPet) {
      setNome(editingPet.nome || '')
      setEspecie(editingPet.especie || 'cao')
      setRaca(editingPet.raca || '')
      setSexo(editingPet.sexo || '')
      setPorte(editingPet.porte || '')
      setCor(editingPet.cor || '')
      setDataNascimento(editingPet.data_nascimento ? editingPet.data_nascimento.split('T')[0] : '')
      setCastrado(editingPet.castrado === true ? 'true' : editingPet.castrado === false ? 'false' : 'null')
      setVacinado(editingPet.vacinado === true ? 'true' : editingPet.vacinado === false ? 'false' : 'null')
      setObservacao(editingPet.observacao || '')
      setSelectedUnitId(editingPet.unidade_id || '')
    } else {
      setNome('')
      setEspecie('cao')
      setRaca('')
      setSexo('')
      setPorte('')
      setCor('')
      setDataNascimento('')
      setCastrado('null')
      setVacinado('null')
      setObservacao('')
      if (activeUnits.length > 0) {
        setSelectedUnitId(activeUnits[0].unidade_id)
      } else {
        setSelectedUnitId('')
      }
    }
  }, [isOpen, editingPet, activeUnits])

  if (!isOpen) return null

  const hasNoActiveUnit = !isEditing && activeUnits.length === 0

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (loading) return

    setError(null)

    if (!isEditing && !selectedUnitId) {
      setError('Selecione uma unidade residencial ativa para o pet.')
      return
    }

    if (!nome.trim()) {
      setError('O nome do pet é obrigatório.')
      return
    }

    if (!especie.trim()) {
      setError('A espécie do pet é obrigatória.')
      return
    }

    if (dataNascimento && dataNascimento > todayStr) {
      setError('A data de nascimento não pode estar no futuro.')
      return
    }

    setLoading(true)

    try {
      const castradoVal = castrado === 'true' ? true : castrado === 'false' ? false : null
      const vacinadoVal = vacinado === 'true' ? true : vacinado === 'false' ? false : null

      if (isEditing && editingPet) {
        const res = await adminUpdatePet({
          petId: editingPet.id,
          profileId,
          nome: nome.trim(),
          especie: especie.trim(),
          raca: raca.trim() || null,
          sexo: sexo || null,
          porte: porte || null,
          cor: cor.trim() || null,
          dataNascimento: dataNascimento || null,
          castrado: castradoVal,
          vacinado: vacinadoVal,
          observacao: observacao.trim() || null,
        })

        if (res.error) {
          setError(res.error)
          setLoading(false)
          return
        }
      } else {
        const res = await adminCreatePet({
          profileId,
          unidadeId: selectedUnitId,
          nome: nome.trim(),
          especie: especie.trim(),
          raca: raca.trim() || null,
          sexo: sexo || null,
          porte: porte || null,
          cor: cor.trim() || null,
          dataNascimento: dataNascimento || null,
          castrado: castradoVal,
          vacinado: vacinadoVal,
          observacao: observacao.trim() || null,
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
      setError(err instanceof Error ? err.message : 'Erro ao processar pet.')
      setLoading(false)
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm animate-in fade-in duration-200">
      <div className="bg-white rounded-2xl shadow-xl w-full max-w-lg overflow-hidden border border-gray-100 flex flex-col max-h-[90vh]">
        {/* Header */}
        <div className="px-6 py-4 border-b border-gray-100 flex items-center justify-between bg-gray-50/50">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-orange-100 flex items-center justify-center text-[#FC5931]">
              <PawPrint size={20} />
            </div>
            <div>
              <h3 className="font-bold text-gray-900 text-base">
                {isEditing ? 'Editar Pet' : 'Adicionar Pet'}
              </h3>
              <p className="text-xs text-gray-500">
                Tutor: <span className="font-semibold text-gray-700">{residentName}</span>
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            disabled={loading}
            className="text-gray-400 hover:text-gray-600 p-2 rounded-lg hover:bg-gray-100 transition-colors"
          >
            <X size={18} />
          </button>
        </div>

        {/* Form Body */}
        <form onSubmit={handleSubmit} className="flex-1 overflow-y-auto p-6 space-y-4">
          {error && (
            <div className="p-3.5 bg-red-50 border border-red-200 rounded-xl flex items-start gap-2.5 text-xs text-red-700 animate-in fade-in">
              <AlertCircle size={16} className="text-red-500 shrink-0 mt-0.5" />
              <div className="flex-1 font-medium">{error}</div>
            </div>
          )}

          {hasNoActiveUnit && (
            <div className="p-3.5 bg-amber-50 border border-amber-200 rounded-xl flex items-start gap-2.5 text-xs text-amber-800">
              <AlertCircle size={16} className="text-amber-600 shrink-0 mt-0.5" />
              <div>
                <strong>Atenção:</strong> Este morador não possui vínculos residenciais ativos no condomínio. Cadastre ou aprove um vínculo de moradia antes de adicionar pets.
              </div>
            </div>
          )}

          {/* Unidade Residencial */}
          {!isEditing && (
            <div>
              <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">
                Unidade Residencial <span className="text-red-500">*</span>
              </label>
              {activeUnits.length === 1 ? (
                <div className="px-3.5 py-2.5 rounded-xl border border-gray-200 bg-gray-50 text-sm font-semibold text-gray-800">
                  {activeUnits[0].bloco_nome ? `Bloco ${activeUnits[0].bloco_nome} · ` : ''}
                  Apto {activeUnits[0].apto_numero || 'S/N'}
                </div>
              ) : activeUnits.length > 1 ? (
                <select
                  value={selectedUnitId}
                  onChange={(e) => setSelectedUnitId(e.target.value)}
                  disabled={loading}
                  className="w-full px-3.5 py-2.5 rounded-xl border border-gray-200 text-sm font-medium focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931] outline-none transition-all"
                  required
                >
                  {activeUnits.map((u) => (
                    <option key={u.unidade_id} value={u.unidade_id}>
                      {u.bloco_nome ? `Bloco ${u.bloco_nome} · ` : ''}Apto {u.apto_numero || 'S/N'}
                    </option>
                  ))}
                </select>
              ) : (
                <div className="px-3.5 py-2.5 rounded-xl border border-red-200 bg-red-50 text-xs text-red-600">
                  Nenhuma unidade ativa disponível.
                </div>
              )}
            </div>
          )}

          {isEditing && (
            <div className="bg-gray-50 border border-gray-100 rounded-xl p-3 text-xs text-gray-500 flex items-center justify-between">
              <span>
                Unidade vinculada: <strong>{editingPet?.unidade_bloco ? `Bloco ${editingPet.unidade_bloco} · ` : ''}Apto {editingPet?.unidade_apto || 'S/N'}</strong>
              </span>
              <span className="text-[11px] text-gray-400">
                (Para alterar a unidade, utilize a ação específica)
              </span>
            </div>
          )}

          {/* Nome e Espécie */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
            <div>
              <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">
                Nome do Pet <span className="text-red-500">*</span>
              </label>
              <input
                type="text"
                placeholder="Ex: Nina, Thor, Mel"
                value={nome}
                onChange={(e) => setNome(e.target.value)}
                disabled={loading}
                className="w-full px-3.5 py-2.5 rounded-xl border border-gray-200 text-sm font-medium focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931] outline-none transition-all"
                required
              />
            </div>

            <div>
              <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">
                Espécie <span className="text-red-500">*</span>
              </label>
              <select
                value={especie}
                onChange={(e) => setEspecie(e.target.value)}
                disabled={loading}
                className="w-full px-3.5 py-2.5 rounded-xl border border-gray-200 text-sm font-medium focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931] outline-none transition-all"
                required
              >
                {ESPECIES_PET.map((sp) => (
                  <option key={sp.value} value={sp.value}>
                    {sp.label}
                  </option>
                ))}
              </select>
            </div>
          </div>

          {/* Raça e Cor */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
            <div>
              <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">
                Raça <span className="text-gray-400 font-normal">(Opcional)</span>
              </label>
              <input
                type="text"
                placeholder="Ex: Golden, Siamês, SRD"
                value={raca}
                onChange={(e) => setRaca(e.target.value)}
                disabled={loading}
                className="w-full px-3.5 py-2.5 rounded-xl border border-gray-200 text-sm font-medium focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931] outline-none transition-all"
              />
            </div>

            <div>
              <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">
                Cor / Pelagem <span className="text-gray-400 font-normal">(Opcional)</span>
              </label>
              <input
                type="text"
                placeholder="Ex: Dourado, Preto, Branco"
                value={cor}
                onChange={(e) => setCor(e.target.value)}
                disabled={loading}
                className="w-full px-3.5 py-2.5 rounded-xl border border-gray-200 text-sm font-medium focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931] outline-none transition-all"
              />
            </div>
          </div>

          {/* Sexo e Porte */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
            <div>
              <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">
                Sexo <span className="text-gray-400 font-normal">(Opcional)</span>
              </label>
              <select
                value={sexo}
                onChange={(e) => setSexo(e.target.value)}
                disabled={loading}
                className="w-full px-3.5 py-2.5 rounded-xl border border-gray-200 text-sm font-medium focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931] outline-none transition-all"
              >
                {SEXOS_PET.map((s) => (
                  <option key={s.value} value={s.value}>
                    {s.label}
                  </option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">
                Porte <span className="text-gray-400 font-normal">(Opcional)</span>
              </label>
              <select
                value={porte}
                onChange={(e) => setPorte(e.target.value)}
                disabled={loading}
                className="w-full px-3.5 py-2.5 rounded-xl border border-gray-200 text-sm font-medium focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931] outline-none transition-all"
              >
                {PORTES_PET.map((p) => (
                  <option key={p.value} value={p.value}>
                    {p.label}
                  </option>
                ))}
              </select>
            </div>
          </div>

          {/* Data de Nascimento */}
          <div>
            <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">
              Data de Nascimento <span className="text-gray-400 font-normal">(Opcional)</span>
            </label>
            <input
              type="date"
              max={todayStr}
              value={dataNascimento}
              onChange={(e) => setDataNascimento(e.target.value)}
              disabled={loading}
              className="w-full px-3.5 py-2.5 rounded-xl border border-gray-200 text-sm font-medium focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931] outline-none transition-all"
            />
          </div>

          {/* Castrado e Vacinado (Tri-state) */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5 pt-1">
            <div>
              <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">
                Castrado?
              </label>
              <div className="grid grid-cols-3 gap-1 bg-gray-100 p-1 rounded-xl text-xs font-semibold">
                <button
                  type="button"
                  onClick={() => setCastrado('null')}
                  className={`py-1.5 rounded-lg transition-all ${castrado === 'null' ? 'bg-white shadow-sm text-gray-800' : 'text-gray-500 hover:text-gray-800'}`}
                >
                  N/I
                </button>
                <button
                  type="button"
                  onClick={() => setCastrado('true')}
                  className={`py-1.5 rounded-lg transition-all ${castrado === 'true' ? 'bg-white shadow-sm text-emerald-700 font-bold' : 'text-gray-500 hover:text-gray-800'}`}
                >
                  Sim
                </button>
                <button
                  type="button"
                  onClick={() => setCastrado('false')}
                  className={`py-1.5 rounded-lg transition-all ${castrado === 'false' ? 'bg-white shadow-sm text-zinc-700 font-bold' : 'text-gray-500 hover:text-gray-800'}`}
                >
                  Não
                </button>
              </div>
            </div>

            <div>
              <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">
                Vacinado?
              </label>
              <div className="grid grid-cols-3 gap-1 bg-gray-100 p-1 rounded-xl text-xs font-semibold">
                <button
                  type="button"
                  onClick={() => setVacinado('null')}
                  className={`py-1.5 rounded-lg transition-all ${vacinado === 'null' ? 'bg-white shadow-sm text-gray-800' : 'text-gray-500 hover:text-gray-800'}`}
                >
                  N/I
                </button>
                <button
                  type="button"
                  onClick={() => setVacinado('true')}
                  className={`py-1.5 rounded-lg transition-all ${vacinado === 'true' ? 'bg-white shadow-sm text-emerald-700 font-bold' : 'text-gray-500 hover:text-gray-800'}`}
                >
                  Sim
                </button>
                <button
                  type="button"
                  onClick={() => setVacinado('false')}
                  className={`py-1.5 rounded-lg transition-all ${vacinado === 'false' ? 'bg-white shadow-sm text-zinc-700 font-bold' : 'text-gray-500 hover:text-gray-800'}`}
                >
                  Não
                </button>
              </div>
            </div>
          </div>

          {/* Observações */}
          <div>
            <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">
              Observações <span className="text-gray-400 font-normal">(Opcional)</span>
            </label>
            <textarea
              rows={2}
              placeholder="Ex: Dócil com crianças, assustado com barulho, usa coleira peitoral."
              value={observacao}
              onChange={(e) => setObservacao(e.target.value)}
              disabled={loading}
              className="w-full px-3.5 py-2.5 rounded-xl border border-gray-200 text-sm font-medium focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931] outline-none transition-all resize-none"
            />
          </div>

          {/* Footer Actions */}
          <div className="pt-3 border-t border-gray-100 flex items-center justify-end gap-2.5">
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
              className="px-5 py-2 rounded-xl text-xs font-bold text-white bg-[#FC5931] hover:bg-[#FC5931]/90 transition-all shadow-sm flex items-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {loading ? (
                <>
                  <Loader2 size={14} className="animate-spin" />
                  Salvando...
                </>
              ) : isEditing ? (
                'Salvar Alterações'
              ) : (
                'Cadastrar Pet'
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
