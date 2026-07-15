# Diretrizes e Regras do Projeto — Condomeet

## Política Oficial de Classificação de Mensagens

O Condomeet não realiza comunicações promocionais, campanhas comerciais, cross-sell, upsell, publicidade ou qualquer forma de marketing via WhatsApp.

Todas as mensagens emitidas pelo ecossistema Condomeet possuem caráter exclusivamente operacional, transacional, administrativo ou de segurança, decorrentes da prestação do serviço condominial e de solicitações realizadas pelo próprio morador, síndico, administração ou condomínio.

### Diretrizes de Categoria de Templates (Meta Cloud API):

1. **Utility (Utilidade):** Categoria padrão e obrigatória para todas as mensagens operacionais (encomendas, visitantes, reservas, documentos, ocorrências, boletos, assembleias e alertas).
2. **Authentication (Autenticação):** Utilizada exclusivamente para OTP, login, recuperação de senha e validação de identidade.
3. **Marketing:** Proibido no ecossistema Condomeet. Nenhum template deve ser submetido ou mantido nessa categoria.

Sempre que um novo template for criado, ele deverá ser inicialmente projetado e submetido como Utility, exceto se for explicitamente autenticação. Caso a Meta classifique como Marketing, o texto deve ser revisado e reenquadrado para Utility.

---

## 🚦 Baseline Operacional e Piloto Real Park (Fase 1)

O projeto encontra-se sob **Ordem de Operação Assistida** do piloto **Real Park** (ID `ed90ec35-95f0-4a04-92b4-35fe4217f0e1`) no estágio **`encomendas`** a partir de 12/07/2026.

### Diretrizes e Restrições de Desenvolvimento (Congelamento):
1. **Congelamento da Arquitetura do WhatsApp:** É proibido realizar novos deploies estruturais, alterações de banco, modificações de webhooks, workers, failover ou lógica de janela de 24h relacionadas ao WhatsApp durante este período de observação assistida de 7 dias (salvo correções críticas de produção autorizadas).
2. **Escopo Restrito do Piloto:** Apenas o condomínio Real Park e o módulo de encomendas estão autorizados a transitar pela Meta Cloud API. Demais condomínios e módulos permanecem canalizados pelo BotConversa.
3. **Mapeamento de Avanço:** O avanço para a Fase 2 (Visitantes) só será autorizado após a manutenção contínua e sem falhas dos KPIs de qualidade: Delivery Rate > 98%, Failovers = 0, Latência média < 3s, e 0 Reclamações operacionais.

---

## 📌 Dívidas Técnicas Registradas (WhatsApp)

1. **Substituição da lógica de roteamento textual por metadados / message_type:**
   - **Descrição:** Substituir a validação atual por texto (`textBody.includes("Chegou uma encomenda")`) na tomada de decisão de envio do piloto Real Park.
   - **Solução Futura:** Utilizar lógica baseada em `condominio_id` e `message_type` operacional (e/ou payload de metadados estruturado).
   - **Objetivo:** Permitir que mensagens de texto, imagens e outros anexos do módulo de encomendas do piloto Real Park sejam roteadas de forma consistente pela `META_CLOUD_API` (API Oficial).

2. **Implementação de Jitter (Tempo de Envio Aleatório):**
   - **Descrição:** Substituir os intervalos de espera estáticos (`COOLDOWN_TEXT_MS = 15000` e `COOLDOWN_FILE_MS = 25000`) por um atraso aleatório oscilando entre 20 e 40 segundos no envio de mensagens.
   - **Solução Futura:** Utilizar um gerador de atraso dinâmico no loop do worker (ex: `Math.floor(Math.random() * (40000 - 20000 + 1) + 20000)`).
   - **Objetivo:** Dificultar a detecção de padrões repetitivos automatizados pelos algoritmos anti-spam da Meta, reduzindo o risco de bloqueios e banimentos do número de disparo.


---

## 📊 Baseline Oficial — Dashboard de Consumo Meta (Fase de Homologação Concluída)

O Dashboard de Consumo por Condomínio da API Oficial Meta encontra-se homologado e implantado.

