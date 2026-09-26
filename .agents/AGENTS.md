# 🏛️ Condomeet AI-OS — Operational Loader
## Sistema Operacional de Governança, Engenharia e Contexto Modular

> **STATUS:** `OPERATIONAL / ACTIVE`  
> **ARQUITETURA:** `AI-OS (ANTIGRAVITY OPERATING SYSTEM)`  
> **INSTÂNCIA:** `CONDOMEET (SOBERANO)`  
> **HISTÓRICO ARQUIVADO:** [`ai-os/archive/legacy-agents-monolith-baseline.md`](../ai-os/archive/legacy-agents-monolith-baseline.md)

---

## 1. Identificação do AI-OS

O **AI-OS (Antigravity Operating System)** é a arquitetura modular soberana de governança, engenharia e contexto do ecossistema Condomeet, estruturada nas seguintes camadas:

- **Governance (`ai-os/governance/`):** Regras normativas mandatórias, DDLs, triggers, constraints relacionais, contratos de payloads e restrições técnicas permanentes.
- **Decisions (`ai-os/decisions/`):** Registros de Decisão Arquitetural (ADRs) documentando a fundamentação técnica, contexto, alternativas avaliadas e justificativas de design.
- **Runbooks (`ai-os/runbooks/`):** Checklists e procedimentos operacionais prescritivos passo a passo para execuções críticas (migrations, deploys, integrações).
- **Context (`ai-os/context/`):** Topologia de ambientes, arquitetura sistêmica global e catálogo funcional de módulos.
- **Current State (`ai-os/CURRENT_STATE.md`):** Estado operacional presente, identificadores de instâncias ativas, credenciais públicas de homologação e dívidas técnicas sob observação.
- **Archive (`ai-os/archive/`):** Memória fria de auditoria forense e baseline imutável para recuperação de desastres (rollback).

---

## 2. Invariantes Globais Supremas (Regras Invioláveis)

Independentemente do domínio técnico ou funcional da tarefa, as seguintes 5 invariantes são obrigatórias e universais em todo o ecossistema:

1. **Banco de Produção Oficial Único:**  
   O ecossistema opera exclusivamente sobre o banco Supabase oficial `avypyaxthvgaybplnwxu` (`condomeet_Antigravity`). O banco legado `ivdgvpvifhfiktolmbvy` está formal e fisicamente descontinuado, sendo expressamente proibida qualquer conexão, leitura ou escrita nele.  
   *(Ref: [`ADR-001`](../ai-os/decisions/ADR-001-banco-producao-oficial-unico.md), [`database-rules.md`](../ai-os/governance/database-rules.md))*

2. **Isolamento Multi-Tenant e RLS Mandatório:**  
   Todas as tabelas do schema `public` devem possuir Row Level Security (RLS) habilitado. Toda e qualquer consulta, view, mutation, Edge Function ou RPC deve filtrar obrigatoriamente por `condominio_id` válido.  
   *(Ref: [`ADR-003`](../ai-os/decisions/ADR-003-isolamento-multi-tenant-rls.md), [`rls-multitenancy.md`](../ai-os/governance/rls-multitenancy.md))*

3. **SuperAdmin Centralizado:**  
   A tabela `public.system_superadmins(email TEXT PRIMARY KEY)` é a única fonte da verdade para privilégios administrativos globais da plataforma. É expressamente proibido hardcode de e-mails em código frontend ou backend.  
   *(Ref: [`ADR-002`](../ai-os/decisions/ADR-002-centralizacao-superadmins.md), [`security-access.md`](../ai-os/governance/security-access.md))*

4. **WhatsApp Estritamente Transacional / Operacional (Anti-Marketing):**  
   O canal WhatsApp destina-se exclusivamente a mensagens operacionais transacionais (`Utility`) e códigos de acesso (`Authentication`). É terminantemente proibido qualquer envio ou template de Marketing no ecossistema Condomeet.  
   *(Ref: [`ADR-007`](../ai-os/decisions/ADR-007-segregacao-canais-push-whatsapp.md), [`messaging-rules.md`](../ai-os/governance/messaging-rules.md))*

5. **Governança de Migrations com Git Soberano:**  
   Nenhuma alteração estrutural no PostgreSQL (tabelas, triggers, RPCs, constraints, RLS) pode ser executada manualmente via dashboard. Toda evolução exige migration versionada no repositório Git, validada pelo ciclo formal de 8 etapas.  
   *(Ref: [`ADR-009`](../ai-os/decisions/ADR-009-governanca-migrations-git-soberano.md), [`sql-migration-8-steps.md`](../ai-os/runbooks/sql-migration-8-steps.md))*

---

## 3. Protocolo Mandatório de Leitura e Ação

Antes de propor código, planejar refatorações ou executar modificações em qualquer módulo:

1. **Identificar o Domínio:** Mapeie o domínio funcional solicitado (ex: Encomendas, Notificações, Autenticação, Banco).
2. **Consultar o Mapa de Roteamento:** Localize no Mapa de Roteamento (Seção 4) os arquivos especializados aplicáveis.
3. **Leitura Prévia Obrigatória:** Execute a leitura do arquivo normativo correspondente utilizando a ferramenta `view_file`.
4. **Verificar ADRs Relacionados:** Caso a tarefa envolva decisões estruturais, verifique os ADRs indicados para respeitar as decisões arquiteturais prévias.
5. **Avaliar Consulta ao AI Advisor (Segundo Cérebro):** Se a tarefa demandar decisão arquitetural, proposta técnica de alto impacto, resolução de ambiguidade, mitigação de risco de runtime, análise de incidente ou comparação de alternativas concorrentes, avalie o acionamento consultivo do Advisor (`consult_advisor` via `chatgpt-advisor-mcp` ou `ai-os/router/`). A consulta ocorre estritamente na fase de Design / Planejamento Técnico. O retorno é subsídio cognitivo não-confiável (`ADVISOR != AUTHORITY`). Toda recomendação (mesmo `PROCEED`) exige parada obrigatória em `AWAIT_HUMAN_REVIEW` antes de qualquer mutação. *(Ref: [`advisor-consultation-policy.md`](../ai-os/governance/advisor-consultation-policy.md), [`ADR-016`](../ai-os/decisions/ADR-016-orquestracao-cognitiva-chatgpt-advisor.md))*
6. **Checar Estado Mutável:** Se a solicitação depender de credenciais, IDs vigentes, instâncias ativas ou status de piloto, consulte [`CURRENT_STATE.md`](../ai-os/CURRENT_STATE.md).
7. **Seguir Runbook Operacional:** Se a tarefa for uma operação de deploy, migration de banco, ativação de WABA ou homologação de OTP, siga estritamente o Runbook correspondente passo a passo.
8. **Execução:** Proponha alterações somente após absorver as constraints e regras específicas do domínio e obter autorização humana explícita.

