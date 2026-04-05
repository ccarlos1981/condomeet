---
stepsCompleted: [1, 2]
workflowType: 'architecture'
project_name: 'condomeet-assembleia-online'
user_name: 'cristiano'
date: '2026-04-05'
inputDocuments:
  - _bmad-output/planning-artifacts/prd-assembleia-online.md
  - _bmad-output/planning-artifacts/architecture.md
  - supabase/migrations/20260313_enquetes.sql
---

# Architecture Decision Document — Assembleia Online

_Módulo complementar à arquitetura principal do Condomeet. Segue os mesmos padrões de naming, RLS, e estrutura._

---

## 1. Project Context Analysis

### 1.1 Contexto do Módulo

O módulo de Assembleia Online é uma extensão do Condomeet existente. **Não altera** a arquitetura base — adiciona:
- 7 novas tabelas no PostgreSQL
- 3 novas Edge Functions
- 1 integração externa (Jitsi Meet)
- Extensão do Supabase Realtime (canais de votação)

### 1.2 Alinhamento com Arquitetura Existente

| Decisão existente | Como a Assembleia se encaixa |
|---|---|
| Multi-tenancy via RLS + `condominio_id` | ✅ Todas as tabelas terão `condominio_id` |
| snake_case no banco | ✅ Seguindo: `assembleias`, `assembleia_pautas`, etc. |
| Feature-First no Flutter | ✅ `lib/features/assembleia/` (Fase 3) |
| Edge Functions em Deno | ✅ `supabase/functions/assembleia-*` |
| Auth via Supabase JWT | ✅ Voto autenticado via `auth.uid()` |
| Padrão de enquetes como referência | ✅ Votação segue padrão de enquetes (com melhorias) |

### 1.3 Diferenças vs Enquetes

A assembleia é **mais complexa** que enquetes por:

| Aspecto | Enquetes | Assembleia |
|---|---|---|
| Quem vota | Morador (indivíduo) | Unidade (1 voto por apt) |
| Bloqueio | Não tem | Inadimplente bloqueado |
| Sobreposição | unique(enquete_id, user_id) | UPSERT(assembleia_id, pauta_id, unit_id) |
| Resultado | Mostra durante votação | Resultado secreto até encerrar (configurável) |
| Quórum | Não tem | Simples / 2/3 / Unanimidade por pauta |
| Peso | 1 pessoa = 1 voto | Fração ideal ou 1:1 |
| Timeline | Simples (abrir/fechar) | Assembleia ao vivo + votação assíncrona (até 3 dias) |
| Audit trail | Não tem | IP + hash SHA-256 + timestamp |

---

## 2. Data Architecture

### 2.1 Database Schema (7 tabelas)

