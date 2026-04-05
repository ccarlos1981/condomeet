---
stepsCompleted: ['step-01-init', 'step-02-discovery', 'step-03-success', 'step-04-journeys', 'step-05-domain', 'step-06-innovation', 'step-07-project-type', 'step-08-scoping', 'step-09-functional', 'step-10-nonfunctional', 'step-11-polish']
inputDocuments:
  - _bmad-output/planning-artifacts/prd.md
  - _bmad-output/planning-artifacts/product-brief-condomeet-2026-01-27-mvp-scope.md
  - _bmad-output/planning-artifacts/product-brief-condomeet-2026-01-27.md
  - _bmad-output/planning-artifacts/architecture.md
  - docs/assembleia-online-research.html
  - ~/Downloads/edital de assembleia montserrat.pdf
workflowType: 'prd'
classification:
  projectType: Web App (Admin Panel) + Mobile App (future)
  domain: PropTech (Condominium Management) - Online Assembly & Governance
  complexity: High
  projectContext: Brownfield (new module for existing platform)
---

# PRD — Condomeet Assembleia Online

**Autor:** Cristiano  
**Data:** 2026-04-04  
**Versão:** 1.0  
**Status:** Aprovado

---

## Executive Summary

O módulo de **Assembleia Online** do Condomeet é uma solução completa para gestão de assembleias condominiais digitais. Permite que síndicos conduzam assembleias ordinárias (AGO) e extraordinárias (AGE) nas modalidades presencial, online ou híbrida — tudo dentro da plataforma.

Combina videoconferência ao vivo (Jitsi Meet), votação secreta por unidade com validade jurídica, chat em tempo real, e geração automática de ata por IA, em total conformidade com a **Lei nº 14.309/2022**.

### Diferencial Competitivo

O diferencial principal é a **ATA automática por Inteligência Artificial** — transcreve a gravação da assembleia e gera um documento estruturado pronto para revisão e registro. Funcionalidade **inexistente nos concorrentes** do mercado condominial (TownSq, Superlógica, uCondo, CondominioDigital).

---

## Success Criteria

### Síndico (Administrador)
- Cria e configura assembleia completa em **< 10 minutos** via wizard guiado
- Sente **confiança jurídica** graças ao guia legal integrado
- Recebe **ATA pré-gerada por IA** em até 15 minutos após encerrar votação
- Não precisa treinamento externo — sistema autoguiado

### Morador (Participante)
- Entra na assembleia com **1 clique** (link via WhatsApp/Push)
- Participa de qualquer lugar, inclusive viajando
- Voto **secreto e seguro** — nunca vê votos individuais de outros
- Representante com procuração vota pela unidade representada

### Negócio
- **Diferencial #1**: nenhum concorrente tem ATA por IA
- Target: 50% dos condomínios ativos usando assembleia online em 12 meses
- Funcionalidade como upsell premium

### Métricas Técnicas

| Métrica | Target |
|---|---|
| Tempo para criar assembleia | < 10 minutos |
| Tempo para morador entrar | < 30 segundos |
| ATA gerada após encerramento da votação | < 15 minutos |
| Capacidade simultânea | 500+ participantes |
| Precisão transcrição (PT-BR) | > 90% |
| Disponibilidade durante assembleia | 99.9% |

---

## User Journeys

### Journey 1: Paulo, o Síndico — Criando a AGO Anual

**Abertura**: Paulo é síndico do Montserrat, 120 unidades. A AGO anual está chegando — da última vez, alugou salão, imprimiu 200 folhas, 40% compareceu, ata demorou 2 semanas.

**Ação**: Abre o Condomeet, clica "Nova Assembleia". O wizard guiado aparece com 5 steps — o sistema mostra dicas legais em cada etapa. O edital com procuração é gerado automaticamente e enviado por WhatsApp + Push.