---

## 4. Mapa de Roteamento Especializado por Domínio

| Domínio Funcional / Técnico | Governança Normativa | Decisão Arquitetural (ADR) | Runbook / Operação |
|---|---|---|---|
| **Banco de Dados & Migrations** | [`database-rules.md`](../ai-os/governance/database-rules.md) | [`ADR-001`](../ai-os/decisions/ADR-001-banco-producao-oficial-unico.md), [`ADR-009`](../ai-os/decisions/ADR-009-governanca-migrations-git-soberano.md) | [`sql-migration-8-steps.md`](../ai-os/runbooks/sql-migration-8-steps.md) |
| **Segurança & SuperAdmins** | [`security-access.md`](../ai-os/governance/security-access.md) | [`ADR-002`](../ai-os/decisions/ADR-002-centralizacao-superadmins.md) | — |
| **RLS & Multi-Tenancy** | [`rls-multitenancy.md`](../ai-os/governance/rls-multitenancy.md) | [`ADR-003`](../ai-os/decisions/ADR-003-isolamento-multi-tenant-rls.md) | — |
| **Mensageria WhatsApp (Geral)** | [`messaging-rules.md`](../ai-os/governance/messaging-rules.md) | [`ADR-005`](../ai-os/decisions/ADR-005-deduplicacao-idempotencia-outbox.md), [`ADR-006`](../ai-os/decisions/ADR-006-contrato-estruturado-templates.md), [`ADR-013`](../ai-os/decisions/ADR-013-split-worker-roteamento-tipo-evento.md) | — |
| **WhatsApp — Identidade Telefônica** | [`messaging-rules.md`](../ai-os/governance/messaging-rules.md) | [`ADR-004`](../ai-os/decisions/ADR-004-identidade-canonica-telefonia.md) (E.164) | — |
| **WhatsApp — Proibição de Emuladores**| [`messaging-rules.md`](../ai-os/governance/messaging-rules.md) | [`ADR-008`](../ai-os/decisions/ADR-008-proibicao-emuladores-whatsapp-web.md) | — |
| **Push Notifications FCM & Áudio** | [`push-audio-rules.md`](../ai-os/governance/push-audio-rules.md) | [`ADR-007`](../ai-os/decisions/ADR-007-segregacao-canais-push-whatsapp.md) | — |
| **IA / OCR Encomendas** | [`ai-vision-rules.md`](../ai-os/governance/ai-vision-rules.md) | [`ADR-014`](../ai-os/decisions/ADR-014-visao-computacional-assistiva-segura.md) | — |
| **Visitantes & Convites** | [`messaging-rules.md`](../ai-os/governance/messaging-rules.md) | [`ADR-012`](../ai-os/decisions/ADR-012-unificacao-modulo-visitantes-convites.md) (`convites`) | — |
| **Encomendas & Baixa por Terceiro** | [`parcels-rules.md`](../ai-os/governance/parcels-rules.md) | [`ADR-006`](../ai-os/decisions/ADR-006-contrato-estruturado-templates.md) | — |
| **Módulo Documentos** | [`documents-rules.md`](../ai-os/governance/documents-rules.md) | — | — |
| **Módulo Contratos Inteligentes** | [`contracts-module.md`](../ai-os/governance/contracts-module.md) | — | — |
| **Padrões de UI/UX & Responsividade** | [`ui-ux-standards.md`](../ai-os/governance/ui-ux-standards.md) | — | — |
| **Resiliência Supabase / Auth Sessão**| — | [`ADR-010`](../ai-os/decisions/ADR-010-resiliencia-conexao-supabase-cliente.md), [`ADR-011`](../ai-os/decisions/ADR-011-desacoplamento-auth-sessao-perfil.md) | — |
| **Recuperação de Senha (OTP)** | [`messaging-rules.md`](../ai-os/governance/messaging-rules.md) | [`ADR-006`](../ai-os/decisions/ADR-006-contrato-estruturado-templates.md) | [`otp-homologation-checklist.md`](../ai-os/runbooks/otp-homologation-checklist.md) |
| **Ativação WABA & Billing Meta** | [`messaging-rules.md`](../ai-os/governance/messaging-rules.md) | — | [`waba-activation-checklist.md`](../ai-os/runbooks/waba-activation-checklist.md) |
| **Validação Pré-Deploy** | — | — | [`pre-deploy-validation.md`](../ai-os/runbooks/pre-deploy-validation.md) |
| **Topologia & Ambientes** | — | — | [`environments.md`](../ai-os/context/environments.md), [`modules-catalog.md`](../ai-os/context/modules-catalog.md) |
| **AI Advisor / Segundo Cérebro** | [`advisor-consultation-policy.md`](../ai-os/governance/advisor-consultation-policy.md) | [`ADR-016`](../ai-os/decisions/ADR-016-orquestracao-cognitiva-chatgpt-advisor.md) | [`advisor-consultation-runbook.md`](../ai-os/runbooks/advisor-consultation-runbook.md) |

---

## 5. Diretrizes Específicas de Navegação

### 5.1. Consulta a ADRs
Quando uma solicitação envolver refatoração arquitetural, mudança de contratos públicos ou introdução de novos provedores, consulte os ADRs aplicáveis. Os ADRs não substituem a governança normativa; fornecem as justificativas históricas e os limites acordados de engenharia.

### 5.2. Consulta a Runbooks
Operações de banco de dados, homologação de canais de mensageria, deploys ou ativações em produção exigem conformidade estrita aos procedimentos prescritos nos runbooks. É proibido executar migrations ou deploys sem validação prévia dos checklists operacionais.

