-- # Epic 8: Reestruturação do Banco de Dados (Schema 2.0)

-- 1. Tabela de Condomínios
CREATE TABLE IF NOT EXISTS condominios (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nome TEXT NOT NULL,
    apelido TEXT UNIQUE, -- Sem acentos, para URLs/identificação fácil
    cnpj TEXT,
    cep TEXT,
    logradouro TEXT,
    bairro TEXT,
    numero TEXT,
    complemento TEXT,
    cidade TEXT,
    estado TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Tabela de Blocos
CREATE TABLE IF NOT EXISTS blocos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    condominio_id UUID NOT NULL REFERENCES condominios(id) ON DELETE CASCADE,
    nome_ou_numero TEXT NOT NULL, -- 'A', '1', 'Bloco Norte', etc.
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(condominio_id, nome_ou_numero)
);

-- 3. Tabela de Apartamentos/Casas
CREATE TABLE IF NOT EXISTS apartamentos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    condominio_id UUID NOT NULL REFERENCES condominios(id) ON DELETE CASCADE,
    numero TEXT NOT NULL, -- '101', 'Casa 5', etc.
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(condominio_id, numero)
);

-- 4. Tabela de Unidades (Vínculo Bloco + Apartamento)
CREATE TABLE IF NOT EXISTS unidades (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    condominio_id UUID NOT NULL REFERENCES condominios(id) ON DELETE CASCADE,
    bloco_id UUID NOT NULL REFERENCES blocos(id) ON DELETE CASCADE,
    apartamento_id UUID NOT NULL REFERENCES apartamentos(id) ON DELETE CASCADE,
    bloqueada BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(condominio_id, bloco_id, apartamento_id)
);

-- 5. Tabela de Perfil (Substitui 'profiles')
CREATE TABLE IF NOT EXISTS perfil (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    condominio_id UUID REFERENCES condominios(id) ON DELETE SET NULL,
    nome_completo TEXT NOT NULL,
    whatsapp TEXT,
    whatsapp_msg_consent BOOLEAN DEFAULT TRUE,
    bloqueado BOOLEAN DEFAULT FALSE,
    status_aprovacao TEXT DEFAULT 'pendente', -- 'pendente', 'aprovado', 'rejeitado'
    tipo_morador TEXT, -- 'Proprietário', 'Inquilino', 'Cônjuge', etc.
    papel_sistema TEXT DEFAULT 'Morador', -- 'ADMIN', 'Síndico', 'Porteiro', etc.
    bloco_txt TEXT, -- Denormalizado para busca rápida na portaria
    apto_txt TEXT,  -- Denormalizado para busca rápida na portaria
    fcm_token TEXT,
    botconversa_id TEXT,
    historico_status JSONB DEFAULT '[]', -- Armazena [{data, status, responsavel_id, motivo}]
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Tabela de Vínculo Perfil <-> Unidade
CREATE TABLE IF NOT EXISTS unidade_perfil (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    perfil_id UUID NOT NULL REFERENCES perfil(id) ON DELETE CASCADE,
    unidade_id UUID NOT NULL REFERENCES unidades(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(perfil_id, unidade_id)
);

-- 7. Tabelas Funcionais (Nomes em Português)

-- Encomendas
CREATE TABLE IF NOT EXISTS encomendas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    resident_id UUID NOT NULL REFERENCES perfil(id),
    condominio_id UUID NOT NULL REFERENCES condominios(id),
    status TEXT DEFAULT 'pending',
    arrival_time TIMESTAMPTZ DEFAULT NOW(),
    delivery_time TIMESTAMPTZ,
    photo_url TEXT,
    pickup_proof_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Convites
CREATE TABLE IF NOT EXISTS convites (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    resident_id UUID NOT NULL REFERENCES perfil(id),
    condominio_id UUID NOT NULL REFERENCES condominios(id),
    guest_name TEXT NOT NULL,
    validity_date TIMESTAMPTZ NOT NULL,
    qr_data TEXT,
    status TEXT DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- SOS Alertas
CREATE TABLE IF NOT EXISTS sos_alertas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    resident_id UUID NOT NULL REFERENCES perfil(id),
    condominium_id UUID NOT NULL REFERENCES condominios(id),
    latitude REAL,
    longitude REAL,
    status TEXT DEFAULT 'active',
    acknowledged_by UUID REFERENCES perfil(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Ocorrências
CREATE TABLE IF NOT EXISTS ocorrencias (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    resident_id UUID NOT NULL REFERENCES perfil(id),
    condominium_id UUID NOT NULL REFERENCES condominios(id),
    description TEXT,
    category TEXT,
    status TEXT DEFAULT 'pending',
    photo_paths TEXT[], -- Array de paths
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Reservas de Áreas Comuns
CREATE TABLE IF NOT EXISTS reservas_areas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    condominio_id UUID NOT NULL REFERENCES condominios(id),
    area_id UUID NOT NULL, -- UUID da área comum
    resident_id UUID NOT NULL REFERENCES perfil(id),
    booking_date DATE NOT NULL,
    status TEXT DEFAULT 'confirmed',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Documentos
CREATE TABLE IF NOT EXISTS documentos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    condominio_id UUID NOT NULL REFERENCES condominios(id),
    title TEXT NOT NULL,
    category TEXT,
    file_url TEXT,
    file_extension TEXT,
    upload_date TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. Inventário e Assembleias

CREATE TABLE IF NOT EXISTS itens_inventario (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    condominio_id UUID NOT NULL REFERENCES condominios(id) ON DELETE CASCADE,
    nome TEXT NOT NULL,
    descricao TEXT,
    categoria TEXT,
    quantidade_atual INTEGER NOT NULL DEFAULT 0,
    quantidade_minima INTEGER DEFAULT 0,
    eh_consumivel BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS transacoes_inventario (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    item_id UUID NOT NULL REFERENCES itens_inventario(id) ON DELETE CASCADE,
    perfil_id UUID REFERENCES perfil(id),
    tipo_transacao TEXT NOT NULL, -- 'in', 'out_permanent', 'out_temporary', 'return'
    quantidade INTEGER NOT NULL,
    notas TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS assembleias (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    condominio_id UUID NOT NULL REFERENCES condominios(id) ON DELETE CASCADE,
    titulo TEXT NOT NULL,
    descricao TEXT,
    data_inicio TIMESTAMPTZ NOT NULL,
    data_fim TIMESTAMPTZ NOT NULL,
    status TEXT DEFAULT 'draft',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS opcoes_assembleia (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    assembleia_id UUID NOT NULL REFERENCES assembleias(id) ON DELETE CASCADE,
    titulo TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS votos_assembleia (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    assembleia_id UUID NOT NULL REFERENCES assembleias(id) ON DELETE CASCADE,
    opcao_id UUID NOT NULL REFERENCES opcoes_assembleia(id) ON DELETE CASCADE,
    perfil_id UUID NOT NULL REFERENCES perfil(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(assembleia_id, perfil_id)
);