**Clímax**: No dia, 85 unidades online + 20 presenciais. Paulo conduz com controle total — muta todos, abre votação por pauta, vê resultado instantâneo no dashboard. Dona Maria, 78 anos, participa da casa da filha em São Paulo.

**Resolução**: Ao encerrar votação (3 dias depois), ata pré-gerada por IA em 10 minutos. Paulo revisa, ajusta dois nomes, publica. *"Nunca mais volta a ser no papel."*

### Journey 2: Marina, a Moradora Viajando

**Abertura**: Marina em viagem de trabalho recebe no WhatsApp a convocação.

**Ação**: Clica no link, entra na sala. Vê o vídeo do salão, chat lateral. Quando chega a pauta, vota "A favor" com um toque.

**Clímax**: Tela mostra "✅ Voto registrado pela Unidade 304". Resultado exibido: 78% a favor — sem expor votos individuais.

**Resolução**: Recebe a ata completa por push. *"Finalmente minha voz conta mesmo longe."*

### Journey 3: João, o Procurador

**Abertura**: Seu Antônio (501) viaja. Registra procuração para João (502) pelo app.

**Ação**: João entra e o sistema reconhece a procuração: "Votando como: Unidade 502 (própria) e Unidade 501 (procuração)". Vota duas vezes separadamente.

**Resolução**: Ata registra: "Unidade 501 — voto por procuração (João, procurador)". Legal e rastreável.

### Journey 4: Paulo — Edge Case (Queda de Internet)

**Abertura**: Durante AGE polêmica, internet do condomínio cai.

**Ação**: Sistema detecta queda, mostra aviso, votação pausa automaticamente. Moradores online mantêm conexão (Jitsi). Paulo reconecta em 4 minutos.

**Resolução**: Dashboard mostra 83→79 reconectados. Votos preservados. Ata registra incidente com timestamp.

### Journey Requirements Summary

| Journey | Capabilities |
|---|---|
| J1 - Síndico cria assembleia | Wizard guiado, edital auto-gerado, guia legal, convocação WhatsApp/Push |
| J2 - Moradora viajando | Entrada 1 clique, vídeo + chat, votação secreta por unidade |
| J3 - Procuração | Procuração digital, votação múltipla, audit trail |
| J4 - Edge case queda | Reconexão automática, votação pausável, log de incidentes |

---

## Domain-Specific Requirements

### Compliance & Regulatório

| Requisito Legal | Fonte | Implementação |
|---|---|---|
| Assembleia virtual permitida se não proibida pela convenção | Lei 14.309/2022, Art. 1.354-A | Guia legal no wizard |
| Convocação com antecedência mínima | Convenção (geralmente 10 dias) | Validação de data configurável |
| Edital informa modalidade + link + como participar | Lei 14.309/2022 | Edital auto-gerado completo |
| 1ª convocação: quórum qualificado | Art. 1.352 CC | Verificação antes de permitir votação |
| 2ª convocação: maioria dos presentes | Art. 1.353 CC | Transição automática |
| Inadimplentes não votam | Art. 1.335, III CC | Bloqueio automático do financeiro |
| Procuração específica por assembleia | Art. 654 CC | Template auto-gerado, não exige firma reconhecida (exceto se convenção exigir) |
| Ata registra todos os fatos relevantes | Art. 1.354 CC | ATA por IA + log de incidentes |
| Igualdade presencial = online | Lei 14.309/2022 | Mesmos direitos em ambas modalidades |

### Regras de Negócio Críticas

| Regra | Detalhamento |
|---|---|
| **Voto por unidade** | Uma unidade = um voto. 2º voto da mesma unidade sobrepõe o 1º |
| **Eleição da Mesa** | Pauta 0 opcional — votação para presidente e secretário da sessão |
| **Procuração configurável** | Default: simples (digital). Opção: exigir firma reconhecida |
| **Bloqueio de inadimplente** | Bloqueado de votar, pode assistir/comentar |
| **Peso de voto** | Por fração ideal (m²) ou por unidade (1:1) — configurável |
| **Quórum por pauta** | Maioria simples, qualificada (2/3), ou unanimidade |
| **Timeline separada** | Assembleia (vídeo) e Votação são independentes — votação pode permanecer aberta até 3 dias após a sessão ao vivo |
| **ATA gerada após votação** | ATA só é gerada quando o síndico encerra o período de votação, não quando encerra a assembleia ao vivo |