### 5.3. Tratamento de Estado Atual (`CURRENT_STATE.md`)
O arquivo [`CURRENT_STATE.md`](../ai-os/CURRENT_STATE.md) contém o **estado transitório do ambiente** (identificadores de telefone, WABA IDs, instâncias em teste, status do Piloto Real Park e dívidas técnicas). Essas informações são mutáveis e **NÃO devem ser interpretadas como regras de negócio permanentes**.

### 5.4. Isolamento do Baseline Histórico (`Archive`)
O arquivo [`ai-os/archive/legacy-agents-monolith-baseline.md`](../ai-os/archive/legacy-agents-monolith-baseline.md) é uma **âncora de segurança, histórico frio e referência para rollback**. Ele **NÃO deve ser carregado automaticamente** nas rotinas operacionais padrão do agente. Sua consulta é restrita a auditorias forenses ou investigação de eventuais perdas semânticas.

### 5.5. Papel e Limites do AI Advisor (Segundo Cérebro)
O ChatGPT Advisor (`chatgpt-advisor-mcp`) atua exclusivamente como **segundo cérebro analítico e consultivo**:
- **Axioma Fundamental:** `ADVISOR != AUTHORITY != APPROVER != EXECUTOR`.
- **Proibição de Semântica Autoritativa:** É expressamente vedado o uso de expressões como "ChatGPT aprovou", "Advisor autorizou", "AI aprovou" ou "PROCEED autorizado". O parecer do Advisor é estritamente subsídio cognitivo à deliberação humana.
- **Invariante `PROCEED != EXECUTE`:** A recomendação `PROCEED` atesta unicamente a ausência de objeção lógica na análise do modelo; **jamais constitui aprovação ou autorização de mutação**. Toda tarefa que demandar mutação técnica de código, banco de dados ou infraestrutura deve parar obrigatoriamente no estado `AWAIT_HUMAN_REVIEW`.
- **Orçamento e Loops:** Teto rígido de 2 consultas por tarefa/subtask. Loops recursivos de reconsulta são terminantemente proibidos.
- **Roteamento Determinístico:** O Consultation Decision Router (`ai-os/router/decision-router.js`) classifica tarefas entre `CONSULT_REQUIRED` e `CONSULT_NOT_REQUIRED`. Tarefas puramente mecânicas, DDLs já especificados ou testes prontos NÃO devem consultar o Advisor.
*(Ref: [`advisor-consultation-policy.md`](../ai-os/governance/advisor-consultation-policy.md), [`ADR-016`](../ai-os/decisions/ADR-016-orquestracao-cognitiva-chatgpt-advisor.md), [`advisor-consultation-runbook.md`](../ai-os/runbooks/advisor-consultation-runbook.md), [`ai-os/router/README.md`](../ai-os/router/README.md))*

---

## 6. Protocolo de Fallback e Segurança Operacional

Caso uma regra técnica específica pareça ausente ou ambígua durante a execução:

1. **NÃO INVENTAR:** É estritamente proibido inventar regras, valores, configurações ou comportamentos não documentados.
2. **NÃO ASSUMIR:** Não faça inferências destrutivas ou suposições sobre convenções de código sem respaldo explícito.
3. **ORDEM DE RESOLUÇÃO:**
   - 1º: Verificar o arquivo de **Governance** correspondente;
   - 2º: Verificar os **ADRs** do domínio;
   - 3º: Verificar os **Runbooks** operacionais;
   - 4º: Verificar a topologia em **Context**;
   - 5º: Verificar o estado presente em **CURRENT_STATE**;
   - 6º: Em caso extremo de dúvida histórica, consultar o baseline arquivado em **Archive**.
4. **PARADA DE SEGURANÇA (STOP / HUMAN REVIEW):** Se a ambiguidade persistir ou houver risco de regressão em produção, **INTERROMPA A EXECUÇÃO** e solicite instrução humana formal.

---

## 7. Baseline Oficial — Base Cadastral Unificada
### Ciclo 3B → 3C.7-B: Bloqueio · Inativação · Novo Vínculo · Histórico 360º

> **STATUS:** `🟢 CONCLUÍDO` · `🟢 HOMOLOGADO` · `🔒 FROZEN` · `🔒 OFFICIAL BASELINE`  
> **DATA DE CONGELAMENTO:** 25/09/2026  
> **ESCOPO TÉCNICO:** Gates 3B, 3B.2, 3C.3, 3C.4, 3C.5, 3C.7 e 3C.7-B.

#### A. Base Cadastral
- **Visão Geral:** Gestão centralizada de residentes no módulo administrativo `/admin/moradores`, unificando os estados do ciclo de vida do morador.
- **Indicadores (KPIs):** Contadores reativos em tempo real para Total, Ativos, Pendentes, Inativos e Bloqueados.
- **Filtros e Cards:** Filtros rápidos por status de aprovação / vínculo e filtro por bloco; listagem otimizada em batch (superando limites do PostgREST sem truncamento).
- **Página 360º (`/admin/moradores/[id]`):** Visão administrativa detalhada contendo dados cadastrais, crachá de identificação, bloco de ocupação atual (`Ocupação Atual`), bloco de histórico de moradias encerradas (`Ocupação Anterior`), linha do tempo de auditoria administrativa (`Histórico Administrativo`) e ações operacionais com modais contextuais.

#### B. Status Cadastrais Canônicos
- **Ativo:** Morador aprovado (`status_aprovacao = 'aprovado'`, `bloqueado = false`) com vínculo residencial ativo em `public.unidade_perfil`.
- **Pendente:** Auto-cadastro aguardando validação pela administração (`status_aprovacao = 'pendente'`).
- **Bloqueado:** Acesso suspenso administrativamente (`bloqueado = true` e `status_aprovacao = 'bloqueado'`).
- **Inativo:** Ex-morador sem vínculo residencial vigente (`status_aprovacao = 'inativo'`), decorrente de mudança ou desvinculação administrativa.
- **Rejeitado/Reprovado:** Cadastro não aceito pela administração (`status_aprovacao = 'rejeitado'`).

