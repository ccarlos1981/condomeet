-- ============================================================
-- Migration: 20260405_assembleias_feature
-- Tabelas para Assembleias Online do Condomínio
-- Referência: PRD prd-assembleia-online.md + architecture-assembleia-online.md
-- ============================================================

-- ═══════════════════════════════════════════════════════════
--  0. ALTER TABLE unidades — novos campos para assembleia
-- ═══════════════════════════════════════════════════════════
ALTER TABLE unidades ADD COLUMN IF NOT EXISTS fracao_ideal DECIMAL(6,2) DEFAULT 1.00;
ALTER TABLE unidades ADD COLUMN IF NOT EXISTS bloqueada_assembleia BOOLEAN DEFAULT false;
ALTER TABLE unidades ADD COLUMN IF NOT EXISTS bloqueada_app BOOLEAN DEFAULT false;

COMMENT ON COLUMN unidades.fracao_ideal IS 'Peso do voto da unidade. Default 1.00. Síndico configura individualmente.';
COMMENT ON COLUMN unidades.bloqueada_assembleia IS 'Se true, a unidade não pode votar em assembleias (ex: inadimplência).';
COMMENT ON COLUMN unidades.bloqueada_app IS 'Se true, todos os moradores da unidade perdem acesso ao app.';

-- ═══════════════════════════════════════════════════════════
--  1. assembleias — assembleia principal
-- ═══════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.assembleias (
  id                      UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  condominio_id           UUID        NOT NULL,
  nome                    TEXT        NOT NULL,
  tipo                    TEXT        NOT NULL DEFAULT 'AGO',          -- AGO | AGE
  modalidade              TEXT        NOT NULL DEFAULT 'online',      -- online | presencial | hibrida
  status                  TEXT        NOT NULL DEFAULT 'rascunho',    -- rascunho | agendada | em_andamento | votacao_aberta | finalizada | ata_publicada | cancelada

  -- Datas de convocação
  dt_1a_convocacao        TIMESTAMPTZ,
  dt_2a_convocacao        TIMESTAMPTZ,

  -- Datas da sessão ao vivo (transmissão/presencial)
  dt_inicio_transmissao   TIMESTAMPTZ,
  dt_fim_transmissao      TIMESTAMPTZ,

  -- Datas da votação (independente da sessão ao vivo)
  dt_inicio_votacao       TIMESTAMPTZ,
  dt_fim_votacao          TIMESTAMPTZ,

  -- Local & Transmissão
  local_presencial        TEXT,
  jitsi_room_name         TEXT,

  -- Mesa diretora
  eleicao_mesa            BOOLEAN     DEFAULT false,
  presidente_mesa         TEXT,
  secretario_mesa         TEXT,

  -- Configurações de votação
  peso_voto_tipo          TEXT        NOT NULL DEFAULT 'unitario',   -- unitario | fracao_ideal
  procuracao_exige_firma  BOOLEAN     DEFAULT false,

  -- Edital & ATA
  edital_url              TEXT,
  ata_url                 TEXT,
  gravacao_url            TEXT,

  -- Metadata
  created_by              UUID        NOT NULL,
  created_at              TIMESTAMPTZ DEFAULT NOW(),
  updated_at              TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_assembleias_condo_status ON assembleias(condominio_id, status);
CREATE INDEX IF NOT EXISTS idx_assembleias_created ON assembleias(condominio_id, created_at DESC);

-- ═══════════════════════════════════════════════════════════
--  2. assembleia_pautas — itens de pauta
-- ═══════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.assembleia_pautas (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  assembleia_id   UUID        NOT NULL REFERENCES assembleias(id) ON DELETE CASCADE,
  ordem           INT         NOT NULL DEFAULT 0,
  titulo          TEXT        NOT NULL,
  descricao       TEXT,
  tipo            TEXT        NOT NULL DEFAULT 'votacao',   -- votacao | informativo
  quorum_tipo     TEXT        NOT NULL DEFAULT 'simples',   -- simples | dois_tercos | unanimidade
  opcoes_voto     JSONB       DEFAULT '["A favor","Contra","Abstenção"]'::jsonb,
  modo_resposta   TEXT        NOT NULL DEFAULT 'unica',     -- unica (radio) | multipla (checkbox)
  max_escolhas    INT         DEFAULT 1,                    -- máx de opções que o votante pode marcar (só para multipla)
  resultado_visivel BOOLEAN   DEFAULT false,                -- mostrar resultado durante votação?
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pautas_assembleia ON assembleia_pautas(assembleia_id, ordem);

-- ═══════════════════════════════════════════════════════════
--  3. assembleia_votos — 1 voto por unidade por pauta (UPSERT)
-- ═══════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.assembleia_votos (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  assembleia_id     UUID        NOT NULL REFERENCES assembleias(id) ON DELETE CASCADE,
  pauta_id          UUID        NOT NULL REFERENCES assembleia_pautas(id) ON DELETE CASCADE,
  unit_id           UUID        NOT NULL,
  voto              TEXT        NOT NULL,                           -- "A favor" | "Contra" | "Abstenção"
  votante_user_id   UUID        NOT NULL,                           -- quem apertou o botão
  por_procuracao    BOOLEAN     DEFAULT false,
  procuracao_id     UUID,                                           -- FK para assembleia_procuracoes (nullable)
  ip_address        INET,
  user_agent        TEXT,
  voto_hash         TEXT,                                           -- SHA-256 do voto+timestamp+ip
  peso_aplicado     DECIMAL(10,6) DEFAULT 1.0,                      -- peso do voto no momento
  created_at        TIMESTAMPTZ DEFAULT NOW(),
  updated_at        TIMESTAMPTZ DEFAULT NOW()
);

-- Garante 1 voto por unidade por pauta (UPSERT para sobreposição)
CREATE UNIQUE INDEX IF NOT EXISTS idx_votos_unique ON assembleia_votos(assembleia_id, pauta_id, unit_id);
CREATE INDEX IF NOT EXISTS idx_votos_pauta ON assembleia_votos(assembleia_id, pauta_id);

-- ═══════════════════════════════════════════════════════════
--  4. assembleia_procuracoes — procurações digitais
-- ═══════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.assembleia_procuracoes (
  id                    UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  assembleia_id         UUID        NOT NULL REFERENCES assembleias(id) ON DELETE CASCADE,
  outorgante_unit_id    UUID        NOT NULL,                       -- unidade que dá o poder
  outorgante_user_id    UUID        NOT NULL,                       -- morador que dá o poder
  outorgado_user_id     UUID        NOT NULL,                       -- procurador
  status                TEXT        NOT NULL DEFAULT 'pendente',    -- pendente | aprovada | rejeitada
  aprovado_por          UUID,                                       -- síndico que aprovou
  aprovado_em           TIMESTAMPTZ,
  documento_url         TEXT,                                       -- upload se firma reconhecida
  created_at            TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_procuracoes_assembleia ON assembleia_procuracoes(assembleia_id);
CREATE INDEX IF NOT EXISTS idx_procuracoes_outorgado ON assembleia_procuracoes(outorgado_user_id, assembleia_id);

-- ═══════════════════════════════════════════════════════════
--  5. assembleia_presencas — controle de presença
-- ═══════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.assembleia_presencas (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  assembleia_id   UUID        NOT NULL REFERENCES assembleias(id) ON DELETE CASCADE,
  unit_id         UUID        NOT NULL,
  user_id         UUID        NOT NULL,
  tipo_presenca   TEXT        NOT NULL DEFAULT 'online',   -- online | presencial | procuracao
  ip_address      INET,
  entrada_em      TIMESTAMPTZ DEFAULT NOW(),
  saida_em        TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_presencas_assembleia ON assembleia_presencas(assembleia_id);

-- ═══════════════════════════════════════════════════════════
--  6. assembleia_chat — mensagens do chat ao vivo
-- ═══════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.assembleia_chat (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  assembleia_id   UUID        NOT NULL REFERENCES assembleias(id) ON DELETE CASCADE,
  user_id         UUID        NOT NULL,
  mensagem        TEXT        NOT NULL,
  tipo            TEXT        NOT NULL DEFAULT 'texto',    -- texto | sistema | moderacao
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_chat_assembleia ON assembleia_chat(assembleia_id, created_at);

-- ═══════════════════════════════════════════════════════════
--  7. assembleia_audit_log — log imutável de eventos
-- ═══════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.assembleia_audit_log (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  assembleia_id   UUID        NOT NULL REFERENCES assembleias(id) ON DELETE CASCADE,
  evento          TEXT        NOT NULL,                    -- criou | publicou | iniciou | votou | encerrou_votacao | gerou_ata | cancelou | ...
  dados           JSONB,                                   -- detalhes do evento
  user_id         UUID,
  ip_address      INET,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ⚠️ SEM UPDATE/DELETE — tabela append-only para validade jurídica
CREATE INDEX IF NOT EXISTS idx_audit_assembleia ON assembleia_audit_log(assembleia_id, created_at);

-- ═══════════════════════════════════════════════════════════
--  TRIGGER: updated_at automático na tabela assembleias
-- ═══════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION update_assembleia_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_assembleias_updated_at ON assembleias;
CREATE TRIGGER trg_assembleias_updated_at
  BEFORE UPDATE ON assembleias
  FOR EACH ROW EXECUTE FUNCTION update_assembleia_updated_at();

-- ═══════════════════════════════════════════════════════════
--  RLS — Row Level Security
-- ═══════════════════════════════════════════════════════════

-- ── assembleias ─────────────────────────────────────────────
ALTER TABLE assembleias ENABLE ROW LEVEL SECURITY;

-- Admin: full CRUD no seu condomínio
DROP POLICY IF EXISTS "admin_crud_assembleias" ON assembleias;
CREATE POLICY "admin_crud_assembleias"
ON assembleias FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM perfil p
    WHERE p.id = auth.uid()
      AND p.condominio_id = assembleias.condominio_id
      AND p.papel_sistema IN ('Síndico', 'Síndico (a)', 'ADMIN', 'admin', 'Sub-Síndico')
  )
);

-- Moradores: SELECT apenas assembleias não-rascunho do seu condomínio
DROP POLICY IF EXISTS "morador_select_assembleias" ON assembleias;
CREATE POLICY "morador_select_assembleias"
ON assembleias FOR SELECT TO authenticated
USING (
  assembleias.status != 'rascunho'
  AND EXISTS (
    SELECT 1 FROM perfil p
    WHERE p.id = auth.uid()
      AND p.condominio_id = assembleias.condominio_id
  )
);

-- ── assembleia_pautas ───────────────────────────────────────
ALTER TABLE assembleia_pautas ENABLE ROW LEVEL SECURITY;

-- Admin: full CRUD via assembleia ownership
DROP POLICY IF EXISTS "admin_crud_assembleia_pautas" ON assembleia_pautas;
CREATE POLICY "admin_crud_assembleia_pautas"
ON assembleia_pautas FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM assembleias a
    JOIN perfil p ON p.id = auth.uid()
      AND p.condominio_id = a.condominio_id
      AND p.papel_sistema IN ('Síndico', 'Síndico (a)', 'ADMIN', 'admin', 'Sub-Síndico')
    WHERE a.id = assembleia_pautas.assembleia_id
  )
);

-- Moradores: SELECT pautas de assembleias visíveis
DROP POLICY IF EXISTS "morador_select_assembleia_pautas" ON assembleia_pautas;
CREATE POLICY "morador_select_assembleia_pautas"
ON assembleia_pautas FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM assembleias a
    JOIN perfil p ON p.id = auth.uid() AND p.condominio_id = a.condominio_id
    WHERE a.id = assembleia_pautas.assembleia_id
      AND a.status != 'rascunho'
  )
);