### Risk Mitigations

| Risco | Impacto | Mitigação |
|---|---|---|
| Assembleia contestada judicialmente | Alto | Audit trail + gravação + ata com hash |
| Voto manipulado/fraudado | Crítico | Voto criptografado + IP + hash SHA-256 |
| Queda da videoconferência | Alto | Reconexão auto + votação pausável |
| Morador alega não foi convocado | Médio | Log de envio WhatsApp + Push + confirmação |
| Inadimplente vota por engano | Alto | Bloqueio automático pré-assembleia |
| Procuração inválida | Médio | Validação prévia pelo síndico |

---

## Innovation & Novel Patterns

| # | Inovação | Status no Mercado |
|---|---|---|
| 1 | **ATA automática por IA** (Whisper + LLM) | Nenhum concorrente tem |
| 2 | **Votação assíncrona pós-assembleia** (até 3 dias) | Inédito no setor |
| 3 | **Videoconferência nativa integrada** (Jitsi) | Concorrentes usam links externos |
| 4 | **Guia legal em tempo real** no wizard | Inexistente |
| 5 | **Audit trail com validade jurídica** (IP + hash SHA-256) | Diferencial técnico |

### Competitive Landscape

| Feature | TownSq | Superlógica | uCondo | **Condomeet** |
|---|---|---|---|---|
| Vídeo | Link externo | ❌ | ❌ | **Jitsi nativo** |
| Votação | ✅ | ✅ | ✅ | **✅ + assíncrona** |
| ATA por IA | ❌ | ❌ | ❌ | **✅** |
| Guia legal | ❌ | ❌ | ❌ | **✅** |

---

## Technical Architecture

| Componente | Stack | Razão |
|---|---|---|
| Frontend Admin | Next.js (existente) | Brownfield |
| Videoconferência | Jitsi Meet (JaaS → self-hosted) | Grátis para dev, escala para 500+ |
| Chat real-time | Supabase Realtime Channels | Já usado no projeto |
| Votação | Supabase + RLS + UPSERT | Voto por unidade, secreto, audit trail |
| Notificações | WhatsApp (BotConversa) + FCM Push | Já integrado |
| Gravação | Jitsi Recording (Jibri) → Supabase Storage | Armazenamento seguro |
| Transcrição | OpenAI Whisper API | $0.006/min, PT-BR excelente |
| Geração ATA | Google Gemini / GPT-4o | Edge Function assíncrona |
| PDF | React-PDF ou jsPDF | Edital + Ata + Procuração |

### Permission Matrix (RBAC)

| Ação | Síndico | Morador | Porteiro | Super Admin |
|---|---|---|---|---|
| Criar assembleia | ✅ | ❌ | ❌ | ✅ |
| Editar assembleia | ✅ | ❌ | ❌ | ✅ |
| Conduzir (moderação) | ✅ | ❌ | ❌ | ✅ |
| Participar (vídeo/chat) | ✅ | ✅ | ❌ | ✅ |
| Votar | ✅* | ✅* | ❌ | ❌ |
| Ver resultados | ✅ | ✅ | ❌ | ✅ |
| Gerar/assinar ata | ✅ | ❌ | ❌ | ✅ |

*\* Apenas se unidade adimplente*

### Custo de Infraestrutura

| Fase | Jitsi | IA (Whisper + LLM) |
|---|---|---|
| Desenvolvimento | R$0 (JaaS Dev, 25 MAUs) | R$0 (teste) |
| Produção inicial | R$0 (até 25 MAUs) ou ~R$500/mês (JaaS Basic) | ~R$3/assembleia |
| Escala | ~R$200/mês (self-hosted) | ~R$3/assembleia |