```
┌─────────────────────┐
│    assembleias       │ ← assembleia principal
├─────────────────────┤
│ id (PK, UUID)       │
│ condominio_id (FK)  │──→ condominios
│ nome                │
│ tipo (AGO/AGE)      │
│ modalidade           │
│ status              │
│ dt_1a_convocacao    │
│ dt_2a_convocacao    │
│ dt_inicio_votacao   │
│ dt_fim_votacao      │
│ dt_inicio_transmissao│
│ dt_fim_transmissao  │
│ local_presencial    │
│ jitsi_room_name     │
│ presidente_mesa     │
│ secretario_mesa     │
│ eleicao_mesa        │ (boolean)
│ peso_voto_tipo      │ (fracao_ideal | unitario)
│ procuracao_exige_firma│ (boolean)
│ created_by (FK)     │──→ perfil
│ created_at          │
│ updated_at          │
└────────┬────────────┘
         │ 1:N
         ▼
┌─────────────────────┐
│  assembleia_pautas   │ ← itens de pauta
├─────────────────────┤
│ id (PK, UUID)       │
│ assembleia_id (FK)  │──→ assembleias
│ ordem               │
│ titulo              │
│ descricao           │
│ tipo (votacao|info)  │
│ quorum_tipo         │ (simples|dois_tercos|unanimidade)
│ opcoes_voto         │ (JSONB: ["A favor","Contra","Abstenção"])
│ resultado_visivel   │ (boolean - mostrar durante ou só no fim)
│ created_at          │
└────────┬────────────┘
         │ 1:N
         ▼
┌─────────────────────────┐
│  assembleia_votos        │ ← votos (1 por unidade por pauta)
├─────────────────────────┤
│ id (PK, UUID)           │
│ assembleia_id (FK)      │──→ assembleias
│ pauta_id (FK)           │──→ assembleia_pautas
│ unit_id (FK)            │──→ units
│ voto                    │ (text: opcao escolhida)
│ votante_user_id (FK)    │──→ perfil (quem apertou o botão)
│ por_procuracao          │ (boolean)
│ procuracao_id (FK)      │──→ assembleia_procuracoes (nullable)
│ ip_address              │
│ user_agent              │
│ voto_hash               │ (SHA-256 do voto+timestamp+ip)
│ peso_aplicado           │ (decimal - peso do voto no momento)
│ created_at              │
│ updated_at              │  ← atualizado se mesma unidade vota 2x
├─────────────────────────┤
│ UNIQUE (assembleia_id,  │
│   pauta_id, unit_id)    │ ← garante 1 voto por unidade por pauta
│                         │   (UPSERT para sobreposição)
└─────────────────────────┘

┌─────────────────────────┐
│ assembleia_procuracoes   │ ← procurações digitais
├─────────────────────────┤
│ id (PK, UUID)           │
│ assembleia_id (FK)      │──→ assembleias
│ outorgante_unit_id (FK) │──→ units (quem dá o poder)
│ outorgante_user_id (FK) │──→ perfil
│ outorgado_user_id (FK)  │──→ perfil (procurador)
│ status                  │ (pendente|aprovada|rejeitada)
│ aprovado_por (FK)       │──→ perfil (síndico que aprovou)
│ aprovado_em             │
│ documento_url           │ (se firma reconhecida - upload)
│ created_at              │
└─────────────────────────┘

┌─────────────────────────┐
│ assembleia_presencas     │ ← controle de presença
├─────────────────────────┤
│ id (PK, UUID)           │
│ assembleia_id (FK)      │──→ assembleias
│ unit_id (FK)            │──→ units
│ user_id (FK)            │──→ perfil
│ tipo_presenca           │ (online|presencial|procuracao)
│ ip_address              │
│ entrada_em              │
│ saida_em                │
└─────────────────────────┘

┌─────────────────────────┐
│ assembleia_chat          │ ← mensagens do chat ao vivo
├─────────────────────────┤
│ id (PK, UUID)           │
│ assembleia_id (FK)      │──→ assembleias
│ user_id (FK)            │──→ perfil
│ mensagem                │
│ tipo                    │ (texto|sistema|moderacao)
│ created_at              │
└─────────────────────────┘

┌─────────────────────────┐
│ assembleia_audit_log     │ ← log imutável de eventos
├─────────────────────────┤
│ id (PK, UUID)           │
│ assembleia_id (FK)      │──→ assembleias
│ evento                  │ (criou|publicou|iniciou|votou|encerrou|...)
│ dados                   │ (JSONB - detalhes do evento)
│ user_id (FK)            │──→ perfil
│ ip_address              │
│ created_at              │
│                         │
│ ⚠️ SEM UPDATE/DELETE    │ ← imutável para validade jurídica
└─────────────────────────┘
```

### 2.2 Status Machine da Assembleia

```
  [rascunho] ──publicar──→ [agendada] ──iniciar──→ [em_andamento]
                              │                        │
                          cancelar                  encerrar_sessao
                              ▼                        ▼
                         [cancelada]           [votacao_aberta]
                                                      │
                                                 encerrar_votacao
                                                      ▼
                                                 [finalizada]
                                                      │
                                                 gerar_ata
                                                      ▼
                                                 [ata_publicada]
```

### 2.3 Índices Estratégicos

```sql
-- Performance: buscar assembleias do condomínio
CREATE INDEX idx_assembleias_condo_status ON assembleias(condominio_id, status);

-- Performance: votos por pauta (para resultado em tempo real)
CREATE INDEX idx_votos_pauta ON assembleia_votos(assembleia_id, pauta_id);

-- Performance: verificar se unidade já votou (para UPSERT)
CREATE UNIQUE INDEX idx_votos_unique ON assembleia_votos(assembleia_id, pauta_id, unit_id);

-- Performance: inadimplência check
-- (usa tabela existente de unidades/financeiro)

-- Audit log: buscar por assembleia
CREATE INDEX idx_audit_assembleia ON assembleia_audit_log(assembleia_id, created_at);
```

---

## 3. RLS Strategy (Row Level Security)

Seguindo o **padrão existente** do Condomeet (referência: enquetes.sql):

### 3.1 assembleias

```
Admin (Síndico): ALL → condominio_id match + papel_sistema IN ('Síndico','ADMIN',...)
Morador: SELECT → condominio_id match + status != 'rascunho'
```

### 3.2 assembleia_votos

```
Admin: SELECT agregado (nunca voto individual de outro) → via view
Morador: INSERT/UPDATE próprio (unit_id da sua unidade) + status = 'votacao_aberta'
         SELECT próprio voto apenas
⚠️ NUNCA: SELECT de votos de outras unidades (voto secreto)
```