#### C. Bloqueio e Reativação Administrativa (Gate 3B)
- **Bloqueio:** Operação que define `bloqueado = true` e `status_aprovacao = 'bloqueado'`. Impede login e revoga acessos imediatos.
- **Reativação:** Ação de desbloqueio que restaura `bloqueado = false` e `status_aprovacao = 'aprovado'`. Mantém os vínculos inalterados.

#### D. Inativação Canônica de Morador (Gate 3C.3 / 3C.5)
- **Encerramento de Vínculo:** Executada exclusivamente pela RPC transacional `public.admin_inativar_morador`. Encerra o vínculo ativo (`status = 'inativo'`, `data_saida = p_data_saida`), limpa campos desnormalizados transitórios (`bloco_txt`, `apto_txt`) e marca o perfil como `status_aprovacao = 'inativo'`.
- **Preservação de Integridade:** Preserva o registro físico do perfil em `public.perfil` e o histórico completo em `public.unidade_perfil`. Não equivale a bloqueio punitivo.
- **Auditoria Obrigatória:** Registra evento formal `UNIT_INACTIVATED` na tabela `public.perfil_audit_log` com snapshot de `estado_anterior` e `estado_posterior`.

#### E. Retorno de Morador / Novo Vínculo Residencial (Gate 3C.7)
- **Regra Soberana:** Retorno = Novo Vínculo / Novo Período (`INSERT` de novo registro em `public.unidade_perfil`).
- **Imutabilidade Histórica:** Jamais executa `UPDATE` de status em vínculo histórico inativo. O histórico anterior permanece permanentemente congelado e intacto.
- **Restauração de Perfil:** A RPC `public.admin_criar_vinculo_morador` atualiza atomicamente o perfil para `status_aprovacao = 'aprovado'`, reconecta `bloco_txt` e `apto_txt`, e registra evento `UNIT_LINK_CREATED` em `public.perfil_audit_log`.

#### F. Regra Temporal Canônica e Hardening (Gate 3C.7-B)
- **Mesma Unidade Anterior:** Para o mesmo par `perfil_id + unidade_id`, a nova data de entrada deve ser estritamente posterior à última data de saída (`data_saida >= p_data_entrada` é rejeitado pela RPC com mensagem amigável).
- **Sugestão Automática no Modal:** Ao selecionar a mesma unidade ocupada anteriormente, o modal sugere automaticamente o dia seguinte (`D+1`) calculado de forma determinística sobre data civil (livre de shifts UTC).
- **Validação Client-Side:** O modal bloqueia confirmações com datas anteriores ou iguais à data de saída da mesma unidade.
- **Unidade Distinta:** Ao selecionar unidade diferente, a restrição temporal específica da unidade anterior não se aplica.
- **Evento de Auditoria de Correção:** Eventos de retificação de data são documentados via `UNIT_LINK_ENTRY_DATE_CORRECTED` preservando o evento original.

#### G. Histórico Residencial e Administrativo
- **Histórico de Ocupação:** Exibe na Página 360º todos os períodos passados e presentes (bloco, apto, data de entrada e data de saída formatadas).
- **Histórico Administrativo:** Exibe a linha do tempo de ações administrativas executadas por operadores (Inativações, Criação de Vínculos, Correções, Bloqueios e Desbloqueios) com motivos e datas.

#### H. Autenticação e Proteções Sistêmicas (Gate 3C.4)
- **Perfil Inativo:** Não possui acesso às rotas residenciais nem operacionais comuns. No Web App é redirecionado para `/inactive-account`; no Flutter emite `AuthState.inactiveAccount` e navega para `InactiveAccountScreen`.
- **Retorno / Recuperação de Acesso:** Ao receber um novo vínculo aprovado, recupera acesso pleno de forma transparente pelas credenciais e fluxos nativos existentes.
- **Inibição de FCM:** Perfis com status inativo têm persistência e atualização de tokens FCM ignoradas, prevenindo envio inadvertido de notificações.

#### I. Multi-Tenancy e Isolamento RLS
- **Isolamento Mandatório:** `condominio_id` é validado estritamente no backend/RPCs a partir do contexto do operador e das unidades do condomínio, jamais confiado cegamente do payload do cliente.
- **RLS em Reservas e Módulos:** Políticas RLS e rotas de API garantem que apenas moradores com `status_aprovacao = 'aprovado'` e `bloqueado = false` criem reservas ou interajam com áreas comuns.

#### J. Notificações e Desacoplamento (Gate 3B.2)
- **Trigger `tr_fn_perfil_approved`:** Dispara a Edge Function `approval-notify` (WhatsApp/Push) SOMENTE na transição estrita `OLD.status_aprovacao = 'pendente' AND NEW.status_aprovacao = 'aprovado'`.
- **Transições Silenciosas:** Reativações (`bloqueado` → `aprovado`) e novos vínculos de ex-moradores (`inativo` → `aprovado`) são silenciosas, não gerando spam de boas-vindas. Credenciais são obtidas dinamicamente via Supabase Vault.

#### K. Segurança Operacional e Transacionalidade
- **RPCs `SECURITY DEFINER`:** `admin_inativar_morador` e `admin_criar_vinculo_morador` executam com `SET search_path TO 'public'` e checagem estrita de permissões (`system_superadmins` ou perfil com papel de síndico/administrador no condomínio).
- **Atomicidade e Integridade:** Todas as mutações de perfil, vínculo e audit log ocorrem dentro da mesma transação PostgreSQL.

#### L. Dívidas Técnicas Sob Observação
- **Policy Legada de Insert em `unidade_perfil`:** A policy `Permitir inserção de perfil em unidade para o próprio condom` permanece identificada como excessivamente permissiva (`WITH CHECK (true)`). Não foi alterada neste ciclo para mitigar riscos de regressão em fluxos legados e está catalogada no AI-OS para hardening futuro.

#### M. Portal do Morador (Privacidade)
- **Segregação de Auditoria:** O histórico administrativo de auditoria (`perfil_audit_log`) destina-se exclusivamente a síndicos e administradores no painel de gestão. É terminantemente vedada a sua exibição no Portal do Morador ou aplicativo móvel do morador.

