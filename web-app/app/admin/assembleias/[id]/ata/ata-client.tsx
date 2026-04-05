'use client'

import React, { useState, useEffect, useRef } from 'react'
import { ArrowLeft, Printer, Building2, Save, FileSignature, CheckCircle2, RotateCcw } from 'lucide-react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'

interface AtaClientProps {
  assembleia: any
  condominio: any
}

export default function AtaClient({ assembleia, condominio }: AtaClientProps) {
  const router = useRouter()
  const supabase = createClient()
  
  const [ataTexto, setAtaTexto] = useState(assembleia.ata_texto || '')
  const [isSaving, setIsSaving] = useState(false)
  const [isGenerating, setIsGenerating] = useState(false)
  const [showSavedMsg, setShowSavedMsg] = useState(false)
  
  const [presidenteNome, setPresidenteNome] = useState(assembleia.presidente_mesa || 'Nome do Presidente')
  const [secretarioNome, setSecretarioNome] = useState(assembleia.secretario_mesa || 'Nome do Secretário')

  const textareaRef = useRef<HTMLTextAreaElement>(null)

  // Ajusta altura do textarea
  useEffect(() => {
    if (textareaRef.current) {
      textareaRef.current.style.height = 'auto'
      textareaRef.current.style.height = `${textareaRef.current.scrollHeight}px`
    }
  }, [ataTexto])

  const handleSave = async () => {
    setIsSaving(true)
    try {
      const { error } = await supabase
        .from('assembleias')
        .update({ ata_texto: ataTexto })
        .eq('id', assembleia.id)
      
      if (error) throw error
      
      setShowSavedMsg(true)
      setTimeout(() => setShowSavedMsg(false), 3000)
    } catch (err) {
      console.error(err)
      alert("Erro ao salvar ATA.")
    } finally {
      setIsSaving(false)
    }
  }

  const handleRegenerate = async () => {
    if (ataTexto && ataTexto.trim() !== '') {
      if(!confirm("Atenção: Gerar a ATA novamente apagará todas as edições manuais que você fez acima. Deseja continuar?")) return
    }
    setIsGenerating(true)
    try {
      const { data: { session } } = await supabase.auth.getSession()
      const response = await fetch(`${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/assembleia-ata-generate`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${session?.access_token}`
        },
        body: JSON.stringify({ assembleia_id: assembleia.id })
      })

      const responseData = await response.json()
      if (!response.ok) throw new Error(responseData.error)
      
      setAtaTexto(responseData.ata_texto)
      setShowSavedMsg(true)
      setTimeout(() => setShowSavedMsg(false), 3000)
    } catch (err: any) {
      console.error(err)
      alert("Erro ao gerar ATA: " + err.message)
    } finally {
      setIsGenerating(false)
    }
  }

  const handlePrint = () => {
    window.print()
  }

  // Gera array de 50 linhas para usar como numeradores na margem, para dar o visual clássico de cartório
  const lineNumbers = Array.from({ length: 80 }, (_, i) => i + 1)

  return (
    <>
      {/* Estilos globais para controle exato de impressão */}
      <style suppressHydrationWarning>{`
        @media print {
          @page {
            size: A4 portrait;
            margin: 15mm;
          }
          body {
            background-color: white !important;
            -webkit-print-color-adjust: exact !important;
            print-color-adjust: exact !important;
          }
        }
      `}</style>
      
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

          <div className="flex items-center gap-3">
            {showSavedMsg && (
              <span className="text-green-600 flex items-center gap-1 font-medium text-sm animate-fade-in-out">
                <CheckCircle2 size={16} /> Salvo!
              </span>
            )}

            <button
              onClick={handleRegenerate}
              disabled={isGenerating}
              className="flex items-center gap-2 px-4 py-2 bg-gray-200 text-gray-700 hover:bg-gray-300 rounded-lg font-medium transition-all"
              title="Sincronizar novamente com o banco de dados via IA"
            >
              <RotateCcw size={16} className={isGenerating ? "animate-spin" : ""} />
              {isGenerating ? "Gerando IA..." : "Recriar Texto"}
            </button>

            <button
              onClick={handleSave}
              disabled={isSaving}
              className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white hover:bg-blue-700 rounded-lg font-medium transition-all shadow-md"
            >
              <Save size={18} />
              {isSaving ? "Salvando..." : "Salvar Rascunho"}
            </button>

            <button
              onClick={handlePrint}
              className="flex items-center gap-2 px-5 py-2.5 bg-[#FC5931] text-white hover:bg-[#e04f2c] rounded-xl font-bold transition-all shadow-md"
            >
              <Printer size={18} />
              Imprimir / Gerar PDF
            </button>
          </div>
        </div>

        {/* --- A4 PAGE: ATA --- */}
        <div className="bg-white mx-auto shadow-xl print:shadow-none w-[210mm] print:w-full min-h-[297mm] print:min-h-0 relative flex flex-col" style={{ WebkitPrintColorAdjust: 'exact', printColorAdjust: 'exact' }}>
          
          {/* TOP GRAPHIC ACCENT (Sobrio para Ata) - Escondido na impressão para economizar tinta */}
          <div className="absolute top-0 left-0 w-full h-[60px] pointer-events-none z-0 bg-gray-900 print:hidden"></div>

          {/* CONTENT CONTAINER - Retornado o padding também para impressão, respeitando as bordas */}
          <div className="relative z-10 flex-1 flex flex-col pt-[8mm] pb-[20mm] px-[20mm] print:px-[15mm] print:py-[10mm]">
        
          {/* HEADER JURÍDICO */}
          <div className="flex border-b-2 border-gray-900 pb-4 mb-8 pt-4 items-center justify-between">
            <div className="flex flex-col w-[70%]">
              <h1 className="text-2xl font-serif font-black text-gray-900 uppercase tracking-tight">
                Ata de Assembleia
              </h1>
              <h2 className="text-sm font-serif font-bold text-gray-500 mt-1">
                {assembleia.tipo === 'extraordinaria' ? 'ASSEMBLEIA GERAL EXTRAORDINÁRIA' : 'ASSEMBLEIA GERAL ORDINÁRIA'}
              </h2>
              <p className="text-xs font-mono text-gray-400 mt-1 uppercase">Folha 01 // ID: {assembleia.id.split('-')[0]}</p>
            </div>
            
            <div className="flex flex-col items-end w-[30%]">
              <div className="w-16 h-16 border-2 border-gray-100 rounded-lg flex items-center justify-center shadow-sm">
                 <img src="/logo.png" className="w-12 h-12 object-contain grayscale" alt="Logo" />
              </div>
              <strong className="text-sm text-gray-800 font-bold mt-2 text-right">{condominio.nome}</strong>
              <p className="text-[10px] text-gray-500 text-right">CNPJ: {condominio.cnpj || 'Não cadastrado'}</p>
            </div>
          </div>

          {/* DOCUMENT BODY WITH MARGIN LINES */}
          <div className="flex flex-1 relative min-h-[600px]">
             
             {/* NUMBERED LEFT MARGIN (Classical Cartorial Look) */}
             <div className="w-8 border-r-2 border-double border-red-300 mr-4 flex flex-col items-center pt-2 select-none print:w-6 pointer-events-none relative z-0">
               {lineNumbers.map(n => (
                 <span key={n} className="text-[11px] font-mono text-gray-400 print:text-gray-600 leading-[32px] h-[32px]">{String(n).padStart(2, '0')}</span>
               ))}
             </div>

             {/* TEXTAREA BACKGROUND LINED */}
             <div className="flex-1 relative pb-12">
                <div className="absolute inset-0 pointer-events-none print:hidden" style={{
                  backgroundImage: 'repeating-linear-gradient(transparent, transparent 31px, #f3f4f6 31px, #f3f4f6 32px)',
                  backgroundSize: '100% 32px'
                }}></div>
                
                {!ataTexto ? (
                  <div className="flex flex-col items-center justify-center h-[300px] bg-gray-50/80 rounded-lg relative z-10 border border-dashed border-gray-300 print:hidden">
                    <p className="text-gray-500 mb-4 text-center">Nenhum texto de Ata disponível ainda.<br/>Gere sua Ata por IA usando o botão no topo.</p>
                    <button onClick={handleRegenerate} className="px-4 py-2 bg-[#FC5931] text-white rounded font-bold shadow">
                      Gerar ATA por IA
                    </button>
                  </div>
                ) : (
                  <>
                    <textarea
                      ref={textareaRef}
                      value={ataTexto}
                      onChange={(e) => setAtaTexto(e.target.value)}
                      className="w-full relative z-10 bg-transparent outline-none resize-none overflow-hidden font-serif text-[15px] leading-[32px] text-gray-900 text-justify pt-[2px] print:hidden"
                      style={{ minHeight: '600px' }}
                      spellCheck="false"
                    />
                    
                    {/* Divisão exata para que a impressão quebre a página corretamente, porque Textarea nativo não quebra em duas páginas na impressão */}
                    <div className="hidden print:block w-full relative z-10 bg-transparent font-serif text-[15px] leading-[32px] text-gray-900 text-justify pt-[2px] whitespace-pre-wrap">
                      {ataTexto}
                    </div>
                  </>
                )}
             </div>
          </div>

          {/* SIGNATURES PAGE / SECTION */}
          <div className="mt-16 pt-8 break-inside-avoid">
             <div className="text-center mb-12">
               <p className="text-gray-800 font-serif leading-relaxed text-lg">
                 Para constar, eu, <strong>{secretarioNome}</strong>, lavrei a presente ata que, lida e achada conforme, será assinada por mim e pelo Presidente da Mesa.
               </p>
               <p className="text-gray-600 mt-6">{condominio.cidade || 'Brasília'} - {condominio.estado || 'DF'}, {new Date().toLocaleDateString('pt-BR', { year: 'numeric', month: 'long', day: 'numeric' })}</p>
             </div>

             <div className="flex justify-around items-end pt-12 pb-8">
               <div className="flex flex-col items-center px-4 w-[250px]">
                 <div className="w-full h-px bg-gray-900 mb-2"></div>
                 <input 
                   value={presidenteNome}
                   onChange={e => setPresidenteNome(e.target.value)}
                   className="text-center font-bold text-gray-900 bg-transparent outline-none w-full border-b border-transparent hover:border-gray-300"
                 />
                 <span className="text-sm text-gray-600 uppercase font-bold mt-1 tracking-widest">Presidente</span>
               </div>

               <div className="flex flex-col items-center px-4 w-[250px]">
                 <div className="w-full h-px bg-gray-900 mb-2"></div>
                 <input 
                   value={secretarioNome}
                   onChange={e => setSecretarioNome(e.target.value)}
                   className="text-center font-bold text-gray-900 bg-transparent outline-none w-full border-b border-transparent hover:border-gray-300"
                 />
                 <span className="text-sm text-gray-600 uppercase font-bold mt-1 tracking-widest">Secretário(a)</span>
               </div>
             </div>
          </div>

          {/* SELOS CARTORIAIS / AUTENTICAÇÃO DIGITAL */}
          <div className="mt-12 bg-gray-50 border-2 border-gray-200 rounded-xl p-6 print:border-gray-300 break-inside-avoid flex items-center justify-between">
            <div className="flex items-center gap-4">
               <div className="bg-white p-3 rounded-lg border border-gray-200 shadow-sm">
                 <FileSignature size={32} className="text-[#FC5931]" />
               </div>
               <div>
                  <h4 className="text-gray-900 font-bold uppercase tracking-widest mb-1">Registro & Autenticidade</h4>
                  <p className="text-gray-500 text-xs w-[350px]">
                    Este documento pode ser assinado digitalmente validando sua integridade e autoria via ICP-Brasil ou Gov.br, possuindo pleno valor legal segundo a MP nº 2.200-2/2001. A via original acompanha comprovantes criptográficos das assinaturas.
                  </p>
               </div>
            </div>
            
            <div className="flex flex-col items-center border-l-2 border-dashed border-gray-300 pl-6 space-y-2">
              <div className="w-[120px] h-[50px] border border-blue-600/30 bg-blue-50 flex items-center justify-center rounded-md text-blue-700 font-bold text-xs uppercase tracking-wider relative overflow-hidden">
                 <div className="absolute top-0 left-0 w-full h-[6px] bg-blue-600"></div>
                 ASSINATURA<br/>GOV.BR
              </div>
              <div className="text-[9px] text-gray-400">Espaço Reservado Validação</div>
            </div>
          </div>

        </div> {/* END CONTENT CONTAINER */}
      </div>

    </div>
    </>
  )
}
