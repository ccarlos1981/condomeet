-- ==============================================================================
-- Migration: 20260926080000_create_dependentes_canonical_foundation.sql
-- Module: Base Cadastral 360º — Gate 3G.2-A (Parte 1)
-- Scope: Tabela Canônica de Dependentes (Foundation Only)
-- ==============================================================================

CREATE TABLE public.dependentes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    condominio_id UUID NOT NULL REFERENCES public.condominios(id),
    unidade_id UUID NOT NULL REFERENCES public.unidades(id),
    responsavel_perfil_id UUID NOT NULL REFERENCES public.perfil(id),
    nome_completo TEXT NOT NULL,
    parentesco TEXT NOT NULL,
    data_nascimento DATE NOT NULL,
    foto_path TEXT NULL,
    observacao TEXT NULL,
    status TEXT NOT NULL DEFAULT 'ativo',
    perfil_convertido_id UUID NULL REFERENCES public.perfil(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- Constraints Locais
    CONSTRAINT chk_dependentes_nome_completo CHECK (length(trim(nome_completo)) >= 2),
    CONSTRAINT chk_dependentes_parentesco CHECK (parentesco IN (
        'filho',
        'conjuge_companheiro',
        'pai_mae',
        'enteado',
        'outro_familiar',
        'outro_dependente'
    )),
    CONSTRAINT chk_dependentes_status CHECK (status IN ('ativo', 'inativo')),
    CONSTRAINT chk_dependentes_data_nascimento CHECK (data_nascimento <= CURRENT_DATE),
    CONSTRAINT chk_dependentes_observacao CHECK (observacao IS NULL OR length(observacao) <= 500)
);

-- Comentários descritivos
COMMENT ON TABLE public.dependentes IS 'Tabela canônica de dependentes vinculados a residentes e unidades (Gate 3G.2-A)';
COMMENT ON COLUMN public.dependentes.id IS 'Identificador primário único do dependente';
COMMENT ON COLUMN public.dependentes.condominio_id IS 'Condomínio de lotação do dependente';
COMMENT ON COLUMN public.dependentes.unidade_id IS 'Unidade de moradia do dependente';
COMMENT ON COLUMN public.dependentes.responsavel_perfil_id IS 'Perfil do residente titular responsável pelo dependente';
COMMENT ON COLUMN public.dependentes.nome_completo IS 'Nome completo do dependente';
COMMENT ON COLUMN public.dependentes.parentesco IS 'Grau de parentesco (filho, conjuge_companheiro, pai_mae, enteado, outro_familiar, outro_dependente)';
COMMENT ON COLUMN public.dependentes.data_nascimento IS 'Data de nascimento do dependente (não futura)';
COMMENT ON COLUMN public.dependentes.foto_path IS 'Caminho da foto do dependente no Storage (se houver)';
COMMENT ON COLUMN public.dependentes.observacao IS 'Observações gerais com limite de 500 caracteres';
COMMENT ON COLUMN public.dependentes.status IS 'Status cadastral do dependente (ativo | inativo)';
COMMENT ON COLUMN public.dependentes.perfil_convertido_id IS 'ID do perfil caso o dependente seja convertido em morador independente';

-- Índice UNIQUE Parcial: Duplicidade Ativa (mesma unidade + mesmo nome normalizado + mesma data de nascimento)
CREATE UNIQUE INDEX idx_dependentes_unique_ativo_unidade_nome_nascimento 
ON public.dependentes (unidade_id, lower(trim(nome_completo)), data_nascimento) 
WHERE status = 'ativo';

-- Índice UNIQUE Parcial: Perfil Convertido (único quando preenchido)
CREATE UNIQUE INDEX idx_dependentes_unique_perfil_convertido 
ON public.dependentes (perfil_convertido_id) 
WHERE perfil_convertido_id IS NOT NULL;

-- Índices relacionais e operacionais
CREATE INDEX idx_dependentes_condominio_id ON public.dependentes(condominio_id);
CREATE INDEX idx_dependentes_unidade_id ON public.dependentes(unidade_id);
CREATE INDEX idx_dependentes_responsavel_perfil_id ON public.dependentes(responsavel_perfil_id);
CREATE INDEX idx_dependentes_status ON public.dependentes(status);
