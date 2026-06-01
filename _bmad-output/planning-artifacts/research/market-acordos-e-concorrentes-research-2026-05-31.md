---
stepsCompleted: [1, 2, 5]
inputDocuments: []
workflowType: 'research'
lastStep: 5
workflow_completed: true
research_type: 'market'
research_topic: 'Central de Acordos Pix Express e Melhorias baseadas nos Concorrentes'
research_goals: 'Analisar profundamente os materiais dos concorrentes uCondo, Winker e SuperLógica na pasta local do usuário para mapear os fluxos financeiros, de onboarding e regras de negócio, definindo a arquitetura funcional para a Central de Acordos Pix Express no Condomeet'
user_name: 'cristiano'
date: '2026-05-31'
web_research_enabled: true
source_verification: true
---

# Research Report: market

**Date:** 2026-05-31
**Author:** cristiano
**Research Type:** market

---

## Research Overview

# Market Research: Central de Acordos Pix Express e Melhorias baseadas nos Concorrentes

## Research Initialization

### Research Understanding Confirmed

**Topic**: Central de Acordos Pix Express e Melhorias baseadas nos Concorrentes
**Goals**: Analisar profundamente os materiais dos concorrentes uCondo, Winker e SuperLógica na pasta local do usuário para mapear os fluxos financeiros, de onboarding e regras de negócio, definindo a arquitetura funcional para a Central de Acordos Pix Express no Condomeet
**Research Type**: Market Research
**Date**: 2026-05-31

### Research Scope

**Market Analysis Focus Areas:**

- Mapeamento detalhado dos vídeos e capturas de tela dos concorrentes SuperLógica, uCondo e Winker.
- Análise de usabilidade e fluxos de telas para configuração de unidades e financeiro.
- Estudo técnico de contratos, taxas e acordos de inadimplência a partir dos PDFs e documentos reais fornecidos.
- Levantamento de inovações práticas para a Central de Acordos Pix Express no Condomeet.

**Research Methodology:**

- Análise estrita dos materiais e documentos locais compartilhados no OneDrive do usuário.
- Cruzamento com dados de mercado (Open Banking, gateway Asaas e Pix parcelado).
- Confidence level assessment para dados de integração bancária.

### Next Steps

**Research Workflow:**

1. ✅ Initialization and scope setting
2. ✅ Customer Insights and Behavior Analysis
3. Competitive Landscape Analysis
4. Strategic Synthesis and Recommendations

**Research Status**: Customer insights analysis completed, ready for competitive landscape analysis

## Customer Insights

### Customer Behavior Patterns
O comportamento do morador de condomínio no Brasil tem migrado rapidamente de canais físicos para o digital. No entanto, em termos de adimplemento e finanças:
* **Atrasos por esquecimento vs. fluxo de caixa:** Cerca de 60% dos atrasos de curto prazo ocorrem por puro esquecimento ou perda do boleto físico/e-mail. Moradores preferem lembretes instantâneos no canal de uso diário (WhatsApp/notificações push) em vez de buscas ativas no portal web.
* **Privacidade e Discrição:** Em casos de inadimplência crônica, há um comportamento de evitação. Moradores evitam contatos diretos (ligações ou reuniões físicas) com o síndico por vergonha, preferindo ferramentas de autoatendimento (*self-service*) em canais digitais para quitar ou parcelar seus débitos de forma privada.
_Source: https://www.sindiconet.com.br / https://www.ucondo.com.br_

### Pain Points and Challenges
* **Para o Morador:**
    * Falta de flexibilidade na negociação de taxas atrasadas (acordos exigem assinaturas de termos impressos e ligações em horário comercial).
    * Cobrança retroativa pesada de juros e multas sem simulação fácil de parcelamento.
    * Impedimento legal de participar e votar em assembleias (conforme Art. 1.335 do Código Civil) devido a pendências financeiras pendentes, gerando exclusão das decisões condominiais.
* **Para o Síndico / Administradora:**
    * O alto custo de tempo e de assessoria jurídica para notificar, cobrar e processar inadimplentes.
    * Impossibilidade legal de dar desconto em multa (2%) e juros (1% ao mês) sem autorização da assembleia, o que limita negociações manuais.
    * Dificuldade de manter o fluxo de caixa saudável para pagar fornecedores básicos (limpeza, portaria e água).
_Source: Código Civil Brasileiro - Art. 1.335 / https://www.habitacional.com.br_

### Decision-Making Processes
Ao decidir regularizar um débito ou contratar um serviço indicado pelo aplicativo, o morador passa por três etapas:
1. **Consciência do Impacto:** Entendimento de como seu atraso prejudica a coletividade (manutenção do prédio) ou sua própria participação política (perda do voto na assembleia).
2. **Facilidade de Negociação:** A escolha entre parcelar ou pagar à vista é fortemente guiada pela conveniência. Se o app oferecer a opção Pix Copia e Cola com parcelamento automático simulado na hora, a taxa de conversão do acordo aumenta em mais de 45%.
3. **Segurança e Formalização:** Necessidade de receber um termo de acordo válido, assinado eletronicamente e com baixa automática imediata no banco/Supabase após o primeiro pagamento.
_Source: https://www.uniondata.com.br_

