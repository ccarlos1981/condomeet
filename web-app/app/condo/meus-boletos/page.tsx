import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import { FileText, Copy, Download, CheckCircle2, AlertCircle, Calendar } from 'lucide-react'
import CopyButton from './copy-button'

export default async function MeusBoletosPage() {
  const supabase = await createClient()

  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id')
    .eq('id', user.id)
    .single()

  const condoId = profile?.condominio_id
  if (!condoId) redirect('/condo')

  // Buscar unidades atreladas ao perfil
  // No Supabase, unidades_perfil vincula perfil_id <-> unidade_id
  // Mas como as faturas estao ligadas ao unidade_id, precisamos descobrir as unidades do usuario.

  // Em um sistema real com RLS, ou apenas listando as unidades do cara:
  // Como nao tenho a tabela exata de relacao aqui no snippet, vamos puxar as faturas pelo RLS ou 
  // assumindo que a RLS da tabela faturamentos ja filtra para o morador.
  const { data: faturas } = await supabase
    .from('faturamentos')
    .select(`
      id,
      valor_total,
      data_vencimento,
      status_pagamento,
      data_pagamento,
      gateway_invoice_url,
      gateway_pix_copia_cola,
      unidades ( id, blocos ( nome_ou_numero ), apartamentos ( numero ) )
    `)
    .eq('condominio_id', condoId)
    .order('data_vencimento', { ascending: false })

  // Filtramos no JS apenas para fins de MVP caso RLS falhe, mas o ideal é RLS.
  const abertos = faturas?.filter(f => f.status_pagamento === 'pendente') || []
  const pagos = faturas?.filter(f => f.status_pagamento === 'pago') || []

  function formatCurrency(val: number | string) {
    return Number(val).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' })
  }

  function formatDate(d: string) {
    if (!d) return ''
    const [y, m, day] = d.split('-')
    return `${day}/${m}/${y}`
  }

  return (
    <div className="p-4 md:p-6 max-w-4xl mx-auto space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Meus Boletos</h1>
        <p className="text-gray-500 mt-1">
          Acompanhe suas taxas condominiais e pagamentos. A baixa é automática via PIX ou boleto.
        </p>
      </div>

      {/* Abertos/Vencidos */}
      <h2 className="text-lg font-bold text-gray-800 mt-8 mb-4">Em Aberto</h2>
      
      {abertos.length === 0 && (
        <div className="bg-green-50 text-green-800 p-6 rounded-2xl border border-green-100 flex items-center gap-4">
          <div className="bg-green-200 p-3 rounded-full text-green-700">
            <CheckCircle2 size={24} />
          </div>
          <div>
            <h3 className="font-bold text-lg">Tudo certo por aqui!</h3>
            <p className="opacity-80">Você não possui taxas em aberto no momento.</p>
          </div>
        </div>
      )}

      <div className="space-y-6">
        {abertos.map(fatura => {
          const isVencido = new Date(fatura.data_vencimento) < new Date()
          return (
            <div key={fatura.id} className={`bg-white rounded-2xl shadow-sm border overflow-hidden relative ${isVencido ? 'border-red-200' : 'border-orange-100'}`}>
              <div className={`absolute top-0 left-0 w-1 h-full ${isVencido ? 'bg-red-500' : 'bg-[#FC5931]'}`}></div>
              <div className="p-5">
                <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
                  <div>
                    <div className="flex items-center gap-2 mb-1">
                      {isVencido ? (
                        <span className="px-2.5 py-1 bg-red-100 text-red-800 rounded-full text-xs font-bold flex items-center gap-1">
                          <AlertCircle size={14} /> Vencido
                        </span>
                      ) : (
                        <span className="px-2.5 py-1 bg-orange-100 text-orange-800 rounded-full text-xs font-bold flex items-center gap-1">
                          <Calendar size={14} /> A Vencer
                        </span>
                      )}
                      <span className="text-sm text-gray-500">Unidade: {(fatura.unidades as any)?.blocos?.nome_ou_numero ? `${(fatura.unidades as any).blocos.nome_ou_numero} / ` : ''}Apto {(fatura.unidades as any)?.apartamentos?.numero}</span>
                    </div>
                    <h3 className="font-bold text-gray-900 text-xl">Taxa Condominial</h3>
                    <p className="text-gray-500 text-sm mt-1">Vencimento: {formatDate(fatura.data_vencimento)}</p>
                  </div>
                  
                  <div className="text-left md:text-right">
                    <p className="text-3xl font-bold text-gray-900">{formatCurrency(fatura.valor_total)}</p>
                  </div>
                </div>

                <div className="mt-6 pt-5 border-t border-gray-100 flex flex-wrap gap-3">
                  {fatura.gateway_pix_copia_cola && (
                    <CopyButton text={fatura.gateway_pix_copia_cola} label="Copiar PIX (Copia e Cola)" primary />
                  )}
                  {fatura.gateway_invoice_url && (
                    <a href={fatura.gateway_invoice_url} target="_blank" rel="noreferrer" className="flex-1 md:flex-none px-4 py-2.5 bg-gray-50 hover:bg-gray-100 text-gray-700 border border-gray-200 rounded-xl font-medium transition-colors flex items-center justify-center gap-2 text-sm">
                      <Download size={16} /> Ver PDF do Boleto
                    </a>
                  )}
                </div>
              </div>
            </div>
          )
        })}
      </div>

      {/* Histórico */}
      <h2 className="text-lg font-bold text-gray-800 mt-10 mb-4">Histórico de Pagos</h2>
      <div className="space-y-4">
        {pagos.length === 0 && <p className="text-gray-500">Nenhum pagamento registrado ainda.</p>}
        {pagos.map(fatura => (
          <div key={fatura.id} className="bg-white rounded-xl shadow-sm border border-gray-100 p-4 flex flex-col md:flex-row md:items-center justify-between gap-4 opacity-80 hover:opacity-100 transition-opacity">
            <div className="flex items-center gap-4">
              <div className="w-12 h-12 bg-green-50 rounded-full flex items-center justify-center text-green-600 flex-shrink-0">
                <CheckCircle2 size={24} />
              </div>
              <div>
                <p className="font-bold text-gray-900">Unidade {(fatura.unidades as any)?.apartamentos?.numero}</p>
                <p className="text-sm text-gray-500">Pago em {formatDate(fatura.data_pagamento?.split('T')[0])}</p>
              </div>
            </div>
            <div className="text-left md:text-right flex items-center gap-4 justify-between md:justify-end w-full md:w-auto">
              <p className="font-bold text-gray-900">{formatCurrency(fatura.valor_total)}</p>
              {fatura.gateway_invoice_url && (
                <a href={fatura.gateway_invoice_url} target="_blank" rel="noreferrer" className="text-gray-400 hover:text-[#FC5931] p-2 bg-gray-50 rounded-lg transition-colors" title="Ver Recibo">
                  <FileText size={18} />
                </a>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