---

## Project Scoping & Phased Development

### Fase 1 — MVP (Admin Panel Web)

| # | Feature | Prioridade |
|---|---|---|
| 1 | Wizard de criação (4 steps) | Must-have |
| 2 | Lista de assembleias com status | Must-have |
| 3 | Detalhes com abas (Info, Pautas, Dashboard) | Must-have |
| 4 | Votação por unidade (secreta + bloqueio) | Must-have |
| 5 | Bloqueio automático de inadimplentes | Must-have |
| 6 | Dashboard em tempo real | Must-have |
| 7 | Geração de edital em PDF | Must-have |
| 8 | Envio de convocação (WhatsApp + Push) | Must-have |
| 9 | Votação assíncrona (até 3 dias) | Must-have |
| 10 | Eleição da Mesa (Pauta 0 opcional) | Should-have |

### Fase 2 — Growth

| # | Feature |
|---|---|
| 11 | 🎥 Transmissão Jitsi integrada |
| 12 | 💬 Chat da assembleia (Realtime) |
| 13 | 🤖 ATA automática por IA |
| 14 | 📜 Procuração digital |
| 15 | ✋ Levantar a mão / fila de fala |
| 16 | 📊 Apuração detalhada |
| 17 | 📋 Lista de presença |
| 18 | 📖 Guia legal integrado |

### Fase 3 — Vision

| # | Feature |
|---|---|
| 19 | 📱 Acesso mobile (Flutter) |
| 20 | 📑 Exportação para cartório digital |
| 21 | 🔄 Sessão permanente (suspender/retomar) |
| 22 | 📊 Analytics histórico |
| 23 | 🌐 Assembleia assíncrona (votação aberta 48h) |

---

## Functional Requirements

### Gestão de Assembleias

- **FR1**: Síndico pode criar nova assembleia via wizard passo a passo
- **FR2**: Síndico pode definir tipo (AGO/AGE), modalidade (Online/Presencial/Híbrida) e datas
- **FR3**: Síndico pode configurar 1ª e 2ª convocação com quóruns diferentes
- **FR4**: Síndico pode editar assembleia em status "Rascunho" ou "Agendada"
- **FR5**: Síndico pode cancelar assembleia agendada
- **FR6**: Síndico pode visualizar lista de assembleias com filtro por status
- **FR7**: Síndico pode definir período de votação independente da assembleia (até 3 dias após)
- **FR8**: Sistema atualiza status automaticamente (Rascunho → Agendada → Em andamento → Votação aberta → Finalizada)

### Pautas & Votação

- **FR9**: Síndico pode adicionar, editar e remover pautas
- **FR10**: Síndico pode marcar pauta como "Votação" ou "Informativo"
- **FR11**: Síndico pode configurar quórum por pauta (simples, 2/3, unanimidade)
- **FR12**: Síndico pode habilitar "Eleição da Mesa" como Pauta 0 opcional
- **FR13**: Morador pode votar em cada pauta (A favor / Contra / Abstenção)
- **FR14**: Sistema registra voto por unidade — segundo voto da mesma unidade sobrepõe o primeiro
- **FR15**: Sistema impede voto de unidade inadimplente
- **FR16**: Sistema mantém voto secreto — ninguém vê votos individuais
- **FR17**: Sistema exibe resultado agregado em tempo real
- **FR18**: Síndico pode configurar peso do voto (fração ideal ou 1:1)

### Inadimplência & Bloqueio

- **FR19**: Sistema sincroniza inadimplentes do módulo financeiro
- **FR20**: Síndico pode visualizar lista de unidades bloqueadas
- **FR21**: Síndico pode bloquear/desbloquear manualmente uma unidade
- **FR22**: Unidade bloqueada pode assistir mas não votar

