'use client'
import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'
import { ChevronLeft, Lock, User, Phone, Mail, Eye, EyeOff, Check, Loader2, Building2, MapPin } from 'lucide-react'

const TIPO_ESTRUTURA_OPTIONS = [
  { value: 'predio', label: 'Prédio (Bloco e Apto)' },
  { value: 'casa_rua', label: 'Casa (Rua e Número)' },
  { value: 'casa_quadra', label: 'Casa (Quadra e Lote)' },
]

export default function SindicoRegisterPage() {
  const router = useRouter()
  const supabase = createClient()
  const [currentStep, setCurrentStep] = useState(0)
  const [loading, setLoading] = useState(false)
  const [globalError, setGlobalError] = useState('')

  // Step 1: Dados do Condomínio
  const [tipoEstrutura, setTipoEstrutura] = useState('predio')
  const [condoNome, setCondoNome] = useState('')
  const [condoCep, setCondoCep] = useState('')
  const [condoEndereco, setCondoEndereco] = useState('')
  const [condoNumero, setCondoNumero] = useState('')
  const [condoCidade, setCondoCidade] = useState('')
  const [condoEstado, setCondoEstado] = useState('')

  // Step 2: Dados de Acesso
  const [nome, setNome] = useState('')
  const [whatsapp, setWhatsapp] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [showPwd, setShowPwd] = useState(false)
  const [showConfirmPwd, setShowConfirmPwd] = useState(false)

  // Success modal
  const [showSuccess, setShowSuccess] = useState(false)

  async function handleNext() {
    setGlobalError('')

    if (currentStep === 0) {
      // Validate step 1
      if (!condoNome.trim()) { setGlobalError('Nome do condomínio é obrigatório'); return }
      if (!condoCep.trim()) { setGlobalError('CEP é obrigatório'); return }
      if (!condoEndereco.trim()) { setGlobalError('Endereço é obrigatório'); return }
      if (!condoNumero.trim()) { setGlobalError('Número é obrigatório'); return }
      if (!condoCidade.trim()) { setGlobalError('Cidade é obrigatória'); return }
      if (!condoEstado.trim() || condoEstado.length !== 2) { setGlobalError('Estado deve ter 2 caracteres (sigla)'); return }
      setCurrentStep(1)
    } else if (currentStep === 1) {
      // Validate step 2
      if (!nome.trim()) { setGlobalError('Nome é obrigatório'); return }
      if (!whatsapp || whatsapp.length < 10) { setGlobalError('WhatsApp inválido (mínimo 10 dígitos)'); return }
      if (!email || !email.includes('@')) { setGlobalError('E-mail inválido'); return }
      if (!password || !/^\d+$/.test(password)) { setGlobalError('A senha deve conter apenas números'); return }
      if (password !== confirmPassword) { setGlobalError('As senhas não coincidem'); return }
      await submitRegistration()
    }
  }

  async function submitRegistration() {
    setLoading(true)
    setGlobalError('')
    try {
      // 1. Create auth user
      const { data: signUpData, error: signUpError } = await supabase.auth.signUp({
        email: email.trim().toLowerCase(),
        password,
      })
      if (signUpError) throw signUpError
      const userId = signUpData.user?.id
      if (!userId) throw new Error('Falha ao criar conta')

      // 2. Create condominium
      const { data: condoResult, error: condoError } = await supabase.from('condominios').insert({
        nome: condoNome.trim(),
        cep: condoCep.trim(),
        logradouro: condoEndereco.trim(),
        numero: condoNumero.trim(),
        cidade: condoCidade.trim(),
        estado: condoEstado.trim().toUpperCase(),
        tipo_estrutura: tipoEstrutura,
      }).select().single()
      if (condoError) throw condoError
      const condominioId = condoResult.id

      // 3. Create Bloco "0" and Apto "0" (admin placeholder)
      const { data: blocoResult, error: blocoError } = await supabase.from('blocos').insert({
        condominio_id: condominioId,
        nome_ou_numero: '0',
      }).select().single()
      if (blocoError) throw blocoError

      const { data: aptoResult, error: aptoError } = await supabase.from('apartamentos').insert({
        condominio_id: condominioId,
        numero: '0',
      }).select().single()
      if (aptoError) throw aptoError

      // 4. Create Unidade
      const { data: unidadeResult, error: unidadeError } = await supabase.from('unidades').insert({
        condominio_id: condominioId,
        bloco_id: blocoResult.id,
        apartamento_id: aptoResult.id,
      }).select().single()
      if (unidadeError) throw unidadeError

      // 5. Create Sindico Profile (auto-approved)
      const { error: perfilError } = await supabase.from('perfil').insert({
        id: userId,
        condominio_id: condominioId,
        nome_completo: nome.trim(),
        email: email.trim().toLowerCase(),
        whatsapp: whatsapp.trim(),
        status_aprovacao: 'aprovado',
        tipo_morador: 'Proprietário',
        papel_sistema: 'Síndico',
      })
      if (perfilError) throw perfilError

      // 6. Link Sindico to unit 0-0
      const { error: linkError } = await supabase.from('unidade_perfil').insert({
        perfil_id: userId,
        unidade_id: unidadeResult.id,
      })
      if (linkError) throw linkError

      // 7. Auto-login
      await supabase.auth.signInWithPassword({
        email: email.trim().toLowerCase(),
        password,
      })

      setShowSuccess(true)
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e)
      if (msg.includes('already') || msg.includes('duplicate')) {
        setGlobalError('Este e-mail já existe. Tente fazer login.')
      } else {
        setGlobalError(`Erro no cadastro: ${msg}`)
      }
    } finally {
      setLoading(false)
    }
  }

  const steps = [
    { label: 'Dados do Condomínio', num: 1 },
    { label: 'Seus Dados de Acesso', num: 2 },
  ]

  if (showSuccess) {
    return (
      <div className="min-h-screen bg-[#f4f6f9] flex items-center justify-center p-4">
        <div className="bg-white rounded-3xl shadow-xl w-full max-w-md p-8 text-center">
          <div className="w-20 h-20 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <Check size={40} className="text-green-600" />
          </div>
          <h2 className="text-xl font-bold text-gray-900 mb-2">Condomínio Registrado!</h2>
          <p className="text-sm text-gray-500 mb-6">
            Seu condomínio e perfil de Síndico foram criados com sucesso. Você já está logado e pode começar a configurar tudo.
          </p>
          <button
            onClick={() => { router.push('/condo'); router.refresh() }}
            className="w-full py-3 bg-[#FC5931] text-white rounded-xl font-bold text-sm hover:bg-[#D42F1D] transition-all"
          >
            Acessar o Painel
          </button>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-[#f4f6f9] flex items-center justify-center p-4">
      <div className="bg-white rounded-3xl shadow-xl w-full max-w-lg overflow-hidden">
        {/* Header */}
        <div className="bg-gradient-to-r from-[#FC5931] to-[#D42F1D] px-6 py-4 flex items-center gap-3">
          <button onClick={() => currentStep > 0 ? setCurrentStep(currentStep - 1) : router.push('/login')} className="text-white hover:bg-white/20 rounded-full p-1 transition-colors" title="Voltar">
            <ChevronLeft size={22} />
          </button>
          <h1 className="text-white font-bold text-lg">Cadastro de Síndico</h1>
        </div>

        {/* Stepper indicators */}
        <div className="px-6 pt-6 pb-2">
          <div className="flex gap-4">
            {steps.map((step, i) => (
              <div key={i} className="flex-1">
                <div className="flex items-center gap-2 mb-1">
                  <div className={`w-6 h-6 rounded-full flex items-center justify-center text-xs font-bold flex-shrink-0 transition-all ${
                    i < currentStep ? 'bg-green-500 text-white' :
                    i === currentStep ? 'bg-[#FC5931] text-white' :
                    'bg-gray-200 text-gray-400'
                  }`}>
                    {i < currentStep ? <Check size={12} /> : step.num}
                  </div>
                  <span className={`text-xs ${i === currentStep ? 'text-gray-800 font-semibold' : 'text-gray-400'}`}>
                    {step.label}
                  </span>
                </div>
                <div className={`h-1 rounded-full transition-all ${
                  i < currentStep ? 'bg-green-500' :
                  i === currentStep ? 'bg-[#FC5931]' :
                  'bg-gray-200'
                }`} />
              </div>
            ))}
          </div>
        </div>

        {/* Step content */}
        <div className="px-6 py-4 min-h-[400px]">
          {/* Step 1: Dados do Condomínio */}
          {currentStep === 0 && (
            <div className="space-y-4">
              <p className="text-sm text-gray-500">Bem-vindo, Síndico! Vamos registrar seu condomínio na plataforma.</p>

              <div>
                <label className="text-xs font-medium text-gray-500 mb-1 block">Tipo de Estrutura *</label>
                <select
                  value={tipoEstrutura}
                  onChange={e => setTipoEstrutura(e.target.value)}
                  className="w-full px-4 py-3 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-[#FC5931] bg-gray-50 text-sm appearance-none"
                  title="Tipo de Estrutura"
                >
                  {TIPO_ESTRUTURA_OPTIONS.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
                </select>
              </div>

              <div>
                <label className="text-xs font-medium text-gray-500 mb-1 block">Nome Oficial do Condomínio *</label>
                <div className="relative">
                  <Building2 size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400" />
                  <input
                    type="text"
                    placeholder="Nome do condomínio"
                    value={condoNome}
                    onChange={e => setCondoNome(e.target.value)}
                    className="w-full pl-10 pr-4 py-3 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-[#FC5931] bg-gray-50 text-sm"
                  />
                </div>
              </div>

              <div>
                <label className="text-xs font-medium text-gray-500 mb-1 block">CEP *</label>
                <input
                  type="text"
                  inputMode="numeric"
                  placeholder="00000-000"
                  value={condoCep}
                  onChange={e => setCondoCep(e.target.value.replace(/\D/g, ''))}
                  className="w-full px-4 py-3 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-[#FC5931] bg-gray-50 text-sm"
                />
              </div>

              <div>
                <label className="text-xs font-medium text-gray-500 mb-1 block">Endereço (Rua/Avenida) *</label>
                <div className="relative">
                  <MapPin size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400" />
                  <input
                    type="text"
                    placeholder="Rua/Avenida"
                    value={condoEndereco}
                    onChange={e => setCondoEndereco(e.target.value)}
                    className="w-full pl-10 pr-4 py-3 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-[#FC5931] bg-gray-50 text-sm"
                  />
                </div>
              </div>

              <div className="grid grid-cols-3 gap-3">
                <div>
                  <label className="text-xs font-medium text-gray-500 mb-1 block">Número *</label>
                  <input
                    type="text"
                    placeholder="Nº"
                    value={condoNumero}
                    onChange={e => setCondoNumero(e.target.value)}
                    className="w-full px-4 py-3 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-[#FC5931] bg-gray-50 text-sm"
                  />
                </div>
                <div className="col-span-2">
                  <label className="text-xs font-medium text-gray-500 mb-1 block">Cidade *</label>
                  <input
                    type="text"
                    placeholder="Cidade"
                    value={condoCidade}
                    onChange={e => setCondoCidade(e.target.value)}
                    className="w-full px-4 py-3 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-[#FC5931] bg-gray-50 text-sm"
                  />
                </div>
              </div>

              <div>
                <label className="text-xs font-medium text-gray-500 mb-1 block">Estado (Sigla) *</label>
                <input
                  type="text"
                  placeholder="UF"
                  maxLength={2}
                  value={condoEstado}
                  onChange={e => setCondoEstado(e.target.value.toUpperCase())}
                  className="w-full px-4 py-3 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-[#FC5931] bg-gray-50 text-sm"
                />
                <span className="text-xs text-gray-400 mt-1 block text-right">{condoEstado.length}/2</span>
              </div>
            </div>
          )}

          {/* Step 2: Dados de Acesso */}
          {currentStep === 1 && (
            <div className="space-y-4">
              <div>
                <label className="text-xs font-medium text-gray-500 mb-1 block">Seu Nome Completo *</label>
                <div className="relative">
                  <User size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400" />
                  <input
                    type="text"
                    placeholder="Seu nome completo"
                    value={nome}
                    onChange={e => setNome(e.target.value)}
                    className="w-full pl-10 pr-4 py-3 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-[#FC5931] bg-gray-50 text-sm"
                  />
                </div>
              </div>
              <div>
                <label className="text-xs font-medium text-gray-500 mb-1 block">Seu WhatsApp (Apenas números) *</label>
                <div className="relative">
                  <Phone size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400" />
                  <input
                    type="tel"
                    inputMode="numeric"
                    placeholder="Ex: 11999999999"
                    value={whatsapp}
                    onChange={e => setWhatsapp(e.target.value.replace(/\D/g, ''))}
                    className="w-full pl-10 pr-4 py-3 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-[#FC5931] bg-gray-50 text-sm"
                  />
                </div>
              </div>
              <div>
                <label className="text-xs font-medium text-gray-500 mb-1 block">Seu E-mail Administrativo *</label>
                <div className="relative">
                  <Mail size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400" />
                  <input
                    type="email"
                    placeholder="email@exemplo.com"
                    value={email}
                    onChange={e => setEmail(e.target.value)}
                    className="w-full pl-10 pr-4 py-3 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-[#FC5931] bg-gray-50 text-sm"
                  />
                </div>
              </div>
              <div>
                <label className="text-xs font-medium text-gray-500 mb-1 block">Senha Numérica *</label>
                <div className="relative">
                  <Lock size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400" />
                  <input
                    type={showPwd ? 'text' : 'password'}
                    inputMode="numeric"
                    placeholder="Apenas números"
                    value={password}
                    onChange={e => setPassword(e.target.value.replace(/\D/g, ''))}
                    className="w-full pl-10 pr-11 py-3 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-[#FC5931] bg-gray-50 text-sm"
                  />
                  <button type="button" onClick={() => setShowPwd(!showPwd)} className="absolute right-3.5 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600" title="Mostrar/ocultar senha">
                    {showPwd ? <EyeOff size={16} /> : <Eye size={16} />}
                  </button>
                </div>
              </div>
              <div>
                <label className="text-xs font-medium text-gray-500 mb-1 block">Confirmar Senha *</label>
                <div className="relative">
                  <Lock size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400" />
                  <input
                    type={showConfirmPwd ? 'text' : 'password'}
                    inputMode="numeric"
                    placeholder="Confirme a senha"
                    value={confirmPassword}
                    onChange={e => setConfirmPassword(e.target.value.replace(/\D/g, ''))}
                    className="w-full pl-10 pr-11 py-3 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-[#FC5931] bg-gray-50 text-sm"
                  />
                  <button type="button" onClick={() => setShowConfirmPwd(!showConfirmPwd)} className="absolute right-3.5 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600" title="Mostrar/ocultar senha">
                    {showConfirmPwd ? <EyeOff size={16} /> : <Eye size={16} />}
                  </button>
                </div>
              </div>
            </div>
          )}

          {/* Error */}
          {globalError && (
            <div className="mt-4 p-3 bg-red-50 border border-red-200 rounded-xl">
              <p className="text-red-600 text-xs text-center">{globalError}</p>
            </div>
          )}
        </div>

        {/* Footer buttons */}
        <div className="px-6 pb-6 space-y-3">
          <button
            onClick={handleNext}
            disabled={loading}
            className="w-full py-3 bg-[#FC5931] text-white rounded-xl font-bold text-sm hover:bg-[#D42F1D] transition-all disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
          >
            {loading ? (
              <><Loader2 size={16} className="animate-spin" /> Processando...</>
            ) : (
              currentStep === 1 ? 'Salvar Tudo e Entrar' : 'Avançar'
            )}
          </button>
          {currentStep > 0 && (
            <button
              onClick={() => setCurrentStep(currentStep - 1)}
              className="w-full py-3 border-2 border-gray-200 text-gray-500 rounded-xl font-semibold text-sm hover:bg-gray-50 transition-all"
            >
              Voltar
            </button>
          )}
        </div>

        <p className="text-center text-[10px] text-gray-400 pb-4">
          Todos os direitos reservados à @2SCapital @2026
        </p>
      </div>
    </div>
  )
}
