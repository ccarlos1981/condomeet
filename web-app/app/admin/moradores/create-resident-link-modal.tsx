'use client'

import { useState, useEffect, useMemo } from 'react'
import {
  X,
  Calendar,
  Home,
  CheckCircle,
  Loader2,
  AlertTriangle,
  Building2,
  User,
  Mail,
  ShieldCheck,
} from 'lucide-react'
import { adminGetResidentLinkContext, adminCreateResidentLink, adminGetUnitOccupancy } from '@/app/admin/actions'
import { getBlocoLabel, getAptoLabel } from '@/lib/labels'

interface CreateResidentLinkModalProps {
  isOpen: boolean
  onClose: () => void
  profileId: string
  residentName: string
  tipoEstrutura?: string
  onSuccess: (result: any) => void
}

const TIPOS_MORADOR_CANONICOS = [
  'Morador (a)',
  'Proprietário (a)',
  'Inquilino (a)',
  'Dependente',
  'Cônjuge',
  'Família',
  'Proprietário não morador',
  'Locador',
  'Locatário',
  'Síndico',
]

export default function CreateResidentLinkModal({
  isOpen,
  onClose,
  profileId,
  residentName,
  tipoEstrutura = 'predio',
  onSuccess,
}: CreateResidentLinkModalProps) {
  const blocoLabel = getBlocoLabel(tipoEstrutura)
  const aptoLabel = getAptoLabel(tipoEstrutura)

  // Estados de carregamento do contexto
  const [loadingContext, setLoadingContext] = useState(true)
  const [contextError, setContextError] = useState<string | null>(null)

  // Dados carregados do contexto
  const [profileEmail, setProfileEmail] = useState<string>('')
  const [blocos, setBlocos] = useState<Array<{ id: string; nome_ou_numero: string }>>([])
  const [units, setUnits] = useState<Array<{ id: string; bloco_id: string; numero: string }>>([])
  const [lastExitInfo, setLastExitInfo] = useState<{
    unidadeId: string
    dataSaida: string
    bloco: string
    apto: string
  } | null>(null)

  // Estados do formulário
  const [selectedBlocoId, setSelectedBlocoId] = useState<string>('')
  const [selectedUnidadeId, setSelectedUnidadeId] = useState<string>('')
  const [dataEntrada, setDataEntrada] = useState<string>(() => {
    return new Date().toISOString().split('T')[0]
  })
  const [tipoMorador, setTipoMorador] = useState<string>('Morador (a)')

  // Estados de submissão
  const [submitting, setSubmitting] = useState(false)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  // Gate 3G.4-D2: Ocupação da unidade destino
  const MAX_OCUPANTES_UNIDADE = 4
  const [unitOccupancy, setUnitOccupancy] = useState<number | null>(null)
  const [loadingOccupancy, setLoadingOccupancy] = useState(false)
  const [occupancyError, setOccupancyError] = useState<string | null>(null)
  const limiteAtingidoDestino = unitOccupancy !== null && unitOccupancy >= MAX_OCUPANTES_UNIDADE

  // Carregar dados ao abrir o modal
  useEffect(() => {
    let isMounted = true

    async function loadData() {
      if (!isOpen || !profileId) return
      setLoadingContext(true)
      setContextError(null)
      setErrorMessage(null)

      try {
        const res = await adminGetResidentLinkContext(profileId)
        if (!isMounted) return

        if (res.error) {
          setContextError(res.error)
          setLoadingContext(false)
          return
        }

        if (res.profile) {
          setProfileEmail(res.profile.email || '')
          if (res.profile.tipo_morador && TIPOS_MORADOR_CANONICOS.includes(res.profile.tipo_morador)) {
            setTipoMorador(res.profile.tipo_morador)
          } else {
            setTipoMorador('Morador (a)')
          }
        }

        setBlocos(res.blocos || [])
        setUnits(res.units || [])
        setLastExitInfo(res.lastExitInfo || null)

        // Selecionar primeiro bloco por padrão se houver
        if (res.blocos && res.blocos.length > 0) {
          setSelectedBlocoId(res.blocos[0].id)
        }

        setLoadingContext(false)
      } catch (err: unknown) {
        if (!isMounted) return
        setContextError('Falha ao carregar informações do condomínio.')
        setLoadingContext(false)
      }
    }

    loadData()

    return () => {
      isMounted = false
    }
  }, [isOpen, profileId])

  // Função auxiliar determinística para cálculo de dia seguinte civil (ano/mês/dia seguros)
  function getNextDayCivil(dateStr: string): string {
    const parts = dateStr.split('T')[0].split('-')
    if (parts.length !== 3) return dateStr
    const year = parseInt(parts[0], 10)
    const month = parseInt(parts[1], 10) - 1
    const day = parseInt(parts[2], 10)
    const d = new Date(year, month, day + 1, 12, 0, 0)
    const nextY = d.getFullYear()
    const nextM = String(d.getMonth() + 1).padStart(2, '0')
    const nextD = String(d.getDate()).padStart(2, '0')
    return `${nextY}-${nextM}-${nextD}`
  }

  // Filtrar unidades do bloco selecionado
  const availableUnits = useMemo(() => {
    if (!selectedBlocoId) return []
    return units.filter((u) => u.bloco_id === selectedBlocoId)
  }, [units, selectedBlocoId])

  // Quando o bloco muda, resetar ou selecionar primeira unidade
  useEffect(() => {
    if (availableUnits.length > 0) {
      if (!availableUnits.some((u) => u.id === selectedUnidadeId)) {
        setSelectedUnidadeId(availableUnits[0].id)
      }
    } else {
      setSelectedUnidadeId('')
    }
  }, [availableUnits, selectedUnidadeId])

  // Gate 3G.4-D2: Consultar ocupação da unidade destino quando a seleção muda
  useEffect(() => {
    let isMounted = true

    async function fetchOccupancy() {
      if (!selectedUnidadeId) {
        setUnitOccupancy(null)
        setOccupancyError(null)
        return
      }

      setLoadingOccupancy(true)
      setOccupancyError(null)

      try {
        const res = await adminGetUnitOccupancy(selectedUnidadeId)
        if (!isMounted) return

        if (res.error) {
          setOccupancyError(res.error)
          setUnitOccupancy(null)
        } else {
          setUnitOccupancy(res.ocupacao ?? 0)
        }
      } catch {
        if (!isMounted) return
        setOccupancyError('Falha ao verificar ocupação.')
        setUnitOccupancy(null)
      } finally {
        if (isMounted) setLoadingOccupancy(false)
      }
    }

    fetchOccupancy()
    return () => { isMounted = false }
  }, [selectedUnidadeId])

  // Identificar se a unidade selecionada é a mesma do período anterior
  const isSameUnitAsLast = useMemo(() => {
    if (!lastExitInfo || !selectedUnidadeId) return false
    return lastExitInfo.unidadeId === selectedUnidadeId
  }, [lastExitInfo, selectedUnidadeId])

  // Sugestão automática de data de entrada ao selecionar a mesma unidade da ocupação anterior (Gate 3C.7-B)
  useEffect(() => {
    if (!selectedUnidadeId) return

    if (lastExitInfo && selectedUnidadeId === lastExitInfo.unidadeId && lastExitInfo.dataSaida) {
      const exitDateStr = lastExitInfo.dataSaida.split('T')[0]
      const nextDayStr = getNextDayCivil(exitDateStr)
      setDataEntrada((prev) => {
        // Se a data atual for menor ou igual à data de saída, sugere o dia seguinte
        if (!prev || prev <= exitDateStr) {
          return nextDayStr
        }
        return prev
      })
    } else {
      // Se trocou para outra unidade e a data estava fixada na saída + 1 da unidade anterior
      const todayStr = new Date().toISOString().split('T')[0]
      setDataEntrada((prev) => {
        if (lastExitInfo?.dataSaida && prev === getNextDayCivil(lastExitInfo.dataSaida.split('T')[0])) {
          return todayStr
        }
        return prev
      })
    }
  }, [selectedUnidadeId, lastExitInfo])

  // Obter labels do bloco e unidade selecionados para o resumo
  const selectedBlocoObj = blocos.find((b) => b.id === selectedBlocoId)
  const selectedUnitObj = units.find((u) => u.id === selectedUnidadeId)

  // Validação temporal client-side estrita (Gate 3C.7-B: dataEntrada <= exitDateStr bloqueia)
  const dateValidationWarning = useMemo(() => {
    if (!dataEntrada) return 'A data de entrada é obrigatória.'
    if (isSameUnitAsLast && lastExitInfo?.dataSaida) {
      const exitDateStr = lastExitInfo.dataSaida.split('T')[0]
      if (dataEntrada <= exitDateStr) {
        return `Para retornar a esta unidade, escolha uma data posterior à última saída (${formatDate(exitDateStr)}).`
      }
    }
    return null
  }, [dataEntrada, isSameUnitAsLast, lastExitInfo])

  function formatDate(dStr?: string | null) {
    if (!dStr) return '—'
    const parts = dStr.split('T')[0].split('-')
    if (parts.length === 3) return `${parts[2]}/${parts[1]}/${parts[0]}`
    return dStr
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (submitting) return

    // Gate 3G.4-D2: Proteção do handler contra bypass programático
    if (limiteAtingidoDestino) {
      setErrorMessage('Esta unidade já atingiu o limite de 4 pessoas.')
      return
    }
    if (loadingOccupancy || occupancyError) {
      setErrorMessage('Aguarde a verificação de ocupação da unidade.')
      return
    }

    setErrorMessage(null)

    if (!selectedUnidadeId) {
      setErrorMessage('Por favor, selecione uma unidade residencial.')
      return
    }

    if (!dataEntrada) {
      setErrorMessage('A data de entrada é obrigatória.')
      return
    }

    if (dateValidationWarning) {
      setErrorMessage(dateValidationWarning)
      return
    }

    setSubmitting(true)

    try {
      const res = await adminCreateResidentLink({
        profileId,
        unidadeId: selectedUnidadeId,
        dataEntrada,
        tipoMorador,
      })

      if (res.error) {
        setErrorMessage(res.error)
        setSubmitting(false)
        return
      }

      onSuccess(res.result)
      onClose()
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Erro ao criar novo vínculo.'
      setErrorMessage(msg)
      setSubmitting(false)
    }
  }

  if (!isOpen) return null

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-xs animate-in fade-in duration-200">
      <div
        className="bg-white rounded-2xl shadow-2xl border border-gray-100 w-full max-w-lg overflow-hidden flex flex-col max-h-[90vh]"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header Institucional */}
        <div className="px-6 py-4 border-b border-gray-100 flex items-center justify-between bg-slate-50/80">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-emerald-100/70 border border-emerald-200/80 flex items-center justify-center text-emerald-700">
              <Home size={20} />
            </div>
            <div>
              <h2 className="text-base font-bold text-gray-900">Novo Vínculo Residencial</h2>
              <p className="text-xs text-gray-500">
                Atribuir nova unidade e restabelecer o vínculo residencial.
              </p>
            </div>
          </div>
          <button
            type="button"
            disabled={submitting}
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600 p-1.5 rounded-lg hover:bg-gray-100 transition-colors disabled:opacity-50"
          >
            <X size={18} />
          </button>
        </div>

        {/* Corpo do Modal */}
        <div className="p-6 overflow-y-auto space-y-5 text-sm">
          {loadingContext ? (
            <div className="py-12 flex flex-col items-center justify-center space-y-3 text-gray-400">
              <Loader2 size={32} className="animate-spin text-emerald-600" />
              <p className="text-xs font-medium">Carregando unidades e dados cadastrais...</p>
            </div>
          ) : contextError ? (
            <div className="p-4 rounded-xl bg-red-50 border border-red-200 text-red-700 space-y-2">
              <div className="flex items-center gap-2 font-semibold">
                <AlertTriangle size={16} />
                <span>Não foi possível carregar o formulário</span>
              </div>
              <p className="text-xs">{contextError}</p>
            </div>
          ) : (
            <form id="create-link-form" onSubmit={handleSubmit} className="space-y-4">
              {/* Card de Identificação do Morador (Read-Only) */}
              <div className="p-3.5 rounded-xl bg-slate-50 border border-slate-200/70 flex items-center justify-between gap-4">
                <div className="flex items-center gap-3">
                  <div className="w-9 h-9 rounded-full bg-slate-200 flex items-center justify-center text-slate-700">
                    <User size={18} />
                  </div>
                  <div>
                    <h3 className="font-semibold text-gray-900">{residentName}</h3>
                    <p className="text-xs text-gray-500 flex items-center gap-1.5">
                      <Mail size={12} />
                      {profileEmail || 'E-mail não informado'}
                    </p>
                  </div>
                </div>
                <span className="text-[11px] font-bold px-2 py-0.5 rounded-full bg-zinc-200/70 text-zinc-700 border border-zinc-300">
                  INATIVO
                </span>
              </div>

              {/* Grid: Bloco e Apartamento/Unidade */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
                <div>
                  <label className="block text-xs font-semibold text-gray-700 mb-1 flex items-center gap-1">
                    <Building2 size={13} className="text-slate-500" />
                    {blocoLabel}
                  </label>
                  <select
                    value={selectedBlocoId}
                    onChange={(e) => setSelectedBlocoId(e.target.value)}
                    disabled={submitting}
                    className="w-full text-xs font-medium bg-white border border-gray-200 rounded-xl px-3 py-2 text-gray-800 focus:outline-hidden focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all disabled:opacity-50"
                  >
                    {blocos.map((b) => (
                      <option key={b.id} value={b.id}>
                        {blocoLabel} {b.nome_ou_numero}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-xs font-semibold text-gray-700 mb-1 flex items-center gap-1">
                    <Home size={13} className="text-slate-500" />
                    {aptoLabel} / Unidade
                  </label>
                  <select
                    value={selectedUnidadeId}
                    onChange={(e) => setSelectedUnidadeId(e.target.value)}
                    disabled={submitting || availableUnits.length === 0}
                    className="w-full text-xs font-medium bg-white border border-gray-200 rounded-xl px-3 py-2 text-gray-800 focus:outline-hidden focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all disabled:opacity-50"
                  >
                    {availableUnits.length === 0 ? (
                      <option value="">Nenhuma unidade neste {blocoLabel.toLowerCase()}</option>
                    ) : (
                      availableUnits.map((u) => (
                        <option key={u.id} value={u.id}>
                          {aptoLabel} {u.numero}
                        </option>
                      ))
                    )}
                  </select>
                </div>
              </div>

              {/* Gate 3G.4-D2: Indicador de ocupação da unidade destino */}
              {selectedUnidadeId && (
                <div className="flex items-center gap-2">
                  {loadingOccupancy ? (
                    <span className="text-xs font-medium text-gray-500 flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-gray-50 border border-gray-200">
                      <Loader2 size={12} className="animate-spin" />
                      Verificando ocupação...
                    </span>
                  ) : occupancyError ? (
                    <span className="text-xs font-semibold px-2.5 py-1 rounded-lg bg-red-50 text-red-700 border border-red-200">
                      ⚠ {occupancyError}
                    </span>
                  ) : unitOccupancy !== null ? (
                    <>
                      <span className={`text-xs font-semibold px-2.5 py-1 rounded-lg ${
                        limiteAtingidoDestino
                          ? 'bg-red-50 text-red-700 border border-red-200'
                          : unitOccupancy >= 3
                            ? 'bg-amber-50 text-amber-700 border border-amber-200'
                            : 'bg-gray-50 text-gray-600 border border-gray-200'
                      }`}>
                        Ocupação da unidade: {unitOccupancy} / {MAX_OCUPANTES_UNIDADE} pessoas
                      </span>
                      {limiteAtingidoDestino && (
                        <span className="text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-full bg-red-100 text-red-700 border border-red-200">
                          Limite atingido
                        </span>
                      )}
                    </>
                  ) : null}
                </div>
              )}

              {/* Mensagem de bloqueio por limite (Gate 3G.4-D2) */}
              {limiteAtingidoDestino && (
                <div className="p-3 rounded-xl bg-red-50/70 border border-red-200 text-red-800 text-xs flex items-center gap-2">
                  <AlertTriangle size={15} className="text-red-600 shrink-0" />
                  <span>Esta unidade já atingiu o limite de 4 pessoas. Não é possível criar um novo vínculo residencial nesta unidade.</span>
                </div>
              )}

              {/* Alerta de Retorno à Mesma Unidade (Discreto) */}
              {isSameUnitAsLast && lastExitInfo?.dataSaida && (
                <div className="p-3 rounded-xl bg-blue-50/70 border border-blue-200 text-blue-800 text-xs flex items-center gap-2">
                  <CheckCircle size={15} className="text-blue-600 shrink-0" />
                  <div>
                    <span>Retorno à mesma unidade anterior: </span>
                    <strong className="font-semibold">
                      Última saída em {formatDate(lastExitInfo.dataSaida)}
                    </strong>
                    <span className="block text-[11px] text-blue-600 mt-0.5">
                      Data sugerida automaticamente: dia seguinte à desocupação ({formatDate(getNextDayCivil(lastExitInfo.dataSaida))}).
                    </span>
                  </div>
                </div>
              )}

              {/* Grid: Data de Entrada e Tipo de Morador */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
                <div>
                  <label className="block text-xs font-semibold text-gray-700 mb-1 flex items-center gap-1">
                    <Calendar size={13} className="text-slate-500" />
                    Data de Entrada
                  </label>
                  <input
                    type="date"
                    value={dataEntrada}
                    onChange={(e) => setDataEntrada(e.target.value)}
                    disabled={submitting}
                    className="w-full text-xs font-medium bg-white border border-gray-200 rounded-xl px-3 py-2 text-gray-800 focus:outline-hidden focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all disabled:opacity-50"
                  />
                </div>

                <div>
                  <label className="block text-xs font-semibold text-gray-700 mb-1 flex items-center gap-1">
                    <ShieldCheck size={13} className="text-slate-500" />
                    Tipo de Morador
                  </label>
                  <select
                    value={tipoMorador}
                    onChange={(e) => setTipoMorador(e.target.value)}
                    disabled={submitting}
                    className="w-full text-xs font-medium bg-white border border-gray-200 rounded-xl px-3 py-2 text-gray-800 focus:outline-hidden focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all disabled:opacity-50"
                  >
                    {TIPOS_MORADOR_CANONICOS.map((t) => (
                      <option key={t} value={t}>
                        {t}
                      </option>
                    ))}
                  </select>
                </div>
              </div>

              {/* Card de Resumo de Confirmação Canônica */}
              <div className="p-4 rounded-xl bg-emerald-50/60 border border-emerald-200/80 space-y-2 text-xs text-emerald-950">
                <div className="font-bold text-emerald-900 flex items-center gap-1.5">
                  <CheckCircle size={14} className="text-emerald-700" />
                  Resumo do Novo Vínculo
                </div>
                <div className="grid grid-cols-2 gap-2 text-xs">
                  <div>
                    <span className="text-emerald-700 font-medium">Morador: </span>
                    <strong className="text-emerald-950">{residentName}</strong>
                  </div>
                  <div>
                    <span className="text-emerald-700 font-medium">Nova Unidade: </span>
                    <strong className="text-emerald-950">
                      {selectedBlocoObj ? `${blocoLabel} ${selectedBlocoObj.nome_ou_numero}` : ''}
                      {selectedUnitObj ? ` · ${aptoLabel} ${selectedUnitObj.numero}` : ''}
                    </strong>
                  </div>
                  <div>
                    <span className="text-emerald-700 font-medium">Data de Início: </span>
                    <strong className="text-emerald-950">{formatDate(dataEntrada)}</strong>
                  </div>
                  <div>
                    <span className="text-emerald-700 font-medium">Tipo: </span>
                    <strong className="text-emerald-950">{tipoMorador}</strong>
                  </div>
                </div>
                <p className="text-[11px] text-emerald-800 font-normal pt-1 border-t border-emerald-200/70">
                  ℹ️ Será criado um novo período residencial. O histórico anterior permanecerá preservado.
                </p>
              </div>

              {/* Mensagem de Erro */}
              {errorMessage && (
                <div className="p-3.5 rounded-xl bg-red-50 border border-red-200 text-red-700 text-xs flex items-start gap-2 animate-in fade-in">
                  <AlertTriangle size={15} className="shrink-0 mt-0.5" />
                  <span>{errorMessage}</span>
                </div>
              )}
            </form>
          )}
        </div>

        {/* Footer com Ações */}
        <div className="px-6 py-3.5 bg-gray-50 border-t border-gray-100 flex items-center justify-end gap-2.5">
          <button
            type="button"
            disabled={submitting}
            onClick={onClose}
            className="px-4 py-2 rounded-xl text-xs font-semibold text-gray-700 hover:bg-gray-200 transition-colors disabled:opacity-50"
          >
            Cancelar
          </button>
          <button
            type="submit"
            form="create-link-form"
            disabled={submitting || loadingContext || !!contextError || limiteAtingidoDestino || loadingOccupancy || !!occupancyError}
            title={limiteAtingidoDestino ? 'Esta unidade já atingiu o limite de 4 pessoas.' : undefined}
            className={`inline-flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-semibold shadow-xs transition-colors disabled:opacity-50 ${
              limiteAtingidoDestino
                ? 'bg-gray-300 text-gray-500 cursor-not-allowed'
                : 'bg-emerald-600 hover:bg-emerald-700 active:bg-emerald-800 text-white cursor-pointer'
            }`}
          >
            {submitting ? (
              <>
                <Loader2 size={13} className="animate-spin" />
                Criando vínculo...
              </>
            ) : (
              <>
                <CheckCircle size={13} />
                Criar vínculo
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  )
}