### Convocação & Edital

- **FR23**: Sistema gera edital em PDF completo
- **FR24**: Sistema gera modelo de procuração junto com o edital
- **FR25**: Síndico pode configurar se procuração exige firma reconhecida
- **FR26**: Síndico pode enviar convocação via WhatsApp
- **FR27**: Síndico pode enviar convocação via Push notification
- **FR28**: Sistema registra log de envio de cada convocação

### Dashboard & Acompanhamento

- **FR29**: Dashboard em tempo real: unidades cadastradas, votaram, % participação
- **FR30**: Detalhamento por pauta: válidos, duplicados, inadimplentes, rejeitados
- **FR31**: Lista de presença (quais unidades participaram)
- **FR32**: Resultado da apuração com gráficos

### Ata & Documentação

- **FR33**: Sistema gera ata estruturada com deliberações e resultados
- **FR34**: Síndico pode revisar e editar ata antes de publicar
- **FR35**: Síndico pode exportar ata em PDF
- **FR36**: Audit trail completo (IP, timestamp, user agent, hash por voto)
- **FR37**: Sistema distribui ata finalizada para moradores (WhatsApp + Push)

### Procuração

- **FR38**: Morador pode registrar procuração digital indicando representante
- **FR39**: Síndico pode validar procurações antes da assembleia
- **FR40**: Procurador pode votar pela unidade representada
- **FR41**: Sistema registra na ata quais votos foram por procuração

### Guia & Orientação Legal

- **FR42**: Sistema exibe orientação legal em cada step do wizard
- **FR43**: Síndico pode acessar guia completo de como conduzir assembleia
- **FR44**: Sistema valida regras legais automaticamente (antecedência, quórum)

---

## Non-Functional Requirements

### Performance

| NFR | Métrica |
|---|---|
| **NFR1**: Dashboard assembly carregamento | < 2 segundos |
| **NFR2**: Registro de voto — feedback | < 1 segundo |
| **NFR3**: Atualização resultado real-time | < 3 segundos |
| **NFR4**: Geração PDF edital | < 5 segundos |
| **NFR5**: Geração ATA por IA (2h assembleia) | < 15 minutos |

### Security

| NFR | Requisito |
|---|---|
| **NFR6**: Votos criptografados em repouso | AES-256 |
| **NFR7**: Audit trail imutável | IP + timestamp + SHA-256, sem UPDATE/DELETE |
| **NFR8**: RLS por condomínio | Isolamento multi-tenant |
| **NFR9**: Autenticação para votar | JWT + verificação de unidade |
| **NFR10**: LGPD compliance | Dados anonimizáveis, retenção configurável |

### Scalability

| NFR | Métrica |
|---|---|
| **NFR11**: Participantes simultâneos | 500+ |
| **NFR12**: Assembleias paralelas | 10+ simultâneas |
| **NFR13**: Histórico sem degradação | 100+ assembleias por condomínio |

### Reliability

| NFR | Métrica |
|---|---|
| **NFR14**: Disponibilidade durante assembleia | 99.9% |
| **NFR15**: Votos nunca são perdidos | Persistência imediata |
| **NFR16**: Reconexão automática | < 10 segundos |

### Integration

| NFR | Requisito |
|---|---|
| **NFR17**: WhatsApp (BotConversa) | Convocação e ata para todos |
| **NFR18**: Push notification (FCM) | Convocação, início, encerramento |
| **NFR19**: Supabase Storage | Gravações e PDFs |
| **NFR20**: Módulo financeiro | Sync de inadimplência |

---

## Referências

- Lei nº 14.309/2022 (assembleias virtuais)
- Código Civil, Arts. 1.335, 1.352, 1.353, 1.354, 1.354-A, 654
- Edital de Assembleia — Condomínio Montserrat (referência real)
- Pesquisa de mercado: TownSq, Superlógica, uCondo, CondominioDigital
