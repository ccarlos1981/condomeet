// ── Tutorial Data ── Single source of truth for all walkthrough content ──

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
  // ── INÍCIO ──────────────────────────────────────────────────────────────
  {
    id: 'inicio',
    title: 'Tela Inicial',
    emoji: '🏠',
    section: 'Início',
    steps: [
      { emoji: '👋', title: 'Bem-vindo', description: 'Na tela inicial você vê uma saudação personalizada com seu nome, bloco e apartamento.' },
      { emoji: '⚡', title: 'Ações Rápidas', description: 'Os cards de ação rápida levam você direto para as funções mais usadas: autorizar visitante, encomendas, check-in e manutenções.' },
      { emoji: '📊', title: 'Indicadores', description: 'Os números no topo mostram: autorizações pendentes, encomendas a retirar e convites feitos no mês.' },
      { emoji: '📋', title: 'Últimas autorizações', description: 'Logo abaixo, veja suas autorizações mais recentes com status (Aguardando ou Liberado).' },
    ],
  },
  {
    id: 'perfil',
    title: 'Meu Perfil',
    emoji: '👤',
    section: 'Início',
    steps: [
      { emoji: '⚙️', title: 'Acessar perfil', description: 'Clique em "Editar Perfil" no final do menu lateral para ver e alterar suas informações.' },
      { emoji: '✏️', title: 'Editar dados', description: 'Atualize seu nome, telefone, email e foto de perfil. Mantenha sempre atualizado!' },
      { emoji: '🚗', title: 'Veículo', description: 'Se você tem carro, registre placa e modelo. Isso ajuda a portaria na identificação.' },
      { emoji: '📱', title: 'Notificações', description: 'Certifique-se que as notificações estão ativas para receber avisos e alertas.', tip: 'Manter o telefone atualizado ajuda a administração entrar em contato em emergências.' },
    ],
  },

  // ── VISITANTES ──────────────────────────────────────────────────────────
  {
    id: 'autorizar-visitante',
    title: 'Autorizar Visitante',
    emoji: '🚗',
    section: 'Visitantes',
    steps: [
      { emoji: '➕', title: 'Criar autorização', description: 'Clique em "Autorizar Visitante" no menu. Preencha o nome do visitante e a data de validade.' },
      { emoji: '📅', title: 'Definir validade', description: 'Escolha até quando a autorização é válida. Pode ser por 1 dia, 1 semana ou data específica.' },
      { emoji: '📤', title: 'Enviar', description: 'Após preencher, clique em "Criar Convite". A portaria receberá a autorização automaticamente.' },
      { emoji: '📱', title: 'QR Code', description: 'O sistema gera um QR Code que o visitante pode mostrar na portaria para agilizar a entrada.', tip: 'Envie o QR Code por WhatsApp para seu visitante. É a forma mais rápida!' },
      { emoji: '👁️', title: 'Acompanhar', description: 'Na tela inicial, veja o status: "Aguardando" (ainda não chegou) ou "Liberado" (já entrou).' },
    ],
  },
  {
    id: 'visitante-checkin',
    title: 'Visitante c/ Autorização',
    emoji: '✅',
    section: 'Visitantes',
    steps: [
      { emoji: '📋', title: 'Ver chegadas', description: 'Nesta área, veja os visitantes que já foram autorizados e estão aguardando para entrar.' },
      { emoji: '🔍', title: 'Buscar', description: 'Use filtros por código, placa, crachá ou documento para encontrar rapidamente o visitante.' },
      { emoji: '✅', title: 'Confirmar entrada', description: 'Ao identificar o visitante, clique em "Confirmar Entrada" para registrar a chegada.' },
    ],
  },

  // ── COMUNICAÇÃO ────────────────────────────────────────────────────────
  {
    id: 'avisos',
    title: 'Avisos',
    emoji: '🔔',
    section: 'Comunicação',
    steps: [
      { emoji: '📋', title: 'Ver avisos', description: 'Clique em "Avisos" no menu lateral para ver todos os comunicados enviados pela administração.' },
      { emoji: '📖', title: 'Ler aviso', description: 'Clique no aviso para abrir e ler o conteúdo completo. Pode conter texto, imagens e links.' },
      { emoji: '🔔', title: 'Notificações', description: 'Quando a administração publica um aviso novo, você recebe uma notificação no celular!', tip: 'Fique atento aos avisos com ícone de urgência — são os mais importantes.' },
    ],
  },
  {
    id: 'fale-sindico',
    title: 'Fale com o Síndico',
    emoji: '💬',
    section: 'Comunicação',
    steps: [
      { emoji: '✍️', title: 'Enviar mensagem', description: 'Clique em "Fale com o Síndico" no menu. Escreva sua mensagem e clique em "Enviar".' },
      { emoji: '📎', title: 'Anexar foto', description: 'Se necessário, tire uma foto para ilustrar o problema (ex: vazamento, portão quebrado).' },
      { emoji: '💬', title: 'Acompanhar resposta', description: 'Quando o síndico responder, você recebe notificação. Volte à tela para ver a conversa completa.' },
      { emoji: '🏷️', title: 'Status', description: 'Acompanhe o status: Pendente (enviado), Em andamento (sendo analisado) ou Resolvido.' },
    ],
  },
  {
    id: 'ocorrencias',
    title: 'Ocorrências',
    emoji: '⚠️',
    section: 'Comunicação',
    steps: [
      { emoji: '➕', title: 'Registrar ocorrência', description: 'Clique em "Ocorrências" e depois em "+ Nova Ocorrência" para registrar um problema.' },
      { emoji: '✍️', title: 'Descrever o problema', description: 'Preencha: tipo (barulho, vazamento, etc.), descrição detalhada e local do problema.' },
      { emoji: '📸', title: 'Anexar foto/vídeo', description: 'Tire fotos ou vídeos para documentar o problema. Isso ajuda na resolução!' },
      { emoji: '📤', title: 'Enviar', description: 'Envie a ocorrência. A administração será notificada e tomará as providências.' },
      { emoji: '👁️', title: 'Acompanhar', description: 'Acompanhe o andamento da sua ocorrência. Quando for resolvida, você receberá notificação.' },
    ],
  },
  {
    id: 'enquetes',
    title: 'Enquetes',
    emoji: '📊',
    section: 'Comunicação',
    steps: [
      { emoji: '📋', title: 'Ver enquetes', description: 'Clique em "Enquetes" para ver as pesquisas ativas criadas pela administração.' },
      { emoji: '🗳️', title: 'Votar', description: 'Escolha sua opção e clique para votar. Cada morador tem direito a 1 voto por enquete.' },
      { emoji: '📊', title: 'Ver resultados', description: 'Após votar, veja os resultados parciais em tempo real. O gráfico mostra as porcentagens.' },
      { emoji: '⏰', title: 'Prazo', description: 'Fique atento! Cada enquete tem um prazo. Após a data limite, não é mais possível votar.', tip: 'Participe das enquetes! Sua opinião ajuda na tomada de decisões do condomínio.' },
    ],
  },
  {
    id: 'album-fotos',
    title: 'Álbum de Fotos',
    emoji: '📷',
    section: 'Comunicação',
    steps: [
      { emoji: '📸', title: 'Ver álbuns', description: 'Clique em "Álbum de Fotos" para ver todas as galerias de fotos do condomínio.' },
      { emoji: '👀', title: 'Navegar', description: 'Clique em um álbum para abrir e ver todas as fotos. Você pode ampliar clicando na imagem.' },
      { emoji: '📅', title: 'Eventos', description: 'Os álbuns geralmente registram eventos, obras, reformas e momentos do condomínio.' },
    ],
  },

  // ── GESTÃO PESSOAL ─────────────────────────────────────────────────────
  {
    id: 'encomendas',
    title: 'Minhas Encomendas',
    emoji: '📦',
    section: 'Gestão Pessoal',
    steps: [
      { emoji: '📦', title: 'Ver encomendas', description: 'Clique em "Minhas Encomendas" para ver todas as entregas recebidas na portaria para você.' },
      { emoji: '🔔', title: 'Notificação', description: 'Quando a portaria registra uma encomenda para seu apartamento, você recebe notificação push!', tip: 'Retire suas encomendas o mais rápido possível para não acumular na portaria.' },
      { emoji: '✅', title: 'Confirmar retirada', description: 'Ao retirar, a portaria marca como "Entregue" e o status muda automaticamente na sua tela.' },
      { emoji: '📋', title: 'Histórico', description: 'Veja o histórico completo de todas as encomendas (data de chegada, tipo, status).' },
    ],
  },
  {
    id: 'reservas',
    title: 'Reservas',
    emoji: '📅',
    section: 'Gestão Pessoal',
    steps: [
      { emoji: '🏊', title: 'Ver áreas disponíveis', description: 'Clique em "Reservas" para ver as áreas comuns disponíveis: salão, churrasqueira, piscina, quadra, etc.' },
      { emoji: '📅', title: 'Escolher data e hora', description: 'Selecione a área desejada, escolha a data e o horário disponível no calendário.' },
      { emoji: '📝', title: 'Confirmar reserva', description: 'Leia e aceite as regras de uso da área. Clique em "Confirmar" para finalizar a reserva.' },
      { emoji: '💰', title: 'Taxa', description: 'Algumas áreas podem ter taxa de uso. O valor é exibido antes da confirmação.' },
      { emoji: '✅', title: 'Aprovação', description: 'Algumas áreas precisam de aprovação do síndico. Aguarde a confirmação e você será notificado.', tip: 'Faça a reserva com antecedência para garantir a data desejada.' },
      { emoji: '❌', title: 'Cancelar', description: 'Se precisar, cancele sua reserva antes da data. Vá em "Minhas Reservas" e clique em "Cancelar".' },
    ],
  },
  {
    id: 'documentos',
    title: 'Documentos',
    emoji: '📄',
    section: 'Gestão Pessoal',
    steps: [
      { emoji: '📋', title: 'Ver documentos', description: 'Clique em "Documentos" para ver os arquivos compartilhados pela administração.' },
      { emoji: '📂', title: 'Categorias', description: 'Os documentos são organizados por categorias: Regulamento, Atas, Balancetes, Convenção, etc.' },
      { emoji: '📥', title: 'Baixar', description: 'Clique no documento desejado para baixar em PDF. Ideal para consultar regras e informações.' },
    ],
  },
  {
    id: 'contratos',
    title: 'Contratos',
    emoji: '📝',
    section: 'Gestão Pessoal',
    steps: [
      { emoji: '📋', title: 'Ver contratos', description: 'Acesse "Contratos" para ver os contratos ativos do condomínio (elevador, limpeza, segurança, etc.).' },
      { emoji: '🔍', title: 'Detalhes', description: 'Clique em um contrato para ver: empresa, tipo de serviço, valor e vigência.' },
      { emoji: '📊', title: 'Transparência', description: 'Essa área é para dar transparência aos moradores sobre os contratos firmados pela administração.' },
    ],
  },
  {
    id: 'manutencao',
    title: 'Manutenções',
    emoji: '🔧',
    section: 'Gestão Pessoal',
    steps: [
      { emoji: '📋', title: 'Ver manutenções', description: 'Clique em "Manutenções" para ver as ordens de serviço registradas no condomínio.' },
      { emoji: '👁️', title: 'Acompanhar', description: 'Veja o status de cada manutenção: Pendente, Em andamento ou Concluída.' },
      { emoji: '📅', title: 'Histórico', description: 'Consulte o histórico completo de manutenções realizadas, com datas e descrições.' },
    ],
  },

  // ── COMUNIDADE ─────────────────────────────────────────────────────────
  {
    id: 'classificados',
    title: 'Classificados',
    emoji: '🛒',
    section: 'Comunidade',
    steps: [
      { emoji: '📋', title: 'Ver anúncios', description: 'Clique em "Classificados" para ver o que outros moradores estão vendendo, trocando ou doando.' },
      { emoji: '➕', title: 'Criar anúncio', description: 'Clique em "+ Novo Anúncio" para vender algo: móvel, eletrodoméstico, roupas, etc.' },
      { emoji: '✍️', title: 'Preencher', description: 'Informe: título, descrição, preço (ou "Doação"), categoria e adicione fotos do item.' },
      { emoji: '💬', title: 'Contato', description: 'Interessados entram em contato diretamente com você pelo chat ou telefone informado.', tip: 'Antes de publicar, o anúncio passa por moderação da administração.' },
    ],
  },
  {
    id: 'indicacoes',
    title: 'Indicações de Serviço',
    emoji: '❤️',
    section: 'Comunidade',
    steps: [
      { emoji: '📋', title: 'Ver indicações', description: 'Veja as indicações de profissionais feitas por outros moradores (eletricista, encanador, diarista, etc.).' },
      { emoji: '➕', title: 'Indicar', description: 'Conhece um bom profissional? Clique em "+ Nova Indicação" e compartilhe com seus vizinhos!' },
      { emoji: '✍️', title: 'Preencher', description: 'Informe: nome do profissional, tipo de serviço, telefone e sua avaliação.' },
      { emoji: '⭐', title: 'Avaliar', description: 'Dê uma nota e escreva um comentário sobre sua experiência com o profissional.' },
    ],
  },
  {
    id: 'garagem',
    title: 'Garagem Inteligente',
    emoji: '🚗',
    section: 'Comunidade',
    steps: [
      { emoji: '🅿️', title: 'Ver vagas', description: 'Veja as vagas de garagem disponíveis para aluguel no condomínio.' },
      { emoji: '📋', title: 'Anunciar vaga', description: 'Se você tem uma vaga sobrando, anuncie para outros moradores alugarem.' },
      { emoji: '💰', title: 'Negociar', description: 'Defina o valor do aluguel e entre em contato com os interessados.' },
    ],
  },

  // ── ASSEMBLEIAS ────────────────────────────────────────────────────────
  {
    id: 'assembleias',
    title: 'Assembleias',
    emoji: '⚖️',
    section: 'Assembleias',
    steps: [
      { emoji: '📋', title: 'Ver assembleias', description: 'Clique em "Assembleias" para ver as assembleias agendadas e passadas do condomínio.' },
      { emoji: '📅', title: 'Próxima assembleia', description: 'Veja data, horário e pauta da próxima assembleia. Prepare-se com antecedência!' },
      { emoji: '🎥', title: 'Sala ao vivo', description: 'No dia da assembleia, acesse a "Sala ao Vivo" para participar por vídeo e votar em tempo real.' },
      { emoji: '🗳️', title: 'Votar', description: 'Durante a assembleia, vote nas pautas diretamente pelo celular ou computador. O resultado aparece na hora!' },
      { emoji: '📄', title: 'ATA', description: 'Após a assembleia, a ATA é publicada automaticamente. Consulte a qualquer momento.', tip: 'Participe das assembleias! É seu direito e dever como condômino.' },
    ],
  },

  // ── ESTRUTURA ──────────────────────────────────────────────────────────
  {
    id: 'estrutura',
    title: 'Estrutura do Condomínio',
    emoji: '🏢',
    section: 'Informações',
    steps: [
      { emoji: '🏢', title: 'Ver estrutura', description: 'Clique em "Estrutura" para ver os blocos e unidades do seu condomínio.' },
      { emoji: '📊', title: 'Informações', description: 'Veja a quantidade de blocos, torres, apartamentos e a estrutura completa.' },
      { emoji: '👥', title: 'Moradores', description: 'Consulte os moradores de cada bloco (informações públicas permitidas pela administração).' },
    ],
  },
  {
    id: 'busca-moradores',
    title: 'Busca Moradores',
    emoji: '🔍',
    section: 'Informações',
    steps: [
      { emoji: '🔍', title: 'Buscar', description: 'Use o campo de busca para encontrar moradores pelo nome, bloco ou apartamento.' },
      { emoji: '👤', title: 'Ver contato', description: 'Clique no morador para ver as informações de contato disponíveis (telefone, email).' },
      { emoji: '📱', title: 'Entrar em contato', description: 'Utilize as informações para entrar em contato com seu vizinho quando necessário.' },
    ],
  },

  // ── PORTARIA ───────────────────────────────────────────────────────────
  {
    id: 'aprovacoes',
    title: 'Aprovações',
    emoji: '✅',
    section: 'Portaria',
    steps: [
      { emoji: '📋', title: 'Ver pendências', description: 'Clique em "Aprovações" para ver todos os moradores e solicitações aguardando aprovação.' },
      { emoji: '👤', title: 'Analisar cadastro', description: 'Revise os dados do morador: nome, bloco, apartamento, tipo (proprietário/inquilino) e documentos.' },
      { emoji: '✅', title: 'Aprovar', description: 'Clique em "Aprovar" para liberar o acesso do morador ao sistema do condomínio.' },
      { emoji: '❌', title: 'Rejeitar', description: 'Se os dados estiverem incorretos, clique em "Rejeitar" e informe o motivo.', tip: 'Aprovações rápidas garantem que novos moradores tenham acesso ao sistema sem demora.' },
    ],
  },
  {
    id: 'liberar-visitante',
    title: 'Liberar Visitante',
    emoji: '🚪',
    section: 'Portaria',
    steps: [
      { emoji: '📋', title: 'Ver visitantes', description: 'Veja a lista de visitantes autorizados pelos moradores que estão aguardando liberação.' },
      { emoji: '🔍', title: 'Buscar', description: 'Use o campo de busca para localizar rapidamente o visitante pelo nome, placa ou código.' },
      { emoji: '📄', title: 'Verificar dados', description: 'Confira os dados do visitante: nome, documento, placa do veículo e morador que autorizou.' },
      { emoji: '✅', title: 'Liberar entrada', description: 'Clique em "Liberar" para registrar a entrada do visitante no condomínio.' },
      { emoji: '📊', title: 'Registrar saída', description: 'Quando o visitante sair, registre a saída para manter o controle atualizado.', tip: 'Sempre verifique o documento do visitante antes de liberar a entrada.' },
    ],
  },
  {
    id: 'encomendas-admin',
    title: 'Encomendas do Condomínio',
    emoji: '📦',
    section: 'Portaria',
    steps: [
      { emoji: '📦', title: 'Ver todas as encomendas', description: 'Veja a lista completa de encomendas recebidas no condomínio, de todos os moradores.' },
      { emoji: '➕', title: 'Registrar encomenda', description: 'Quando chegar uma entrega, clique em "Registrar" e informe: morador destinatário, tipo e descrição.' },
      { emoji: '📸', title: 'Fotografar', description: 'Tire uma foto da encomenda como comprovante. O morador será notificado automaticamente.' },
      { emoji: '✅', title: 'Confirmar retirada', description: 'Quando o morador retirar, marque como "Entregue" e registre quem retirou.' },
      { emoji: '📊', title: 'Filtros', description: 'Use filtros por status (Pendente, Entregue) e por bloco/apartamento para encontrar encomendas.', tip: 'Notifique o morador novamente se a encomenda estiver pendente há mais de 2 dias.' },
    ],
  },
  {
    id: 'registro-turno',
    title: 'Registro de Turno',
    emoji: '📋',
    section: 'Portaria',
    steps: [
      { emoji: '🕐', title: 'Iniciar turno', description: 'Ao começar seu turno, registre o horário de início e quaisquer observações relevantes.' },
      { emoji: '✍️', title: 'Registrar ocorrências', description: 'Durante o turno, registre eventos importantes: visitantes, entregas, problemas, etc.' },
      { emoji: '🔄', title: 'Passagem de turno', description: 'Ao finalizar, registre o que o próximo porteiro precisa saber (pendências, alertas).' },
      { emoji: '📊', title: 'Histórico', description: 'Consulte o histórico de turnos anteriores para verificar registros e ocorrências passadas.', tip: 'Um bom registro de turno evita mal-entendidos e garante a continuidade do trabalho.' },
    ],
  },
  {
    id: 'autorizar-visitante-portaria',
    title: 'Autorização Visitante (Portaria)',
    emoji: '🛡️',
    section: 'Portaria',
    steps: [
      { emoji: '📋', title: 'Ver autorizações', description: 'Veja todas as autorizações de visitantes criadas pelos moradores para o dia atual.' },
      { emoji: '🔍', title: 'Buscar autorização', description: 'Busque por nome do visitante, morador, bloco ou código para localizar a autorização.' },
      { emoji: '✅', title: 'Confirmar chegada', description: 'Quando o visitante chegar, localize a autorização e confirme a entrada.' },
      { emoji: '➕', title: 'Criar autorização', description: 'Em casos especiais, crie uma autorização diretamente pela portaria, informando morador e visitante.' },
      { emoji: '📊', title: 'Relatório', description: 'Acompanhe o fluxo de visitantes do dia com status em tempo real.', tip: 'Sempre valide a identidade do visitante com a autorização antes de liberar.' },
    ],
  },
  {
    id: 'reservas-portaria',
    title: 'Reservas (Portaria)',
    emoji: '📅',
    section: 'Portaria',
    steps: [
      { emoji: '📋', title: 'Ver reservas do dia', description: 'Veja todas as reservas de áreas comuns agendadas para hoje e os próximos dias.' },
      { emoji: '🔑', title: 'Liberar acesso', description: 'Quando o morador chegar para usar a área reservada, confirme e libere o acesso.' },
      { emoji: '👁️', title: 'Fiscalizar', description: 'Monitore o uso das áreas comuns e registre qualquer irregularidade.' },
      { emoji: '📊', title: 'Calendário', description: 'Consulte o calendário completo de reservas para planejar o suporte necessário.', tip: 'Verifique o horário da reserva para garantir que o morador respeite o limite de uso.' },
    ],
  },
  {
    id: 'visita-proprietario',
    title: 'Visita Proprietário',
    emoji: '🏠',
    section: 'Portaria',
    steps: [
      { emoji: '📋', title: 'Registrar visita', description: 'Quando um proprietário não-morador visitar o condomínio, registre a visita aqui.' },
      { emoji: '✍️', title: 'Preencher dados', description: 'Informe: nome do proprietário, unidade, motivo da visita e horário de entrada.' },
      { emoji: '📊', title: 'Histórico', description: 'Consulte o histórico de visitas de proprietários para controle e segurança.' },
    ],
  },
]