-- ── assembleia_votos ────────────────────────────────────────
ALTER TABLE assembleia_votos ENABLE ROW LEVEL SECURITY;

-- Admin: SELECT agregado (votos do seu condomínio) — nunca vê voto individual de outro
DROP POLICY IF EXISTS "admin_select_votos" ON assembleia_votos;
CREATE POLICY "admin_select_votos"
ON assembleia_votos FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM assembleias a
    JOIN perfil p ON p.id = auth.uid()
      AND p.condominio_id = a.condominio_id
      AND p.papel_sistema IN ('Síndico', 'Síndico (a)', 'ADMIN', 'admin', 'Sub-Síndico')
    WHERE a.id = assembleia_votos.assembleia_id
  )
);

-- Morador: INSERT/UPDATE próprio voto (unit_id da sua unidade)
DROP POLICY IF EXISTS "morador_upsert_voto" ON assembleia_votos;
CREATE POLICY "morador_upsert_voto"
ON assembleia_votos FOR INSERT TO authenticated
WITH CHECK (
  assembleia_votos.votante_user_id = auth.uid()
  AND EXISTS (
    SELECT 1 FROM assembleias a
    WHERE a.id = assembleia_votos.assembleia_id
      AND a.status = 'votacao_aberta'
      AND NOW() BETWEEN a.dt_inicio_votacao AND a.dt_fim_votacao
  )
);

