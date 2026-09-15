# 📘 Runbook — Checklist e Protocolo de Validação Pré-Deploy
## Critérios de Qualidade, Governança de Ambiente, Testes e Gates de Produção

> **Camada do AI-OS:** Runbooks Operacionais (`ai-os/runbooks/`)
> **Status:** `OPERACIONAL / CONGELADO`
> **Regime de Execução:** Mandatório antes de qualquer promoção ou deploy para o ambiente de Produção

---

## 1. Objetivo

Padronizar as validações obrigatórias de integridade técnica, compatibilidade de ambiente, compilação de código, suítes de teste e governança de dados antes da liberação de deploys no ecossistema Condomeet, prevenindo split-brain de banco de dados, regressões funcionais e interrupções em serviços críticos.

---

## 2. Gate 1 — Governança Canônica de Ambiente e Banco de Dados (Hard Gate)

Antes de qualquer deploy ou alteração de variáveis de ambiente:

### 2.1. Validação de Variáveis de Ambiente da Vercel (Web)
Qualquer alteração em `Production` na Vercel que modifique variáveis de conexão do Supabase deve obrigatoriamente validar:
- [ ] `NEXT_PUBLIC_SUPABASE_URL` aponta exclusivamente para:
  ```text
  https://avypyaxthvgaybplnwxu.supabase.co
  ```
- [ ] `NEXT_PUBLIC_SUPABASE_ANON_KEY` pertence exclusivamente ao Project Ref `avypyaxthvgaybplnwxu`.
- [ ] **Proibição Absoluta do Banco Legado:** Confirmar que em nenhuma hipótese o Project Ref `ivdgvpvifhfiktolmbvy` (`condomeetBD`) está configurado no ambiente de produção da Vercel ou nos builds mobile.

### 2.2. Hard Gate Pré-Alteração no Banco de Dados
Caso o deploy envolva migrações ou alterações de banco:
1. Identificar formalmente o Supabase Project Ref;
2. Confirmar que o Project Ref é `avypyaxthvgaybplnwxu`;
3. Confirmar que o nome do projeto é `condomeet_Antigravity`;
4. Confirmar que o ambiente é `Production`;
5. **Critério de Abort:** Se o Project Ref divergir do banco oficial:
   **PARAR A EXECUÇÃO IMEDIATAMENTE. NÃO REALIZAR DEPLOY NEM ALTERAÇÕES.**

### 2.3. Gate 1.1 — Governança de Preview Deployments e Pull Requests (Vercel)

Sempre que um Pull Request for aberto ou atualizado no repositório:

- [ ] **Identificação de Gatilho:** Verificar se o evento Git gerou um Preview Deployment na Vercel.
- [ ] **Verificação de Status do Preview:** Confirmar se o build foi concluído com sucesso (`READY` / `STAGED`).
- [ ] **Diferenciação Estrita de Ambientes:** Confirmar que a URL gerada é efêmera (`*.vercel.app`) e que nenhum domínio ou alias oficial de produção (`condomeet.app.br`, `www.condomeet.app.br`, `home.condomeet.app.br`) foi afetado.
- [ ] **Verificação de Deployment Protection:** Confirmar que o Preview responde com HTTP 302 para requisições não autenticadas, assegurando que o `ssoProtection` está ativo conforme configuração administrativa auditada.
- [ ] **Escopo de Código:** Identificar se o PR altera arquivos sob `web-app/` ou apenas diretórios externos (`docs/`, `ai-os/`, `supabase/`).
- [ ] **Registro de Preview URL:** Registrar a URL gerada no relatório de auditoria quando relevante para validação não produtiva.
- [ ] **Consciência de Banco Compartilhado:**
  - [ ] Reconhecer que, quando o runtime executar operações que utilizem os clientes configurados, essas operações terão como destino o banco de produção (`avypyaxthvgaybplnwxu`).
  - [ ] **NÃO** tratar o Preview como sandbox ou ambiente isolado de banco de dados (`SSO ≠ database isolation`).
  - [ ] **NÃO** executar testes destrutivos de dados no Preview.
  - [ ] **NÃO** cadastrar dados fictícios concorrentes no Preview.
  - [ ] **NÃO** realizar operações financeiras ou fluxos reais de moradores no Preview.
  - [ ] **NÃO** utilizar credenciais de `service_role` no Preview.
  - [ ] **NÃO** disparar notificações de WhatsApp a partir do Preview.
  - [ ] **NÃO** executar migrations a partir do Preview.
