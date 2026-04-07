'use client'

import { useState } from 'react'
import { BookOpen, ChevronRight, ArrowLeft, Printer } from 'lucide-react'

// ── Tutorial Data with screenshots ──────────────────────────────────────────

type TutorialStep = {
  title: string
  description: string
  bold?: string[]
}

type TutorialSection = {
  id: string
  emoji: string
  title: string
  category: string
  screenshot?: string
  steps: TutorialStep[]
}

const tutorialSections: TutorialSection[] = [
  // ─── GERAL ──────────────────────────────────────────────────────────
  {
    id: 'dashboard',
    emoji: '🏠',
    title: 'Como usar o Dashboard',
    category: 'Geral',
    screenshot: '/tutorial/tela_dashboard.png',
    steps: [
      { title: 'Acesse o painel administrativo', description: 'Clique em "Dashboard" no menu lateral. Você verá os cards com os números importantes do condomínio.' },
      { title: 'Analise os indicadores', description: 'Cada card mostra: encomendas pendentes, aprovações, fale conosco e ocorrências abertas.' },
      { title: 'Explore os gráficos', description: 'Role para baixo para ver gráficos de autorizações, ocorrências e reservas dos últimos 6 meses.' },
    ],
  },
  {
    id: 'aprovacoes',
    emoji: '✅',
    title: 'Como aprovar novos moradores',
    category: 'Geral',
    screenshot: '/tutorial/tela_aprovacoes.png',
    steps: [
      { title: 'Acesse "Aprovações"', description: 'Veja a lista de moradores que se cadastraram e aguardam liberação de acesso.' },
      { title: 'Verifique os dados do morador', description: 'Confira: nome completo, bloco, apartamento e perfil (Morador, Proprietário, Inquilino, etc.).' },
      { title: 'Aprove ou Rejeite', description: 'Aprovar: o morador passa a ter acesso completo ao sistema. Rejeitar: o acesso é negado e o morador é notificado.' },
    ],
  },
  {
    id: 'moradores',
    emoji: '👥',
    title: 'Como gerenciar moradores',
    category: 'Geral',
    screenshot: '/tutorial/tela_moradores.png',
    steps: [
      { title: 'Acesse "Moradores"', description: 'Veja todos os moradores aprovados do condomínio organizados por bloco e apartamento.' },
      { title: 'Busque por nome', description: 'Use o campo de busca no topo para encontrar qualquer morador rapidamente.' },
      { title: 'Veja o perfil completo', description: 'Clique no nome do morador para ver telefone, email, veículo e demais informações.' },
    ],
  },
  {
    id: 'busca-moradores',
    emoji: '🔍',
    title: 'Como buscar moradores',
    category: 'Geral',
    steps: [
      { title: 'Acesse "Busca Moradores"', description: 'Essa função permite buscar qualquer morador do condomínio por nome, bloco ou apartamento.' },
      { title: 'Digite o nome ou unidade', description: 'Use o campo de busca e digite o nome, número do bloco ou apartamento. Os resultados aparecem na hora.' },
      { title: 'Veja os detalhes', description: 'Clique no morador para ver informações de contato como telefone e email.' },
    ],
  },

  // ─── COMUNICAÇÃO ────────────────────────────────────────────────────
  {
    id: 'avisos',
    emoji: '🔔',
    title: 'Como publicar avisos',
    category: 'Comunicação',
    screenshot: '/tutorial/tela_avisos.png',
    steps: [
      { title: 'Clique em "+ Novo Aviso"', description: 'O botão está no canto superior direito da tela.' },
      { title: 'Escreva o aviso', description: 'Preencha o título e o conteúdo. Você pode usar negrito, itálico e adicionar imagens.' },
      { title: 'Publique o aviso', description: 'Clique em "Publicar". Todos os moradores receberão uma notificação push no celular automaticamente!' },
      { title: 'Acompanhe a leitura', description: 'Após publicar, veja quantos moradores leram o aviso pelo contador de visualizações.' },
    ],
  },
  {
    id: 'fale-conosco',
    emoji: '💬',
    title: 'Como responder mensagens',
    category: 'Comunicação',
    screenshot: '/tutorial/tela_fale_conosco.png',
    steps: [
      { title: 'Acesse "Fale Conosco"', description: 'Aqui chegam todas as mensagens enviadas pelos moradores para a administração.' },
      { title: 'Clique na mensagem', description: 'Abra a conversa para ver o histórico completo e os detalhes do morador.' },
      { title: 'Responda ao morador', description: 'Digite sua resposta no campo de texto e clique em "Enviar". O morador recebe notificação push!' },
    ],
  },
  {
    id: 'ocorrencias',
    emoji: '⚠️',
    title: 'Como gerenciar ocorrências',
    category: 'Comunicação',
    screenshot: '/tutorial/tela_ocorrencias.png',
    steps: [
      { title: 'Acesse "Ocorrências"', description: 'Veja todas as ocorrências registradas pelos moradores e funcionários.' },
      { title: 'Analise cada ocorrência', description: 'Cada registro mostra: data, hora, descrição do ocorrido e quem registrou.' },
      { title: 'Registre sua resposta', description: 'Adicione observações, altere o status e tome as providências necessárias.' },
    ],
  },
  {
    id: 'enquetes',
    emoji: '📊',
    title: 'Como criar enquetes',
    category: 'Comunicação',
    steps: [
      { title: 'Acesse "Enquetes"', description: 'Clique em "Enquetes" no menu lateral para ver todas as pesquisas do condomínio.' },
      { title: 'Crie uma nova enquete', description: 'Clique em "+ Nova Enquete". Escreva a pergunta e adicione as opções de resposta (ex: "Sim", "Não", "Talvez").' },
      { title: 'Defina o prazo', description: 'Escolha a data limite para que os moradores possam votar. Após o prazo, a enquete fecha automaticamente.' },
      { title: 'Acompanhe os resultados', description: 'Veja em tempo real quantos moradores votaram e o percentual de cada opção. Os resultados ficam disponíveis para todos.' },
    ],
  },
  {
    id: 'album-fotos',
    emoji: '📸',
    title: 'Como usar o álbum de fotos',
    category: 'Comunicação',
    steps: [
      { title: 'Acesse "Álbum de Fotos"', description: 'Clique em "Álbum de Fotos" no menu lateral. Aqui você gerencia todas as fotos e álbuns do condomínio.' },
      { title: 'Crie um álbum', description: 'Clique em "+ Novo Álbum" e dê um nome (ex: "Festa Junina 2026", "Reforma da Piscina").' },
      { title: 'Adicione fotos', description: 'Dentro do álbum, clique em "Adicionar Fotos" e selecione as imagens do seu computador. Você pode enviar várias de uma vez.' },
      { title: 'Compartilhe com os moradores', description: 'Após publicar, os moradores podem ver as fotos pelo aplicativo. Ideal para registrar eventos e obras do condomínio.' },
    ],
  },

  // ─── GESTÃO ─────────────────────────────────────────────────────────
  {
    id: 'encomendas',
    emoji: '📦',
    title: 'Como gerenciar encomendas',
    category: 'Gestão',
    screenshot: '/tutorial/tela_encomendas.png',
    steps: [
      { title: 'Registre a encomenda', description: 'Quando chegar uma encomenda na portaria, clique em "+ Nova Encomenda" e informe bloco, apartamento e tipo.' },
      { title: 'Verifique os dados', description: 'Cada item mostra: destinatário, bloco/apto, data de chegada, tipo (Caixa, Envelope, Sacola...) e status.' },
      { title: 'Confirme a retirada', description: 'Quando o morador retirar a encomenda, marque como "Entregue". O morador recebe a notificação.' },
    ],
  },
  {
    id: 'autorizacao-visitante',
    emoji: '🚪',
    title: 'Como autorizar visitantes',
    category: 'Gestão',
    steps: [
      { title: 'Acesse "Autorização Visitante"', description: 'Pela portaria, acesse a tela de autorização para registrar a entrada de visitantes que chegam ao condomínio.' },
      { title: 'Preencha os dados', description: 'Informe: tipo de visitante (Familiar, Delivery, Uber, Prestador...), bloco, apartamento, nome e dados opcionais (documento, placa, crachá).' },
      { title: 'Registre a visita', description: 'Clique em "Registrar visita". O sistema gera um QR Code automaticamente e o morador é notificado no celular.' },
      { title: 'Confirme a entrada', description: 'Na tela "Visitante c/ Autorização", use os filtros (código, placa, crachá, documento) para localizar o visitante e clique em "Confirmar Entrada".' },
    ],
  },
  {
    id: 'reservas',
    emoji: '📅',
    title: 'Como administrar reservas',
    category: 'Gestão',
    screenshot: '/tutorial/tela_reservas.png',
    steps: [
      { title: 'Acesse "Reservas"', description: 'Veja todas as reservas de áreas comuns feitas pelos moradores (salão, churrasqueira, etc.).' },
      { title: 'Visualize o calendário', description: 'O calendário mostra todas as reservas organizadas por data e área. Clique em uma reserva para ver detalhes.' },
      { title: 'Gerencie as reservas', description: 'Aprove, recuse ou cancele reservas conforme a necessidade. O morador é notificado automaticamente.' },
    ],
  },
  {
    id: 'estoque',
    emoji: '🏗️',
    title: 'Como controlar o estoque',
    category: 'Gestão',
    screenshot: '/tutorial/tela_estoque.png',
    steps: [
      { title: 'Cadastre locais e categorias', description: 'Primeiro, nas abas "ADD LUGAR" e "ADD CATEGORIA", cadastre onde ficam os materiais e suas categorias.' },
      { title: 'Cadastre os produtos', description: 'Na aba "ADD PRODUTO", preencha: nome, local, categoria, quantidade, custo unitário e tipo (consumível ou retornável).' },
      { title: 'Registre entradas e saídas', description: 'Na aba "ENTRADA E SAÍDA", selecione o tipo, o produto e a quantidade. Para vassouras e ferramentas, será empréstimo.' },
      { title: 'Acompanhe o painel', description: 'Na aba "ESTOQUE", veja alertas de estoque crítico, valor total e produtos vencendo. Quando o estoque fica crítico, você recebe notificação push!' },
    ],
  },
  {
    id: 'manutencao',
    emoji: '🔧',
    title: 'Como gerenciar manutenções',
    category: 'Gestão',
    steps: [
      { title: 'Acesse "Manutenção"', description: 'Clique em "Manutenção" no menu lateral para ver todas as ordens de serviço e manutenções do condomínio.' },
      { title: 'Registre uma manutenção', description: 'Clique em "+ Nova Manutenção" e preencha: descrição do serviço, local, prioridade (alta, média, baixa) e prazo estimado.' },
      { title: 'Acompanhe o andamento', description: 'Atualize o status conforme a manutenção avança: Pendente → Em andamento → Concluída. O histórico fica salvo.' },
      { title: 'Registre os custos', description: 'Informe os valores gastos com material e mão de obra para manter o controle financeiro das manutenções.' },
    ],
  },
  {
    id: 'contratos',
    emoji: '📝',
    title: 'Como gerenciar contratos',
    category: 'Gestão',
    steps: [
      { title: 'Acesse "Contratos"', description: 'Clique em "Contratos" no menu lateral para ver todos os contratos ativos do condomínio (elevador, limpeza, segurança, etc.).' },
      { title: 'Cadastre um contrato', description: 'Clique em "+ Novo Contrato" e preencha: empresa, tipo de serviço, valor mensal, data de início e vencimento.' },
      { title: 'Acompanhe os vencimentos', description: 'O sistema alerta quando um contrato está próximo de vencer, permitindo renovação ou renegociação a tempo.' },
    ],
  },
  {
    id: 'documentos',
    emoji: '📄',
    title: 'Como gerenciar documentos',
    category: 'Gestão',
    steps: [
      { title: 'Clique em "+ Novo Documento"', description: 'Acesse a opção no menu lateral para adicionar regulamentos, atas, balancetes, etc.' },
      { title: 'Faça upload do arquivo', description: 'Selecione o arquivo (PDF, imagem), preencha o título e escolha a categoria.' },
      { title: 'Publique para os moradores', description: 'Após o upload, todos os moradores poderão baixar o documento pelo aplicativo.' },
    ],
  },
  {
    id: 'areas-comuns',
    emoji: '🏊',
    title: 'Como cadastrar áreas comuns',
    category: 'Gestão',
    steps: [
      { title: 'Acesse "Áreas Comuns"', description: 'Cadastre todos os espaços do condomínio: Salão de Festas, Churrasqueira, Piscina, Quadra, etc.' },
      { title: 'Configure horários e taxas', description: 'Defina os horários permitidos, taxa de uso (ou gratuito) e regras de utilização.' },
      { title: 'Salve a configuração', description: 'Após salvar, os moradores poderão reservar as áreas pelo aplicativo ou portal.' },
    ],
  },
  {
    id: 'registro-turno',
    emoji: '⏰',
    title: 'Como usar o registro de turno',
    category: 'Gestão',
    steps: [
      { title: 'Acesse "Registro Turno"', description: 'Clique em "Registro Turno" no menu. Aqui a equipe do condomínio registra as atividades realizadas durante cada turno de trabalho.' },
      { title: 'Crie um novo registro', description: 'Clique em "Novo Registro" e preencha: data, turno (Manhã, Tarde, Noite), funcionário responsável e as atividades realizadas.' },
      { title: 'Descreva as ocorrências', description: 'Registre tudo que aconteceu no turno: rondas feitas, problemas detectados, visitantes recebidos, entregas, etc.' },
      { title: 'Consulte o histórico', description: 'Use os filtros de data e turno para consultar registros anteriores. Ótimo para passagem de turno entre funcionários!' },
    ],
  },
  {
    id: 'estrutura',
    emoji: '🏢',
    title: 'Como configurar a estrutura',
    category: 'Gestão',
    steps: [
      { title: 'Acesse "Estrutura"', description: 'Clique em "Estrutura" no menu lateral para configurar os blocos e apartamentos do condomínio.' },
      { title: 'Cadastre os blocos', description: 'Adicione cada bloco/torre do condomínio com seu nome ou número identificador.' },
      { title: 'Cadastre os apartamentos', description: 'Dentro de cada bloco, adicione os apartamentos (unidades) com seus respectivos números.' },
      { title: 'Ajuste as informações', description: 'Atualize as informações sempre que houver mudança na estrutura do condomínio. Isso afeta o cadastro de moradores.' },
    ],
  },
  {
    id: 'classificados',
    emoji: '🛒',
    title: 'Como gerenciar classificados',
    category: 'Gestão',
    steps: [
      { title: 'Acesse "Classificados"', description: 'Clique em "Classificados" no menu. Aqui os moradores podem vender, trocar ou doar itens entre si dentro do condomínio.' },
      { title: 'Modere os anúncios', description: 'Revise os anúncios postados pelos moradores. Você pode aprovar, editar ou remover anúncios inadequados.' },
      { title: 'Acompanhe a atividade', description: 'Veja quantos anúncios estão ativos, vendidos e expirados. Ideal para fomentar a comunidade do condomínio.' },
    ],
  },
  {
    id: 'fornecedores',
    emoji: '🤝',
    title: 'Como cadastrar fornecedores',
    category: 'Gestão',
    steps: [
      { title: 'Clique em "+ Novo Fornecedor"', description: 'Acesse a opção no menu lateral para adicionar empresas prestadoras de serviço.' },
      { title: 'Preencha as informações', description: 'Informe: nome da empresa, CNPJ/CPF, telefone, email e tipo de serviço prestado.' },
      { title: 'Gerencie seu cadastro', description: 'Edite ou desative fornecedores que não prestam mais serviço ao condomínio.' },
    ],
  },
  {
    id: 'funcionarios',
    emoji: '👷',
    title: 'Como gerenciar funcionários',
    category: 'Gestão',
    steps: [
      { title: 'Acesse "Funcionários"', description: 'Clique em "Funcionários" no menu lateral para ver toda a equipe do condomínio: porteiros, zeladores, faxineiros, etc.' },
      { title: 'Cadastre um funcionário', description: 'Clique em "+ Novo Funcionário" e preencha: nome completo, cargo, telefone, horário de trabalho e foto (opcional).' },
      { title: 'Gerencie a equipe', description: 'Edite os dados, altere status (ativo/inativo) e mantenha o cadastro sempre atualizado.' },
      { title: 'Consulte o quadro completo', description: 'Veja a lista completa de funcionários com cargo, contato e situação. Ótimo para planejamento de escalas e gestão de pessoal.' },
    ],
  },
  {
    id: 'visita-proprietario',
    emoji: '🏡',
    title: 'Como registrar visita do proprietário',
    category: 'Gestão',
    steps: [
      { title: 'Acesse "Visita Proprietário"', description: 'Essa função registra quando o proprietário que não mora no condomínio visita sua unidade.' },
      { title: 'Registre a visita', description: 'Preencha: nome do proprietário, bloco, apartamento, data e hora da visita, e motivo (vistoria, reforma, reunião...).' },
      { title: 'Acompanhe o histórico', description: 'Consulte todas as visitas anteriores com data, hora e motivo. Útil para controle de acesso e segurança.' },
    ],
  },
  {
    id: 'assembleias',
    emoji: '⚖️',
    title: 'Como realizar assembleias',
    category: 'Gestão',
    steps: [
      { title: 'Configure as unidades', description: 'Em "Configurações", cadastre as unidades com direito a voto no condomínio.' },
      { title: 'Crie a assembleia', description: 'Clique em "Nova Assembleia" e preencha: título, data, horário e pauta dos assuntos.' },
      { title: 'Publique e notifique', description: 'Publique a assembleia. Os moradores receberão notificação para se preparar.' },
      { title: 'Use a sala ao vivo', description: 'No dia da assembleia, abra a "Sala ao Vivo" para transmissão de vídeo e votação em tempo real.' },
      { title: 'Gere a ATA automaticamente', description: 'Após a assembleia, gere a ATA com inteligência artificial. Revise e publique para os moradores.' },
    ],
  },

  // ─── CONFIGURAÇÃO ───────────────────────────────────────────────────
  {
    id: 'configurar-acesso',
    emoji: '🔐',
    title: 'Como configurar acessos',
    category: 'Configuração',
    steps: [
      { title: 'Acesse "Configurar Acesso"', description: 'Controle quem pode acessar o que no condomínio.' },
      { title: 'Defina os papéis', description: 'Atribua papéis aos usuários: Síndico, Zelador, Porteiro, Morador, etc.' },
      { title: 'Ajuste as permissões', description: 'Cada papel tem permissões diferentes. O síndico tem acesso total ao painel administrativo.' },
    ],
  },
  {
    id: 'configurar-ordem',
    emoji: '📋',
    title: 'Como organizar o menu',
    category: 'Configuração',
    steps: [
      { title: 'Acesse "Configurar Ordem"', description: 'Reorganize a ordem dos itens que aparecem no menu dos moradores.' },
      { title: 'Arraste para reorganizar', description: 'Arraste os itens para cima ou para baixo para definir a ordem desejada.' },
      { title: 'Oculte funções', description: 'Desative funções que o condomínio não utiliza. Elas ficam escondidas do menu dos moradores.' },
    ],
  },
]

