'use client'

import { useState, useEffect, useMemo } from 'react'
import {
  AlertTriangle,
  X,
  Calendar,
  Home,
  CheckCircle,
  HelpCircle,
  Clock,
  Ticket,
  CalendarRange,
  Loader2,
  ShieldAlert,
} from 'lucide-react'
import { adminGetInactivationContext, adminInactivateResident } from '@/app/admin/actions'
import { getBlocoLabel, getAptoLabel } from '@/lib/labels'

interface InactiveModalProps {
  isOpen: boolean
  onClose: () => void
  profileId: string
  residentName: string
  tipoEstrutura?: string
  initialActiveUnits?: Array<{
    id: string
    bloco?: string | null
    apto?: string | null
    data_entrada?: string | null
  }>
  onSuccess: (result: any) => void
}

const MOTIVOS_PADRAO = [
  'Mudança / Desocupação do imóvel',
  'Venda do imóvel',
  'Término de contrato de locação',
  'Encerramento de vínculo familiar / dependência',
  'Outro motivo',
]

export default function InactivateConfirmModal({
  isOpen,
  onClose,
  profileId,
  residentName,
  tipoEstrutura = 'predio',
  initialActiveUnits,
  onSuccess,
}: InactiveModalProps) {
  const blocoLabel = getBlocoLabel(tipoEstrutura)
  const aptoLabel = getAptoLabel(tipoEstrutura)

  // Loading do contexto inicial
  const [loadingContext, setLoadingContext] = useState(true)
  const [contextError, setContextError] = useState<string | null>(null)

  // Dados do morador e alertas READ-ONLY
  const [activeUnits, setActiveUnits] = useState<
    Array<{ id: string; bloco?: string; apto?: string; data_entrada?: string }>
  >([])
  const [futureReservas, setFutureReservas] = useState<
    Array<{ id: string; data_reserva: string; status: string; area_nome: string }>
  >([])
  const [futureConvites, setFutureConvites] = useState<
    Array<{ id: string; guest_name: string; visitor_type: string; validity_date: string; status: string }>
  >([])
  const [isProprietario, setIsProprietario] = useState(false)

  // Campos do formulário
  const [selectedVinculoId, setSelectedVinculoId] = useState<string>('')
  const [dataSaida, setDataSaida] = useState<string>(() => {
    return new Date().toISOString().split('T')[0]
  })
  const [motivoSelecionado, setMotivoSelecionado] = useState<string>(MOTIVOS_PADRAO[0])
  const [motivoCustomizado, setMotivoCustomizado] = useState<string>('')
  const [continuaProprietario, setContinuaProprietario] = useState<boolean>(false)

  // Estados de submissão e erro
  const [submitting, setSubmitting] = useState(false)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  // Buscar dados de contexto ao abrir o modal
  useEffect(() => {
    let isMounted = true

    async function loadData() {
      if (!isOpen || !profileId) return
      setLoadingContext(true)
      setContextError(null)
      setErrorMessage(null)

      try {
        const res = await adminGetInactivationContext(profileId)
        if (!isMounted) return

        if (res.error) {
          setContextError(res.error)
          setLoadingContext(false)
          return
        }

        const units = res.activeLinks ?? []
        setActiveUnits(units)
        if (units.length > 0) {
          setSelectedVinculoId(units[0].id)
        }

        setFutureReservas(res.futureReservas ?? [])
        setFutureConvites(res.futureConvites ?? [])
        setIsProprietario(!!res.isProprietario)
        setLoadingContext(false)
      } catch (err: any) {
        if (!isMounted) return
        setContextError('Não foi possível obter os dados do morador. Tente novamente.')
        setLoadingContext(false)
      }
    }

    loadData()
    return () => {
      isMounted = false
    }
  }, [isOpen, profileId])

  // Vinculo atualmente selecionado
  const selectedUnit = useMemo(() => {
    return activeUnits.find(u => u.id === selectedVinculoId) || activeUnits[0]
  }, [activeUnits, selectedVinculoId])

  // Validação em tempo real
  const validationError = useMemo(() => {
    if (!selectedVinculoId && activeUnits.length > 0) {
      return 'Selecione a unidade a ser inativada.'
    }
    if (!dataSaida) {
      return 'Informe a data de saída.'
    }
    const today = new Date().toISOString().split('T')[0]
    if (dataSaida > today) {
      return 'A data de saída não pode ser futura.'
    }
    if (selectedUnit?.data_entrada) {
      const entradaYmd = selectedUnit.data_entrada.split('T')[0]
      if (dataSaida < entradaYmd) {
        return `A data de saída não pode ser anterior à data de entrada (${new Date(selectedUnit.data_entrada).toLocaleDateString('pt-BR')}).`
      }
    }
    if (!motivoSelecionado) {
      return 'Selecione o motivo da inativação.'
    }
    if (motivoSelecionado === 'Outro motivo' && !motivoCustomizado.trim()) {
      return 'Descreva o motivo no campo de texto.'
    }
    return null
  }, [selectedVinculoId, activeUnits, dataSaida, selectedUnit, motivoSelecionado, motivoCustomizado])

  async function handleConfirm() {
    if (validationError) {
      setErrorMessage(validationError)
      return
    }

    if (!selectedVinculoId) {
      setErrorMessage('Nenhum vínculo imobiliário ativo disponível para inativação.')
      return
    }

    setSubmitting(true)
    setErrorMessage(null)

    const finalMotivo =
      motivoSelecionado === 'Outro motivo'
        ? `Outro: ${motivoCustomizado.trim()}`
        : motivoSelecionado

    try {
      const res = await adminInactivateResident({
        profileId,
        vinculoId: selectedVinculoId,
        dataSaida,
        motivo: finalMotivo,
        continuaProprietario: isProprietario ? continuaProprietario : false,
      })

      if (res.error) {
        setErrorMessage(res.error)
        setSubmitting(false)
        return
      }

      setSubmitting(false)
      onSuccess(res.result)
      onClose()
    } catch (err: any) {
      setErrorMessage('Erro de comunicação ao inativar morador. Tente novamente.')
      setSubmitting(false)
    }
  }

  if (!isOpen) return null

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-xs animate-in fade-in duration-200">
      <div
        className="bg-white rounded-2xl shadow-xl border border-gray-200 w-full max-w-lg overflow-hidden flex flex-col max-h-[90vh]"
        onClick={e => e.stopPropagation()}
      >
        {/* Header */}
        <div className="px-6 py-5 border-b border-gray-100 flex items-center justify-between bg-zinc-50/50">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-red-100 text-red-600 flex items-center justify-center shrink-0">
              <AlertTriangle size={20} />
            </div>
            <div>
              <h2 className="text-base font-bold text-gray-900 leading-tight">
                Inativar Vínculo de Morador
              </h2>
              <p className="text-xs text-gray-500 mt-0.5">
                Desocupação de unidade e encerramento de moradia
              </p>
            </div>
          </div>
          <button
            type="button"
            disabled={submitting}
            onClick={onClose}
            className="p-1.5 rounded-lg text-gray-400 hover:text-gray-600 hover:bg-gray-100 transition-colors disabled:opacity-50"
            title="Fechar"
          >
            <X size={18} />
          </button>
        </div>

        {/* Body (scrollable) */}
        <div className="px-6 py-5 overflow-y-auto space-y-4 text-xs sm:text-sm">
          {/* Target resident name */}
          <div className="p-3 bg-zinc-50 rounded-xl border border-zinc-200 flex items-center justify-between">
            <span className="text-gray-500 font-medium">Morador alvo:</span>
            <span className="font-bold text-gray-900">{residentName}</span>
          </div>

          {loadingContext ? (
            <div className="py-12 flex flex-col items-center justify-center text-gray-400 gap-2">
              <Loader2 size={24} className="animate-spin text-[#FC5931]" />
              <span className="text-xs">Consultando vínculos e compromissos futuros...</span>
            </div>
          ) : contextError ? (
            <div className="p-4 bg-red-50 border border-red-200 rounded-xl text-red-700 text-xs">
              <p className="font-semibold mb-1">Falha na verificação</p>
              <p>{contextError}</p>
            </div>
          ) : (
            <>
              {/* READ-ONLY ALERT: Reservas Futuras */}
              {futureReservas.length > 0 && (
                <div className="p-3.5 bg-amber-50/80 border border-amber-200 rounded-xl text-amber-900 space-y-2">
                  <div className="flex items-start gap-2">
                    <CalendarRange size={16} className="text-amber-600 shrink-0 mt-0.5" />
                    <div>
                      <p className="font-semibold text-xs text-amber-900">
                        {futureReservas.length} reserva(s) futura(s) cadastrada(s)
                      </p>
                      <p className="text-[11px] text-amber-800 leading-relaxed mt-0.5">
                        A inativação não cancela reservas automaticamente. Acesse o módulo de Reservas se desejar liberá-las para outros moradores.
                      </p>
                    </div>
                  </div>
                  <div className="bg-white/80 rounded-lg p-2 border border-amber-100 max-h-24 overflow-y-auto space-y-1">
                    {futureReservas.map(r => (
                      <div key={r.id} className="text-[11px] flex justify-between items-center text-gray-700">
                        <span>{r.area_nome}</span>
                        <span className="font-medium text-gray-500">
                          {new Date(r.data_reserva + 'T12:00:00').toLocaleDateString('pt-BR')}
                        </span>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* READ-ONLY ALERT: Convites Futuros / Ativos */}
              {futureConvites.length > 0 && (
                <div className="p-3.5 bg-sky-50/80 border border-sky-200 rounded-xl text-sky-900 space-y-2">
                  <div className="flex items-start gap-2">
                    <Ticket size={16} className="text-sky-600 shrink-0 mt-0.5" />
                    <div>
                      <p className="font-semibold text-xs text-sky-900">
                        {futureConvites.length} convite(s) ativo(s) ou futuro(s)
                      </p>
                      <p className="text-[11px] text-sky-800 leading-relaxed mt-0.5">
                        A inativação não revoga convites automaticamente. O acesso de portaria pode ser gerenciado no módulo de Convites.
                      </p>
                    </div>
                  </div>
                  <div className="bg-white/80 rounded-lg p-2 border border-sky-100 max-h-24 overflow-y-auto space-y-1">
                    {futureConvites.map(c => (
                      <div key={c.id} className="text-[11px] flex justify-between items-center text-gray-700">
                        <span className="truncate pr-2">{c.guest_name}</span>
                        <span className="font-medium text-gray-500 shrink-0">
                          {c.validity_date ? new Date(c.validity_date).toLocaleDateString('pt-BR') : 'Sem data'}
                        </span>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* Seleção / Exibição da Unidade */}
              <div>
                <label className="text-xs font-semibold text-gray-700 block mb-1">
                  Unidade a ser inativada
                </label>
                {activeUnits.length === 0 ? (
                  <div className="p-3 bg-red-50 border border-red-200 rounded-xl text-red-700 text-xs flex items-center gap-2">
                    <ShieldAlert size={16} />
                    <span>Nenhum vínculo imobiliário ativo encontrado para este perfil.</span>
                  </div>
                ) : activeUnits.length === 1 ? (
                  <div className="p-3 bg-white rounded-xl border border-gray-200 flex items-center justify-between text-xs text-gray-700">
                    <div className="flex items-center gap-2">
                      <Home size={15} className="text-gray-400" />
                      <span className="font-semibold text-gray-900">
                        {blocoLabel} {activeUnits[0].bloco || '—'} · {aptoLabel} {activeUnits[0].apto || '—'}
                      </span>
                    </div>
                    {activeUnits[0].data_entrada && (
                      <span className="text-gray-500 text-[11px]">
                        Entrada: {new Date(activeUnits[0].data_entrada).toLocaleDateString('pt-BR')}
                      </span>
                    )}
                  </div>
                ) : (
                  <select
                    disabled={submitting}
                    value={selectedVinculoId}
                    onChange={e => setSelectedVinculoId(e.target.value)}
                    className="w-full px-3 py-2 text-xs rounded-xl border border-gray-200 bg-white focus:outline-none focus:ring-2 focus:ring-red-500/20 focus:border-red-500 shadow-2xs"
                  >
                    {activeUnits.map(u => (
                      <option key={u.id} value={u.id}>
                        {blocoLabel} {u.bloco || '—'} · {aptoLabel} {u.apto || '—'}
                        {u.data_entrada ? ` (desde ${new Date(u.data_entrada).toLocaleDateString('pt-BR')})` : ''}
                      </option>
                    ))}
                  </select>
                )}
              </div>

              {/* Data de Saída */}
              <div>
                <label className="text-xs font-semibold text-gray-700 block mb-1">
                  Data de saída do imóvel
                </label>
                <div className="relative">
                  <input
                    type="date"
                    disabled={submitting}
                    max={new Date().toISOString().split('T')[0]}
                    value={dataSaida}
                    onChange={e => setDataSaida(e.target.value)}
                    className="w-full px-3 py-2 text-xs rounded-xl border border-gray-200 bg-white focus:outline-none focus:ring-2 focus:ring-red-500/20 focus:border-red-500 shadow-2xs"
                  />
                </div>
                <p className="text-[10px] text-gray-400 mt-1">
                  Não é permitida data futura nem anterior à data de entrada no imóvel.
                </p>
              </div>

              {/* Motivo da Inativação */}
              <div>
                <label className="text-xs font-semibold text-gray-700 block mb-1">
                  Motivo da inativação
                </label>
                <select
                  disabled={submitting}
                  value={motivoSelecionado}
                  onChange={e => setMotivoSelecionado(e.target.value)}
                  className="w-full px-3 py-2 text-xs rounded-xl border border-gray-200 bg-white focus:outline-none focus:ring-2 focus:ring-red-500/20 focus:border-red-500 shadow-2xs"
                >
                  {MOTIVOS_PADRAO.map(m => (
                    <option key={m} value={m}>
                      {m}
                    </option>
                  ))}
                </select>

                {motivoSelecionado === 'Outro motivo' && (
                  <div className="mt-2">
                    <input
                      type="text"
                      disabled={submitting}
                      value={motivoCustomizado}
                      onChange={e => setMotivoCustomizado(e.target.value)}
                      placeholder="Descreva o motivo detalhadamente..."
                      className="w-full px-3 py-2 text-xs rounded-xl border border-gray-200 bg-white focus:outline-none focus:ring-2 focus:ring-red-500/20 focus:border-red-500 shadow-2xs"
                      maxLength={150}
                    />
                  </div>
                )}
              </div>

              {/* Pergunta: Continua Proprietário? (Apenas para tipo_morador proprietário) */}
              {isProprietario && (
                <div className="p-3.5 bg-gray-50 border border-gray-200 rounded-xl space-y-2">
                  <div className="flex items-center justify-between">
                    <div>
                      <span className="text-xs font-bold text-gray-900 block">
                        Continua como proprietário da unidade?
                      </span>
                      <span className="text-[11px] text-gray-500 block">
                        Se o morador mudou de endereço mas mantém a titularidade do imóvel.
                      </span>
                    </div>
                    <label className="relative inline-flex items-center cursor-pointer shrink-0 ml-3">
                      <input
                        type="checkbox"
                        disabled={submitting}
                        checked={continuaProprietario}
                        onChange={e => setContinuaProprietario(e.target.checked)}
                        className="sr-only peer"
                      />
                      <div className="w-9 h-5 bg-gray-300 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-[#FC5931]"></div>
                    </label>
                  </div>
                  {continuaProprietario ? (
                    <p className="text-[10px] text-amber-700 bg-amber-50 p-2 rounded-lg border border-amber-200/60 leading-tight">
                      O perfil permanecerá aprovado como <strong>Proprietário não morador</strong>, preservando histórico e permissões patrimoniais.
                    </p>
                  ) : (
                    <p className="text-[10px] text-gray-500 leading-tight">
                      O perfil será inativado se este for seu último vínculo ativo.
                    </p>
                  )}
                </div>
              )}

              {/* Resumo da Ação */}
              <div className="p-3 bg-zinc-100/70 border border-zinc-200 rounded-xl space-y-1">
                <span className="text-[11px] font-bold text-gray-700 flex items-center gap-1.5">
                  <CheckCircle size={13} className="text-emerald-600" />
                  Resumo antes de confirmar:
                </span>
                <p className="text-[11px] text-gray-600 leading-relaxed">
                  {continuaProprietario
                    ? `O morador deixará de ocupar a unidade ${blocoLabel} ${selectedUnit?.bloco || '—'} · ${aptoLabel} ${selectedUnit?.apto || '—'} e será classificado como Proprietário não morador.`
                    : activeUnits.length > 1
                    ? `Será encerrado o vínculo com a unidade ${blocoLabel} ${selectedUnit?.bloco || '—'} · ${aptoLabel} ${selectedUnit?.apto || '—'}. O morador permanecerá ativo em seu outro vínculo residencial.`
                    : `Será encerrado o vínculo com a unidade ${blocoLabel} ${selectedUnit?.bloco || '—'} · ${aptoLabel} ${selectedUnit?.apto || '—'}. Como é seu último vínculo residencial, o status do perfil passará para INATIVO.`}
                </p>
              </div>

              {/* Mensagem de Erro de Validação ou da RPC */}
              {errorMessage && (
                <div className="p-3 bg-red-50 border border-red-200 rounded-xl text-red-700 text-xs flex items-start gap-2 animate-in fade-in">
                  <AlertTriangle size={15} className="shrink-0 mt-0.5" />
                  <span>{errorMessage}</span>
                </div>
              )}
            </>
          )}
        </div>

        {/* Footer */}
        <div className="px-6 py-4 border-t border-gray-100 bg-gray-50 flex items-center justify-end gap-2.5">
          <button
            type="button"
            disabled={submitting}
            onClick={onClose}
            className="px-4 py-2 rounded-xl text-xs font-semibold text-gray-600 hover:bg-gray-200/60 border border-gray-200 transition-colors disabled:opacity-50"
          >
            Cancelar
          </button>
          <button
            type="button"
            disabled={submitting || loadingContext || activeUnits.length === 0}
            onClick={handleConfirm}
            className="px-4 py-2 rounded-xl text-xs font-semibold bg-red-600 hover:bg-red-700 text-white transition-colors shadow-2xs flex items-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {submitting ? (
              <>
                <Loader2 size={13} className="animate-spin" />
                <span>Inativando...</span>
              </>
            ) : (
              <span>Confirmar Inativação</span>
            )}
          </button>
        </div>
      </div>
    </div>
  )
}
