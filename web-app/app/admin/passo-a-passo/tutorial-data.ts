'use client'

import { BookOpen, ChevronRight, X, Type, Image, ChevronLeft } from 'lucide-react'

// ── Tutorial Data ────────────────────────────────────────────────────────

export type TutorialStep = {
  emoji: string
  title: string
  description: string
  tip?: string
}

export type Tutorial = {
  id: string
  title: string
  emoji: string
  section: string
  steps: TutorialStep[]
}

export const tutorials: Tutorial[] = [
  // ── GERAL ──────────────────────────────────────────────────────────────
  {
    id: 'dashboard',
    title: 'Dashboard',
    emoji: '🏠',
    section: 'Geral',
    steps: [
      { emoji: '👀', title: 'Visão geral', description: 'Ao abrir o painel, você vê os cards com números importantes: encomendas pendentes, aprovações, mensagens e ocorrências.' },
      { emoji: '📊', title: 'Gráficos', description: 'Role para baixo para ver gráficos de autorizações, ocorrências e reservas dos últimos meses.' },
      { emoji: '🔔', title: 'Alertas', description: 'Cards com borda colorida precisam de atenção! Clique neles para ir direto à função.' },
    ],
  },
  {
    id: 'aprovacoes',
    title: 'Aprovações',
    emoji: '✅',
    section: 'Geral',
    steps: [
      { emoji: '📋', title: 'Lista de pendentes', description: 'Aqui aparecem os moradores que se cadastraram e aguardam aprovação para acessar o sistema.' },
      { emoji: '✅', title: 'Aprovar', description: 'Clique no botão verde "Aprovar" ao lado do nome do morador para liberar o acesso dele.' },
      { emoji: '❌', title: 'Recusar', description: 'Clique no botão vermelho "Recusar" se a pessoa não for moradora do condomínio.' },
      { emoji: '🔍', title: 'Verificar dados', description: 'Confira o bloco, apartamento e nome completo antes de aprovar.', tip: 'Na dúvida, entre em contato com o morador antes de aprovar.' },
    ],
  },
  {
    id: 'moradores',
    title: 'Moradores',
    emoji: '👥',
    section: 'Geral',
    steps: [
      { emoji: '📋', title: 'Lista completa', description: 'Veja todos os moradores aprovados do condomínio organizados por bloco e apartamento.' },
      { emoji: '🔍', title: 'Buscar', description: 'Use o campo de busca no topo para encontrar qualquer morador pelo nome.' },
      { emoji: '👤', title: 'Ver perfil', description: 'Clique no nome do morador para ver suas informações completas: telefone, email, veículo, etc.' },
      { emoji: '✏️', title: 'Editar', description: 'No perfil do morador, clique em "Editar" para atualizar informações como bloco, apto ou papel.' },
    ],
  },
  // ── COMUNICAÇÃO ────────────────────────────────────────────────────────
  {
    id: 'avisos',
    title: 'Avisos',
    emoji: '🔔',
    section: 'Comunicação',
    steps: [
      { emoji: '➕', title: 'Criar aviso', description: 'Clique em "+ Novo Aviso" no canto superior direito.' },
      { emoji: '✍️', title: 'Escrever', description: 'Preencha o título e o conteúdo do aviso. Você pode formatar o texto com negrito, itálico, etc.' },
      { emoji: '📸', title: 'Adicionar imagem', description: 'Clique no ícone de câmera para anexar uma foto ao aviso (opcional).' },
      { emoji: '📤', title: 'Publicar', description: 'Clique em "Publicar" para enviar. Todos os moradores receberão uma notificação no celular!', tip: 'O aviso aparece instantaneamente para todos os moradores do condomínio.' },
      { emoji: '👁️', title: 'Ver lidos', description: 'Após publicar, você pode ver quantos moradores leram o aviso.' },
    ],
  },
  {
    id: 'fale-conosco',
    title: 'Fale Conosco',
    emoji: '💬',
    section: 'Comunicação',
    steps: [
      { emoji: '📬', title: 'Ver mensagens', description: 'Aqui chegam todas as mensagens enviadas pelos moradores para a administração.' },
      { emoji: '💬', title: 'Responder', description: 'Clique na mensagem para abrir. Digite sua resposta no campo de texto e clique em "Enviar".' },
      { emoji: '🏷️', title: 'Status', description: 'As mensagens têm status: Pendente (novo), Em andamento, Resolvido. Atualize conforme a situação.' },
      { emoji: '🔔', title: 'Notificação', description: 'O morador recebe notificação push quando você responde!' },
    ],
  },
  {
    id: 'ocorrencias',
    title: 'Ocorrências',
    emoji: '⚠️',
    section: 'Comunicação',
    steps: [
      { emoji: '📋', title: 'Ver ocorrências', description: 'Lista todas as ocorrências registradas pelos moradores (barulho, vazamento, etc.).' },
      { emoji: '🔍', title: 'Detalhes', description: 'Clique na ocorrência para ver fotos, descrição e dados do morador que registrou.' },
      { emoji: '💬', title: 'Responder', description: 'Escreva uma resposta para o morador sobre a providência tomada.' },
      { emoji: '✅', title: 'Resolver', description: 'Marque como "Resolvida" quando o problema for solucionado.' },
    ],
  },
  {
    id: 'enquetes',
    title: 'Enquetes',
    emoji: '📊',
    section: 'Comunicação',
    steps: [
      { emoji: '➕', title: 'Criar enquete', description: 'Clique em "+ Nova Enquete" para criar uma votação para os moradores.' },
      { emoji: '✍️', title: 'Preencher', description: 'Escreva a pergunta e adicione as opções de resposta (mínimo 2 opções).' },
      { emoji: '📅', title: 'Prazo', description: 'Defina uma data limite para as votações.' },
      { emoji: '📤', title: 'Publicar', description: 'Publique e todos os moradores receberão notificação para votar.' },
      { emoji: '📊', title: 'Resultados', description: 'Acompanhe os votos em tempo real no gráfico da enquete.' },
    ],
  },
  {
    id: 'album-fotos',
    title: 'Álbum de Fotos',
    emoji: '📷',
    section: 'Comunicação',
    steps: [
      { emoji: '➕', title: 'Criar álbum', description: 'Clique em "+ Novo Álbum" para criar uma galeria de fotos do condomínio.' },
      { emoji: '📸', title: 'Adicionar fotos', description: 'Arraste fotos ou clique para fazer upload. Você pode enviar várias de uma vez.' },
      { emoji: '📝', title: 'Descrição', description: 'Dê um título e descrição para que os moradores saibam do que se trata.' },
    ],
  },
  // ── GESTÃO ─────────────────────────────────────────────────────────────
  {
    id: 'encomendas',
    title: 'Encomendas',
    emoji: '📦',
    section: 'Gestão',
    steps: [
      { emoji: '📦', title: 'Registrar encomenda', description: 'Quando chegar uma encomenda na portaria, clique em "+ Nova Encomenda".' },
      { emoji: '✍️', title: 'Preencher', description: 'Informe o bloco, apartamento e quem recebeu. Tire uma foto da encomenda se quiser.' },
      { emoji: '🔔', title: 'Notificar', description: 'O morador recebe automaticamente uma notificação no celular avisando que tem encomenda!' },
      { emoji: '✅', title: 'Entregar', description: 'Quando o morador retirar, clique em "Entregar" para registrar que foi entregue.' },
    ],
  },
  {
    id: 'autorizar-visitante',
    title: 'Autorizar Visitante',
    emoji: '🚗',
    section: 'Gestão',
    steps: [
      { emoji: '📋', title: 'Ver autorizações', description: 'Aqui você vê todas as autorizações de visitantes criadas pelos moradores.' },
      { emoji: '✅', title: 'Liberar entrada', description: 'Quando o visitante chegar, encontre a autorização e marque como "Entrada autorizada".' },
      { emoji: '🔍', title: 'Buscar', description: 'Use a barra de busca para encontrar pelo nome do visitante ou do morador.' },
      { emoji: '🚪', title: 'Registrar saída', description: 'Quando o visitante sair, registre a saída para manter o controle.' },
    ],
  },
  {
    id: 'documentos',
    title: 'Documentos',
    emoji: '📄',
    section: 'Gestão',
    steps: [
      { emoji: '➕', title: 'Adicionar documento', description: 'Clique em "+ Novo Documento" para enviar um arquivo (PDF, imagem, etc.).' },
      { emoji: '📂', title: 'Categorias', description: 'Organize por categorias: Regulamento, Atas, Balancetes, etc.' },
      { emoji: '📤', title: 'Upload', description: 'Faça upload do arquivo e preencha o título. Todos os moradores poderão baixar.' },
    ],
  },
  {
    id: 'manutencao',
    title: 'Manutenção',
    emoji: '🔧',
    section: 'Gestão',
    steps: [
      { emoji: '➕', title: 'Criar ordem', description: 'Registre uma nova ordem de manutenção para os equipamentos do condomínio.' },
      { emoji: '📝', title: 'Descrever', description: 'Informe o que precisa ser feito, onde é o problema e a urgência.' },
      { emoji: '📅', title: 'Agendar', description: 'Defina uma data prevista para a manutenção.' },
      { emoji: '✅', title: 'Concluir', description: 'Marque como concluída quando o serviço for finalizado.' },
    ],
  },
  {
    id: 'areas-comuns',
    title: 'Áreas Comuns',
    emoji: '🏊',
    section: 'Gestão',
    steps: [
      { emoji: '➕', title: 'Cadastrar área', description: 'Adicione áreas como: Salão de Festas, Churrasqueira, Piscina, Quadra, etc.' },
      { emoji: '⏰', title: 'Horários', description: 'Defina os horários permitidos para reserva de cada área.' },
      { emoji: '💰', title: 'Taxa', description: 'Se houver taxa de uso, defina o valor. Marque como "Gratuito" se não tiver.' },
      { emoji: '📋', title: 'Regras', description: 'Escreva as regras de uso que os moradores precisam aceitar ao reservar.' },
    ],
  },
  {
    id: 'reservas',
    title: 'Reservas',
    emoji: '📅',
    section: 'Gestão',
    steps: [
      { emoji: '📋', title: 'Ver reservas', description: 'Acompanhe todas as reservas feitas pelos moradores no calendário.' },
      { emoji: '✅', title: 'Aprovar', description: 'Se a área exigir aprovação, analise o pedido e aprove ou recuse.' },
      { emoji: '❌', title: 'Cancelar', description: 'Em caso de necessidade, cancele uma reserva e o morador será notificado.' },
    ],
  },
  {
    id: 'registro-turno',
    title: 'Registro de Turno',
    emoji: '📝',
    section: 'Gestão',
    steps: [
      { emoji: '📋', title: 'Ver registros', description: 'Veja os registros de turno feitos pelos porteiros e funcionários.' },
      { emoji: '➕', title: 'Novo registro', description: 'Crie um registro de ocorrências do turno: o que aconteceu, visitantes, entregas, etc.' },
      { emoji: '📅', title: 'Filtrar', description: 'Filtre por data para ver os registros de um dia específico.' },
    ],
  },
  {
    id: 'estrutura',
    title: 'Estrutura',
    emoji: '🏢',
    section: 'Gestão',
    steps: [
      { emoji: '🏢', title: 'Blocos', description: 'Cadastre os blocos, torres ou quadras do condomínio.' },
      { emoji: '🚪', title: 'Unidades', description: 'Para cada bloco, adicione os apartamentos, casas ou lotes.' },
      { emoji: '⚡', title: 'Gerar automático', description: 'Use o botão "Gerar" para criar toda a estrutura automaticamente (ex: 4 blocos com 40 aptos).' },
    ],
  },
  {
    id: 'classificados',
    title: 'Classificados',
    emoji: '🏷️',
    section: 'Gestão',
    steps: [
      { emoji: '📋', title: 'Moderar', description: 'Aprove ou recuse anúncios criados pelos moradores (venda de móveis, serviços, etc.).' },
      { emoji: '⚠️', title: 'Denúncias', description: 'Verifique se há anúncios denunciados que precisam de revisão.' },
    ],
  },
  {
    id: 'fornecedores',
    title: 'Fornecedores',
    emoji: '🤝',
    section: 'Gestão',
    steps: [
      { emoji: '➕', title: 'Cadastrar', description: 'Clique em "+ Novo Fornecedor" para adicionar uma empresa prestadora.' },
      { emoji: '✍️', title: 'Informações', description: 'Preencha: nome, CNPJ/CPF, telefone, email e tipo de serviço.' },
      { emoji: '📋', title: 'Gerenciar', description: 'Edite ou desative fornecedores que não prestam mais serviço.' },
    ],
  },
  {
    id: 'estoque',
    title: 'Controle de Estoque',
    emoji: '📦',
    section: 'Gestão',
    steps: [
      { emoji: '📍', title: 'Cadastrar locais', description: 'Na aba "ADD LUGAR DE ESTOQUE", cadastre onde ficam os materiais (Almoxarifado, Portaria, etc.).' },
      { emoji: '🏷️', title: 'Criar categorias', description: 'Na aba "ADD CATEGORIA", crie categorias como: Limpeza, Aparelhos, Escritório.' },
      { emoji: '📦', title: 'Cadastrar produto', description: 'Na aba "ADD PRODUTO", preencha: nome, local, categoria, quantidade, custo e tipo (consumível ou retornável).' },
      { emoji: '📥', title: 'Dar entrada', description: 'Na aba "ENTRADA E SAÍDA", selecione "Entrada", escolha o produto e a quantidade recebida.' },
      { emoji: '📤', title: 'Dar saída', description: 'Selecione "Saída", o produto e a quantidade. Para vassouras e ferramentas, será registrado como empréstimo.' },
      { emoji: '📊', title: 'Acompanhar', description: 'Na aba "ESTOQUE" (principal), veja o painel com alertas de estoque crítico e valor total.', tip: 'Quando o estoque fica crítico, você recebe uma notificação push no celular!' },
    ],
  },
  {
    id: 'funcionarios',
    title: 'Funcionários',
    emoji: '👷',
    section: 'Gestão',
    steps: [
      { emoji: '➕', title: 'Cadastrar', description: 'Adicione funcionários do condomínio: porteiros, zeladores, faxineiros, etc.' },
      { emoji: '✍️', title: 'Informações', description: 'Preencha: nome, cargo, telefone, horário de trabalho.' },
      { emoji: '📋', title: 'Gerenciar', description: 'Edite informações ou desative funcionários que saíram.' },
    ],
  },
  {
    id: 'visita-proprietario',
    title: 'Visita Proprietário',
    emoji: '🚪',
    section: 'Gestão',
    steps: [
      { emoji: '📋', title: 'Registros', description: 'Veja todos os registros de entrada e saída de moradores feitos na portaria.' },
      { emoji: '🔍', title: 'Buscar', description: 'Filtre por data, bloco ou apartamento para encontrar registros específicos.' },
    ],
  },
  {
    id: 'assembleias',
    title: 'Assembleias',
    emoji: '⚖️',
    section: 'Gestão',
    steps: [
      { emoji: '📋', title: 'Configurar', description: 'Primeiro, vá em "Configurações" e cadastre as unidades com direito a voto.' },
      { emoji: '➕', title: 'Criar assembleia', description: 'Clique em "Nova Assembleia", preencha: título, data, horário e pauta.' },
      { emoji: '📤', title: 'Publicar', description: 'Publique a assembleia. Os moradores receberão notificação e poderão se preparar.' },
      { emoji: '🎥', title: 'Sala ao vivo', description: 'No dia, abra a "Sala ao Vivo" para transmissão de vídeo e votação em tempo real.' },
      { emoji: '🗳️', title: 'Votação', description: 'Crie votações durante a assembleia. Os moradores votam pelo celular instantaneamente.' },
      { emoji: '📄', title: 'ATA', description: 'Após a assembleia, gere a ATA automaticamente com IA. Revise e publique.' },
    ],
  },
  // ── CONFIGURAÇÃO ───────────────────────────────────────────────────────
  {
    id: 'configurar-acesso',
    title: 'Configurar Acesso',
    emoji: '🔐',
    section: 'Configuração',
    steps: [
      { emoji: '⚙️', title: 'Abrir configurações', description: 'Aqui você controla quem pode acessar o que no condomínio.' },
      { emoji: '👤', title: 'Definir papéis', description: 'Atribua papéis: Síndico, Zelador, Porteiro, Morador.' },
      { emoji: '🔒', title: 'Permissões', description: 'Cada papel tem permissões diferentes. O síndico tem acesso total.' },
    ],
  },
  {
    id: 'configurar-ordem',
    title: 'Configurar Ordem do Menu',
    emoji: '📋',
    section: 'Configuração',
    steps: [
      { emoji: '↕️', title: 'Arrastar', description: 'Arraste os itens do menu para reorganizar a ordem que aparece para os moradores.' },
      { emoji: '👁️', title: 'Ocultar', description: 'Desative funções que seu condomínio não utiliza. Elas ficam escondidas do menu dos moradores.' },
      { emoji: '💾', title: 'Salvar', description: 'Clique em "Salvar" para aplicar a nova ordem do menu.' },
    ],
  },
]

export { BookOpen, ChevronRight, X, Type, Image, ChevronLeft }
