# Documentação Técnica - Controle de Estoque (Almoxarifado)

Este documento descreve a arquitetura técnica, o esquema do banco de dados, as políticas de segurança e a estrutura do frontend para o módulo de **Controle de Estoque** (Almoxarifado) do Condomeet.

---

## 1. Visão Geral
O módulo de estoque permite que a administração do condomínio (síndicos, administradores, zeladores, porteiros, etc.) faça a gestão de materiais e ferramentas de uso interno. O sistema oferece:
- Controle de múltiplos espaços físicos de armazenamento (locais).
- Organização por categorias.
- Controle de quantidade atual, mínima (estoque crítico) e máxima por produto.
- Tipos de controle: Consumível (baixa definitiva), Retornável (empréstimo) ou Misto.
- Histórico completo de movimentações (entrada, saída, empréstimo, devolução, etc.).
- Anexo opcional de Notas Fiscais com armazenamento seguro em bucket privado.

---

## 2. Arquitetura do Banco de Dados

### 2.1. Tabelas (`public`)

#### `estoque_produtos`
Armazena as informações básicas de cada produto do estoque.
- `id` (uuid, PK)
- `condominio_id` (uuid, FK -> condominios)
- `local_id` (uuid, FK -> estoque_locais)
- `categoria_id` (uuid, FK -> estoque_categorias)
- `fornecedor_id` (uuid, FK -> fornecedores, opcional)
- `codigo` (text) - Código identificador gerado automaticamente via RPC.
- `nome` (text) - Nome do produto.
- `descricao` (text, opcional)
- `unidade` (text) - Unidade de medida (ex: unidade, litro, kg, rolo).
- `tipo_controle` (text) - `'consumivel'`, `'retornavel'` ou `'misto'`.
- `marca` (text, opcional)
- `quantidade_atual` (integer) - Quantidade em estoque.
- `quantidade_minima` (integer) - Nível de estoque crítico.
- `quantidade_maxima` (integer)
- `custo_unitario` (numeric) - Valor unitário médio do produto.
- `data_validade` (date, opcional)
- `ativo` (boolean) - Utilizado para **Soft Delete** (`ativo = false`).
- `created_at` / `updated_at` (timestamp with time zone)

#### `estoque_movimentacoes`
Registra todo o histórico de entradas e saídas físicas de mercadorias do estoque.
- `id` (uuid, PK)
- `condominio_id` (uuid, FK)
- `produto_id` (uuid, FK -> estoque_produtos)
- `tipo` (text) - Tipo de movimentação: `'entrada'`, `'saida'`, `'emprestimo'`, `'devolucao'`, `'ajuste'`, `'transferencia'`.
- `quantidade` (integer)
- `motivo` (text, opcional)
- `observacao` (text, opcional)
- `nota_fiscal_path` (text, opcional) - Caminho relativo do arquivo da nota fiscal no bucket de storage.
- `realizado_por` (uuid, FK -> perfil)
- `created_at` (timestamp with time zone)

---

## 3. Armazenamento e Notas Fiscais (Storage)

### 3.1. Configuração do Bucket
Os arquivos de Notas Fiscais são armazenados de forma segura em um bucket privado.
- **Nome do Bucket**: `estoque-notas`
- **Privacidade**: Privado (`public = false`).
- **Tamanho Limite**: 10 MB (`10.485.760` bytes).
- **Formatos Permitidos**: PDF (`application/pdf`), JPEG (`image/jpeg`), PNG (`image/png`).
- **Caminho de Armazenamento**: `estoque_notas/{condominio_id}/{timestamp}_{nome_do_arquivo}`

### 3.2. Fluxo de Segurança (Signed URLs)
Como o bucket é privado, o acesso direto à URL do arquivo falhará. Para visualização segura:
1. O frontend solicita uma **URL Assinada** temporária (Signed URL) com validade curta de 60 segundos.
2. O método `supabase.storage.from('estoque-notas').createSignedUrl(path, 60)` é executado no cliente ou servidor.
3. O navegador abre a Signed URL gerada em uma nova guia para visualização ou download do documento.

---

## 4. Segurança e Row Level Security (RLS)

### 4.1. Tabelas do Banco
O acesso às tabelas do estoque é restrito através da função auxiliar `has_estoque_access(p_condo_id)`:
```sql
CREATE OR REPLACE FUNCTION has_estoque_access(p_condo_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM perfil p 
    WHERE p.id = auth.uid() 
    AND p.condominio_id = p_condo_id
    AND (
      p.papel_sistema ILIKE '%síndico%' 
      OR p.papel_sistema ILIKE '%sindico%' 
      OR p.papel_sistema ILIKE '%admin%'
      OR p.papel_sistema ILIKE '%super_admin%'
      OR p.papel_sistema ILIKE '%zelador%'
      OR p.papel_sistema ILIKE '%funcionario%'
      OR p.papel_sistema ILIKE '%porteiro%'
    )
  );
END;
$$;
```
Cada política RLS nas tabelas `estoque_produtos`, `estoque_movimentacoes`, `estoque_locais` e `estoque_categorias` valida se o usuário possui acesso ao estoque daquele condomínio específico.

### 4.2. Storage RLS
Políticas RLS aplicadas à tabela `storage.objects` para o bucket `estoque-notas`:
- **INSERT**: Permitido para usuários autenticados (`WITH CHECK (bucket_id = 'estoque-notas')`).
- **SELECT**: Permitido para usuários autenticados para permitir a geração de Signed URLs (`USING (bucket_id = 'estoque-notas')`).
- **UPDATE** / **DELETE**: Permitido para atualização/exclusão dos anexos por usuários autenticados.

---

## 5. Implementação no Frontend (Next.js)

### 5.1. Componentes Principais (`web-app/app/admin/estoque/components/`)

- **`produtos-tab.tsx`**:
  - Exibe a listagem de produtos ativos (`ativo = true`).
  - Permite criar novos produtos.
  - Oferece opção de **Editar** (abre o modal com dados pré-carregados para atualizar no banco via `.update()`) e **Excluir** (executa soft delete alterando `ativo = false` no banco).
  
- **`entrada-saida-tab.tsx`**:
  - Interface para registrar novas movimentações (Entradas / Saídas).
  - Inclui input do tipo `file` para anexar nota fiscal opcionalmente.
  - Valida o tamanho (máx 10 MB) e o tipo MIME do arquivo antes do envio.
  - Envia o arquivo ao storage e armazena o caminho relativo `nota_fiscal_path` no banco de dados.

- **`movimentacoes-tab.tsx`**:
  - Exibe a tabela histórica de movimentações.
  - Apresenta a coluna **Nota Fiscal**:
    - Se anexada, exibe o botão `📄 Ver Nota` (gera Signed URL sob demanda e abre em nova aba) e um botão `🔄 Alterar` para substituir o documento.
    - Se ausente, exibe o botão `📎 Anexar` permitindo fazer o upload e vincular o documento diretamente à movimentação sem necessidade de recriá-la.