### 3.3 assembleia_audit_log

```
Admin: SELECT → condominio_id match
Todos: INSERT automático (via trigger, não direto)
Ninguém: UPDATE/DELETE (imutável)
```

### 3.4 Votação — Lógica de Bloqueio

```sql
-- Check antes de permitir voto:
-- 1. Assembleia em status 'votacao_aberta'
-- 2. Dentro do período (dt_inicio_votacao ≤ now() ≤ dt_fim_votacao)
-- 3. Unidade NÃO inadimplente
-- 4. User pertence à unidade OU tem procuração aprovada
```

---

## 4. Edge Functions (Supabase)

### 4.1 Funções Necessárias

| Function | Trigger | O que faz |
|---|---|---|
| `assembleia-convocacao-notify` | Síndico clica "Enviar Convocação" | Envia edital via WhatsApp (BotConversa) + Push (FCM) para todos os moradores |
| `assembleia-ata-gerar` | Síndico clica "Gerar ATA" (após encerrar votação) | (Fase 2) Whisper transcrição + LLM geração → salva PDF no Storage |
| `assembleia-ata-notify` | Após ata ser publicada | Envia ata via WhatsApp + Push |

### 4.2 Funções que NÃO são Edge Functions

| Funcionalidade | Onde roda | Razão |
|---|---|---|
| CRUD assembleia | Cliente (Next.js) → Supabase direto | Padrão existente do projeto |
| Votação | Cliente → Supabase UPSERT direto + RLS | Performance (< 1s) |
| Dashboard real-time | Cliente → Supabase Realtime subscription | Padrão existente |
| Chat | Cliente → Supabase Realtime channel | Padrão existente (Fale Conosco) |
| PDF edital | Cliente (React-PDF / jsPDF) | Sem necessidade de servidor |

---

## 5. Real-Time Architecture

### 5.1 Supabase Realtime Channels

```
Canal: assembleia:{assembleia_id}:votos
  → Broadcast quando voto é registrado (sem expor o voto, só o count)
  → Dashboard do síndico escuta para atualizar métricas

Canal: assembleia:{assembleia_id}:chat
  → Mensagens do chat ao vivo
  → Toggle on/off pelo síndico

Canal: assembleia:{assembleia_id}:status
  → Mudanças de status (votação aberta, pauta x aberta, etc.)
  → Todos os participantes escutam
```

### 5.2 Dashboard Real-Time — Como funciona

```
Morador vota
    ↓
UPSERT em assembleia_votos (via RLS)
    ↓
Supabase DB trigger → incrementa contadores em cache
    ↓
Supabase Realtime → broadcast "vote_updated"
    ↓
Dashboard do síndico recebe → atualiza gráficos
```

**Resultado exibido no dashboard** (agregado, nunca individual):
- Total de unidades cadastradas
- Total que votaram
- Por pauta: A favor X% | Contra Y% | Abstenção Z%
- Válidos | Duplicados | Inadimplentes | Rejeitados

---

## 6. Jitsi Meet Integration

### 6.1 Decisão: Iframe API (não SDK completo)

```
Razão: 
- Iframe é mais simples de integrar em Next.js
- Controles de moderação via postMessage
- Isolamento de segurança (sandbox)
- Troca de JaaS para self-hosted = só mudar a URL
```

### 6.2 Room Naming Convention

```
condomeet-{condominio_id_short}-{assembleia_id_short}
Exemplo: condomeet-abc123-def456
```

### 6.3 Moderação via Jitsi API

```javascript
// Mutar todos
jitsiApi.executeCommand('muteEveryone');

// Chat toggle
jitsiApi.executeCommand('toggleChat');

// Gravar (Jibri)
jitsiApi.executeCommand('startRecording', { mode: 'file' });

// Levantar a mão (Fase 2)
jitsiApi.executeCommand('raiseHand');
```

### 6.4 Custo Strategy

```
Dev/Teste   → JaaS Dev (grátis, 25 MAUs)
Produção    → JaaS Basic ($99/mês) OU Self-hosted (~R$200/mês)
Config      → URL do servidor em variável de ambiente: NEXT_PUBLIC_JITSI_DOMAIN
```

---

## 7. AI Pipeline (Fase 2)

### 7.1 Fluxo de Geração da ATA

```
Gravação Jitsi (vídeo/áudio)
    ↓ upload para Supabase Storage
    ↓
Edge Function: assembleia-ata-gerar
    ↓
    ├── 1. Download áudio do Storage
    ├── 2. Enviar para OpenAI Whisper API (transcrição)
    │       → $0.006/min (~R$2 para 2h de assembleia)
    ├── 3. Combinar transcrição + dados de votação do banco
    ├── 4. Enviar para Gemini/GPT-4o com prompt estruturado
    │       → ~R$1-2 por assembleia
    ├── 5. Gerar PDF da ata
    └── 6. Salvar no Storage + atualizar status para 'ata_publicada'
```