---

## 8. Baseline Oficial — Módulo Veículos
### Base Cadastral 360º — Gate 3D

> **STATUS:** `🟢 CONCLUÍDO` · `🟢 HOMOLOGADO` · `🔒 FROZEN` · `🏛️ OFFICIAL BASELINE`  
> **DATA DE CONGELAMENTO:** 25/09/2026  
> **ESCOPO TÉCNICO:** Gate 3D.1 (Fundação Canônica), Gate 3D.2-B (UI Administrativa e Integração 360º), Gate 3D.2-B.1 (Hotfix RLS de Leitura) e Gate 3D.2-B.3 (Hardening de Imutabilidade de Veículo Inativo).

#### A. Arquitetura Canônica de `public.veiculos`
- **Tabela Soberana:** A tabela `public.veiculos` armazena todos os veículos vinculados a residentes e condomínios.
- **Relacionamento Relacional:**
  - `perfil_id UUID REFERENCES public.perfil(id) ON DELETE CASCADE`: Vinculação canônica ao morador titular.
  - `unidade_id UUID REFERENCES public.unidade(id) ON DELETE CASCADE`: Unidade residencial de lotação do veículo.
  - `condominio_id UUID REFERENCES public.condominio(id) ON DELETE CASCADE`: Tenant isolado.
- **Campos Cadastrais:** `placa` (limpa e normalizada sem traço/espaço, em maiúsculas), `marca`, `modelo`, `cor`, `ano`, `vaga_numero` (identificador da vaga de garagem), `status` ('ativo' | 'inativo').
- **Constraint de Unicidade Parcial:** Garantia soberana de placa ativa única por condomínio:
  `CREATE UNIQUE INDEX idx_veiculos_unique_placa_ativa ON public.veiculos(condominio_id, placa) WHERE status = 'ativo';`
  Permite placas duplicadas apenas se os registros anteriores estiverem com `status = 'inativo'`.

#### B. Segurança, RLS e Hotfix Histórico
- **RLS Ativo:** RLS obrigatório habilitado em `public.veiculos`.
- **Policy de Leitura (`veiculos_admin_select`):** Permite leitura para SuperAdmins e operadores (síndicos/administradores) do mesmo condomínio.
- **Resolução do Incidente Hotfix RLS (Gate 3D.2-B.1):** A policy original realizava `JOIN` direto com `auth.users`, resultando em `42501 permission denied for table users` para usuários logados sob a role `authenticated`. A baseline oficial utiliza identificação puramente via JWT claims:
  `EXISTS (SELECT 1 FROM public.system_superadmins sa WHERE sa.email = (auth.jwt() ->> 'email'))`
  *Invariante:* É terminantemente proibido reintroduzir consultas ou JOINs diretos em `auth.users` dentro de policies RLS.
- **Mutações Restritas:** Não há policies permissivas de INSERT/UPDATE/DELETE para clientes. Toda e qualquer mutação administrativa ocorre obrigatoriamente através de RPCs `SECURITY DEFINER` com `SET search_path TO 'public'`.

#### C. RPCs Administrativas Canônicas
Todas as mutações são transacionais, validam credenciais do operador (`system_superadmins` ou papel administrativo em `public.unidade_perfil`) e registram eventos em `public.perfil_audit_log`:
1. `public.admin_cadastrar_veiculo(...)`: Valida dados cadastrais, formata e converte placa para maiúsculas sem traços, assegura unicidade de placa ativa no condomínio e insere registro com `status = 'ativo'`. Registra auditoria `VEHICLE_CREATED`.
2. `public.admin_atualizar_veiculo(...)`: Atualiza dados descritivos (marca, modelo, cor, ano, vaga) de veículo com `status = 'ativo'`. Rejeita formalmente mutações em veículos inativos. Registra auditoria `VEHICLE_UPDATED`.
3. `public.admin_corrigir_placa_veiculo(...)`: Corrige erro material de digitação na placa de veículo ativo. Exige motivo textual obrigatório. Rejeita veículos inativos. Registra auditoria `VEHICLE_PLATE_CORRECTED` contendo snapshots da placa anterior e nova placa.
4. `public.admin_inativar_veiculo(...)`: Encerra o ciclo ativo do veículo (`status = 'inativo'`). Exige motivo. Registra auditoria `VEHICLE_INACTIVATED`.
5. `public.admin_reativar_veiculo(...)`: Restaura o veículo para `status = 'ativo'`. Valida eventual colisão de placa ativa antes da ativação. Exige motivo. Registra auditoria `VEHICLE_REACTIVATED`.

#### D. Regras de Negócio e Ciclo de Vida do Veículo
- **Veículo Ativo:**
  - Permite edição cadastral (`admin_atualizar_veiculo`).
  - Permite retificação de placa por erro material (`admin_corrigir_placa_veiculo`).
  - Permite inativação administrativa (`admin_inativar_veiculo`).
  - UI exibe ações: `[Editar]`, `[Corrigir placa]`, `[Inativar]`.
- **Veículo Inativo (Histórico Imutável — Gate 3D.2-B.3):**
  - Constitui registro histórico imutável encerrado.
  - Proteção em profundidade no banco de dados: RPCs `admin_atualizar_veiculo` e `admin_corrigir_placa_veiculo` disparam exceção (`RAISE EXCEPTION`) se `v_status = 'inativo'`.
  - Única ação permitida: Reativação (`admin_reativar_veiculo`).
  - UI reflete a regra ocultando `Editar` e `Corrigir placa`, disponibilizando unicamente `[Reativar]`.
- **Regra de Correção de Placa vs. Troca de Veículo:**
  - A correção de placa destina-se *estritamente* a conserto de erro de digitação/cadastro.
  - A substituição real de veículo (venda/aquisição de outro carro) exige canonicamente:
    `INATIVAR veículo anterior` + `CADASTRAR novo veículo`.
- **Auditoria de Placa:** A retificação de placa sempre exige justificativa e grava snapshots de placa anterior e nova para integridade forense.