- [ ] **Registro de Efeito Externo:** Documentar no Result Contract o campo `automated_external_effects` correspondente ao Preview Deployment gerado.
- [ ] **Critério de Abort:** Se o Preview Deployment receber qualquer alias de produção ou desativar o SSO de proteção:
  **INTERROMPER O FLUXO IMEDIATAMENTE E NOTIFICAR A ADMINISTRAÇÃO.**

---

## 3. Gate 2 — Governança de Migrations e Catálogo Git

Se o ciclo incluir modificações no banco de dados (DDL, triggers, RLS ou funções SQL):
- [ ] **Git como Fonte Soberana:** A alteração deve estar formalmente commitada em arquivo de migration no repositório (`supabase/migrations/`).
- [ ] **Auditoria de Drift via `pg_proc`:** Realizar comparação prévia entre a definição instalada no banco (`pg_proc`) e as migrations do repositório Git, confirmando consistência prévia.
- [ ] **Ausência de Concorrência:** Garantir a inexistência de migrations concorrentes redefinindo os mesmos objetos sem prévia consolidação.
- [ ] **Menor Delta Funcional:** Confirmar que a migration corretiva representa estritamente o menor delta funcional necessário para atender ao requisito.

---

## 4. Gate 3 — Qualidade de Código, Typecheck, Build e Testes Automatizados

Todas as camadas da aplicação impactadas pelo ciclo devem atender aos seguintes critérios de aceite técnicos:

### 4.1. Supabase Edge Functions (Backend Deno)
- [ ] Executar a suíte de testes automatizados com Deno:
  ```bash
  deno test
  ```
- [ ] Critério: 100% dos cenários de teste aprovados sem falhas.

### 4.2. Frontend Mobile (Flutter)
- [ ] Executar a análise estática:
  ```bash
  flutter analyze
  ```
  Critério: `0 issues` encontrados.
- [ ] Executar a suíte de testes unitários/widget:
  ```bash
  flutter test
  ```
  Critério: 100% dos testes aprovados.

### 4.3. Frontend Web (Next.js)
- [ ] Executar checagem estática de tipos TypeScript:
  ```bash
  npx tsc --noEmit
  ```
  Critério: `0 erros` de tipagem.
- [ ] Executar verificação de linter (ESLint):
  ```bash
  npm run lint
  ```
  Critério: `0 erros` e `0 warnings`.
- [ ] Executar compilação de produção:
  ```bash
  npm run build
  ```
  Critério: Build concluído com sucesso e 100% das rotas estáticas/dinâmicas compiladas.

---

## 5. Gate 4 — Checklist Obrigatório de Não-Regressão (6 Fluxos Vitais)

Antes da homologação final e promoção para produção, validar a integridade dos 6 fluxos vitais do ecossistema:

- [ ] `VISITOR_INVITE` (Convites e acessos de visitantes)
- [ ] `VISITOR_AUTHORIZED` (Liberações e controle de portaria)
- [ ] `PARCEL` (Notificações e recebimento de encomendas)
- [ ] `SOS` (Alertas de emergência e pânico)
- [ ] `RESERVAS` (Agendamentos e confirmações de áreas comuns)
- [ ] `AVISOS` (Comunicados operacionais do condomínio)

---

## 6. Gate 5 — Requisitos Formais para Promoção a Produção

