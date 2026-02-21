## MVP Scope

### Core Features (Migração Completa do Bubble)

**ESPECIFICAÇÕES TÉCNICAS IMPORTANTES:**

**Arquitetura e Autenticação:**
- **Supabase Auth:** Aproveitar login/senha existente do Supabase
- **Senha numérica:** Permitir apenas números na troca de senha
- **Mobile-first:** 95% do uso é mobile (apps encapsulados para iOS/Android)
- **Futuro:** Migração para lojas oficiais (App Store/Google Play) com notificações push nativas

**Sistema de Perfis e Acessos:**
- **Perfis administrativos:** Síndico, Sub-síndico, Zelador, Administradora (customizável)
- **Controle granular:** Síndico define quem tem acesso a quais funcionalidades
- **Aprovação de novos usuários:** Cadastros ficam bloqueados até aprovação do síndico
- **Notificação de novo cadastro:** Todos os perfis administrativos recebem alerta via WhatsApp

---

**Funcionalidades Diárias (Uso Intenso):**

**1. Gestão de Encomendas**
- Registro de encomendas com foto pela portaria
- Notificações instantâneas via WhatsApp para moradores
- Visualização de encomendas pendentes
- Confirmação de retirada

**2. Autorizações de Visitantes**

**Fluxo Morador (via app):**
- Morador faz login → sistema identifica bloco/apto automaticamente
- Pré-cadastro de visitantes
- Notificação para portaria

**Fluxo Portaria (telefone):**
- Morador liga pedindo autorização
- Portaria cadastra visitante **informando bloco e apto manualmente**
- Sistema registra e notifica morador

**Consulta e Liberação:**
- Portaria consulta autorizações pendentes
- Liberação de acesso
- Histórico de visitas

---

**Funcionalidades Essenciais (Uso Regular):**

**3. Reserva de Espaços Comuns**

**Configuração pelo Síndico:**
- Cadastro de áreas comuns (salão de festa, churrasqueira, etc.)
- **Tipo de reserva:** Por hora OU dia inteiro
- **Status:** Ativo/Inativo
- **Regras de cobrança:**
  - Definir se cobra ou não
  - Valor da cobrança
  - Regra de quando cobra (ex: "a partir do 2º uso no ano", "a partir do 3º uso", etc.)
  
**Uso pelo Morador:**
- Reserva pelo app
- Lembretes automáticos via WhatsApp (1 dia antes)
- Visualização de disponibilidade
- Histórico de reservas

**4. Ocorrências Online**
- Registro de ocorrências com foto pelo morador
- Acompanhamento de status
- Resposta do síndico com histórico rastreável
- Notificações de atualização

**5. Fale Conosco (Comunicação Síndico-Morador)**
- Chat estilo WhatsApp entre morador e síndico
- Histórico de conversas
- Notificações de novas mensagens

**6. Botão SOS**
- Botão de emergência para moradores
- Alerta simultâneo a todos administradores
- Localização e identificação do solicitante

---

**Funcionalidades de Gestão (Síndico/Administração):**

**7. Dashboard Administrativo**
- Visão geral de encomendas, reservas, ocorrências
- Dados e estatísticas de uso
- Gestão de moradores e apartamentos
- **Aprovação de novos cadastros**

**8. Gestão de Acessos**
- Configuração de permissões por perfil (Síndico, Sub-síndico, Zelador, Adm)
- Cadastro de administradores
- Controle de acesso por perfil

**9. Controle de Estoque/Inventário**

**Tipos de Movimentação:**
- **Saída definitiva:** Produtos que saem do almoxarifado e não retornam (ex: material de limpeza consumível)
- **Saída temporária:** Produtos que saem e voltam (ex: vassoura, ferramentas)

**Funcionalidades:**
- Cadastro de itens do condomínio
- Controle de patrimônio
- Registro de entrada/saída com tipo de movimentação
- Alertas de manutenção

**10. Gestão Documental**

**Configuração de Alertas:**
- Upload e compartilhamento de documentos
- **Alertas de vencimento:** Síndico define quantos dias de antecedência quer ser avisado (ex: 30 dias, 60 dias)
- **Múltiplos alertas:** Opção de configurar 2 alertas diferentes (ex: 60 dias e 15 dias antes)
- Acesso controlado por perfil

**11. Assembleias Online**
- Criação de assembleias
- Votação online
- Registro de participação e resultados

**12. Comunicados**
- Envio de avisos gerais
- Taxa de leitura em tempo real
- Notificações via WhatsApp

