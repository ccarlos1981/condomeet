'use client'
import { useState, useCallback } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'
import { Search, ChevronLeft, Building2, Mail, Lock, User, Phone, Eye, EyeOff, Check, Loader2 } from 'lucide-react'

const TIPO_USUARIO_OPTIONS = [
  'Proprietário (a)',
  'Inquilino (a)',
  'Cônjuge',
  'Dependente',
  'Família',
  'Funcionário (a)',
  'Terceirizado (a)',
]

const PERFIL_USUARIO_OPTIONS = [
  'Morador(a)',
  'Proprietário não morador',
  'Locatário (a)',
  'Locador',
  'Funcionário (a)',
  'Porteiro (a)',
  'Zelador (a)',
  'Síndico (a)',
  'Sub Síndico (a)',
  'Afiliado (a)',
  'Terceirizado (a)',
  'Financeiro',
  'Serviços',
]

function getNivel1Label(tipo: string) {
  if (tipo === 'casa_rua') return 'Rua'
  if (tipo === 'casa_quadra') return 'Quadra'
  return 'Bloco'
}

function getNivel2Label(tipo: string) {
  if (tipo === 'casa_rua') return 'Número'
  if (tipo === 'casa_quadra') return 'Lote'
  return 'Apartamento'
}

export default function RegisterPage() {
  const router = useRouter()
  const supabase = createClient()
  const [currentStep, setCurrentStep] = useState(0)
  const [loading, setLoading] = useState(false)
  const [globalError, setGlobalError] = useState('')

  // Step 1: Condomínio
  const [searchQuery, setSearchQuery] = useState('')
  const [isSearching, setIsSearching] = useState(false)
  const [condominios, setCondominios] = useState<any[]>([])
  const [selectedCondo, setSelectedCondo] = useState<any>(null)
  const [tipoEstrutura, setTipoEstrutura] = useState('predio')

  // Step 2: Conta
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [emailError, setEmailError] = useState('')
  const [isCheckingEmail, setIsCheckingEmail] = useState(false)
  const [showPwd, setShowPwd] = useState(false)
  const [showConfirmPwd, setShowConfirmPwd] = useState(false)

  // Step 3: Dados
  const [nome, setNome] = useState('')
  const [whatsapp, setWhatsapp] = useState('')
  const [tipoUsuario, setTipoUsuario] = useState('Proprietário (a)')
  const [perfilUsuario, setPerfilUsuario] = useState('Morador(a)')
  const [consentimentoWhatsapp, setConsentimentoWhatsapp] = useState(true)

  // Step 4: Unidade
  const [blocos, setBlocos] = useState<any[]>([])
  const [apartamentos, setApartamentos] = useState<any[]>([])
  const [selectedBlocoId, setSelectedBlocoId] = useState('')
  const [selectedAptoId, setSelectedAptoId] = useState('')

  // Success modal
  const [showSuccess, setShowSuccess] = useState(false)

  // Debounced search
  const searchCondominios = useCallback(
    (() => {
      let timer: ReturnType<typeof setTimeout>
      return (query: string) => {
        clearTimeout(timer)
        if (query.length < 3) {
          setCondominios([])
          return
        }
        timer = setTimeout(async () => {
          setIsSearching(true)
          try {
            const { data } = await supabase
              .from('condominios')
              .select('id, nome, cidade, estado, tipo_estrutura')
              .ilike('nome', `%${query}%`)
              .order('nome')
              .limit(10)
            setCondominios(data || [])
          } catch { /* ignore */ }
          setIsSearching(false)
        }, 500)
      }
    })(),
    [supabase]
  )

  async function fetchBlocos(condoId: string) {
    const { data } = await supabase
      .from('blocos')
      .select('id, nome_ou_numero')
      .eq('condominio_id', condoId)
      .order('nome_ou_numero')
      .limit(10000)
    setBlocos((data || []).filter((b: any) => b.nome_ou_numero !== '0'))
    setSelectedBlocoId('')
    setSelectedAptoId('')
    setApartamentos([])
  }

  async function fetchApartamentos(condoId: string, blocoId: string) {
    const { data } = await supabase
      .from('unidades')
      .select('apartamento_id, apartamentos(numero)')
      .eq('condominio_id', condoId)
      .eq('bloco_id', blocoId)
      .order('apartamentos(numero)')
      .limit(10000)

    const aptos = (data || []).map((e: any) => {
      const aptoData = e.apartamentos
      let numero = '0'
      if (Array.isArray(aptoData) && aptoData.length > 0) {
        numero = String(aptoData[0].numero)
      } else if (aptoData && typeof aptoData === 'object') {
        numero = String(aptoData.numero)
      }
      return { id: e.apartamento_id, numero }
    }).filter((e: any) => e.numero !== '0')

    setApartamentos(aptos)
    setSelectedAptoId('')
  }

  function selectCondo(condo: any) {
    setSelectedCondo(condo)
    setTipoEstrutura(condo.tipo_estrutura || 'predio')
    setCondominios([])
    setSearchQuery('')
    fetchBlocos(condo.id)
  }

  async function handleNext() {
    setGlobalError('')

    if (currentStep === 0) {
      if (!selectedCondo) {
        setGlobalError('Selecione seu condomínio primeiro')
        return
      }
      setCurrentStep(1)
    } else if (currentStep === 1) {
      // Validate email
      if (!email || !email.includes('@')) {
        setGlobalError('E-mail inválido')
        return
      }
      // Check email availability
      setIsCheckingEmail(true)
      try {
        const { data: exists } = await supabase.rpc('check_email_exists', { email_to_check: email.trim() })
        if (exists === true) {
          setEmailError('Este e-mail já existe. Tente fazer login.')
          setIsCheckingEmail(false)
          return
        }
      } catch {
        setEmailError('Erro ao verificar e-mail.')
        setIsCheckingEmail(false)
        return
      }
      setIsCheckingEmail(false)
      setEmailError('')

      if (!password || !/^\d+$/.test(password)) {
        setGlobalError('A senha deve conter apenas números')
        return
      }
      if (password !== confirmPassword) {
        setGlobalError('As senhas não coincidem')
        return
      }
      setCurrentStep(2)
    } else if (currentStep === 2) {
      if (!nome.trim()) { setGlobalError('Nome é obrigatório'); return }
      if (!whatsapp || whatsapp.length < 10) { setGlobalError('WhatsApp inválido (mínimo 10 dígitos)'); return }
      setCurrentStep(3)
    } else if (currentStep === 3) {
      if (!selectedBlocoId || !selectedAptoId) {
        setGlobalError(`Selecione ${getNivel1Label(tipoEstrutura)} e ${getNivel2Label(tipoEstrutura)}`)
        return
      }
      await submitRegistration()
    }
  }

  async function submitRegistration() {
    setLoading(true)
    setGlobalError('')
    try {
      // Get unidade_id
      const { data: unidade } = await supabase
        .from('unidades')
        .select('id')
        .eq('condominio_id', selectedCondo.id)
        .eq('bloco_id', selectedBlocoId)
        .eq('apartamento_id', selectedAptoId)
        .maybeSingle()

      if (!unidade) {
        setGlobalError('Unidade não encontrada. Tente novamente.')
        setLoading(false)
        return
      }

      // Resolve bloco/apto text
      const blocoData = blocos.find((b: any) => b.id === selectedBlocoId)
      const aptoData = apartamentos.find((a: any) => a.id === selectedAptoId)

      // 1. Create auth user
      const { data: signUpData, error: signUpError } = await supabase.auth.signUp({
        email: email.trim().toLowerCase(),
        password,
      })
      if (signUpError) throw signUpError
      const userId = signUpData.user?.id
      if (!userId) throw new Error('Falha ao criar conta')

      // 2. Insert perfil
      const { error: perfilError } = await supabase.from('perfil').insert({
        id: userId,
        condominio_id: selectedCondo.id,
        nome_completo: nome.trim(),
        email: email.trim().toLowerCase(),
        whatsapp: whatsapp.trim(),
        whatsapp_msg_consent: consentimentoWhatsapp,
        status_aprovacao: 'pendente',
        tipo_morador: tipoUsuario,
        papel_sistema: perfilUsuario,
        bloco_txt: blocoData?.nome_ou_numero || null,
        apto_txt: aptoData?.numero || null,
      })
      if (perfilError) throw perfilError

      // 3. Link unit
      const { error: linkError } = await supabase.from('unidade_perfil').insert({
        perfil_id: userId,
        unidade_id: unidade.id,
      })
      if (linkError) throw linkError

      // 4. Auto-login
      await supabase.auth.signInWithPassword({
        email: email.trim().toLowerCase(),
        password,
      })

      // Show success / pending approval
      setShowSuccess(true)
    } catch (e: any) {
      const msg = e?.message || String(e)
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
    { label: 'Condomínio', num: 1 },
    { label: 'Conta', num: 2 },
    { label: 'Dados', num: 3 },
    { label: 'Unidade', num: 4 },
  ]

  if (showSuccess) {
    return (
      <div className="min-h-screen bg-[#f4f6f9] flex items-center justify-center p-4">
        <div className="bg-white rounded-3xl shadow-xl w-full max-w-md p-8 text-center">
          <div className="w-20 h-20 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <Check size={40} className="text-green-600" />
          </div>
          <h2 className="text-xl font-bold text-gray-900 mb-2">Cadastro Realizado!</h2>
          <p className="text-sm text-gray-500 mb-6">
            Seu cadastro foi enviado para aprovação do Síndico ou Administradora responsável pelo condomínio.
          </p>
          <div className="bg-gray-50 rounded-xl p-4 mb-6">
            <p className="text-xs text-gray-500">
              💡 <strong>Dica:</strong> O síndico costuma analisar solicitações em horários comerciais.
            </p>
          </div>
          <button
            onClick={() => router.push('/login')}
            className="w-full py-3 bg-[#FC5931] text-white rounded-xl font-bold text-sm hover:bg-[#D42F1D] transition-all"
          >
            Voltar ao Início
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
          <h1 className="text-white font-bold text-lg">Cadastro de Morador</h1>
        </div>

        {/* Stepper indicators */}
        <div className="px-6 pt-6 pb-2">
          <div className="flex gap-2">
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
                  <span className={`text-xs truncate ${i === currentStep ? 'text-gray-800 font-semibold' : 'text-gray-400'}`}>
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
        <div className="px-6 py-4 min-h-[340px]">
          {/* Step 1: Condomínio */}
          {currentStep === 0 && (
            <div className="space-y-4">
              <p className="text-base font-bold text-gray-800">Qual é o seu condomínio?</p>

              {selectedCondo ? (
                <div className="flex items-center justify-between p-4 bg-[#FC5931]/10 border border-[#FC5931] rounded-xl">
                  <div className="flex items-center gap-3">
                    <Building2 size={18} className="text-[#FC5931]" />
                    <span className="font-semibold text-sm text-gray-800">{selectedCondo.nome}</span>
                  </div>
                  <button onClick={() => { setSelectedCondo(null); setBlocos([]); setApartamentos([]) }} className="text-red-500 hover:text-red-700 text-xs font-medium" title="Remover seleção">
                    ✕
                  </button>
                </div>
              ) : (
                <>
                  <div className="relative">
                    <Search size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400" />
                    <input
                      type="text"
                      placeholder="Digite o nome do condomínio"
                      value={searchQuery}
                      onChange={e => { setSearchQuery(e.target.value); searchCondominios(e.target.value) }}
                      className="w-full pl-10 pr-10 py-3 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-[#FC5931] bg-gray-50 text-sm"
                    />
                    {isSearching && <Loader2 size={16} className="absolute right-3.5 top-1/2 -translate-y-1/2 text-gray-400 animate-spin" />}
                  </div>

                  {condominios.length > 0 && (
                    <div className="border border-gray-200 rounded-xl overflow-hidden max-h-60 overflow-y-auto">
                      {condominios.map(c => (
                        <button
                          key={c.id}
                          onClick={() => selectCondo(c)}
                          className="w-full text-left px-4 py-3 hover:bg-[#FC5931]/5 border-b border-gray-100 last:border-0 transition-colors"
                        >
                          <div className="flex items-center gap-3">
                            <Building2 size={16} className="text-[#FC5931] flex-shrink-0" />
                            <div>
                              <p className="text-sm font-medium text-gray-800">{c.nome}</p>
                              <p className="text-xs text-gray-400">{c.cidade} - {c.estado}</p>
                            </div>
                          </div>
                        </button>
                      ))}
                    </div>
                  )}
                </>
              )}
            </div>
          )}

          {/* Step 2: Conta */}
          {currentStep === 1 && (
            <div className="space-y-4">
              <div>
                <label className="text-xs font-medium text-gray-500 mb-1 block">Seu melhor e-mail</label>
                <div className="relative">
                  <Mail size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400" />
                  <input
                    type="email"
                    placeholder="email@exemplo.com"
                    value={email}
                    onChange={e => { setEmail(e.target.value); setEmailError('') }}
                    className="w-full pl-10 pr-4 py-3 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-[#FC5931] bg-gray-50 text-sm"
                  />
                </div>
                {emailError && (
                  <div className="mt-2 p-3 bg-red-50 border border-red-200 rounded-xl flex items-center gap-2">
                    <span className="text-red-500 text-xs">⚠️ {emailError}</span>
                  </div>
                )}
                {isCheckingEmail && (
                  <div className="mt-2 flex items-center gap-2 text-xs text-gray-400">
                    <Loader2 size={14} className="animate-spin" /> Verificando e-mail...
                  </div>
                )}
              </div>
              <div>
                <label className="text-xs font-medium text-gray-500 mb-1 block">Senha Numérica</label>
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
                <label className="text-xs font-medium text-gray-500 mb-1 block">Confirmar Senha</label>
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

          {/* Step 3: Dados */}
          {currentStep === 2 && (
            <div className="space-y-4">
              <div>
                <label className="text-xs font-medium text-gray-500 mb-1 block">Nome Completo</label>
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
                <label className="text-xs font-medium text-gray-500 mb-1 block">WhatsApp</label>
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
                <label className="text-xs font-medium text-gray-500 mb-1 block">Tipo de Usuário</label>
                <select
                  value={tipoUsuario}
                  onChange={e => setTipoUsuario(e.target.value)}
                  className="w-full px-4 py-3 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-[#FC5931] bg-gray-50 text-sm appearance-none"
                  title="Tipo de Usuário"
                >
                  {TIPO_USUARIO_OPTIONS.map(o => <option key={o} value={o}>{o}</option>)}
                </select>
              </div>
              <div>
                <label className="text-xs font-medium text-gray-500 mb-1 block">Perfil de Usuário</label>
                <select
                  value={perfilUsuario}
                  onChange={e => setPerfilUsuario(e.target.value)}
                  className="w-full px-4 py-3 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-[#FC5931] bg-gray-50 text-sm appearance-none"
                  title="Perfil de Usuário"
                >
                  {PERFIL_USUARIO_OPTIONS.map(o => <option key={o} value={o}>{o}</option>)}
                </select>
              </div>
              <label className="flex items-start gap-3 cursor-pointer">
                <input
                  type="checkbox"
                  checked={consentimentoWhatsapp}
                  onChange={e => setConsentimentoWhatsapp(e.target.checked)}
                  className="w-4 h-4 mt-0.5 rounded accent-[#FC5931]"
                />
                <span className="text-xs text-gray-600">Aceito receber notificações importantes pelo WhatsApp</span>
              </label>
            </div>
          )}

          {/* Step 4: Unidade */}
          {currentStep === 3 && (
            <div className="space-y-4">
              <p className="text-base font-bold text-gray-800">Selecione onde você mora:</p>
              <div>
                <label className="text-xs font-medium text-gray-500 mb-1 block">
                  Qual seu(sua) {getNivel1Label(tipoEstrutura)}?
                </label>
                <select
                  value={selectedBlocoId}
                  onChange={e => {
                    setSelectedBlocoId(e.target.value)
                    if (e.target.value) fetchApartamentos(selectedCondo.id, e.target.value)
                  }}
                  className="w-full px-4 py-3 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-[#FC5931] bg-gray-50 text-sm appearance-none"
                  title={getNivel1Label(tipoEstrutura)}
                >
                  <option value="">Selecionar...</option>
                  {blocos.map((b: any) => (
                    <option key={b.id} value={b.id}>{getNivel1Label(tipoEstrutura)} {b.nome_ou_numero}</option>
                  ))}
                </select>
              </div>
              <div>
                <label className="text-xs font-medium text-gray-500 mb-1 block">
                  Qual seu(sua) {getNivel2Label(tipoEstrutura)}?
                </label>
                <select
                  value={selectedAptoId}
                  onChange={e => setSelectedAptoId(e.target.value)}
                  disabled={!selectedBlocoId}
                  className="w-full px-4 py-3 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-[#FC5931] bg-gray-50 text-sm appearance-none disabled:opacity-50"
                  title={getNivel2Label(tipoEstrutura)}
                >
                  <option value="">Selecionar...</option>
                  {apartamentos.map((a: any) => (
                    <option key={a.id} value={a.id}>{getNivel2Label(tipoEstrutura)} {a.numero}</option>
                  ))}
                </select>
              </div>
              <p className="text-xs text-gray-400 text-center mt-4">
                Ao clicar em finalizar, seu cadastro será enviado para aprovação do Síndico ou Administradora responsável pelo condomínio.
              </p>
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
              currentStep === 3 ? 'Finalizar Cadastro' : 'Avançar'
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