#### E. Integração com Resident 360º e Prevenção de Erros Mascarados
- **Tratamento Explícito de Erros de Leitura:** É princípio canônico que *erros de consulta nunca podem ser mascarados como array vazio*. No componente `page.tsx`, o retorno de PostgREST `veiculosError` é inspecionado e repassado explicitamente ao `Resident360Client`. Em caso de erro na consulta, o painel exibe banner de erro com diagnóstico, mantendo distinção cristalina entre "falha de leitura/permissão" e "nenhum veículo cadastrado" (empty state legítimo).
- **Aba Veículos & Contadores:** Contador reativo no tab `Veículos (N)` exibindo todos os veículos vinculados ao morador. Card visual dedicado com crachá `ATIVO` (verde) ou `INATIVO` (cinza/alerta), dados da unidade/vaga e ações contextuais.
- **Histórico Administrativo Unificado:** Todas as mutações veiculares geram eventos formais em `public.perfil_audit_log` (`VEHICLE_CREATED`, `VEHICLE_UPDATED`, `VEHICLE_PLATE_CORRECTED`, `VEHICLE_INACTIVATED`, `VEHICLE_REACTIVATED`) que são exibidos de forma cronológica e transparente na linha do tempo da visão 360º do morador.

---

## 9. Baseline Oficial — Módulo Pets
### Base Cadastral 360º — Gate 3E

> **STATUS:** `🟢 CONCLUÍDO` · `🟢 HOMOLOGADO` · `🔒 FROZEN` · `🏛️ OFFICIAL BASELINE`  
> **DATA DE CONGELAMENTO:** 25/09/2026  
> **DEPLOY:** `⏸️ PENDENTE DE AUTORIZAÇÃO HUMANA`  
> **ESCOPO TÉCNICO:** Gate 3E.1-A (Auditoria Mínima), Gate 3E.2-A (Fundação Canônica de Banco), Gate 3E.2-B (Integração Administrativa Resident 360º), Gate 3E.2-B.1 (Hotfix Data Civil) e Gate 3E.2-B.2 (Auditoria Forense de Motivos).

#### A. Arquitetura Canônica de `public.pets`
- **Tabela Soberana:** A tabela `public.pets` centraliza todos os animais de estimação vinculados a residentes e condomínios.
- **Relacionamento Relacional:**
  - `condominio_id UUID REFERENCES public.condominio(id) ON DELETE CASCADE`: Tenant isolado.
  - `perfil_id UUID REFERENCES public.perfil(id) ON DELETE CASCADE`: Tutor principal / morador responsável pelo pet.
  - `unidade_id UUID REFERENCES public.unidade(id) ON DELETE RESTRICT`: Unidade residencial de lotação do animal.
- **Campos Cadastrais:** `nome` (obrigatório), `especie` ('cao' | 'gato' | 'outro', padrão 'cao'), `raca`, `sexo` ('macho' | 'femea'), `porte` ('pequeno' | 'medio' | 'grande'), `cor`, `data_nascimento` (PostgreSQL DATE civil), `castrado` (BOOLEAN), `vacinado` (BOOLEAN), `observacao`, `status` ('ativo' | 'inativo', padrão 'ativo').
- **Integridade Relacional (Triggers e Guards):**
  - Trigger `tr_pets_guard`: Assegura antes do INSERT/UPDATE que `unidade_id` pertence rigorosamente ao `condominio_id` informado.

#### B. Segurança, RLS e Multi-Tenancy
- **RLS Habilitado:** `ALTER TABLE public.pets ENABLE ROW LEVEL SECURITY;`.
- **Policy de Leitura (`pets_admin_select`):** Permite leitura para SuperAdmins e operadores (síndicos/administradores) do mesmo condomínio.
- **Isolamento de Token / JWT:** Implementado puramente via JWT claims (`(auth.jwt() ->> 'email')`), sem JOINs ou consultas diretas em `auth.users`, prevenindo o erro `42501 permission denied for table users`.
- **Mutações Restritas:** Zero policies permissivas de INSERT/UPDATE/DELETE para clientes. Todas as mutações ocorrem exclusivamente através de RPCs `SECURITY DEFINER` com `SET search_path TO 'public'`.

#### C. RPCs Administrativas Canônicas
Todas as mutações são transacionais, validam credenciais administrativas do operador e registram eventos auditáveis em `public.perfil_audit_log`:
1. `public.admin_cadastrar_pet(...)`: Valida dados cadastrais, garante que o perfil possui vínculo ativo na unidade informada e insere o registro com `status = 'ativo'`. Registra auditoria `PET_CREATED`.
2. `public.admin_atualizar_pet(...)`: Atualiza os dados descritivos (nome, espécie, raça, sexo, porte, cor, data de nascimento, castrado, vacinado, observação) de um pet com `status = 'ativo'`. Rejeita formalmente mutações em pets inativos. Registra auditoria `PET_UPDATED`.
3. `public.admin_inativar_pet(...)`: Encerra o ciclo ativo do pet (`status = 'inativo'`). Exige motivo textual obrigatório. Registra auditoria `PET_INACTIVATED`.
4. `public.admin_reativar_pet(...)`: Restaura o pet para `status = 'ativo'`, validando previamente se o morador ainda possui vínculo residencial ativo na unidade cadastrada do animal. Exige motivo textual obrigatório. Registra auditoria `PET_REACTIVATED`.
5. `public.admin_transferir_unidade_pet(...)`: Transfere a lotação residencial do pet para outra unidade válida do mesmo morador. Preserva integralmente o identificador primário (`pet_id`). Exige motivo. Registra auditoria `PET_UNIT_CHANGED`.

#### D. Regras de Negócio e Ciclo de Vida do Pet
- **Pet Ativo:**
  - Permite edição cadastral (`admin_atualizar_pet`).
  - Permite transferência de unidade entre moradias ativas do tutor (`admin_transferir_unidade_pet`).
  - Permite inativação administrativa (`admin_inativar_pet`).
  - UI exibe ações contextuais: `[Editar]`, `[Alterar unidade]` (quando há mais de uma unidade ativa), `[Inativar]`.