### 7.2 Prompt da ATA (conceito)

```
Você é um assistente jurídico especializado em assembleias condominiais.
Com base na transcrição e nos dados de votação, gere uma ATA formal contendo:

1. CABEÇALHO: Nome do condomínio, data, hora, local, modalidade
2. QUÓRUM: Total de unidades, presentes, ausentes, % participação  
3. MESA: Presidente e secretário eleitos/indicados
4. DELIBERAÇÕES: Para cada pauta:
   - Discussão resumida (pontos relevantes da transcrição)
   - Resultado da votação (A favor X%, Contra Y%, Abstenção Z%)
   - Decisão tomada
5. ENCERRAMENTO: Hora de encerramento, assinaturas digitais
6. INCIDENTES: Quedas de conexão, reconexões (se houver)
```

---

## 8. Web Frontend Architecture (Next.js)

### 8.1 Estrutura de Arquivos

```
web-app/app/admin/assembleias/
├── page.tsx                      ← Lista de assembleias
├── assembleias-client.tsx        ← Client component principal
├── nova/
│   └── page.tsx                  ← Wizard de criação (4 steps)
│   └── nova-assembleia-client.tsx
├── [id]/
│   └── page.tsx                  ← Detalhes com abas
│   └── assembleia-detalhe-client.tsx
│   └── components/
│       ├── tab-informacoes.tsx
│       ├── tab-inadimplencia.tsx
│       ├── tab-pautas.tsx
│       ├── tab-votacao.tsx
│       ├── tab-resultados.tsx
│       ├── tab-dashboard.tsx
│       ├── tab-presenca.tsx
│       ├── tab-transmissao.tsx   ← (Fase 2)
│       └── tab-alertas.tsx
```

### 8.2 Padrão de Componentes (referência existente)

Seguindo o padrão de `reservas-admin-client.tsx` e `manutencao-client.tsx`:
- Server component (page.tsx) → fetch inicial com Supabase SSR
- Client component → estado + interatividade
- Modais para CRUD
- Tabela com filtros e ações

---

## 9. Decisões Arquiteturais — Resumo

| # | Decisão | Escolha | Alternativa rejeitada | Razão |
|---|---|---|---|---|
| AD1 | Voto por unidade | UPSERT com UNIQUE constraint | Tabela separada de "último voto" | Mais simples, menos tabelas |
| AD2 | Voto secreto | RLS impede SELECT de votos alheios | Criptografia E2E | RLS é suficiente + mais simples |
| AD3 | Audit trail | Tabela imutável sem UPDATE/DELETE | Blockchain | Overkill — tabela append-only é juridicamente válida |
| AD4 | Real-time dashboard | Supabase Realtime broadcast | Polling a cada 5s | Mais eficiente, já usado no projeto |
| AD5 | Jitsi integration | Iframe API | SDK React | Iframe é mais isolado e simples |
| AD6 | PDF edital | Client-side (jsPDF) | Edge Function | Não precisa servidor, mais rápido |
| AD7 | ATA por IA | Edge Function async | Client-side | Processamento pesado, melhor no servidor |
| AD8 | Timeline separada | Campos dt_inicio/fim separados para assembleia e votação | Single timeline | Votação pode estender 3 dias |
| AD9 | Status machine | Enum com transições definidas | Boolean flags | Mais claro, evita estados inconsistentes |
| AD10 | Chat | Supabase Realtime channel | WebSocket custom | Já temos o padrão (Fale Conosco) |

---

## 10. Validation & Readiness

### 10.1 Checklist de Coerência

| Verificação | Status |
|---|---|
| Todas as 44 FRs mapeadas para tabelas/componentes? | ✅ |
| Padrão de naming segue arquitetura existente? | ✅ snake_case |
| RLS segue padrão de enquetes? | ✅ com melhorias |
| Edge Functions seguem padrão existente? | ✅ Deno |
| Frontend segue padrão page.tsx + client.tsx? | ✅ |
| Nenhuma dependência nova quebra o projeto? | ✅ |
| Custo de infraestrutura é aceitável? | ✅ R$0 no início |

### 10.2 Readiness Assessment

- **Overall Status**: **READY FOR IMPLEMENTATION**
- **Confidence Level**: **High**
- **Dependências externas**: Apenas Jitsi (Fase 2) — MVP funciona sem
- **Risco principal**: Escala da votação em tempo real — mitigado com índices e broadcast