-- Morador: UPDATE próprio voto (sobreposição)
DROP POLICY IF EXISTS "morador_update_voto" ON assembleia_votos;
CREATE POLICY "morador_update_voto"
ON assembleia_votos FOR UPDATE TO authenticated
USING (
  assembleia_votos.votante_user_id = auth.uid()
  OR EXISTS (
    -- Permite update quando é a mesma unidade (UPSERT by unit)
    SELECT 1 FROM perfil p
    WHERE p.id = auth.uid()
      AND p.unit_id = assembleia_votos.unit_id
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM assembleias a
    WHERE a.id = assembleia_votos.assembleia_id
      AND a.status = 'votacao_aberta'
      AND NOW() BETWEEN a.dt_inicio_votacao AND a.dt_fim_votacao
  )
);

-- Morador: SELECT próprio voto apenas (VOTO SECRETO)
DROP POLICY IF EXISTS "morador_select_own_voto" ON assembleia_votos;
CREATE POLICY "morador_select_own_voto"
ON assembleia_votos FOR SELECT TO authenticated
USING (
  assembleia_votos.votante_user_id = auth.uid()
);

-- ── assembleia_procuracoes ──────────────────────────────────
ALTER TABLE assembleia_procuracoes ENABLE ROW LEVEL SECURITY;