- **Pet Inativo (Histórico Imutável):**
  - Registro histórico encerrado imutável.
  - Proteção em profundidade no banco de dados: RPCs `admin_atualizar_pet` e `admin_transferir_unidade_pet` disparam exceção (`RAISE EXCEPTION`) se `v_status = 'inativo'`.
  - Única ação permitida: Reativação (`admin_reativar_pet`).
  - UI oculta `Editar`, `Alterar unidade` e `Inativar`, disponibilizando unicamente `[Reativar]`.
- **Regra Temporal e Tratamento de DATE Civil (Gate 3E.2-B.1):**
  - O campo `data_nascimento` é tratado estritamente como DIA CIVIL (`YYYY-MM-DD`).
  - É proibido o uso de `new Date('YYYY-MM-DD')` ou construtores propensos a timezone shift UTC.
  - Implementado parseamento determinístico via string split (`formatDateCivil`), garantindo que `2000-01-01` permaneça `01/01/2000` em qualquer fuso horário cliente.

#### E. Integração com Resident 360º e Prevenção de Erros Mascarados
- **Tratamento Explícito de Erro de Consulta:** Erros de PostgREST na consulta de pets (`petsError`) nunca são mascarados como array vazio. O estado de falha de conexão/permissão é propagado e renderizado com banner de erro dedicado, mantendo distinção absoluta em relação ao estado legítimo de lista vazia ("Nenhum pet cadastrado").
- **Aba Pets & Contadores:** Contador no tab `Pets (N)` reflete a totalidade do histórico (ativos + inativos). Card visual dedicado com crachá `ATIVO` (verde) ou `INATIVO` (cinza/alerta), dados zootécnicos e ações operacionais com modais contextuais.
- **Histórico Administrativo Unificado:** Todas as mutações do pet gravam eventos canônicos em `public.perfil_audit_log` (`PET_CREATED`, `PET_UPDATED`, `PET_INACTIVATED`, `PET_REACTIVATED`, `PET_UNIT_CHANGED`), renderizados na linha do tempo com ícones, motivos textuais e badges informativas sem exposição de JSON bruto.

#### F. Escopo Deliberadamente Excluído do Gate 3E
- **Fotos / Supabase Storage:** Zero implementação de upload de fotos, storage bucket, carteira de vacinação ou microchip neste ciclo.
- **Módulo Flutter / Mobile:** Zero implementação funcional no app móvel neste ciclo.
- **Módulo Portaria:** Zero implementação de consultas operacionais na portaria neste ciclo.

---

## 10. Baseline Oficial — Fotos de Pets e Veículos
### Base Cadastral 360º — Gate 3F

> **STATUS:** `🟢 CONCLUÍDO` · `🟢 HOMOLOGADO` · `🔒 FROZEN` · `🏛️ OFFICIAL BASELINE`  
> **DATA DE CONGELAMENTO:** 26/09/2026  
> **DEPLOY:** `⏸️ NÃO EXECUTADO MANUALMENTE NO FECHAMENTO (PENDENTE DE AUTORIZAÇÃO HUMANA / NÃO DECLARADO EM PRODUÇÃO)`  
> **ESCOPO TÉCNICO:** Gate 3F.1 (Auditoria e Desenho), Gate 3F.2-A (Fundação Canônica de Banco e Storage), Gate 3F.2-B (Integração Resident 360º, Client e Modais) e Gate 3F.2-C (Auditoria e Fechamento Oficial).

#### A. Arquitetura Canônica de Mídia (Banco e Storage)
- **Colunas Canônicas:**
  - `public.pets.foto_path TEXT NULL`: Armazena o path relativo canônico no storage (`{condominio_id}/pets/{pet_id}/{timestamp}_{uuid}.jpg`).
  - `public.veiculos.foto_path TEXT NULL`: Armazena o path relativo canônico no storage (`{condominio_id}/veiculos/{veiculo_id}/{timestamp}_{uuid}.jpg`).
- **Bucket Privado (`base-cadastral-media`):**
  - Bucket estritamente privado (`public = false`).
  - Limite de arquivo: `5242880` bytes (5 MB).
  - Tipos MIME aceitos: `image/jpeg`, `image/png`, `image/webp`.
- **Signed URLs Temporárias:**
  - URLs temporárias e efêmeras (TTL de 3600s / 1 hora) geradas sob demanda no servidor (`Resident360Page`).
  - Invariante de Segurança: Signed URLs *nunca são persistidas no banco de dados*. O banco armazena exclusivamente o `foto_path` relativo canônico.
  - Geração em batch no carregamento do Resident 360º (`createSignedUrls`) para mitigar roundtrips e latência.

#### B. Segurança, Storage RLS e Multi-Tenancy
- **Isolamento Multi-Tenant:**
  - Validação estrita do `condominio_id` como primeiro segmento do path do arquivo (`split_part(name, '/', 1)`).
  - Políticas de Storage em `storage.objects`:
    - `base_cadastral_media_select`: Permite leitura apenas para operadores do mesmo condomínio (`admin`, `síndico`, `subsíndico`, `administradora`) ou `system_superadmins`.
    - `base_cadastral_media_insert`: Permite gravação validando a hierarquia estrita (`pets`/`veiculos`) e tenant do operador.
    - `base_cadastral_media_delete`: Permite remoção restrita ao condomínio do operador ou SuperAdmin.
- **Desacoplamento de `auth.users`:**
  - Políticas utilizam `auth.jwt() ->> 'email'` para checagem de SuperAdmin e `auth.uid()` para validação em `public.perfil`, sem JOINs ou consultas diretas em `auth.users`.
- **Zero Abertura Genérica:**
  - Nenhuma permissão irrestrita aberta para `authenticated`.

#### C. RPCs Administrativas e Imutabilidade de Inativos
- **RPCs Canônicas Transacionais (`SECURITY DEFINER` com `SET search_path TO 'public'`):**
  - `public.admin_salvar_foto_pet(p_pet_id UUID, p_foto_path TEXT)`
  - `public.admin_remover_foto_pet(p_pet_id UUID, p_motivo TEXT DEFAULT NULL)`
  - `public.admin_salvar_foto_veiculo(p_veiculo_id UUID, p_foto_path TEXT)`
  - `public.admin_remover_foto_veiculo(p_veiculo_id UUID, p_motivo TEXT DEFAULT NULL)`
