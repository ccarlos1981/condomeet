-- x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x
-- Empresas Parceiras (Propaganda)
-- x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x

CREATE TABLE propaganda (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  condominio_id uuid NOT NULL REFERENCES condominios(id) ON DELETE CASCADE,
  nome          text NOT NULL,
  especialidade text,
  endereco      text,
  whatsapp      text,
  celular       text,
  site          text,
  email         text,
  logo_url      text,
  instagram     text,
  facebook      text,
  youtube       text,
  tiktok        text,
  twitter       text,
  linkedin      text,
  ordem         int  NOT NULL DEFAULT 0,
  ativo         boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE propaganda_fotos (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  propaganda_id  uuid NOT NULL REFERENCES propaganda(id) ON DELETE CASCADE,
  foto_url       text NOT NULL,
  ordem          int  NOT NULL DEFAULT 0
);

-- Indexes
CREATE INDEX idx_propaganda_condo ON propaganda(condominio_id, ativo, ordem);
CREATE INDEX idx_propaganda_fotos ON propaganda_fotos(propaganda_id, ordem);

-- RLS
ALTER TABLE propaganda ENABLE ROW LEVEL SECURITY;
ALTER TABLE propaganda_fotos ENABLE ROW LEVEL SECURITY;

-- Moradores do condomínio podem ler propaganda ativa do seu condo
CREATE POLICY "propaganda_read" ON propaganda
  FOR SELECT USING (
    ativo = true AND
    condominio_id IN (
      SELECT condominio_id FROM perfil WHERE id = auth.uid()
    )
  );

-- Apenas super admin pode gerenciar (será verificado via email no server-side)
-- Permitimos INSERT/UPDATE/DELETE via service role (Edge Function ou server)

-- propaganda_fotos: leitura pública para quem pode ler a propaganda
CREATE POLICY "propaganda_fotos_read" ON propaganda_fotos
  FOR SELECT USING (
    propaganda_id IN (
      SELECT p.id FROM propaganda p
      WHERE p.ativo = true AND p.condominio_id IN (
        SELECT condominio_id FROM perfil WHERE id = auth.uid()
      )
    )
  );