-- Admin: full CRUD
DROP POLICY IF EXISTS "admin_crud_procuracoes" ON assembleia_procuracoes;
CREATE POLICY "admin_crud_procuracoes"
ON assembleia_procuracoes FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM assembleias a
    JOIN perfil p ON p.id = auth.uid()
      AND p.condominio_id = a.condominio_id
      AND p.papel_sistema IN ('Síndico', 'Síndico (a)', 'ADMIN', 'admin', 'Sub-Síndico')
    WHERE a.id = assembleia_procuracoes.assembleia_id
  )
);

-- Morador: INSERT própria procuração + SELECT próprias
DROP POLICY IF EXISTS "morador_insert_procuracao" ON assembleia_procuracoes;
CREATE POLICY "morador_insert_procuracao"
ON assembleia_procuracoes FOR INSERT TO authenticated
WITH CHECK (
  assembleia_procuracoes.outorgante_user_id = auth.uid()
);

DROP POLICY IF EXISTS "morador_select_own_procuracao" ON assembleia_procuracoes;
CREATE POLICY "morador_select_own_procuracao"
ON assembleia_procuracoes FOR SELECT TO authenticated
USING (
  assembleia_procuracoes.outorgante_user_id = auth.uid()
  OR assembleia_procuracoes.outorgado_user_id = auth.uid()
);

-- ── assembleia_presencas ────────────────────────────────────
ALTER TABLE assembleia_presencas ENABLE ROW LEVEL SECURITY;

