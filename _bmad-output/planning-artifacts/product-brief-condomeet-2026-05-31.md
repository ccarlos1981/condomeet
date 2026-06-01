---
stepsCompleted: [1, 2, 3, 4, 5]
inputDocuments: ['_bmad-output/brainstorming/brainstorming-session-2026-05-31.md', '_bmad-output/planning-artifacts/research/market-acordos-e-concorrentes-research-2026-05-31.md']
date: 2026-05-31
author: cristiano
---

# Product Brief: condomeet

## Executive Summary

O Condomeet visa liderar a facilidade de gestão de condomínios no mercado brasileiro por meio da digitalização de fluxos operacionais e financeiros cruciais. Esta rodada de melhorias introduz a Central de Acordos Pix Express, a liberação de visitantes via WhatsApp e assembleias eletrônicas sem papel, focando em conveniência móvel para moradores e inteligência contábil de autoatendimento para síndicos.

---

## Core Vision

### Problem Statement

A gestão condominial tradicional no Brasil sofre com a burocracia contábil e a inadimplência. Negociar dívidas com administradoras é um processo lento, manual e constrangedor, exigindo contatos em horário comercial e termos impressos. Ao mesmo tempo, moradores inadimplentes perdem o direito legal de votar em assembleias e reservar áreas comuns, o que gera desgaste na convivência.

### Problem Impact

- **Moradores:** Sentem-se constrangidos ao lidar com a inadimplência e excluídos das decisões do condomínio pela impossibilidade de votar nas assembleias vigentes.
- **Síndicos/Administradoras:** Perdem tempo operacional em cobranças manuais e sofrem com a falta de previsibilidade de caixa e atritos gerados na mediação de desentendimentos.

### Why Existing Solutions Fall Short

Os concorrentes tradicionais (como a SuperLógica) priorizam a robustez de ERPs voltados para administradoras baseados em desktop. Seus fluxos de acordos exigem intervenção humana e assinaturas físicas. Competidores como o uCondo simplificam a usabilidade do morador, mas ainda carecem de liquidação instantânea em tempo real que integre a quitação de débitos com a liberação imediata de direitos políticos em assembleias digitais.

### Proposed Solution

Implementar uma Central de Acordos Pix Express no Condomeet que possibilita ao morador visualizar e parcelar seus débitos pendentes de forma totalmente autônoma no celular. A liquidação do Pix dá baixa contábil imediata no banco de dados e restabelece as permissões de reserva de áreas comuns e voto em assembleias ativas instantaneamente.

### Key Differentiators

- **Autoatendimento Pix Parcelado:** Simulação, acordo assinado eletronicamente e geração de chaves Pix em lote 100% automatizados.
- **Integração em Tempo Real:** Baixa de débito instantânea via gateway Asaas e sincronização automática de elegibilidade para votação e reservas sem intermediação do síndico.
- **Conectividade WhatsApp:** Lembretes de parcelas do acordo e envio direto de termos assinados no canal de preferência do morador.

---

## Target Users

### Primary Users

#### Persona 1: Roberto, 34 anos - O Morador Ocupado (Inadimplente Temporário)
*   **Contexto:** Engenheiro de software, mora sozinho, rotina de trabalho intensa. Faz uso intensivo de internet e aplicativos financeiros (Nubank).
*   **Como sente o problema:** Acabou esquecendo o boleto do condomínio dos últimos 2 meses devido a viagens de trabalho. Recebeu a convocação para a Assembleia Geral Ordinária, onde se discutirá a reforma da fachada, mas está com o direito de voto suspenso por inadimplência.
*   **Motivações:** Resolver suas pendências rapidamente de forma silenciosa e discreta, sem precisar ligar para a administradora em horário comercial. Quer recuperar seu direito de voto na assembleia online imediatamente.
*   **Aha! Moment:** Abre o app, simula o acordo em 2 parcelas, assina eletronicamente e faz o Pix da primeira parcela. Em menos de 2 minutos, o aplicativo muda seu status contábil e libera seu voto na assembleia virtual em tempo real.

#### Persona 2: Sandra, 48 anos - A Síndica Constrangida (Moradora)
*   **Contexto:** Professora aposentada, síndica moradora há 3 anos de um único condomínio residencial.
*   **Como sente o problema:** Detesta ter que cobrar vizinhos pessoalmente ou por telefone. Gasta horas gerando propostas de acordos manuais por e-mail ou intermediando contatos com a administradora externa.
*   **Motivações:** Manter o caixa do condomínio saudável para realizar benfeitorias locais sem gerar conflito ou desgaste de relacionamento com moradores.
*   **Aha! Moment:** Ativa a regra de cobrança de acordos Pix pelo painel e recebe relatórios mensais de acordos quitados de forma 100% autônoma pelo app.

#### Persona 3: Cláudio, 45 anos - O Síndico Profissional (Multi-condomínio)
*   **Contexto:** Administrador de empresas, atua como síndico profissional gerenciando de 5 a 10 condomínios diferentes.
*   **Como sente o problema:** Diferente de Sandra, Cláudio atua como uma empresa de gestão. Ele precisa gerenciar a inadimplência e as regras de múltiplos condomínios simultaneamente. Perder tempo navegando em contas separadas para cada condomínio inviabiliza seu dia.
*   **Motivações:** Ter uma visão consolidada de todos os condomínios sob sua responsabilidade, podendo alternar rapidamente de condomínio ou gerenciar acordos globais de forma escalável.
*   **Aha! Moment:** Acessa um Dashboard Multi-condomínio centralizado no Condomeet que exibe um resumo da inadimplência geral de todas as suas pastas. Com um único clique, ele alterna o contexto para o condomínio desejado para validar acordos ou criar editais de assembleia sem precisar fazer novos logins.

