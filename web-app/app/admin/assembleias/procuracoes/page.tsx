'use client';
import React, { useState } from 'react';
import { FileText, Printer, PenTool } from 'lucide-react';

export default function ProcuracoesPage() {
  const [condoName, setCondoName] = useState('[NOME DO CONDOMÍNIO]');
  const [cidade, setCidade] = useState('[CIDADE/ESTADO]');

  const handlePrint = () => {
    window.print();
  };

  return (
    <div className="flex-1 w-full p-4 lg:p-8 max-w-5xl mx-auto pb-20">
      <div className="mb-8 print:hidden flex justify-between items-end">
        <div>
          <h1 className="text-3xl font-extrabold text-gray-900 tracking-tight flex items-center gap-3">
            <FileText className="text-[#FC5931] w-8 h-8" />
            Modelo de Procuração
          </h1>
          <p className="text-gray-500 mt-2 text-sm">
            Gere, customize e imprima a procuração padrão para os moradores que não puderem estar presentes virtualmente.
          </p>
        </div>
        <button 
          onClick={handlePrint}
          className="flex items-center gap-2 bg-[#FC5931] hover:bg-[#e04f2c] text-white font-medium py-2 px-5 rounded-lg transition-colors shadow-lg shadow-[#FC5931]/20"
        >
          <Printer size={18} />
          Imprimir Procuração
        </button>
      </div>

      <div className="bg-amber-50 border border-amber-200 shadow-sm rounded-2xl p-5 mb-8 print:hidden flex gap-4">
        <div className="mt-1">
          <PenTool className="text-amber-500 w-6 h-6" />
        </div>
        <div>
          <h3 className="font-bold text-amber-800 text-base mb-1">Como usar este modelo</h3>
          <p className="text-amber-700 text-sm leading-relaxed">
            Você pode alterar o nome do condomínio e a cidade/estado nos campos abaixo para preencher o modelo. Quando clicar em imprimir, apenas o documento branco será impresso na folha.
          </p>
          <div className="mt-4 flex gap-4">
             <input 
               type="text" 
               value={condoName}
               onChange={(e) => setCondoName(e.target.value)}
               className="border border-amber-300 rounded-md px-3 py-1.5 focus:outline-none focus:ring focus:ring-amber-200"
               placeholder="Nome do Condomínio"
             />
             <input 
               type="text" 
               value={cidade}
               onChange={(e) => setCidade(e.target.value)}
               className="border border-amber-300 rounded-md px-3 py-1.5 focus:outline-none focus:ring focus:ring-amber-200"
               placeholder="Cidade - UF"
             />
          </div>
        </div>
      </div>

      <div className="bg-gray-200 p-8 rounded-xl print:p-0 print:bg-white print:m-0">
        {/* Folha A4 UI */}
        <div className="bg-white mx-auto shadow-2xl print:shadow-none p-10 md:p-16 text-gray-900 border border-gray-100 max-w-3xl min-h-[29.7cm]">
          
          <div className="text-center mb-12 border-b-2 border-gray-900 pb-8">
             <h2 className="text-2xl font-black uppercase mb-2">INSTRUMENTO PARTICULAR DE PROCURAÇÃO</h2>
             <p className="text-sm font-medium italic text-gray-600">Com poderes específicos para representação em Assembleia do Condomínio</p>
          </div>

          <div className="space-y-8 text-base font-serif leading-loose text-justify text-gray-800">
             <p>
                <strong>OUTORGANTE:</strong> Eu, abaixo assinado(a), proprietário(a) e/ou representante legal da unidade autônoma 
                <span className="inline-block w-24 border-b border-black ml-2 mr-2"></span>, do condomínio <strong>{condoName}</strong>, 
                portador(a) do RG nº <span className="inline-block w-40 border-b border-black ml-2 mr-2"></span> e CPF nº <span className="inline-block w-40 border-b border-black ml-2 mr-2"></span>, 
                nomeio e constituo meu bastante procurador:
             </p>

             <p>
                <strong>OUTORGADO:</strong> Sr(a). <span className="inline-block w-[60%] border-b border-black ml-2 mr-2"></span>, 
                portador(a) do RG nº <span className="inline-block w-40 border-b border-black ml-2 mr-2"></span> e CPF nº <span className="inline-block w-40 border-b border-black ml-2 mr-2"></span>,
             </p>

             <p>
                <strong>PODERES:</strong> Com os poderes específicos para me representar na Assembleia Geral (Ordinária e Extraordinária) do 
                Condomínio referenciado acima, a ser realizada no dia <span className="inline-block w-12 border-b border-black ml-2 mr-2 text-center">/</span><span className="inline-block w-12 border-b border-black ml-2 mr-2 text-center">/</span><span className="inline-block w-20 border-b border-black ml-2 text-center"></span>, 
                podendo para tanto: participar, discutir assuntos em pauta, assinar listas de presença e a respectiva ata, 
                <strong>VOTAR E SER VOTADO</strong> em todos os itens da Ordem do Dia, concordar e discordar de tudo o que for de interesse 
                do condomínio, praticando todos os atos necessários ao fiel cumprimento deste mandato, perante o Síndico, a Administradora ou qualquer interessado.
             </p>

             <div className="pt-10 flex flex-col items-center justify-center">
                 <p className="mb-10 text-center">
                   {cidade}, _____ de _________________ de _______
                 </p>
                 <div className="w-full max-w-sm border-t-2 border-black mb-2 mt-12 text-center"></div>
                 <p className="text-center font-bold text-gray-900">Assinatura do Outorgante</p>
                 <p className="text-center text-xs text-gray-500 mt-2 italic">(Reconhecer firma em cartório caso a convenção exija)</p>
             </div>
          </div>

        </div>
      </div>

    </div>
  );
}