- **Validação Sintática de Path:** Exige rigorosamente 4 segmentos (`{condominio_id}/{entity}/{entity_id}/{filename}`) e extensões aceitas (`.(jpe?g|png|webp)$`).
- **Proteção e Imutabilidade de Inativos:**
  - Se `status != 'ativo'`, as RPCs rejeitam a operação com `RAISE EXCEPTION`.
  - A foto existente é preservada para fins de histórico e memória cadastral da entidade inativa.
- **Substituição e Remoção Seguras:**
  - Fluxo de substituição e remoção com rollback em caso de falha e desvinculação em banco com auditoria completa.

#### D. Frontend e Experiência do Operador (Resident 360º)
- **Modais e Componentes (`photo-modal.tsx`):**
  - `PhotoUploadModal`: Permite upload com drag & drop, pré-visualização, e compressão/redimensionamento client-side via HTML Canvas (max 1200px, 85% de qualidade JPEG).
  - `PhotoRemoveModal`: Confirmação segura de remoção de foto com justificativa opcional.
  - `PhotoViewerModal`: Lightbox para visualização de imagem em tamanho ampliado.
- **UI Integrada:**
  - Thumbnails responsivos em cards de Pets e Veículos, botão de câmera/upload, menu de ações contextuais (visualizar, substituir, remover).
- **Histórico e Auditoria Administrativa Unificada:**
  - Integração dos eventos no `perfil_audit_log`: `PET_PHOTO_UPDATED`, `PET_PHOTO_REMOVED`, `VEHICLE_PHOTO_UPDATED`, `VEHICLE_PHOTO_REMOVED`, com badges, ícones e detalhes renderizados na linha do tempo da visão 360º.

#### E. Homologação Humana e Estado Final Auditado
- **Testes de Homologação Realizados:**
  - Upload e exibição de foto para o Pet `Toy` (`eae01465-8320-4525-a0cf-2898cbb3e085`).
  - Upload e exibição de foto para o Veículo `AAA1235` (`8b4bf78f-4e04-430b-a59c-e0e45a290494`).
  - Visualização em lightbox e renderização adequada das ações de mídia na UI.
- **Auditoria de Eventos de Histórico:**
  - `PET_PHOTO_UPDATED`: Confirmado (`1` evento no log).
  - `VEHICLE_PHOTO_UPDATED`: Confirmado (`1` evento no log).
  - `PET_PHOTO_REMOVED`: Funcionalidade implementada em RPC e UI; `0` eventos encontrados na auditoria final desta homologação (nenhuma remoção executada no fechamento).
  - `VEHICLE_PHOTO_REMOVED`: Funcionalidade implementada em RPC e UI; `0` eventos encontrados na auditoria final desta homologação (nenhuma remoção executada no fechamento).
- **Estado do Storage e Banco no Fechamento:**
  - Pet Toy com foto válida e objeto existente no bucket.
  - Veículo AAA1235 com foto válida e objeto existente no bucket.
  - Bucket `base-cadastral-media`: 2 objetos físicos / 2 referenciados no banco / 0 órfãos.

#### F. Escopo Deliberadamente Excluído do Gate 3F
- **Módulo Flutter / Mobile:** Zero implementação funcional no app móvel neste ciclo.
- **Módulo Portaria:** Zero implementação de consultas ou exibição de fotos de pets/veículos na portaria neste ciclo.
- **Deploy em Produção:** Fechamento realizado sem deploy manual.

---

## TRACEABILITY

| Bloco do Loader Operacional | Fonte Primária no AI-OS | Origem no Monólito / Gate 5.1 |
|---|---|---|
| **Identificação do AI-OS** | [`ai-os/README.md`](../ai-os/README.md) | Gate 5.1 (Seção 3 e 4) |
| **Invariante 1 (Banco Único)** | [`database-rules.md`](../ai-os/governance/database-rules.md), [`ADR-001`](../ai-os/decisions/ADR-001-banco-producao-oficial-unico.md) | `.agents/AGENTS.md:L2070-L2190` |
| **Invariante 2 (RLS Multi-Tenant)** | [`rls-multitenancy.md`](../ai-os/governance/rls-multitenancy.md), [`ADR-003`](../ai-os/decisions/ADR-003-isolamento-multi-tenant-rls.md) | `.agents/AGENTS.md:L1182-L1237` |
| **Invariante 3 (SuperAdmin)** | [`security-access.md`](../ai-os/governance/security-access.md), [`ADR-002`](../ai-os/decisions/ADR-002-centralizacao-superadmins.md) | `.agents/AGENTS.md:L73-L84` |
| **Invariante 4 (WhatsApp Anti-Marketing)** | [`messaging-rules.md`](../ai-os/governance/messaging-rules.md), [`ADR-007`](../ai-os/decisions/ADR-007-segregacao-canais-push-whatsapp.md) | `.agents/AGENTS.md:L1-L18`, `L1042-L1062` |
| **Invariante 5 (Git Soberano)** | [`sql-migration-8-steps.md`](../ai-os/runbooks/sql-migration-8-steps.md), [`ADR-009`](../ai-os/decisions/ADR-009-governanca-migrations-git-soberano.md) | `.agents/AGENTS.md:L369-L408` |
| **Protocolo de Consulta** | Gate 5.1 (Seções 6 e 7) | Gate 5.1 |
| **Mapa de Roteamento** | `ai-os/governance/*`, `decisions/*`, `runbooks/*` | Matriz de Cobertura Gate 4.4.4 |
| **Diretrizes de Navegação** | Gate 5.1 (Seções 5, 8, 9, 10) | Gate 5.1 |
| **Fallback e Parada** | Gate 5.1 (Seções 11 e 12) | Gate 5.1 |
| **AI Advisor (Segundo Cérebro)** | [`advisor-consultation-policy.md`](../ai-os/governance/advisor-consultation-policy.md), [`ADR-016`](../ai-os/decisions/ADR-016-orquestracao-cognitiva-chatgpt-advisor.md), [`advisor-consultation-runbook.md`](../ai-os/runbooks/advisor-consultation-runbook.md) | Gate 7.1.3 e Gate 7.1.4 |