### Premissas Consolidadas de Operação e Segurança:
1. **Atribuição Obrigatória de Custos:** Todos os custos de mensagens e conversas Meta são atribuídos obrigatoriamente a um `condominio_id` válido. Não devem ser permitidos registros de envios órfãos sem condomínio.
2. **Aderência Financeira Total:** A soma consolidada de consumo de todos os condomínios na view/RPC deve possuir aderência de 100% com o faturamento consolidado emitido pela fatura da Meta Cloud API no período.
3. **Isolamento de Performance (Analytics Read-Only):** O módulo de dashboard opera exclusivamente sobre Views e RPCs read-only (`whatsapp_metrics_by_condo_view` e `get_whatsapp_consumption_by_condo`). É expressamente proibida qualquer concorrência, travamento ou escrita que impacte workers de envio, filas de processamento de mensagens ou webhooks transacionais da Meta.
4. **Isolamento de Escopo por Perfil (Segurança):**
   - **MASTER Admins:** Possuem acesso exclusivo ao módulo com visão global de faturamento e volumes de todos os condomínios (incluindo o ranking Top 5 de maiores consumidores).
   - **Síndicos / Subsíndicos:** Não possuem acesso a este módulo administrativo/operacional da plataforma.
5. **Preparação para Faturamento:** O modelo de dados retorna as métricas de volumetria segregadas (mensagens enviadas, conversas pagas/templates e mensagens gratuitas) de forma a garantir a compatibilidade arquitetural com regras futuras de billing (franquias, excedentes e repasses integrais).
6. **Centralização de SuperAdmins (Hardening):** Todas as verificações de privilégios de administrador global (SuperAdmin) devem ser feitas exclusivamente consultando a tabela de banco de dados `public.system_superadmins(email TEXT PRIMARY KEY)` ou o campo de perfil correspondente. É expressamente proibido manter listas de e-mails administrativas em arquivos estáticos (hardcode) do frontend ou backend.

### Observação Operacional — Dashboard de Consumo WhatsApp

Os indicadores financeiros do dashboard interno do Condomeet representam custos estimados operacionais baseados nos eventos processados pela plataforma e não necessariamente o faturamento efetivamente liquidado pela Meta.

O faturamento oficial deve sempre ser considerado aquele apresentado no WhatsApp Manager / Billing da Meta.

Caso futuramente seja implementada integração com APIs oficiais de billing da Meta, os indicadores deverão ser renomeados para:
- Custo Estimado
- Custo Faturado
- Diferença de Faturamento

---


## 📊 Baseline Oficial — SuperAdmin Centralizado (Homologado)

A plataforma passa a utilizar exclusivamente a tabela `public.system_superadmins` como fonte única de verdade para privilégios administrativos globais.

### Premissas Obrigatórias de Governança:
1. **Fim dos Hardcodes:** É proibido utilizar listas hardcoded de e-mails em código.
2. **Consulta Centralizada:** Todo acesso administrativo global deve consultar `system_superadmins`.
3. **Segregação de Papéis:** Roles locais (síndico, subsíndico, morador, porteiro, etc.) continuam sendo gerenciadas pela tabela `perfil`.
4. **Escopo Corporativo:** A tabela `system_superadmins` representa privilégios corporativos da plataforma Condomeet e não privilégios do condomínio.

---

## 📊 Regra Permanente — Ativação de WABA em Produção

Toda nova implantação de WhatsApp Cloud API em produção deve obrigatoriamente validar os seguintes itens antes da homologação final:

### Checklist Obrigatório
- Business Verification = VERIFIED
- WABA Status = ACTIVE
- Phone Status = VERIFIED
- Quality Rating = GREEN
- App inscrito via:
  `POST /{WABA_ID}/subscribed_apps`
- Webhook recebendo eventos:
  - `sent`
  - `delivered`
  - `read`
- Forma de pagamento válida cadastrada na WABA

### Erro Crítico Conhecido
Meta Error:
`131042 - Business eligibility payment issue`

Sintoma:
- Graph API retorna HTTP 200.
- Mensagem assume status "sent".
- Webhook posteriormente converte para "failed".
- Destinatário nunca recebe a mensagem.

Causa:
Ausência de forma de pagamento válida na WABA.

Observação:
Esse erro pode ocorrer mesmo quando:
- Business Verification = VERIFIED
- WABA Status = ACTIVE
- Phone Status = VERIFIED
- Quality Rating = GREEN
- Token possui todos os escopos necessários
- Webhook está operacional
- `subscribed_apps` está ativo