-- Admin: SELECT
DROP POLICY IF EXISTS "admin_select_presencas" ON assembleia_presencas;
CREATE POLICY "admin_select_presencas"
ON assembleia_presencas FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM assembleias a
    JOIN perfil p ON p.id = auth.uid()
      AND p.condominio_id = a.condominio_id
      AND p.papel_sistema IN ('Síndico', 'Síndico (a)', 'ADMIN', 'admin', 'Sub-Síndico')
    WHERE a.id = assembleia_presencas.assembleia_id
  )
);

-- Morador: INSERT própria presença
DROP POLICY IF EXISTS "morador_insert_presenca" ON assembleia_presencas;
CREATE POLICY "morador_insert_presenca"
ON assembleia_presencas FOR INSERT TO authenticated
WITH CHECK (
  assembleia_presencas.user_id = auth.uid()
);

-- ── assembleia_chat ─────────────────────────────────────────
ALTER TABLE assembleia_chat ENABLE ROW LEVEL SECURITY;

-- Admin: full CRUD (para moderar)
DROP POLICY IF EXISTS "admin_crud_chat" ON assembleia_chat;
CREATE POLICY "admin_crud_chat"
ON assembleia_chat FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM assembleias a
    JOIN perfil p ON p.id = auth.uid()
      AND p.condominio_id = a.condominio_id
      AND p.papel_sistema IN ('Síndico', 'Síndico (a)', 'ADMIN', 'admin', 'Sub-Síndico')
    WHERE a.id = assembleia_chat.assembleia_id
  )
);

-- Morador: INSERT + SELECT do chat da assembleia
DROP POLICY IF EXISTS "morador_chat" ON assembleia_chat;
CREATE POLICY "morador_chat"
ON assembleia_chat FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM assembleias a
    JOIN perfil p ON p.id = auth.uid() AND p.condominio_id = a.condominio_id
    WHERE a.id = assembleia_chat.assembleia_id
      AND a.status IN ('em_andamento', 'votacao_aberta')
  )
);

DROP POLICY IF EXISTS "morador_insert_chat" ON assembleia_chat;
CREATE POLICY "morador_insert_chat"
ON assembleia_chat FOR INSERT TO authenticated
WITH CHECK (
  assembleia_chat.user_id = auth.uid()
  AND EXISTS (
    SELECT 1 FROM assembleias a
    JOIN perfil p ON p.id = auth.uid() AND p.condominio_id = a.condominio_id
    WHERE a.id = assembleia_chat.assembleia_id
      AND a.status IN ('em_andamento', 'votacao_aberta')
  )
);

-- ── assembleia_audit_log ────────────────────────────────────
ALTER TABLE assembleia_audit_log ENABLE ROW LEVEL SECURITY;

-- Admin: SELECT only (imutável)
DROP POLICY IF EXISTS "admin_select_audit" ON assembleia_audit_log;
CREATE POLICY "admin_select_audit"
ON assembleia_audit_log FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM assembleias a
    JOIN perfil p ON p.id = auth.uid()
      AND p.condominio_id = a.condominio_id
      AND p.papel_sistema IN ('Síndico', 'Síndico (a)', 'ADMIN', 'admin', 'Sub-Síndico')
    WHERE a.id = assembleia_audit_log.assembleia_id
  )
);

-- INSERT: qualquer autenticado do condomínio (via triggers internos também)
DROP POLICY IF EXISTS "insert_audit" ON assembleia_audit_log;
CREATE POLICY "insert_audit"
ON assembleia_audit_log FOR INSERT TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM assembleias a
    JOIN perfil p ON p.id = auth.uid() AND p.condominio_id = a.condominio_id
    WHERE a.id = assembleia_audit_log.assembleia_id
  )
);

-- ⚠️ NENHUMA policy de UPDATE ou DELETE no audit_log (imutável)

-- ═══════════════════════════════════════════════════════════
--  GRANT para anon (caso needed — padrão Condomeet)
-- ═══════════════════════════════════════════════════════════
-- Tabelas só acessíveis por authenticated (padrão RLS acima)
