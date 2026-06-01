---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7]
inputDocuments:
  - _bmad-output/planning-artifacts/implementation_plan.md
---

# UX Design Specification: Financeiro & Administradoras

**Author:** cristiano
**Date:** 2026-05-25

---

<!-- UX design content will be appended sequentially through collaborative workflow steps -->

## Executive Summary

### Project Vision
Transformar o Condomeet em uma plataforma Multi-Tenant capaz de escalar para Administradoras profissionais. O design deve equilibrar a complexidade de um ERP financeiro (Plano de Contas, DRE, Split de Pagamento) com uma interface minimalista e fluida que já é a assinatura do aplicativo.

### Target Users
- **Funcionário da Administradora (O Especialista):** Precisa de velocidade para alternar entre condomínios (Dropdown Global) e ferramentas robustas para lançar despesas no DRE hierárquico.
- **Síndico (O Gestor):** Precisa aprovar orçamentos e ter previsibilidade visual de metas financeiras.
- **Morador (O Pagador):** Precisa de extrema transparência. Seu principal ponto de contato é a tela de Boletos e o PDF gerado (Boleto + Balancete detalhado do rateio).

### Key Design Challenges
- **Contexto Multi-Tenant:** Garantir que o funcionário saiba exatamente em qual condomínio ele está operando ao usar o Dropdown.
- **Hierarquia de Dados (DRE):** Exibir um Plano de Contas complexo de forma elegante e recolhível.
- **Isolamento de Feature Flag:** Garantir que o design dessas novas telas seja exclusivo para aprovação interna.

### Design Opportunities
- **Gratificação Instantânea (PIX):** Animações de sucesso na tela do morador no exato segundo em que o Webhook do banco avisar que o PIX foi pago.
- **PDF de Transparência:** Um documento visualmente lindo que reduz fricção e chamados de suporte.

## Core User Experience

### Defining Experience
A experiência principal do módulo financeiro é a **"Visão Limpa" (Clear Sight)**. A transparência é o nosso produto principal, garantindo que administradoras e moradores sempre tenham o contexto correto de forma imediata.

### Platform Strategy
- **Web Admin (Desktop):** Principal plataforma para Administradoras e Síndicos, focada em densidade de dados e velocidade de preenchimento (DRE/Livro Caixa).
- **Mobile App/Web (Moradores):** Foco no botão de pagamento PIX e gráficos simplificados. O PDF de Transparência será **100% Mobile-Friendly**, otimizado para telas pequenas e WhatsApp.

### Effortless Interactions
- **Troca de Contexto:** Ao alterar o Condomínio no "Dropdown Global", o sistema exibe imediatamente **Skeleton Loadings** visuais (evitando congelamento) e os dados são atualizados em milissegundos.
- **Pagamento em 1 Toque:** Push notification de "Boleto Gerado" permite copiar código PIX sem atrito.

### Critical Success Moments
- **O "Ping" de Pagamento (PIX):** O webhook aciona uma animação de "Pago" na tela do morador instantaneamente.
- **Fechamento do Mês:** Geração em lote de boletos precisos (com taxa, água, gás e multas discriminadas) em poucos cliques.

### Experience Principles
- **Contexto Acima de Tudo:** O Dropdown Global é absoluto, isolando os condomínios visualmente para evitar erros humanos.
- **Contabilidade sem Dor:** UI em árvore expansível para o DRE, amigável para leigos e poderosa para contadores.

## Desired Emotional Response

### Primary Emotional Goals
- **Para o Morador:** *Paz de Espírito (Peace of Mind).* Sentir que não está sendo enganado e que o pagamento do condomínio é transparente, seguro e justo.
- **Para a Administradora/Síndico:** *Controle Absoluto (Absolute Control).* O sentimento de que a ferramenta trabalha para eles, e não o contrário.

### Emotional Journey Mapping
1. **O Primeiro Contato (Administradora):** *Surpresa agradável.* Ao olhar para o DRE, veem uma tela limpa e espaçada em vez de uma planilha assustadora do Excel.
2. **Durante a Ação Crítica (Síndico):** *Confiança.* Ao apertar "Gerar Boletos do Mês", o sistema passa segurança de que a água, o gás e as multas foram atrelados corretamente.
3. **Pós-Ação (Morador):** *Alívio e Gratidão.* O morador paga o PIX, o app dá um feedback visual imediato eliminando a ansiedade.

### Micro-Emotions
- **Confiança vs. Ansiedade:** A clareza no "PDF de Transparência" elimina a ansiedade do morador sobre o valor da cota.
- **Realização vs. Frustração:** O "Skeleton Loading" instantâneo ao trocar de condomínio no Dropdown gera a sensação de realização rápida.

