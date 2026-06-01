'use client'

import { useState } from 'react'
import DocumentosClient, { Pasta, Documento } from './documentos-client'
import RegrasClient, { Regra } from './regras-client'

export default function DocumentosWrapper({
  initialPastas,
  initialDocs,
  initialRegras,
  condoId,
  tabelaPastas,
  tabelaDocs,
  storageBucket,
  titulo,
  initialCategorias,
}: {
  initialPastas: Pasta[]
  initialDocs: Documento[]
  initialRegras: Regra[]
  condoId: string
  tabelaPastas: string
  tabelaDocs: string
  storageBucket: string
  titulo: string
  initialCategorias: string[]
}) {
  const [activeTab, setActiveTab] = useState<'arquivos' | 'regras'>('arquivos')

  return (
    <div className="space-y-6">
      {/* Tabs selector */}
      <div className="flex border-b border-gray-100 gap-6">
        <button
          onClick={() => setActiveTab('arquivos')}
          className={`pb-3 text-sm font-semibold border-b-2 transition ${
            activeTab === 'arquivos'
              ? 'border-[#FC5931] text-[#FC5931]'
              : 'border-transparent text-gray-500 hover:text-gray-800'
          }`}
        >
          Pastas e Arquivos
        </button>
        <button
          onClick={() => setActiveTab('regras')}
          className={`pb-3 text-sm font-semibold border-b-2 transition ${
            activeTab === 'regras'
              ? 'border-[#FC5931] text-[#FC5931]'
              : 'border-transparent text-gray-500 hover:text-gray-800'
          }`}
        >
          Regimento Interno (Chatbot)
        </button>
      </div>

      {/* Tab contents */}
      {activeTab === 'arquivos' ? (
        <DocumentosClient
          initialPastas={initialPastas}
          initialDocs={initialDocs}
          condoId={condoId}
          tabelaPastas={tabelaPastas}
          tabelaDocs={tabelaDocs}
          storageBucket={storageBucket}
          titulo={titulo}
          initialCategorias={initialCategorias}
        />
      ) : (
        <RegrasClient
          initialRegras={initialRegras}
          condoId={condoId}
        />
      )}
    </div>
  )
}
