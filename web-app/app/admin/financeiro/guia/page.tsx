import { DollarSign, Building2, BarChart3, Settings, ShieldCheck, CheckCircle2 } from 'lucide-react'

export default function FinanceiroGuiaPage() {
  return (
    <div className="p-6 max-w-4xl mx-auto space-y-8">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Passo a Passo: Módulo Financeiro</h1>
        <p className="text-gray-500 mt-1">Siga este guia para configurar as cobranças automatizadas do seu condomínio.</p>
      </div>

      <div className="space-y-6">
        {/* Passo 1 */}
        <div className="bg-white rounded-2xl p-6 shadow-sm border border-gray-100 flex gap-4">
          <div className="flex-shrink-0">
            <div className="w-10 h-10 bg-[#FC5931]/10 text-[#FC5931] rounded-full flex items-center justify-center font-bold text-lg">
              1
            </div>
          </div>
          <div>
            <h2 className="text-lg font-bold text-gray-900 flex items-center gap-2">
              <Building2 size={20} className="text-gray-400" />
              Configure suas Contas e o Gateway
            </h2>
            <p className="text-sm text-gray-600 mt-2 leading-relaxed">
              Antes de gerar qualquer cobrança, o sistema precisa saber para onde o dinheiro vai. Acesse a aba <strong>Contas & Planos</strong>. 
              Lá você verá o Gateway (Asaas) que faz a mágica de gerar boletos e PIX instantâneos com baixa automática.
            </p>
            <ul className="mt-3 space-y-2 text-sm text-gray-600">
              <li className="flex items-center gap-2"><CheckCircle2 size={16} className="text-green-500" /> Verifique se a conta está <strong>Ativa (Split)</strong>.</li>
              <li className="flex items-center gap-2"><CheckCircle2 size={16} className="text-green-500" /> Cadastre o banco do condomínio (Itaú, Bradesco) para os saques.</li>
              <li className="flex items-center gap-2"><CheckCircle2 size={16} className="text-green-500" /> Revise o seu <strong>Plano de Contas</strong> (Despesas com Pessoal, Água, etc).</li>
            </ul>
          </div>
        </div>

        {/* Passo 2 */}
        <div className="bg-white rounded-2xl p-6 shadow-sm border border-gray-100 flex gap-4">
          <div className="flex-shrink-0">
            <div className="w-10 h-10 bg-[#FC5931]/10 text-[#FC5931] rounded-full flex items-center justify-center font-bold text-lg">
              2
            </div>
          </div>
          <div>
            <h2 className="text-lg font-bold text-gray-900 flex items-center gap-2">
              <BarChart3 size={20} className="text-gray-400" />
              Defina a Previsão Orçamentária
            </h2>
            <p className="text-sm text-gray-600 mt-2 leading-relaxed">
              Acesse a tela de <strong>Previsão Orçamentária</strong>. Ela é o seu termômetro financeiro do ano. 
              Aqui você estipula as metas de gastos (ex: 60 mil reais de Água/Esgoto por ano) e o painel avisará automaticamente caso alguma categoria estoure o limite.
            </p>
          </div>
        </div>

        {/* Passo 3 */}
        <div className="bg-white rounded-2xl p-6 shadow-sm border border-gray-100 flex gap-4">
          <div className="flex-shrink-0">
            <div className="w-10 h-10 bg-[#FC5931]/10 text-[#FC5931] rounded-full flex items-center justify-center font-bold text-lg">
              3
            </div>
          </div>
          <div>
            <h2 className="text-lg font-bold text-gray-900 flex items-center gap-2">
              <DollarSign size={20} className="text-gray-400" />
              Feche o Mês (Faturamento Automático)
            </h2>
            <p className="text-sm text-gray-600 mt-2 leading-relaxed">
              No fim do mês, acesse <strong>Faturamento & Boletos</strong>. O sistema mostrará o DRE (Receitas vs Despesas Ordinárias).
              Basta clicar no botão laranja <strong>Fechar Mês e Gerar Boletos</strong>. O nosso motor irá:
            </p>
            <div className="mt-3 p-4 bg-gray-50 rounded-xl border border-gray-100">
              <ol className="list-decimal ml-4 space-y-1 text-sm text-gray-700">
                <li>Ratear as despesas ordinárias entre os apartamentos.</li>
                <li>Procurar multas e ocorrências abertas.</li>
                <li>Procurar cobranças de reservas de churrasqueira e salão de festas.</li>
                <li>Juntar tudo em um único Boleto/PIX.</li>
                <li>Gerar o PDF do Balancete Transparente.</li>
              </ol>
            </div>
          </div>
        </div>

        {/* Passo 4 */}
        <div className="bg-white rounded-2xl p-6 shadow-sm border border-gray-100 flex gap-4">
          <div className="flex-shrink-0">
            <div className="w-10 h-10 bg-[#FC5931]/10 text-[#FC5931] rounded-full flex items-center justify-center font-bold text-lg">
              4
            </div>
          </div>
          <div>
            <h2 className="text-lg font-bold text-gray-900 flex items-center gap-2">
              <ShieldCheck size={20} className="text-gray-400" />
              Deixe os Robôs Trabalharem!
            </h2>
            <p className="text-sm text-gray-600 mt-2 leading-relaxed">
              Depois que o botão for apertado, você não precisa fazer mais nada. O Condomeet vai:
            </p>
            <ul className="mt-3 space-y-2 text-sm text-gray-600">
              <li className="flex items-center gap-2"><CheckCircle2 size={16} className="text-[#FC5931]" /> Enviar avisos push 5 dias antes do vencimento para o morador.</li>
              <li className="flex items-center gap-2"><CheckCircle2 size={16} className="text-[#FC5931]" /> Dar a Baixa Automática no instante em que o morador fizer o PIX.</li>
              <li className="flex items-center gap-2"><CheckCircle2 size={16} className="text-[#FC5931]" /> Mudar a bolinha do aplicativo de Pendente (laranja) para Pago (verde).</li>
            </ul>
          </div>
        </div>

      </div>
    </div>
  )
}