---

**Infraestrutura e Integrações:**

**13. Sistema de Autenticação (Supabase)**
- **Migração:** Aproveitar login/senha existente do Supabase
- Login seguro (email/senha)
- **Senha numérica obrigatória:** Validação para aceitar apenas números
- QR Code para onboarding rápido
- Recuperação de senha

**14. Integração WhatsApp**
- API WhatsApp Business para notificações
- Templates de mensagens
- Envio de fotos e anexos

**15. Multi-plataforma (Mobile-First)**
- **Prioridade:** Apps mobile (95% do uso)
- **Atual:** Apps encapsulados para iOS/Android
- **Futuro (pós-MVP):** Publicação nas lojas oficiais com push notifications
- Web responsivo (5% do uso)

---

### Out of Scope for MVP (Versões Futuras)

**Versão 2.0:**

1. **Classificados (Intra-condomínio)**
   - Modelo OLX dentro do condomínio
   - Moradores anunciam produtos entre si
   - Opção de exibir no Marketplace (inter-condomínios)

2. **Marketplace (Inter-condomínios)**
   - Modelo Mercado Livre entre condomínios
   - Anúncios visíveis para moradores de outros condos
   - Anunciante escolhe se quer exibir além do próprio condomínio

3. **Indicação de Serviços com Avaliações**
   - Moradores indicam profissionais, lojas, empresas
   - **Sistema de avaliações:** Moradores avaliam serviços contratados
   - Ranking de prestadores
   - Reviews e comentários

4. **Enquetes Avançadas**
   - Funcionalidade básica de enquetes está no MVP
   - Recursos avançados (múltiplas opções, enquetes condicionais, análise de resultados) ficam para v2.0

5. **Passagem de Turno Digital**
   - Atualmente em desenvolvimento no Bubble
   - Será incluída em versão futura após validação

**Versão 4.0:**

6. **Serviços Terceirizados/IoT**
   - Abertura de cancela via QR code
   - Sensor de caixa d'água
   - Câmeras integradas
   - **Adiado para v4.0** conforme solicitado

7. **Clube de Benefícios**
   - Parcerias com estabelecimentos
   - Descontos para moradores

---

### MVP Success Criteria

**Critérios Técnicos:**

1. **Migração Supabase:** Todos os usuários existentes migrados sem necessidade de novo cadastro
2. **Mobile-first:** Apps funcionando perfeitamente em iOS e Android (95% dos casos de uso)
3. **Performance:** Notificações entregues em < 5 minutos (100% do tempo)
4. **Disponibilidade:** 99.5%+ uptime

**Critérios de Migração:**

5. **Migração dos 2 Condos Existentes:** Transição sem perda de dados ou funcionalidade
6. **Aprovação de Cadastros:** Sistema de aprovação funcionando sem fricção
7. **Satisfação dos Usuários Atuais:** < 5% de reclamações sobre funcionalidades faltantes
8. **Adoção Mantida:** 1.000+ moradores ativos migrados com sucesso

**Critérios de Crescimento:**

9. **Primeiro Condo Novo:** Onboarding de pelo menos 1 novo condomínio na plataforma refatorada
10. **Conversão Trial:** Manter taxa de 90% de conversão trial → pago

**Critérios de Decisão (Go/No-Go para Escala):**

- **GO:** Se migração for bem-sucedida + 1 novo condo aderir → Investir em marketing e crescimento
- **NO-GO:** Se houver problemas críticos na migração → Corrigir antes de escalar

---

### Future Vision (2-3 Anos)

**Marketplace e Economia Interna:**
- Classificados intra-condomínio (tipo OLX)
- Marketplace inter-condomínios (tipo Mercado Livre)
- Indicação de serviços com sistema robusto de avaliações
- Clube de benefícios com parcerias locais

**Automação e IoT (v4.0):**
- Integração com dispositivos (câmeras, sensores, cancelas)
- Automação de processos
- Smart building features

**Expansão de Mercado:**
- Condomínios comerciais, loteamentos, prédios corporativos
- Parcerias com administradoras (white-label)
- Construtoras (pré-instalação em novos empreendimentos)
- Escala nacional: 500+ condos, 50.000+ moradores

**Modelo de Negócio Evoluído:**
- SaaS (atual): Assinatura mensal por condomínio
- Marketplace: Comissão em transações de serviços
- Parcerias: Revenue share com clube de benefícios
- Enterprise: Licenciamento para grandes administradoras
