# Changelog - Condomeet

Todos os marcos importantes, melhorias e correções feitas no projeto serão registrados neste histórico oficial.

---

## [2.1.0] - 2026-07-09
### Adicionado
- **Módulo de Controle de Estoque (Almoxarifado)**:
  - **Edição Completa de Produtos**: Habilidade de editar todas as propriedades do produto (espaço físico, categoria, fornecedor, quantidade inicial, estoques crítico e máximo, custo unitário, marca, descrição e validade) pela interface administrativa.
  - **Soft-Delete Seguro**: Exclusão lógica de produtos (`ativo = false`) para manter a integridade dos dados históricos no relatório de movimentações.
  - **Upload de Nota Fiscal**: Suporte opcional a anexo de Nota Fiscal (PDF, JPG, PNG de até 10 MB) nas movimentações de estoque.
  - **Gerenciamento de Notas no Histórico**: Opções de anexar nota a uma movimentação sem anexo ou alterar (substituir) o anexo de movimentações anteriores.
  - **Isolamento de Storage por Condomínio**: Bucket de storage privado (`public = false`) `estoque-notas` onde cada condomínio armazena seus arquivos em pastas isoladas (`estoque_notas/{condominio_id}/`).
  - **Políticas de RLS no Storage**: Regras aplicadas ao storage que impedem acesso cruzado ou uploads não autorizados entre condomínios.
  - **Visualização Segura (Signed URLs)**: Visualização segura dos anexos utilizando links temporários assinados válidos por 60 segundos gerados em tempo de execução.
  - **Coleta de Arquivos Órfãos**: Exclusão automática de arquivos antigos do Storage no momento em que uma Nota Fiscal é substituída no histórico.
  - **Documentação Técnica e Manual do Usuário**: Criada a documentação técnica [controle-estoque-tecnico.md](docs/controle-estoque-tecnico.md) e incluído um tutorial funcional na **Etapa 14** de [manual-sindico-web.html](docs/manual-sindico-web.html).

### Arquivos Modificados / Criados
- **Criado**: [supabase/migrations/20260710_add_nota_fiscal_to_estoque.sql](file:///Users/cristiano/Projetos/condomeet-v2/supabase/migrations/20260710_add_nota_fiscal_to_estoque.sql)
- **Criado**: [supabase/migrations/20260710_secure_estoque_storage_rls.sql](file:///Users/cristiano/Projetos/condomeet-v2/supabase/migrations/20260710_secure_estoque_storage_rls.sql)
- **Criado**: [docs/controle-estoque-tecnico.md](file:///Users/cristiano/Projetos/condomeet-v2/docs/controle-estoque-tecnico.md)
- **Modificado**: [web-app/app/admin/estoque/estoque-client.tsx](file:///Users/cristiano/Projetos/condomeet-v2/web-app/app/admin/estoque/estoque-client.tsx)
- **Modificado**: [web-app/app/admin/estoque/components/produtos-tab.tsx](file:///Users/cristiano/Projetos/condomeet-v2/web-app/app/admin/estoque/components/produtos-tab.tsx)
- **Modificado**: [web-app/app/admin/estoque/components/entrada-saida-tab.tsx](file:///Users/cristiano/Projetos/condomeet-v2/web-app/app/admin/estoque/components/entrada-saida-tab.tsx)
- **Modificado**: [web-app/app/admin/estoque/components/movimentacoes-tab.tsx](file:///Users/cristiano/Projetos/condomeet-v2/web-app/app/admin/estoque/components/movimentacoes-tab.tsx)
- **Modificado**: [docs/manual-sindico-web.html](file:///Users/cristiano/Projetos/condomeet-v2/docs/manual-sindico-web.html)