### Design Implications
- **Confiança:** Micro-animações (Check verde pulsante) ativadas imediatamente via Webhook após o pagamento PIX.
- **Paz de Espírito:** Cores neutras (branco, cinzas suaves) no DRE para reduzir a carga cognitiva de funcionários em uso contínuo.

### Emotional Design Principles
- **"Zero Surpresas":** A transparência financeira deve ser tão óbvia na interface que o usuário nunca precisa se perguntar "De onde veio esse valor?".

## UX Pattern Analysis & Inspiration

### Inspiring Products Analysis
- **Superlógica:** Referência no mercado imobiliário. Dominam a exibição hierárquica (gasto por linha) e a previsibilidade. O boleto é um documento que informa, não apenas cobra.
- **Nubank (Conta PJ):** Referência em exibir dados financeiros complexos de forma leve, usando muito "white space" e tipografia amigável.

### Transferable UX Patterns
- **Tree Grids (Tabelas em Árvore Expansíveis):** Padrão perfeito para o "Plano de Contas" (clicar em "2.0.0 Energia" para expandir "2.0.1 Energia X").
- **Split-View Navigation (Visão Dividida):** Para as Administradoras, um painel lateral fixo onde ela pesquisa o condomínio, e o conteúdo na direita muda instantaneamente.

### Anti-Patterns to Avoid
- **"A Armadilha do Excel":** Tentar espremer 25 colunas na mesma tela, criando tabelas horríveis e difíceis de ler. Esconder dados secundários atrás de "Ver detalhes".
- **Ações Escondidas:** O botão de "Gerar Boletos" ou "Aprovar Fechamento" nunca deve estar escondido; deve ser o Call to Action primário da tela no fim do mês.

### Design Inspiration Strategy
- **Adotar:** A transparência brutal do PDF da Superlógica (balancete detalhado junto ao boleto).
- **Adaptar:** A estética "Fintech" moderna do Nubank para dentro do painel Web Admin de condomínios.
- **Evitar:** Estética "ERP dos anos 90" (telas cinzas, botões minúsculos, fontes serrilhadas).

## Design System Foundation

### Design System Choice
**Shadcn UI + Tailwind CSS (Custom Fintech Theme)**

### Rationale for Selection
- **Flexibilidade Total:** Como a inspiração é a estética leve do Nubank, frameworks engessados limitam o design. O Shadcn fornece os componentes acessíveis brutos para vestirmos com a marca Condomeet.
- **Componentes Financeiros Nativos:** Acesso a Data Tables ricas e Menus de Comando (tipo Spotlight) essenciais para o "Dropdown Global" de condomínios.
- **Performance (Zero Lag):** Integração nativa com Next.js (React), permitindo transições e Skeleton Loadings instantâneos sem renderização pesada.

### Implementation Approach
Extração e implementação dos componentes críticos do Shadcn UI (Data Tables, Command Palettes, Modals) diretamente no repositório Web do Condomeet. O tema base usará escalas de cor "Zinc" no lugar de cinzas duros para modernizar a paleta neutra.

### Customization Strategy
- **Uso Restrito da Cor da Marca:** O Laranja/Vermelho (`#FA542F`) será altamente focado. Ele será reservado apenas para botões de Call to Action críticos (ex: `[ Aprovar Fechamento de Boletos ]`), evitando poluição visual nas telas de dados densos do DRE.

## Mecânica da Experiência (O Fechamento do Mês)

### A Experiência Definidora
**A "Geração em Lote Transparente".** Se acertarmos a forma como o Síndico gera os 100 boletos do mês, com o rateio automático de água, gás e multas em apenas 3 cliques, nós vencemos o jogo da usabilidade.

### Modelo Mental do Usuário (Síndico)
- *A Dor:* "Será que esqueci de cobrar a água do apto 202? Será que a multa do 501 entrou?"
- *A Solução:* "O sistema já calculou tudo. Eu só preciso revisar o resumo e apertar um botão."

### A Mecânica Passo a Passo (Geração em Lote)
1. **Iniciação:** Na tela de Faturamento, o Síndico clica no botão Primário `[ Fechar Mês e Gerar Boletos ]`.
2. **Interação (O Resumo):** Um Modal desliza na tela mostrando um *Card de Confiança* com os totais de despesas, rateio de consumos extras e a Taxa de Split de 3% pré-calculada.
3. **Ação:** O Síndico clica em `[ Confirmar e Emitir ]`.
4. **Feedback (A Mágica):** Uma barra de progresso elegante aparece ("Emitindo 1 de 100...").
5. **Conclusão:** Tela de Sucesso com micro-animação e a mensagem de que os boletos foram enviados para o App dos moradores.
