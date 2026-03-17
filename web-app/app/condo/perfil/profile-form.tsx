'use client'

import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'
import { Save, AlertTriangle, Loader2, Lock, Eye, EyeOff } from 'lucide-react'

const TIPOS_MORADOR = [
  'Proprietário (a)', 'Inquilino (a)', 'Cônjuge', 'Dependente',
  'Família', 'Funcionário (a)', 'Terceirizado (a)',
  'Síndico', 'Sub Síndico (a)', 'Porteiro (a)', 'Zelador (a)',
]

interface Bloco { id: string; nome_ou_numero: string }
interface Apto { id: string; numero: string }

interface ProfileFormProps {
  userId: string
  condoId: string
  email: string
  currentName: string
  currentWhatsapp: string
  currentTipoMorador: string
  currentBlocoTxt: string
  currentAptoTxt: string
  currentBlocoId: string
  currentAptoId: string
  blocos: Bloco[]
  initialAptos: Apto[]
}

export default function ProfileForm({
  userId, condoId, email,
  currentName, currentWhatsapp, currentTipoMorador,
  currentBlocoTxt, currentAptoTxt,
  currentBlocoId, currentAptoId,
  blocos, initialAptos,
}: ProfileFormProps) {
  const supabase = createClient()
  const router = useRouter()

  const [nome, setNome] = useState(currentName)
  const [whatsapp, setWhatsapp] = useState(currentWhatsapp)
  const [tipoMorador, setTipoMorador] = useState(currentTipoMorador)
  const [saving, setSaving] = useState(false)
  const [loadingAptos, setLoadingAptos] = useState(false)

  const [selectedBlocoId, setSelectedBlocoId] = useState(currentBlocoId)
  const [selectedBlocoTxt, setSelectedBlocoTxt] = useState(currentBlocoTxt)
  const [selectedAptoId, setSelectedAptoId] = useState(currentAptoId)
  const [selectedAptoTxt, setSelectedAptoTxt] = useState(currentAptoTxt)
  const [aptos, setAptos] = useState<Apto[]>(initialAptos)

  const [aptChanged, setAptChanged] = useState(false)
  const [message, setMessage] = useState<{ text: string; type: 'success' | 'error' | 'warning' } | null>(null)

  // Change password state
  const [showChangePwd, setShowChangePwd] = useState(false)
  const [newPwd, setNewPwd] = useState('')
  const [confirmPwd, setConfirmPwd] = useState('')
  const [showNewPwd, setShowNewPwd] = useState(false)
  const [showConfirmPwd, setShowConfirmPwd] = useState(false)
  const [pwdLoading, setPwdLoading] = useState(false)
  const [pwdError, setPwdError] = useState('')

  async function handleBlocoChange(blocoId: string) {
    const bloco = blocos.find(b => b.id === blocoId)
    setSelectedBlocoId(blocoId)
    setSelectedBlocoTxt(bloco?.nome_ou_numero ?? '')
    setSelectedAptoId('')
    setSelectedAptoTxt('')
    setAptos([])

    if (blocoId) {
      setLoadingAptos(true)
      // Step 1: get apartment IDs for this bloco
      const { data: unidades } = await supabase
        .from('unidades')
        .select('apartamento_id')
        .eq('condominio_id', condoId)
        .eq('bloco_id', blocoId)

      if (unidades && unidades.length > 0) {
        const aptoIds = unidades.map((u: any) => u.apartamento_id)
        const { data: aptosData } = await supabase
          .from('apartamentos')
          .select('id, numero')
          .in('id', aptoIds)
          .order('numero')

        const mapped: Apto[] = (aptosData ?? []).map((a: any) => ({ id: a.id, numero: String(a.numero) }))
        mapped.sort((a, b) => a.numero.localeCompare(b.numero, undefined, { numeric: true }))
        setAptos(mapped)
      }
      setLoadingAptos(false)
    }

    const changed = (bloco?.nome_ou_numero ?? '') !== currentBlocoTxt
    setAptChanged(changed)
  }

  function handleAptoChange(aptoId: string) {
    const apto = aptos.find(a => a.id === aptoId)
    setSelectedAptoId(aptoId)
    setSelectedAptoTxt(apto?.numero ?? '')
    const changed =
      selectedBlocoTxt !== currentBlocoTxt ||
      (apto?.numero ?? '') !== currentAptoTxt
    setAptChanged(changed)
  }

  async function handleSave() {
    if (!nome.trim()) {
      setMessage({ text: 'Nome é obrigatório', type: 'error' })
      return
    }

    if (aptChanged) {
      const confirmed = window.confirm(
        'Ao mudar de apartamento, seu acesso será bloqueado até o síndico aprovar novamente.\n\nDeseja continuar?'
      )
      if (!confirmed) return
    }

    setSaving(true)
    setMessage(null)

    try {
      if (aptChanged && selectedBlocoTxt && selectedAptoTxt) {
        const { data: result, error: rpcError } = await supabase.rpc('change_apartment', {
          p_user_id: userId,
          p_new_bloco_txt: selectedBlocoTxt,
          p_new_apto_txt: selectedAptoTxt,
        })

        if (rpcError) throw rpcError
        if (result?.success === false) {
          setMessage({ text: result.error, type: 'error' })
          setSaving(false)
          return
        }
      }

      const { error } = await supabase.rpc('update_profile', {
        p_user_id: userId,
        p_nome_completo: nome.trim(),
        p_whatsapp: whatsapp.trim(),
        p_tipo_morador: tipoMorador,
      })
      if (error) throw error

      if (aptChanged) {
        setMessage({ text: 'Apartamento alterado! Aguarde aprovação do síndico.', type: 'warning' })
        setTimeout(async () => {
          await supabase.auth.signOut()
          router.push('/login')
        }, 2000)
      } else {
        setMessage({ text: 'Perfil atualizado com sucesso! ✅', type: 'success' })
        setTimeout(() => router.refresh(), 1500)
      }
    } catch (e: any) {
      setMessage({ text: `Erro: ${e.message ?? e}`, type: 'error' })
    } finally {
      setSaving(false)
    }
  }

  const tiposSet = new Set([...TIPOS_MORADOR, tipoMorador])

  return (
    <div className="max-w-xl mx-auto p-6">
      <h1 className="text-2xl font-bold text-gray-800 mb-6">Editar Perfil</h1>

      {message && (
        <div className={`mb-4 p-4 rounded-xl text-sm font-medium ${
          message.type === 'success' ? 'bg-green-50 text-green-700 border border-green-200' :
          message.type === 'warning' ? 'bg-orange-50 text-orange-700 border border-orange-200' :
          'bg-red-50 text-red-700 border border-red-200'
        }`}>{message.text}</div>
      )}

      {/* Dados Pessoais */}
      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6 mb-6">
        <h2 className="text-lg font-semibold text-gray-700 mb-4">Dados Pessoais</h2>
        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-500 mb-1">E-mail</label>
            <input type="email" value={email} disabled className="w-full px-4 py-2.5 rounded-xl border border-gray-200 bg-gray-50 text-gray-400 cursor-not-allowed" />
            <p className="text-xs text-gray-400 mt-1">O e-mail não pode ser alterado</p>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-600 mb-1">Nome Completo</label>
            <input type="text" value={nome} onChange={e => setNome(e.target.value)} className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931] outline-none" />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-600 mb-1">WhatsApp</label>
            <input type="tel" value={whatsapp} onChange={e => setWhatsapp(e.target.value)} className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931] outline-none" />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-600 mb-1">Tipo de Morador</label>
            <select value={tipoMorador} onChange={e => setTipoMorador(e.target.value)} className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931] outline-none bg-white">
              {[...tiposSet].map(t => <option key={t} value={t}>{t}</option>)}
            </select>
          </div>
        </div>
      </div>

      {/* Minha Unidade */}
      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6 mb-6">
        <h2 className="text-lg font-semibold text-gray-700 mb-2">Minha Unidade</h2>
        <p className="text-sm text-gray-400 mb-4">Atualmente: Bloco {currentBlocoTxt || '?'} / Apto {currentAptoTxt || '?'}</p>
        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-600 mb-1">Bloco</label>
            <select value={selectedBlocoId} onChange={e => handleBlocoChange(e.target.value)} className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931] outline-none bg-white">
              <option value="">Selecione o bloco</option>
              {blocos.map(b => <option key={b.id} value={b.id}>Bloco {b.nome_ou_numero}</option>)}
            </select>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-600 mb-1">Apartamento</label>
            <select value={selectedAptoId} onChange={e => handleAptoChange(e.target.value)} disabled={loadingAptos} className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931] outline-none bg-white disabled:opacity-50">
              <option value="">{loadingAptos ? 'Carregando...' : 'Selecione o apartamento'}</option>
              {aptos.map(a => <option key={a.id} value={a.id}>Apto {a.numero}</option>)}
            </select>
          </div>
          {aptChanged && (
            <div className="flex items-start gap-3 bg-orange-50 border border-orange-200 rounded-xl p-4">
              <AlertTriangle className="text-orange-500 flex-shrink-0 mt-0.5" size={20} />
              <p className="text-sm text-orange-700">Ao mudar de unidade, seu acesso será bloqueado até o síndico aprovar novamente.</p>
            </div>
          )}
        </div>
      </div>

      {/* Segurança */}
      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6 mb-6">
        <h2 className="text-lg font-semibold text-gray-700 mb-4">Segurança</h2>
        {!showChangePwd ? (
          <button
            onClick={() => setShowChangePwd(true)}
            className="flex items-center gap-2 text-sm text-[#FC5931] hover:underline font-medium"
          >
            <Lock size={16} /> Alterar Senha
          </button>
        ) : (
          <div className="space-y-3">
            <div className="relative">
              <input
                type={showNewPwd ? 'text' : 'password'}
                inputMode="numeric"
                placeholder="Nova senha (somente números)"
                value={newPwd}
                onChange={e => setNewPwd(e.target.value.replace(/\D/g, ''))}
                className="w-full px-4 py-2.5 pr-11 rounded-xl border border-gray-200 focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931] outline-none text-sm"
              />
              <button type="button" onClick={() => setShowNewPwd(!showNewPwd)} title="Mostrar/ocultar senha" className="absolute right-3.5 top-1/2 -translate-y-1/2 text-gray-400">
                {showNewPwd ? <EyeOff size={16}/> : <Eye size={16}/>}
              </button>
            </div>
            <div className="relative">
              <input
                type={showConfirmPwd ? 'text' : 'password'}
                inputMode="numeric"
                placeholder="Confirmar nova senha"
                value={confirmPwd}
                onChange={e => setConfirmPwd(e.target.value.replace(/\D/g, ''))}
                className="w-full px-4 py-2.5 pr-11 rounded-xl border border-gray-200 focus:ring-2 focus:ring-[#FC5931]/20 focus:border-[#FC5931] outline-none text-sm"
              />
              <button type="button" onClick={() => setShowConfirmPwd(!showConfirmPwd)} title="Mostrar/ocultar senha" className="absolute right-3.5 top-1/2 -translate-y-1/2 text-gray-400">
                {showConfirmPwd ? <EyeOff size={16}/> : <Eye size={16}/>}
              </button>
            </div>
            {pwdError && <p className="text-red-500 text-xs">{pwdError}</p>}
            <div className="flex gap-2">
              <button
                onClick={async () => {
                  if (newPwd.length < 4) { setPwdError('Mínimo de 4 dígitos'); return }
                  if (newPwd !== confirmPwd) { setPwdError('As senhas não coincidem'); return }
                  setPwdLoading(true); setPwdError('')
                  try {
                    const { error } = await supabase.auth.updateUser({ password: newPwd })
                    if (error) throw error
                    setMessage({ text: 'Senha alterada com sucesso! ✅', type: 'success' })
                    setShowChangePwd(false); setNewPwd(''); setConfirmPwd('')
                  } catch {
                    setPwdError('Erro ao alterar senha. Tente novamente.')
                  } finally { setPwdLoading(false) }
                }}
                disabled={pwdLoading || !newPwd || !confirmPwd}
                className="px-4 py-2 bg-[#FC5931] text-white rounded-xl text-sm font-semibold hover:bg-[#D42F1D] disabled:opacity-50"
              >
                {pwdLoading ? 'Salvando...' : 'Salvar Senha'}
              </button>
              <button
                onClick={() => { setShowChangePwd(false); setNewPwd(''); setConfirmPwd(''); setPwdError('') }}
                className="px-4 py-2 text-gray-500 text-sm hover:underline"
              >
                Cancelar
              </button>
            </div>
          </div>
        )}
      </div>

      <button onClick={handleSave} disabled={saving} className={`w-full flex items-center justify-center gap-2 px-6 py-3 rounded-xl text-white font-bold text-base transition-all shadow-lg ${aptChanged ? 'bg-orange-500 hover:bg-orange-600' : 'bg-[#FC5931] hover:bg-[#D42F1D]'} disabled:opacity-50`}>
        {saving ? <Loader2 className="animate-spin" size={20} /> : <Save size={20} />}
        {aptChanged ? 'Salvar e Solicitar Aprovação' : 'Salvar Alterações'}
      </button>
    </div>
  )
}
