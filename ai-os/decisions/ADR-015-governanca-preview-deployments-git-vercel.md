# ADR-015 — Governança de Preview Deployments e Integração Git-Vercel

## Status
Proposed

## Date
2026-09-15

## 1. Contexto
O ecossistema Condomeet utiliza a Vercel para hospedagem e entrega contínua do frontend web (`web-app/`). A integração nativa com o GitHub aciona automaticamente compilações de Preview Deployments ao abrir ou atualizar Pull Requests (incluindo Draft PRs). A introdução de regimes automatizados de engenharia (`CONTROLLED_MUTATION`) gera branches padronizadas (`ai-task/*`) e Pull Requests formais para revisão humana, provocando execuções de build e instâncias efêmeras na infraestrutura da Vercel.

## 2. Problema
Historicamente, o AI-OS tratava o ciclo de implantação sob uma premissa simplificada de que apenas deploys manuais ou merges na branch principal geravam deploy. Isso gerava três lacunas:
1. Falta de distinção entre mutações locais comitadas e efeitos colaterais automáticos de nuvem;
2. Risco de desenvolvedores e agentes confundirem a proteção de acesso de tela (SSO) com isolamento físico de banco de dados;
3. Consumo desnecessário de quotas de build da Vercel ao compilar tarefas puramente documentais (`docs/**`).

## 3. Fatos Arquiteturais Auditados
- Projeto Vercel: `condomeet` (`prj_D7mxhbCRW6SHdMbxtwdDvip2YBJu`), Root Directory: `web-app`.
- Team Vercel: `condomeets-projects` (`team_sreFJ7SdY2O86JG0yIII1bpW`).
- Branch de Produção: `main` (conforme configuração administrativa auditada).
- Deployment Protection: Ativo via `ssoProtection` (`all_except_custom_domains`). Previews não são públicos (requisições anônimas recebem HTTP 302 redirecionando para `https://vercel.com/sso-api`).
- Supabase em Preview e Production: Ambos utilizam atualmente as variáveis `NEXT_PUBLIC_SUPABASE_URL` e `NEXT_PUBLIC_SUPABASE_ANON_KEY` apontando para o projeto oficial `avypyaxthvgaybplnwxu` (`condomeet_Antigravity`).
- Credenciais na Vercel: Restritas a chaves públicas de cliente (`anon_key`). Ausência de credenciais administrativas ou `service_role`.
- Ignored Build Step: Não configurado (`commandForIgnoringBuildStep: null`).

## 4. Decisão Normativa Permanente (Normative Rules)
1. **Definição e Escopo de Preview:**
   - Ambientes de Preview são ambientes efêmeros destinados à validação/homologação não produtiva, sujeitos às restrições específicas de acesso a dados e serviços externos definidas neste ADR.
   - Sob nenhuma hipótese um Preview Deployment promove código para produção ou assume domínios oficiais.
2. **Separação Conceitual: SSO ≠ Isolamento de Banco:**
   - O Deployment Protection restringe quem acessa a interface web, mas NÃO isola o banco de dados.
   - É proibido classificar o Preview como "sandbox de dados" ou "ambiente isolado do banco".
3. **Proibição Absoluta de Chaves Administrativas no Preview:**
   - É terminantemente proibido configurar `SUPABASE_SERVICE_ROLE_KEY` ou qualquer segredo administrativo de backend no escopo Preview da Vercel.
4. **Proteção Obrigatória contra Acesso Público:**
   - O mecanismo de `ssoProtection` deve permanecer permanentemente ativo para evitar exposição pública de telas em desenvolvimento.
5. **Governança de Mutação vs. Efeito Externo:**
   - Tarefas de `CONTROLLED_MUTATION` que gerem branches/PRs devem declarar no Result Contract o evento colateral de infraestrutura (`AUTOMATED_EXTERNAL_EFFECT`).

## 5. Preview vs. Production
| Dimensão | Preview Deployment | Production Deployment |
|---|---|---|
| **Gatilho** | Abertura/Atualização de PR (inclusive Draft) | Push/Merge na branch `main` |
| **Vinculação** | Branch do PR (efêmera) | Branch `main` conforme configuração administrativa auditada |
| **Domínio / URL** | Efêmero (`condomeet-git-*-condomeets-projects.vercel.app`) | Oficial (`condomeet.app.br`, `www.condomeet.app.br`, `home.condomeet.app.br`) |
| **Acesso Externo** | Restrito via Vercel SSO (HTTP 302 para anônimos) | Público via CDN conforme configuração administrativa auditada |
| **Destino Supabase** | Aponta atualmente para `avypyaxthvgaybplnwxu` | Aponta para `avypyaxthvgaybplnwxu` |
| **Credenciais** | Chaves públicas de cliente (`anon_key`) | Chaves públicas de cliente (`anon_key`) |

## 6. Integração GitHub → Vercel
A integração é reativa ao ciclo de vida de Pull Requests do GitHub através do GitHub App oficial da Vercel. O dispatch é assíncrono e automático a partir do envio de commits para branches com PR aberto.