// Group by category
const categories = tutorialSections.reduce((acc, section) => {
  if (!acc[section.category]) acc[section.category] = []
  acc[section.category].push(section)
  return acc
}, {} as Record<string, TutorialSection[]>)

export default function PassoAPassoClient() {
  const [activeSection, setActiveSection] = useState<string | null>(null)

  const selected = activeSection
    ? tutorialSections.find(s => s.id === activeSection) ?? null
    : null

  return (
    <div className="min-h-screen">
      {/* Header */}
      <div className="bg-gradient-to-r from-[#1a1a2e] to-[#16213e] text-white px-8 py-6 rounded-b-3xl shadow-lg mb-6 print:bg-white print:text-black print:shadow-none">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-4">
            <div className="w-12 h-12 bg-white/10 rounded-2xl flex items-center justify-center">
              <BookOpen size={24} className="text-[#FC5931]" />
            </div>
            <div>
              <h1 className="text-2xl font-bold">📖 Manual do Administrador</h1>
              <p className="text-white/60 text-sm">Condomeet — Painel Web</p>
            </div>
          </div>
          <div className="flex gap-3 print:hidden">
            {selected && (
              <button
                onClick={() => setActiveSection(null)}
                className="flex items-center gap-2 px-4 py-2 bg-white/10 hover:bg-white/20 rounded-xl text-sm transition-colors"
              >
                <ArrowLeft size={16} />
                Voltar ao índice
              </button>
            )}
            <button
              onClick={() => window.print()}
              className="flex items-center gap-2 px-4 py-2 bg-[#FC5931] hover:bg-[#D42F1D] rounded-xl text-sm transition-colors"
            >
              <Printer size={16} />
              Imprimir
            </button>
          </div>
        </div>
      </div>

      {!selected ? (
        /* ── TABLE OF CONTENTS ─────────────────────────────────────────── */
        <div className="max-w-4xl mx-auto px-6 pb-12">
          {/* Intro */}
          <div className="bg-blue-50 border border-blue-100 rounded-2xl p-6 mb-8">
            <h2 className="text-lg font-bold text-blue-800 mb-2">👋 Bem-vindo ao Manual!</h2>
            <p className="text-sm text-blue-700 leading-relaxed">
              Aqui você encontra o passo a passo de <strong>todas as funções</strong> do painel administrativo. 
              Escolha uma função abaixo para aprender como usar. É simples e rápido!
            </p>
          </div>

          {/* Sections by category */}
          {Object.entries(categories).map(([categoryName, items]) => (
            <div key={categoryName} className="mb-8">
              <h3 className="text-xs uppercase tracking-[0.15em] font-bold text-gray-400 mb-3 px-1">
                {categoryName}
              </h3>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                {items.map(section => (
                  <button
                    key={section.id}
                    onClick={() => setActiveSection(section.id)}
                    className="flex items-center gap-4 p-4 bg-white rounded-2xl border border-gray-100 hover:border-[#FC5931]/30 hover:shadow-md transition-all group text-left"
                  >
                    <span className="text-3xl">{section.emoji}</span>
                    <div className="flex-1 min-w-0">
                      <p className="font-semibold text-gray-800 group-hover:text-[#FC5931] transition-colors">
                        {section.title}
                      </p>
                      <p className="text-xs text-gray-400 mt-0.5">
                        {section.steps.length} passos {section.screenshot ? '• com imagem' : ''}
                      </p>
                    </div>
                    <ChevronRight size={18} className="text-gray-300 group-hover:text-[#FC5931] transition-colors" />
                  </button>
                ))}
              </div>
            </div>
          ))}
        </div>
      ) : (
        /* ── TUTORIAL PAGE (like PDF manual) ────────────────────────────── */
        <div className="max-w-3xl mx-auto px-6 pb-16">
          {/* Tutorial title */}
          <div className="mb-8">
            <span className="text-4xl">{selected.emoji}</span>
            <h2 className="text-2xl font-bold text-gray-900 mt-2">{selected.title}</h2>
            <p className="text-sm text-gray-400 mt-1">{selected.category} — {selected.steps.length} passos</p>
          </div>

          {/* Steps — exactly like the PDF style */}
          <div className="space-y-8 mb-10">
            {selected.steps.map((step, idx) => (
              <div key={idx} className="flex gap-5">
                {/* Step number circle */}
                <div className="flex flex-col items-center">
                  <div className="w-10 h-10 rounded-full bg-[#FC5931] text-white flex items-center justify-center font-bold text-lg shrink-0 shadow-sm">
                    {idx + 1}
                  </div>
                  {idx < selected.steps.length - 1 && (
                    <div className="w-0.5 flex-1 bg-gray-200 mt-2" />
                  )}
                </div>
                {/* Step content */}
                <div className="pb-4">
                  <h3 className="text-lg font-bold text-gray-900">{step.title}</h3>
                  <p className="text-gray-600 mt-1 leading-relaxed">{step.description}</p>
                </div>
              </div>
            ))}
          </div>

          {/* Screenshot — like the PDF with phone mockup but here it's a browser mockup */}
          {selected.screenshot && (
            <div className="bg-gray-50 rounded-3xl border border-gray-100 p-4 shadow-sm">
              {/* Browser chrome mockup */}
              <div className="bg-[#1a1a2e] rounded-t-2xl px-4 py-2.5 flex items-center gap-3">
                <div className="flex gap-1.5">
                  <div className="w-3 h-3 rounded-full bg-red-400" />
                  <div className="w-3 h-3 rounded-full bg-yellow-400" />
                  <div className="w-3 h-3 rounded-full bg-green-400" />
                </div>
                <div className="flex-1 bg-white/10 rounded-lg px-3 py-1 text-white/50 text-xs">
                  condomeet.com.br/admin
                </div>
              </div>
              {/* Screenshot */}
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={selected.screenshot}
                alt={`Tela: ${selected.title}`}
                className="w-full rounded-b-2xl border border-gray-200"
              />
            </div>
          )}

          {/* Navigation between tutorials */}
          <div className="flex items-center justify-between mt-10 pt-6 border-t border-gray-100">
            {(() => {
              const currentIdx = tutorialSections.findIndex(s => s.id === selected.id)
              const prev = currentIdx > 0 ? tutorialSections[currentIdx - 1] : null
              const next = currentIdx < tutorialSections.length - 1 ? tutorialSections[currentIdx + 1] : null
              return (
                <>
                  {prev ? (
                    <button
                      onClick={() => { setActiveSection(prev.id); window.scrollTo(0, 0) }}
                      className="flex items-center gap-2 text-sm text-gray-500 hover:text-[#FC5931] transition-colors"
                    >
                      <ArrowLeft size={14} />
                      {prev.emoji} {prev.title}
                    </button>
                  ) : <div />}
                  {next ? (
                    <button
                      onClick={() => { setActiveSection(next.id); window.scrollTo(0, 0) }}
                      className="flex items-center gap-2 text-sm text-[#FC5931] hover:text-[#D42F1D] font-medium transition-colors"
                    >
                      {next.emoji} {next.title}
                      <ChevronRight size={14} />
                    </button>
                  ) : (
                    <button
                      onClick={() => setActiveSection(null)}
                      className="flex items-center gap-2 text-sm text-green-600 font-medium"
                    >
                      ✅ Voltar ao índice
                    </button>
                  )}
                </>
              )
            })()}
          </div>
        </div>
      )}
    </div>
  )
}
