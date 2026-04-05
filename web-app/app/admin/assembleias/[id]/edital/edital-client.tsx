'use client'

import React, { useState, useEffect } from 'react'
import { ArrowLeft, Printer, Building2, FilePenLine } from 'lucide-react'
import { useRouter } from 'next/navigation'

interface EditalClientProps {
  assembleia: any
  pautas: any[]
  condominio: any
}

export default function EditalClient({ assembleia, pautas, condominio }: EditalClientProps) {
  const router = useRouter()
  
  // Date formatting helpers
  const dt1 = assembleia.dt_1a_convocacao ? new Date(assembleia.dt_1a_convocacao) : null
  const dt2 = assembleia.dt_2a_convocacao ? new Date(assembleia.dt_2a_convocacao) : null

  const getFullDateDisplay = (d: Date | null) => {
    if (!d) return '[DATA]'
    return new Intl.DateTimeFormat('pt-BR', { day: '2-digit', month: 'long', year: 'numeric' }).format(d)
  }

  const getDayOfWeek = (d: Date | null) => {
    if (!d) return '[DIA DA SEMANA]'
    return `(${new Intl.DateTimeFormat('pt-BR', { weekday: 'long' }).format(d)})`
  }

  const getHour = (d: Date | null) => {
    if (!d) return '[HORA]'
    return new Intl.DateTimeFormat('pt-BR', { hour: '2-digit', minute: '2-digit' }).format(d) + 'min'
  }

  // Editable fields state (persisted locally so edits aren't lost on accident)
  
  let textoAbertura = `Prezado(a) Condômino(a),

A Administração do Condomínio ${condominio.nome || '[NOME DO CONDOMÍNIO]'}, no uso das atribuições que lhe foram conferidas pela Convenção Condominial e legislação vigente, convoca todos os condôminos para a ${assembleia.tipo === 'extraordinaria' ? 'Assembleia Geral Extraordinária - AGE' : 'Assembleia Geral Ordinária - AGO'}, a qual será realizada no próximo dia ${getFullDateDisplay(dt1)} ${getDayOfWeek(dt1)}, no local: ${assembleia.local_presencial || 'Auditório/Salão de Festas'}, em primeira convocação, às ${getHour(dt1)}, com pelo menos 2/3 dos condôminos em dia com suas contribuições condominiais, ou em segunda e última convocação, às ${getHour(dt2)}, por maioria dos votos dos presentes.`

  const isOnline = assembleia.modalidade === 'online' || assembleia.modalidade === 'hibrida'
  // Buscando da votação (como preenchido no assistente) se não houver um específico para transmissão, ou sempre usando votação.
  const dtT1 = assembleia.dt_inicio_votacao ? new Date(assembleia.dt_inicio_votacao) : (assembleia.dt_inicio_transmissao ? new Date(assembleia.dt_inicio_transmissao) : null)
  const dtT2 = assembleia.dt_fim_votacao ? new Date(assembleia.dt_fim_votacao) : (assembleia.dt_fim_transmissao ? new Date(assembleia.dt_fim_transmissao) : null)

  if (isOnline) {
    
    // Fallbacks if not configured yet
    const startStr = dtT1 ? `${getFullDateDisplay(dtT1)} às ${getHour(dtT1)}` : '[DATA E HORA DE INÍCIO]'
    const endStr = dtT2 ? `${getFullDateDisplay(dtT2)} às ${getHour(dtT2)}` : '[DATA E HORA DE ENCERRAMENTO]'

    textoAbertura += `\n\nA assembleia contará com ambiente virtual, cujo período de interações no chat e votações online começará em ${startStr} e se encerrará em ${endStr}.`
  }

  textoAbertura += `\n\nA convocação é feita para tratarem da seguinte pauta:`

  const defaultAbertura = textoAbertura

  const defaultObservacoes = `• Todos deverão apresentar documento com foto no ato da assinatura da lista de presença.
• Os condôminos podem ser representados nesta assembleia por procuradores, munidos com procurações específicas.
• Somente poderão votar nas assembleias os condôminos que estiverem quites com todas as suas obrigações condominiais e que estejam devidamente relacionados como proprietário do imóvel na lista de presença, sendo assim, é necessária atualização cadastral junto à administradora.
• As decisões das assembleias obrigam a todos os condôminos, ainda que a ela não tenham comparecido ou votado;`

  const [cidadeData, setCidadeData] = useState(`${condominio.cidade || 'Brasília'}-${condominio.estado || 'DF'}, ${getFullDateDisplay(new Date())}.`)
  const [abertura, setAbertura] = useState(defaultAbertura)
  const [observacoes, setObservacoes] = useState(defaultObservacoes)
  const [sindicoNome, setSindicoNome] = useState('Nome do Síndico')
  const [signatureImage, setSignatureImage] = useState<string | null>(null)
  
  // Try to load from localStorage if edited previously
  useEffect(() => {
    const saved = localStorage.getItem(`edital_${assembleia.id}`)
    if (saved) {
      try {
        const parsed = JSON.parse(saved)
        if (parsed.cidadeData) setCidadeData(parsed.cidadeData)
        if (parsed.abertura) setAbertura(parsed.abertura)
        if (parsed.observacoes) setObservacoes(parsed.observacoes)
        if (parsed.sindicoNome) setSindicoNome(parsed.sindicoNome)
        if (parsed.signatureImage) setSignatureImage(parsed.signatureImage)
      } catch (err) {
        console.error("Error parsing local storage", err)
      }
    }
  }, [assembleia.id])

  const saveToLocal = (key: string, value: string | null) => {
    try {
      const current = JSON.parse(localStorage.getItem(`edital_${assembleia.id}`) || '{}')
      current[key] = value
      localStorage.setItem(`edital_${assembleia.id}`, JSON.stringify(current))
    } catch(err) {
      console.error(err)
    }
  }

  const handlePrint = () => {
    window.print()
  }

  const handleSignatureUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return
    const reader = new FileReader()
    reader.onload = (event) => {
      const dataUrl = event.target?.result as string
      setSignatureImage(dataUrl)
      saveToLocal('signatureImage', dataUrl)
    }
    reader.readAsDataURL(file)
  }

  const handleRemoveSignature = () => {
    setSignatureImage(null)
    saveToLocal('signatureImage', null)
  }

  return (
    <div className="bg-gray-100 min-h-screen py-8 print:py-0 print:bg-white text-black font-sans">
      
      {/* --- TOP CONTROL BAR (Hidden on Print) --- */}
      <div className="max-w-[210mm] mx-auto mb-6 flex justify-between items-center print:hidden px-4 sm:px-0">
        <button
          onClick={() => router.push(`/admin/assembleias/${assembleia.id}`)}
          className="flex items-center gap-2 text-gray-600 hover:text-gray-900 transition-colors"
        >
          <ArrowLeft size={20} />
          <span>Voltar para Assembleia</span>
        </button>

        <div className="flex items-center gap-4">
          <div className="flex items-center gap-2 text-sm text-gray-500 bg-white px-3 py-1.5 rounded-lg border border-gray-200">
            <FilePenLine size={16} />
            <span>Campos com borda amarela são editáveis</span>
          </div>

          <button
            onClick={handlePrint}
            className="flex items-center gap-2 px-5 py-2.5 bg-[#FC5931] text-white hover:bg-[#e04f2c] rounded-xl font-bold transition-all shadow-md"
          >
            <Printer size={18} />
            Imprimir / Gerar PDF
          </button>
        </div>
      </div>

      {/* --- A4 PAGE: EDITAL --- */}
      <div className="bg-white mx-auto shadow-xl print:shadow-none w-[210mm] min-h-[297mm] relative flex flex-col" style={{ WebkitPrintColorAdjust: 'exact', printColorAdjust: 'exact' }}>
        
        {/* TOP GRAPHIC ACCENT */}
        <div className="absolute top-0 left-0 w-full h-[240px] pointer-events-none z-0">
          <svg viewBox="0 0 100 100" preserveAspectRatio="none" className="w-full h-full opacity-95">
            <path d="M0,0 L100,0 C60,40 40,80 0,100 Z" fill="#F3F4F6"></path>
            <path d="M0,0 L70,0 C40,30 20,60 0,80 Z" fill="#111827"></path>
            <path d="M0,0 L40,0 C20,20 10,40 0,50 Z" fill="#FC5931"></path>
          </svg>
        </div>

        {/* WATERMARK P1 */}
        <div className="absolute inset-0 flex items-center justify-center pointer-events-none z-0 overflow-hidden">
           <img 
             src="/logo.png" 
             alt="watermark" 
             className="w-[70%] object-contain opacity-[0.05] print:opacity-[0.05]" 
             style={{ 
               filter: 'grayscale(100%)',
               mixBlendMode: 'multiply',
             }} 
           />
        </div>

        {/* CONTENT CONTAINER */}
        <div className="relative z-10 flex-1 flex flex-col p-[20mm] print:p-[15mm]">
        
        {/* HEADER */}
        <div className="flex pt-2 mb-8 items-start justify-between">
          <div className="w-[30%]"></div> {/* Space over the left wave */}

          {/* Logo Condominio Center */}
          <div className="flex flex-col items-center w-[40%]">
             <div className="w-20 h-20 bg-white border border-gray-100 rounded-full flex items-center justify-center p-2 shadow-sm text-gray-400 mb-2">
               <img src="/logo.png" className="w-full h-full object-contain grayscale opacity-80" alt="Logo" />
             </div>
             <h1 className="text-2xl font-serif font-black text-gray-900 tracking-tight text-center leading-none">{condominio.nome || 'Condomínio'}</h1>
             <p className="text-[10px] font-sans font-bold text-gray-400 tracking-[0.25em] uppercase mt-2">Residencial</p>
          </div>
          
          {/* Adm Logo */}
          <div className="w-[30%] flex justify-end">
             <div className="flex flex-col items-end pt-2">
                <div className="flex items-center gap-2">
                  <div className="w-6 h-6 border-2 border-gray-200 rounded flex items-center justify-center opacity-70">
                    <Building2 size={12} className="text-gray-400" />
                  </div>
                  <strong className="text-lg text-gray-500 font-serif leading-none tracking-tight">Condomeet</strong>
                </div>
                <span className="text-[9px] tracking-[0.2em] text-[#FC5931] font-bold uppercase mt-1">Administradora</span>
             </div>
          </div>
        </div>

        {/* TITLE E INFO VIRTUAL */}
        <div className="text-center mb-8 pt-4">
          <h2 className="text-4xl font-serif font-black text-[#FC5931] uppercase tracking-wide">
            Edital de Convocação
          </h2>
          <h3 className="text-2xl font-serif text-gray-800 mt-4 font-semibold">
            {assembleia.tipo === 'extraordinaria' ? 'Assembleia Geral Extraordinária' : 'Assembleia Geral Ordinária'}
          </h3>
          <p className="text-xl font-serif font-semibold text-gray-500 mt-2">
            {getFullDateDisplay(dt1)} {getDayOfWeek(dt1)}
          </p>
        </div>

        {/* DATE / CITY */}
        <div className="text-right mb-8">
           <input 
             value={cidadeData}
             onChange={e => {
               setCidadeData(e.target.value)
               saveToLocal('cidadeData', e.target.value)
             }}
             className="text-right font-bold text-gray-800 bg-transparent border-b border-transparent hover:border-yellow-400 focus:border-yellow-500 outline-none print:border-transparent w-full"
           />
        </div>

        {/* ABERTURA */}
        <div className="mb-8">
          <textarea
            value={abertura}
            onChange={e => {
              setAbertura(e.target.value)
              saveToLocal('abertura', e.target.value)
            }}
            className="w-full text-justify text-gray-800 bg-transparent border border-transparent hover:border-yellow-400 focus:border-yellow-500 rounded p-1 outline-none print:border-transparent resize-none overflow-hidden"
            rows={10}
          />
        </div>

        {/* PAUTAS */}
        <div className="mb-10 pl-8 pr-4">
          <ol className="list-decimal text-gray-800 space-y-4 text-justify font-medium">
            {pautas.map((pauta) => (
              <li key={pauta.id} className="pl-2 marker:font-bold marker:text-[#FC5931]">
                {pauta.titulo}
                {pauta.descricao && (
                  <span className="font-normal block mt-1 text-gray-600">{pauta.descricao}</span>
                )}
              </li>
            ))}
            {pautas.length === 0 && (
              <li className="pl-2 font-normal text-gray-500 italic">Nenhuma pauta cadastrada.</li>
            )}
          </ol>
        </div>

        {/* INFO VOTAÇÃO ELETRÔNICA */}
        {isOnline && (dtT1 || dtT2) && (
          <div className="mb-10 px-8">
            <div className="border border-[#FC5931] bg-[#FC5931]/5 p-4 rounded-lg shadow-sm print:border-gray-800 print:bg-transparent">
               <p className="font-bold text-[#FC5931] print:text-gray-900 mb-3 uppercase text-sm tracking-widest text-center">Informações da Votação Eletrônica</p>
               <div className="flex justify-center flex-wrap gap-x-12 gap-y-2">
                 <p className="text-gray-800 text-sm"><strong>Abertura:</strong> {dtT1 ? `${getFullDateDisplay(dtT1)} às ${getHour(dtT1)}` : 'Não definida'}</p>
                 <p className="text-gray-800 text-sm"><strong>Encerramento:</strong> {dtT2 ? `${getFullDateDisplay(dtT2)} às ${getHour(dtT2)}` : 'Não definida'}</p>
               </div>
               <p className="text-gray-700 text-sm mt-3 text-center"><strong>Ambiente:</strong> Aplicativo / Portal Condomeet</p>
            </div>
          </div>
        )}

        {/* OBSERVAÇÕES */}
        <div className="mb-12">
          <h4 className="font-bold text-[#FC5931] text-lg mb-3">Observações:</h4>
          <textarea
            value={observacoes}
            onChange={e => {
              setObservacoes(e.target.value)
              saveToLocal('observacoes', e.target.value)
            }}
            className="w-full text-justify text-gray-800 bg-transparent border border-transparent hover:border-yellow-400 focus:border-yellow-500 rounded p-1 outline-none print:border-transparent resize-none overflow-hidden"
            rows={8}
          />
        </div>

        {/* ASSINATURA */}
        <div className="mt-16 flex flex-col items-center justify-center pb-8 border-b-2 border-transparent">
          <div className="h-28 flex items-end justify-center mb-2 relative w-64 group relative">
            {signatureImage ? (
              <div className="relative w-full h-full flex justify-center items-center">
                <img src={signatureImage} alt="Assinatura" className="max-h-full max-w-full object-contain" />
                <button 
                  onClick={handleRemoveSignature}
                  className="absolute -top-4 -right-4 bg-red-100 text-red-600 rounded-full p-1 print:hidden opacity-0 group-hover:opacity-100 transition-opacity"
                  title="Remover assinatura"
                >
                  <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M18 6 6 18"/><path d="m6 6 12 12"/></svg>
                </button>
              </div>
            ) : (
              <label className="cursor-pointer flex flex-col items-center justify-center text-gray-400 hover:text-blue-500 transition-colors py-4 border-2 border-dashed border-gray-200 hover:border-blue-400 rounded-lg w-full h-full print:hidden">
                <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="mb-2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" x2="12" y1="3" y2="15"/></svg>
                <span className="text-sm font-medium text-center px-2">Anexar Imagem<br/>da Assinatura</span>
                <input type="file" accept="image/png, image/jpeg, image/jpg" className="hidden" onChange={handleSignatureUpload} />
              </label>
            )}
          </div>
          <div className="w-64 h-px bg-gray-800 mb-2"></div>
          <input 
             value={sindicoNome}
             onChange={e => {
               setSindicoNome(e.target.value)
               saveToLocal('sindicoNome', e.target.value)
             }}
             className="text-center font-bold text-xl text-gray-900 bg-transparent border-b border-transparent hover:border-yellow-400 focus:border-yellow-500 outline-none print:border-transparent w-full max-w-[300px]"
          />
          <p className="text-gray-600 font-medium">Síndico(a) {condominio.nome}</p>
          <p className="text-gray-500 text-sm mt-4">Sua presença é muito importante. Compareça!</p>
        </div>

        {/* FOOTER */}
        <div className="mt-auto pt-4 border-t border-gray-200 flex justify-between items-end text-[10px] text-gray-500 relative z-10 w-full mb-0 uppercase tracking-wider font-medium">
          <div className="flex-1">
            <p className="text-gray-800 font-bold">{condominio.nome}</p>
            <p>{condominio.logradouro}, {condominio.numero} {condominio.complemento && `- ${condominio.complemento}`}</p>
            <p>{condominio.bairro}</p>
          </div>
          <div className="flex-1 text-right">
             <p>{condominio.cidade} - {condominio.estado}</p>
             <p>CEP: {condominio.cep}</p>
          </div>
        </div>

        </div> {/* END CONTENT CONTAINER */}
      </div>

      {/* --- PAGE BREAK FOR PRINT --- */}
      <div className="break-before-page"></div>

      {/* --- A4 PAGE 2: PROCURAÇÃO --- */}
      <div className="bg-white mx-auto shadow-xl print:shadow-none w-[210mm] min-h-[297mm] relative flex flex-col mt-8 print:mt-0" style={{ WebkitPrintColorAdjust: 'exact', printColorAdjust: 'exact' }}>
        
        {/* TOP GRAPHIC ACCENT P2 */}
        <div className="absolute top-0 right-0 w-full h-[160px] pointer-events-none z-0 transform scale-x-[-1]">
          <svg viewBox="0 0 100 100" preserveAspectRatio="none" className="w-full h-full opacity-90">
            <path d="M0,0 L100,0 C60,40 40,80 0,100 Z" fill="#F3F4F6"></path>
            <path d="M0,0 L70,0 C40,30 20,60 0,80 Z" fill="#111827"></path>
            <path d="M0,0 L40,0 C20,20 10,40 0,50 Z" fill="#FC5931"></path>
          </svg>
        </div>

        {/* WATERMARK P2 */}
        <div className="absolute inset-0 flex items-center justify-center pointer-events-none z-0 overflow-hidden">
           <img 
             src="/logo.png" 
             alt="watermark" 
             className="w-[70%] object-contain opacity-[0.05] print:opacity-[0.05]" 
             style={{ 
               filter: 'grayscale(100%)',
               mixBlendMode: 'multiply',
             }} 
           />
        </div>

        {/* CONTENT CONTAINER P2 */}
        <div className="relative z-10 flex-1 flex flex-col p-[20mm] print:p-[15mm]">
        
        {/* HEADER P2 */}
         <div className="flex justify-center items-center mb-10 border-b-2 border-gray-100 pb-8 pt-4">
          <div className="flex flex-col items-center gap-3">
             <div className="w-16 h-16 bg-white border border-gray-100 rounded-full flex items-center justify-center p-2 shadow-sm text-gray-400">
               <img src="/logo.png" className="w-full h-full object-contain grayscale opacity-80" alt="Logo" />
             </div>
             <h1 className="text-xl font-serif font-black text-gray-900 tracking-tight text-center">{condominio.nome || 'Condomínio'}</h1>
          </div>
        </div>

        {/* TITLE P2 */}
        <div className="text-center mb-12">
          <h2 className="text-3xl font-serif font-black text-[#FC5931] uppercase tracking-widest">
            Procuração
          </h2>
        </div>

        {/* TEXTO PROCURAÇÃO */}
        <div className="text-justify text-lg leading-loose text-gray-800 space-y-6 px-4">
          <p>
            Pelo presente instrumento particular de procuração, eu, <span className="inline-block w-[350px] border-b border-gray-400"></span>, 
            RG: <span className="inline-block w-[150px] border-b border-gray-400"></span>, 
            CPF: <span className="inline-block w-[200px] border-b border-gray-400"></span>, 
            proprietário da unidade <span className="inline-block w-[120px] border-b border-gray-400"></span> do 
            <strong> {condominio.nome}</strong>, constituo e nomeio meu bastante procurador(a) o(a) 
            Sr(a). <span className="inline-block w-[350px] border-b border-gray-400"></span>, 
            RG: <span className="inline-block w-[150px] border-b border-gray-400"></span>, 
            CPF: <span className="inline-block w-[200px] border-b border-gray-400"></span>, outorgando-lhe poderes para representar na 
            <strong> {assembleia.tipo === 'extraordinaria' ? 'Assembleia Geral Extraordinária' : 'Assembleia Geral Ordinária'} </strong> 
            a realizar-se no dia <strong>{getFullDateDisplay(dt1)}</strong>, podendo para tanto, aprovar ou rejeitar qualquer proposta, 
            apresentar proposições, votar e ser votado(a), enfim, praticar todos os atos que se façam necessários para bem me representar.
          </p>

          <div className="text-right mt-16 pt-8 pr-4">
             {condominio.cidade || 'Brasília'}, <span className="inline-block w-12 border-b border-gray-400"></span> de <span className="inline-block w-32 border-b border-gray-400"></span> de 202__
          </div>
        </div>

        {/* ASSINATURA P2 */}
        <div className="mt-32 flex flex-col items-center justify-center">
          <div className="w-96 h-px bg-gray-800 mb-2"></div>
          <p className="text-gray-900 font-bold text-xl uppercase tracking-widest font-serif">Assinatura</p>
        </div>


        </div> {/* END CONTENT CONTAINER P2 */}
      </div>
    </div>
  )
}