### Secondary Users

#### Marcos, 42 anos (Porteiro do Condomínio)
*   **Contexto:** Porteiro noturno. Fica sobrecarregado nos horários de pico tentando ligar para apartamentos físicos para liberar visitantes.
*   **Como se beneficia:** Com a liberação expressa via WhatsApp (contingência complementar para visitantes inesperados e entregadores), ele insere o nome do visitante no terminal e o morador autoriza com um clique no WhatsApp, poupando-o de interfonar repetidamente.

### User Journey

**Cenário:** Roberto quer votar na Assembleia Geral Online de seu condomínio hoje à noite, mas está com parcelas em atraso.
1.  **Descoberta:** Roberto recebe uma notificação: *"A Assembleia sobre a reforma começa em 1 hora. Sua unidade está suspensa para votação devido a pendências"*.
2.  **Onboarding:** Clica no link direto e abre a **Central de Acordos Pix Express** no celular.
3.  **Uso Core (Negociação):** O app exibe o valor corrigido com multa/juros. Ele seleciona dividir em 2 parcelas. O termo é exibido e assinado com biometria facial (1 clique).
4.  **Sucesso Momentâneo:** O app gera o Pix Copia e Cola. Roberto faz a transferência.
5.  **Resolução:** A API do Asaas comunica o Supabase em tempo real. O Condomeet atualiza o status de Roberto e libera seu voto na Assembleia Virtual imediatamente.

---

## Success Metrics

### Business Objectives

*   **Objetivos de Curto Prazo (3 meses):**
    *   Lançar o MVP da Central de Acordos Pix Express em 3 condomínios-piloto.
    *   Garantir 100% de estabilidade nas integrações de Webhooks de pagamento (Asaas/Supabase) e notificações automáticas de WhatsApp (BotConversa/Z-API).
    *   Validar a usabilidade do painel multi-condomínio com pelo menos 2 síndicos profissionais parceiros.
*   **Objetivos de Longo Prazo (12 meses):**
    *   Implementar a funcionalidade em toda a base de condomínios do Condomeet.
    *   Garantir a retenção (*Churn* anual abaixo de 3%) por meio do alto valor agregado da automatização de inadimplência.
    *   Explorar monetização via split de taxas de transação ou pacotes de cobrança ativa.

### Key Performance Indicators

- **Taxa de Conversão de Acordos:** Porcentagem de moradores inadimplentes que iniciam a simulação e quitam o primeiro Pix. (Meta: **>50%**).
- **Taxa de Baixa Automática em Tempo Real:** Porcentagem de acordos pagos que atualizam a elegibilidade contábil no Supabase em menos de 60 segundos. (Meta: **>98%**).
- **Tempo de Resolução do Débito:** Tempo médio entre o alerta de inadimplência e o pagamento do primeiro Pix. (Meta: **<5 minutos**).
- **Velocidade na Liberação de Visitantes Inesperados:** Porcentagem de autorizações de contingência enviadas via WhatsApp que são respondidas pelo morador em menos de 2 minutos. (Meta: **>80%**).
- **Eficiência Administrativa (Síndico Profissional):** Tempo gasto para alterar contexto entre condomínios no painel consolidado. (Meta: **<3 segundos**).

---

## MVP Scope

### Core Features

- **Central de Acordos Pix Express (Morador e Adm):**
  * Simulação e parcelamento amigável via aplicativo móvel.
  * Assinatura digital do termo com 1 clique (FaceID/Biometria).
  * Webhook do gateway Asaas para confirmação de pagamento instantâneo.
  * Atualização de adimplência em tempo real no banco de dados.
- **Painel Multi-condomínio:**
  * Alternador de condomínios ultra-rápido no cabeçalho do painel do síndico profissional.
  * Visão geral unificada de inadimplência.
- **Assembleias Paperless:**
  * Credenciamento e votação digital integrados.
  * Bloqueio/desbloqueio automático de voto de inadimplentes após pagamento do acordo Pix.
- **Liberação de Visitantes Express via WhatsApp:**
  * Solicitação interativa enviada ao WhatsApp do morador com botões de Aprovado/Recusado para visitas não agendadas previamente.

### Out of Scope for MVP

- **Concierge Condominial Inteligente via WhatsApp:** Robô com IA conversacional para responder regras do regimento interno e encomendas (V2).
- **Depósito de Reserva Dinâmico:** Integração de caução digital em reservas de áreas comuns (V2).
- **Conciliação e Balancete Autônomo por IA:** Classificação contábil automática de arquivos OFX/extratos (V3).
- **Indicações com Cashback Condominial:** Ecossistema de taxas de serviços de profissionais indicados revertidas para o condomínio (V3).

### MVP Success Criteria

- Conclusão do fluxo de acordo pelo morador em menos de 5 minutos.
- Mudança instantânea no Supabase Realtime liberando o botão de voto na assembleia.
- Menos de 90 segundos para o morador responder ao check-in inesperado de portaria no WhatsApp.

### Future Vision

O Condomeet evoluirá para uma plataforma de inteligência e governança preditiva, onde síndicos gerenciam centenas de condomínios de forma autônoma com IAs contábeis (balancetes autônomos), reservas de áreas comuns asseguradas por garantias digitais, e moradia conectada a serviços locais integrados.