## 7. Deployment Protection
O `ssoProtection` com `deploymentType: "all_except_custom_domains"` assegura que apenas usuários autenticados no time `condomeets-projects` possam acessar o Preview. Requisições anônimas recebem HTTP 302 e cabeçalho `x-robots-tag: noindex`.

## 8. Supabase & Governança de Dados
Como não há projeto Supabase separado de homologação no estado atual:
- Quando o runtime do Preview executar operações que utilizem as variáveis ou clientes Supabase configurados, essas operações terão como destino o projeto oficial de produção `avypyaxthvgaybplnwxu`.
- A contenção de privilégios repousa sobre o **Row Level Security (RLS)** mandatório (Invariante Global 2) e sobre a ausência de chaves `service_role`.

## 9. Environment Variables
As variáveis do escopo Preview devem espelhar estritamente as variáveis públicas necessárias para o cliente web (`NEXT_PUBLIC_*`). Nenhuma credencial com privilégios de escrita administrativa ou segredos de mensageria pode ser adicionada ao escopo Preview.

## 10. Diretrizes para Testes Funcionais
Como o Preview conecta ao banco de produção quando invocado:
- Não utilizar dados fictícios concorrentes no Preview;
- Não executar testes destrutivos de dados;
- Não realizar INSERT/UPDATE/DELETE arbitrários apenas para testes de tela;
- Não executar fluxos financeiros reais;
- Não disparar mensagens de WhatsApp;
- Não executar operações administrativas sensíveis;
- Não executar migrations a partir do Preview;
- Qualquer homologação funcional que possa alterar dados reais exige procedimento específico e autorização humana prévia.

## 11. URLs de Preview
As URLs geradas pela Vercel seguem padrão determinístico baseado na branch e no time (`https://condomeet-git-<branch>-condomeets-projects.vercel.app`). Elas são recicladas a cada novo deploy da branch.

## 12. Regime CONTROLLED_MUTATION
No âmbito do AI-OS, as tarefas de mutação operam com clara fronteira:
- A mutação autorizada encerra-se no commit e push da branch pelo executor;
- O deployment de Preview é um efeito colateral de integração.

## 13. Automated External Effects
Efeitos automáticos acionados pela infraestrutura de nuvem decorrentes de operações Git devem ser rotulados como `AUTOMATED_EXTERNAL_EFFECT` no Result Contract, registrando o estado do deployment sem tratar o evento como erro do agente.

## 14. Production Deployment
Production está vinculada à branch `main` conforme configuração administrativa auditada. A promoção de código para o ambiente oficial de produção requer conformidade estrita com o Runbook de Validação Pré-Deploy e autorização humana expressa.

## 15. Ignored Build Step
No estado atual, o Ignored Build Step não está configurado (`commandForIgnoringBuildStep: null`). Qualquer futura implementação deve passar por homologação formal para prevenir falsos negativos em PRs com múltiplos commits. Scripts simplistas como `git diff --quiet HEAD^ HEAD ./web-app` são rejeitados.

## 16. Auditoria e Rastreabilidade
Cada Preview Deployment possui Deployment ID auditável na Vercel (ex: `dpl_*`), rastreável ao commit SHA e ao PR correspondente no GitHub.

## 17. Segurança
A proteção do ecossistema assenta-se na combinação de:
1. Autenticação SSO na borda da Vercel (bloqueio de acesso externo anônimo);
2. Políticas RLS ativas em 100% das tabelas do schema público do Supabase;
3. Ausência de credenciais administrativas no frontend.

## 18. Limitações Conhecidas
- Consumo de tempo de compilação na Vercel para qualquer PR enviado enquanto o Ignored Build Step não estiver homologado;
- Ausência de banco de dados fisicamente segregado para testes de integração de ponta a ponta.

## 19. Consequências Arquiteturais
- **Positivas:** Fim da ambiguidade entre Preview e Produção; clareza conceitual de que SSO não é isolamento de banco; disciplina nos testes funcionais.
- **Trade-offs:** Exige monitoramento administrativo de quotas da Vercel e rigor operacional ao manipular telas de Preview.

## 20. Itens que Exigem Revisão Administrativa Periódica
- Auditoria periódica de variáveis de ambiente no painel da Vercel;
- Monitoramento de minutos consumidos por compilações;
- Manutenção da proteção de acesso SSO.

## 21. Estado Operacional Vigente (Current State)
- Banco Supabase oficial: `avypyaxthvgaybplnwxu`.
- Vercel Team: `condomeets-projects` | Projeto: `condomeet`.
- Ignored Build Step: Não configurado (`null`).
- Preview Deployment Protection: Ativo (`all_except_custom_domains`).

## 22. Evoluções Futuras (Roadmap Técnico)
- `FUTURE / REQUIRES_HOMOLOGATION`: Homologação de script seguro de Ignored Build Step (baseado em `origin/main...HEAD`) para poupar builds em deltas fora de `web-app/`.
- `FUTURE / REQUIRES_HOMOLOGATION`: Avaliação arquitetural de banco Supabase dedicado de staging/homologação.
