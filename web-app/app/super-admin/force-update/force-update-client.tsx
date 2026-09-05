'use client'

import React, { useState, useTransition } from 'react'
import { AppVersionPolicy, updateAppVersionPolicy, toggleKillSwitch, rollbackToBaseline } from './actions'
import { Shield, AlertTriangle, RefreshCw, CheckCircle2, AlertOctagon, Smartphone, Apple, Save, RotateCcw } from 'lucide-react'

interface ForceUpdateClientProps {
  initialPolicy: AppVersionPolicy
  userEmail: string
}

export default function ForceUpdateClient({ initialPolicy, userEmail }: ForceUpdateClientProps) {
  const [policy, setPolicy] = useState<AppVersionPolicy>(initialPolicy)
  const [minAndroid, setMinAndroid] = useState<number>(initialPolicy.min_android_build)
  const [minIos, setMinIos] = useState<number>(initialPolicy.min_ios_build)
  const [latestAndroid, setLatestAndroid] = useState<string>(initialPolicy.latest_android_version)
  const [latestIos, setLatestIos] = useState<string>(initialPolicy.latest_ios_version)
  const [title, setTitle] = useState<string>(initialPolicy.force_update_title)
  const [message, setMessage] = useState<string>(initialPolicy.force_update_message)
  
  const [isPending, startTransition] = useTransition()
  const [statusMessage, setStatusMessage] = useState<{ type: 'success' | 'error'; text: string } | null>(null)

  const handleSave = () => {
    setStatusMessage(null)
    startTransition(async () => {
      const res = await updateAppVersionPolicy({
        min_android_build: minAndroid,
        min_ios_build: minIos,
        latest_android_version: latestAndroid,
        latest_ios_version: latestIos,
        force_update_title: title,
        force_update_message: message,
      })

      if (res.success) {
        setStatusMessage({ type: 'success', text: 'Política de atualização salva com sucesso!' })
        setPolicy(prev => ({
          ...prev,
          min_android_build: minAndroid,
          min_ios_build: minIos,
          latest_android_version: latestAndroid,
          latest_ios_version: latestIos,
          force_update_title: title,
          force_update_message: message,
          updated_at: new Date().toISOString(),
          updated_by: userEmail,
        }))
      } else {
        setStatusMessage({ type: 'error', text: res.error || 'Falha ao salvar política.' })
      }
    })
  }

  const handleToggleKillSwitch = (current: boolean) => {
    setStatusMessage(null)
    startTransition(async () => {
      const res = await toggleKillSwitch(!current)
      if (res.success) {
        setPolicy(prev => ({
          ...prev,
          is_kill_switch_active: !current,
          updated_at: new Date().toISOString(),
          updated_by: userEmail,
        }))
        setStatusMessage({
          type: 'success',
          text: !current ? 'Kill Switch ATIVADO: Todos os bloqueios foram suspensos temporariamente.' : 'Kill Switch DESATIVADO: Regras normais de bloqueio ativas.',
        })
      } else {
        setStatusMessage({ type: 'error', text: res.error || 'Falha ao alternar Kill Switch.' })
      }
    })
  }

  const handleRollback = () => {
    if (!confirm('Deseja realmente reverter para o baseline de segurança (Build 101 / Sem Bloqueios)?')) return
    setStatusMessage(null)
    startTransition(async () => {
      const res = await rollbackToBaseline()
      if (res.success) {
        setMinAndroid(101)
        setMinIos(101)
        setPolicy(prev => ({
          ...prev,
          min_android_build: 101,
          min_ios_build: 101,
          is_kill_switch_active: false,
          updated_at: new Date().toISOString(),
          updated_by: userEmail,
        }))
        setStatusMessage({ type: 'success', text: 'Rollback executado com sucesso! Mínima retornada para Build 101.' })
      } else {
        setStatusMessage({ type: 'error', text: res.error || 'Falha ao executar rollback.' })
      }
    })
  }

  return (
    <div className="min-h-screen bg-slate-50 p-6 md:p-10">
      <div className="max-w-5xl mx-auto space-y-8">
        
        {/* Header */}
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 bg-white p-6 rounded-2xl shadow-sm border border-slate-200">
          <div className="flex items-center gap-4">
            <div className="w-12 h-12 rounded-xl bg-blue-50 text-blue-600 flex items-center justify-center font-bold">
              <Shield className="w-6 h-6" />
            </div>
            <div>
              <h1 className="text-2xl font-bold text-slate-900">Governança de Versões e Force Update</h1>
              <p className="text-sm text-slate-500">Gestão permanente da política de atualização obrigatória do aplicativo Condomeet.</p>
            </div>
          </div>
          <div className="flex items-center gap-2">
            <span className="text-xs px-3 py-1 bg-slate-100 text-slate-700 rounded-full font-medium">
              SuperAdmin: {userEmail}
            </span>
          </div>
        </div>

        {/* Status Alerts */}
        {statusMessage && (
          <div className={`p-4 rounded-xl flex items-center gap-3 border ${
            statusMessage.type === 'success' ? 'bg-emerald-50 text-emerald-800 border-emerald-200' : 'bg-red-50 text-red-800 border-red-200'
          }`}>
            {statusMessage.type === 'success' ? <CheckCircle2 className="w-5 h-5 flex-shrink-0" /> : <AlertTriangle className="w-5 h-5 flex-shrink-0" />}
            <span className="text-sm font-medium">{statusMessage.text}</span>
          </div>
        )}

        {/* Kill Switch Card */}
        <div className={`p-6 rounded-2xl border transition-all ${
          policy.is_kill_switch_active 
            ? 'bg-amber-50 border-amber-300' 
            : 'bg-white border-slate-200 shadow-sm'
        }`}>
          <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
            <div className="flex items-start gap-4">
              <div className={`w-10 h-10 rounded-lg flex items-center justify-center flex-shrink-0 ${
                policy.is_kill_switch_active ? 'bg-amber-100 text-amber-700' : 'bg-slate-100 text-slate-600'
              }`}>
                <AlertOctagon className="w-5 h-5" />
              </div>
              <div>
                <h3 className="text-base font-semibold text-slate-900">Kill Switch de Emergência</h3>
                <p className="text-sm text-slate-600 mt-0.5">
                  {policy.is_kill_switch_active
                    ? '⚠️ Kill Switch ATIVADO. Todas as versões do app estão liberadas sem bloqueio.'
                    : 'Regra de bloqueio ativa normalmente conforme os valores de build mínima configurados.'}
                </p>
              </div>
            </div>
            <button
              onClick={() => handleToggleKillSwitch(policy.is_kill_switch_active)}
              disabled={isPending}
              className={`px-5 py-2.5 rounded-xl font-semibold text-sm transition-all shadow-sm ${
                policy.is_kill_switch_active
                  ? 'bg-amber-600 hover:bg-amber-700 text-white'
                  : 'bg-slate-800 hover:bg-slate-900 text-white'
              }`}
            >
              {policy.is_kill_switch_active ? 'Desativar Kill Switch' : 'Ativar Kill Switch de Emergência'}
            </button>
          </div>
        </div>

        {/* Main Configuration Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          
          {/* Android Card */}
          <div className="bg-white p-6 rounded-2xl shadow-sm border border-slate-200 space-y-4">
            <div className="flex items-center gap-3 pb-3 border-b border-slate-100">
              <div className="w-8 h-8 rounded-lg bg-emerald-50 text-emerald-600 flex items-center justify-center">
                <Smartphone className="w-4 h-4" />
              </div>
              <div>
                <h2 className="font-semibold text-slate-900">Android (Google Play)</h2>
                <p className="text-xs text-slate-500">Package: br.com.condod.wwwc</p>
              </div>
            </div>

            <div className="space-y-3">
              <div>
                <label className="block text-xs font-semibold text-slate-700 mb-1">
                  Build Mínima Suportada (versionCode)
                </label>
                <input
                  type="number"
                  value={minAndroid}
                  onChange={(e) => setMinAndroid(Number(e.target.value))}
                  className="w-full px-3.5 py-2 bg-slate-50 border border-slate-200 rounded-xl text-slate-900 font-semibold focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
                <p className="text-[11px] text-slate-500 mt-1">Dispositivos com build inferior a este valor serão bloqueados.</p>
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-700 mb-1">
                  Versão Nominal Exibida (versionName)
                </label>
                <input
                  type="text"
                  value={latestAndroid}
                  onChange={(e) => setLatestAndroid(e.target.value)}
                  className="w-full px-3.5 py-2 bg-slate-50 border border-slate-200 rounded-xl text-slate-900 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
              </div>
            </div>
          </div>

          {/* iOS Card */}
          <div className="bg-white p-6 rounded-2xl shadow-sm border border-slate-200 space-y-4">
            <div className="flex items-center gap-3 pb-3 border-b border-slate-100">
              <div className="w-8 h-8 rounded-lg bg-slate-100 text-slate-800 flex items-center justify-center">
                <Apple className="w-4 h-4" />
              </div>
              <div>
                <h2 className="font-semibold text-slate-900">iOS (Apple App Store)</h2>
                <p className="text-xs text-slate-500">App ID: 6740927806</p>
              </div>
            </div>

            <div className="space-y-3">
              <div>
                <label className="block text-xs font-semibold text-slate-700 mb-1">
                  Build Mínima Suportada (CFBundleVersion)
                </label>
                <input
                  type="number"
                  value={minIos}
                  onChange={(e) => setMinIos(Number(e.target.value))}
                  className="w-full px-3.5 py-2 bg-slate-50 border border-slate-200 rounded-xl text-slate-900 font-semibold focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
                <p className="text-[11px] text-slate-500 mt-1">Dispositivos com build inferior a este valor serão bloqueados.</p>
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-700 mb-1">
                  Versão Nominal Exibida (CFBundleShortVersionString)
                </label>
                <input
                  type="text"
                  value={latestIos}
                  onChange={(e) => setLatestIos(e.target.value)}
                  className="w-full px-3.5 py-2 bg-slate-50 border border-slate-200 rounded-xl text-slate-900 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
              </div>
            </div>
          </div>
        </div>

        {/* Messaging Configuration Card */}
        <div className="bg-white p-6 rounded-2xl shadow-sm border border-slate-200 space-y-4">
          <h2 className="font-semibold text-slate-900 pb-3 border-b border-slate-100">
            Textos da Tela de Bloqueio (ForceUpdateScreen)
          </h2>

          <div className="space-y-4">
            <div>
              <label className="block text-xs font-semibold text-slate-700 mb-1">Título do Popup</label>
              <input
                type="text"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                className="w-full px-3.5 py-2 bg-slate-50 border border-slate-200 rounded-xl text-slate-900 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>

            <div>
              <label className="block text-xs font-semibold text-slate-700 mb-1">Mensagem Explicativa</label>
              <textarea
                rows={3}
                value={message}
                onChange={(e) => setMessage(e.target.value)}
                className="w-full px-3.5 py-2 bg-slate-50 border border-slate-200 rounded-xl text-slate-900 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
          </div>
        </div>

        {/* Action Buttons & Audit Info */}
        <div className="flex flex-col md:flex-row items-center justify-between gap-4 pt-2">
          <div className="text-xs text-slate-500">
            Última alteração: {policy.updated_at ? new Date(policy.updated_at).toLocaleString('pt-BR') : 'N/A'} 
            {policy.updated_by && ` por ${policy.updated_by}`}
          </div>

          <div className="flex items-center gap-3 w-full md:w-auto">
            <button
              onClick={handleRollback}
              disabled={isPending}
              type="button"
              className="flex-1 md:flex-none flex items-center justify-center gap-2 px-5 py-2.5 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-xl font-semibold text-sm transition-all"
            >
              <RotateCcw className="w-4 h-4" />
              Rollback Baseline (101)
            </button>

            <button
              onClick={handleSave}
              disabled={isPending}
              type="button"
              className="flex-1 md:flex-none flex items-center justify-center gap-2 px-6 py-2.5 bg-blue-600 hover:bg-blue-700 text-white rounded-xl font-semibold text-sm transition-all shadow-sm shadow-blue-500/20"
            >
              {isPending ? <RefreshCw className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />}
              Salvar Alterações
            </button>
          </div>
        </div>

      </div>
    </div>
  )
}