### Propagação da Cobrança
Após inclusão do cartão de crédito na WABA, a ativação financeira da Meta pode levar alguns minutos para propagar internamente.

Durante esse período podem coexistir mensagens:
- entregues normalmente;
- falhadas com erro 131042;
- pendentes de sincronização.

Não assumir falha sistêmica até transcorrer pelo menos 15 minutos após o cadastro da forma de pagamento.

### Comportamento Esperado da Outbox
Mensagens marcadas como FAILED não devem ser reenviadas automaticamente após a correção da causa raiz.

Motivo:
Evitar entrega tardia de eventos sensíveis como:
- autorizações de visitantes;
- liberações temporárias;
- notificações operacionais expiradas.

Reenvios devem ocorrer somente por ação administrativa explícita.

---

## 📊 Regra Permanente — Hash obrigatório em whatsapp_outbox

Toda inserção na tabela `whatsapp_outbox` deve obrigatoriamente gerar e persistir `message_hash`.

### Objetivo
Garantir:
- deduplicação;
- prevenção de spam;
- idempotência de webhooks;
- proteção contra múltiplos envios acidentais;
- consistência entre fluxos automáticos e manuais.

### Regra
É proibido executar qualquer:

```sql
INSERT INTO whatsapp_outbox (...)
```

sem preencher o campo `message_hash`.

A ausência do campo viola a constraint:

```sql
message_hash NOT NULL
```

e interrompe imediatamente o fluxo de envio.

### Implementação Oficial

Todos os canais de envio devem utilizar o mesmo algoritmo de geração de hash baseado em:

- telefone normalizado;
- tipo do payload;
- conteúdo da mensagem;
- condomínio de origem.

Implementação conceitual:

```text
SHA256(
  telefone_normalizado +
  payload_type +
  conteudo +
  condominio_id
)
```

### Fluxos obrigatoriamente cobertos

- smartSend (Edge Functions)
- sendManualMessage (Painel Administrativo)
- reenvio manual
- campanhas futuras
- automações futuras
- integrações externas
- qualquer novo produtor de registros em `whatsapp_outbox`

### Helpers Oficiais

As implementações homologadas para geração do hash são:

- `normalizePhone()`
- `sha256()`

É proibida a criação de algoritmos alternativos ou hashes incompatíveis entre fluxos.

### Observação operacional

O comportamento atual é determinístico e idempotente.

Caso futuramente seja necessário permitir múltiplos envios manuais idênticos para o mesmo destinatário, o fluxo manual poderá incorporar um componente temporal (`timestamp`) ou `UUID` ao cálculo do hash, sem alterar o comportamento dos fluxos automáticos.

Até nova decisão arquitetural, permanece obrigatório o comportamento determinístico para todos os produtores da tabela `whatsapp_outbox`.

---

## 📊 Baseline Oficial — API Oficial Meta em Produção

A implantação da API Oficial Meta foi promovida para produção no ambiente Condomeet.

### Premissas Obrigatórias:

1. **system_superadmins como Fonte Única:** A tabela `system_superadmins` é a única fonte de verdade para privilégios administrativos globais.
2. **Sem Listas Estáticas (Hardcode):** É proibido utilizar listas hardcoded de e-mails em frontend ou backend.
3. **Módulos Exclusivos:** O Dashboard e o Chat da API Oficial são módulos exclusivos para SuperAdmins.
4. **Isolamento do Ecossistema WhatsApp:** O módulo opera exclusivamente sobre Views, RPCs e tabelas próprias do ecossistema WhatsApp.
5. **Sem Impacto Transacional:** Nenhuma consulta do dashboard poderá impactar:
   - workers;
   - filas de envio;
   - webhooks Meta;
   - processamento transacional.
6. **Vínculo com Condomínio:** Todas as mensagens enviadas pela plataforma devem possuir obrigatoriamente um `condominio_id` válido.
7. **Aderência Financeira:** O custo consolidado dos condomínios deve possuir aderência integral com o custo global da Meta.
8. **Banco de Homologação:** O módulo foi homologado em produção utilizando o banco `ivdgvpvifhfiktolmbvy` (`condomeetBD`).

### Status:
- Produção: **APROVADO**
- Observabilidade: **ATIVA**
- Billing futuro: **COMPATÍVEL**
- Hardening: **CONCLUÍDO**