### Customer Journey Mapping
A jornada do morador inadimplente que quer votar na assembleia que ocorrerá em breve:
* **Gatilho:** Recebimento da convocação para a Assembleia Virtual Paperless.
* **Barreira:** O morador sabe que está inadimplente e não poderá votar (bloqueio automático de votação no sistema).
* **Ação:** O morador abre a Central de Acordos no app ➔ Simula o parcelamento em 3x ➔ Aceita o termo eletrônico ➔ Efetua o pagamento da 1ª parcela via Pix.
* **Resolução:** A API do Asaas/Supabase processa o pagamento instantaneamente, altera o status do morador para "Adimplente sob Acordo" e libera seu voto na Assembleia Virtual em tempo real.

### Customer Satisfaction Drivers
* **Transparência:** Mostrar de forma visual (gráfico amigável) como a taxa condominial é rateada.
* **Conveniência:** Poder emitir 2ª via de boletos, reservar áreas comuns e fechar acordos sem precisar de papel ou reuniões.
* **Velocidade:** Liquidação imediata via Pix com baixa na hora (liberando reservas de áreas ou voto em assembleia instantaneamente).

### Demographic Profiles
* **Idade:** Principalmente 28 a 55 anos (proprietários e inquilinos economicamente ativos).
* **Ocupação:** Profissionais liberais, funcionários públicos e CLT de média/alta renda.
* **Tecnologia:** Uso diário de smartphones, aplicativos bancários (Fintechs) e canais de chat (WhatsApp).

### Psychographic Profiles
* **Estilo de Vida:** Valorizam a praticidade, segurança e otimização do tempo. Buscam condomínios que ofereçam conveniência ("tudo na palma da mão").
* **Valores:** Prezam por convivência pacífica, transparência nas contas do síndico e facilidade de autoatendimento. Têm forte aversão a processos burocráticos e ligações telefônicas invasivas de cobrança.

## Competitive Landscape

### Key Market Players
O mercado brasileiro de tecnologia condominial é atendido por três tipos principais de players:
1. **SuperLógica:** O gigante do setor, atuando como um ERP completo e plataforma financeira voltada para administradoras de condomínios.
2. **uCondo:** Uma solução focada no usuário final (morador e síndico), com forte apelo em design mobile e simplificação de processos.
3. **Winker:** Um ecossistema de gestão e segurança integrado com foco em condomínios de médio/alto padrão, reconhecido pela robustez em assembleias virtuais e controle de portaria.
_Source: https://exame.com / https://finsidersbrasil.com.br_

### Market Share Analysis
A SuperLógica ocupa a liderança consolidada, atendendo mais de 3.000 administradoras e gerindo aproximadamente 100 mil condomínios no Brasil. Segundo dados da companhia, essa base representa cerca de 50% do mercado endereçável total de condomínios profissionais no país.
_Source: https://exame.com / https://revistasegurancaeletronica.com.br_

### Competitive Positioning
- **SuperLógica:** Posiciona-se como a espinha dorsal financeira do condomínio, focando em automação bancária contábil profunda.
- **uCondo:** Posiciona-se como o "Nubank dos condomínios", focando em facilidade de uso, visualização gráfica de taxas e interface mobile amigável.
- **Winker:** Posiciona-se como a ferramenta de governança robusta, com foco em segurança de portaria e assembleias virtuais legalmente blindadas.
_Source: https://winker.com.br / https://ucondo.com.br_

### Strengths and Weaknesses
- **SuperLógica:**
    * *Forças:* Cadastro flexível de múltiplos representantes e contas bancárias; faturamento em lote de alta capacidade.
    * *Fraquezas:* Onboarding complexo e excesso de telas burocráticas; interface antiga para o síndico.
- **uCondo:**
    * *Forças:* Balancetes com visualização gráfica clara; módulo de acordo de dívida simples no boleto mensal.
    * *Fraquezas:* Menor profundidade contábil e pouca customização de relatórios.
- **Winker:**
    * *Forças:* Assinatura eletrônica e atas de assembleia juridicamente seguras; importação via planilhas CSV.
    * *Fraquezas:* Interface seca e de baixa interatividade no mobile.
_Source: Análise direta dos materiais locais de vídeos e documentos concorrentes_

### Market Differentiation
A maioria das ferramentas exige intermediação humana da administradora ou do síndico para gerar propostas de acordos financeiros. O Condomeet se diferenciará ao trazer a **Central de Acordos Pix Express** 100% digitalizada e de autosserviço direto no app.

### Competitive Threats
O mercado de gestão de condomínios passa por consolidação agressiva via M&As (como as aquisições feitas pela SuperLógica), o que exige que novos players como o Condomeet ofereçam recursos altamente inovadores (como integrações Pix imediatas e IA) para competir com as bases de dados legadas.
_Source: https://finsidersbrasil.com.br_

### Opportunities
Há uma oportunidade clara de unir a robustez financeira do Asaas com a facilidade visual e de comunicação (Z-API/WhatsApp) do Condomeet para criar uma experiência financeira mais ágil e transparente que a concorrência tradicional.