A aprovação no ambiente de desenvolvimento/homologação **NÃO autoriza e NÃO constitui deploy automático em produção**.

A liberação definitiva para deploy em produção exige o cumprimento formal dos 7 requisitos:
1. **Revisão Estática:** Revisão detalhada da migration, scripts de implantação e diffs de código.
2. **Análise de Impacto:** Avaliação do impacto operacional no condomínio e nos moradores.
3. **Compatibilidade Reversa:** Verificação da compatibilidade de contratos das Edge Functions e do banco de dados com clientes Web e Mobile ativos.
4. **Estratégia de Observabilidade:** Validação de logs estruturados, monitoramento de exceptions e métricas de erro.
5. **Plano de Rollback:** Plano detalhado, documentado e testado para reversão em caso de anomalia.
6. **Janela Operacional:** Definição da janela de manutenção e ordem estrita de deploy de artefatos.
7. **Autorização Formal:** Autorização explícita e formal do responsável pelo projeto.

---

## 7. Critérios de Bloqueio (STATUS = BLOCKED)

O deploy para produção está sumariamente **BLOQUEADO** se:
- `NEXT_PUBLIC_SUPABASE_URL` ou `NEXT_PUBLIC_SUPABASE_ANON_KEY` apontarem para o banco legado `ivdgvpvifhfiktolmbvy`;
- Houver falha de typecheck (`tsc --noEmit`), lint ou build em qualquer aplicação;
- Qualquer teste unitário ou de integração falhar;
- For constatada divergência não investigada entre o repositório Git e `pg_proc`;
- Qualquer um dos 6 fluxos vitais apresentar regressão;
- Inexistir plano de rollback documentado;
- Inexistir autorização humana expressa do responsável.

---

## TRACEABILITY

- **Fonte Primária:** [`.agents/AGENTS.md`](../../.agents/AGENTS.md)
- **Seções de Origem:**
  - `🚫 Banco Legado` (`.agents/AGENTS.md:L2090-L2112`)
  - `🔐 Regra de Produção` (`.agents/AGENTS.md:L2114-L2134`)
  - `🔎 Validação Obrigatória Antes de Alterações de Produção` (`.agents/AGENTS.md:L2136-L2156`)
  - `Checklist Obrigatório de Não-Regressão` (`.agents/AGENTS.md:L394-L401`)
  - `Próximo Gate Formal de Governança` (`.agents/AGENTS.md:L1950-L1970`)
  - `Resultados Oficiais da Homologação (FASE 5)` (`.agents/AGENTS.md:L2444-L2446`)
  - `Diretrizes de Infraestrutura e DDL Crítico` (`.agents/AGENTS.md:L373-L381`)
- **Arquivos AI-OS Complementares Utilizados:**
  - [`ai-os/governance/database-rules.md`](../governance/database-rules.md) (Seções 1 e 2)
  - [`ai-os/context/environments.md`](../context/environments.md) (Seções 1, 2 e 3)
  - [`ai-os/decisions/ADR-001-banco-producao-oficial-unico.md`](../decisions/ADR-001-banco-producao-oficial-unico.md)
  - [`ai-os/decisions/ADR-009-governanca-migrations-git-soberano.md`](../decisions/ADR-009-governanca-migrations-git-soberano.md)
  - [`ai-os/CURRENT_STATE.md`](../CURRENT_STATE.md) (Seção 1)
  - [`ai-os/decisions/ADR-015-governanca-preview-deployments-git-vercel.md`](../decisions/ADR-015-governanca-preview-deployments-git-vercel.md)
- **Eventuais Lacunas / Pontos HUMAN REVIEW REQUIRED:**
  - Configuração específica de pipeline CI/CD automatizado via GitHub Actions para bloqueio de merge em branch principal: `NOT SPECIFIED IN SOURCE / HUMAN REVIEW REQUIRED` (controles descritos no monólito são operacionais e manuais).
