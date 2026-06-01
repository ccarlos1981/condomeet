---
stepsCompleted: [1, 2, 3, 4]
inputDocuments:
  - _bmad-output/planning-artifacts/prd.md
  - _bmad-output/planning-artifacts/architecture.md
  - _bmad-output/planning-artifacts/architecture-mvp-phase1.md
  - _bmad-output/planning-artifacts/ux-design-specification.md
  - _bmad-output/planning-artifacts/ux-design-financeiro.md
---

# condomeet - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for condomeet, decomposing the requirements from the PRD, UX Design if it exists, and Architecture requirements into implementable stories.

## Requirements Inventory

### Functional Requirements

- **FR1**: Porteiro can register incoming parcels and capture a verification photograph within 3 seconds using the native camera bridge.
- **FR2**: Porteiro can find resident records within 1 second by typing queries into a predictive fuzzy search interface.
- **FR3**: Resident can receive automated WhatsApp notifications containing the parcel photo immediately after porteiro registration.
- **FR4**: Resident can receive a parallel Push Notification if the system detects that WhatsApp delivery confirmation exceeds 15 seconds.
- **FR5**: Resident can confirm parcel collection via either WhatsApp quick reply or the mobile application.
- **FR6**: Resident can generate and share temporary digital access credentials (QR Codes/alphanumeric tokens) for visitors.
- **FR7**: User can trigger a high-priority SOS emergency alert that simultaneously sends push notifications to administrators and highlights the gate console.
- **FR8**: Administrator can send targeted announcements to specific condominium blocks or the entire property.
- **FR9**: Resident can register maintenance or security occurrences and attach up to 3 photographs.
- **FR10**: Resident can send direct messages to the administration team through a real-time "Fale Conosco" chat channel.
- **FR11**: Resident can view common area calendars and request bookings for specific date or hourly time slots.
- **FR12**: Administrator can configure common area booking rules, including tiered pricing policies (e.g., first 2 bookings free) and monthly booking frequency limits.
- **FR13**: Administrator can upload, categorize, and control access to secure condominium documents using role-based access control (RBAC) levels.
- **FR14**: Síndico can approve or reject resident onboarding registration requests.
- **FR15**: Resident can authenticate into the application using a secure 6-digit PIN password or legacy credential matching (username/password lookup in legacy users table).
- **FR16**: Resident can view overdue fees, simulate installment options, and sign legally binding digital agreement terms using mobile biometrics (FaceID/TouchID).
- **FR17**: Resident can copy the Pix "Copia e Cola" code or scan a generated QR Code for the initial installment payment.
- **FR18**: Resident can have their status updated to "Adimplente sob Acordo" within 60 seconds after Asaas gateway confirms payment completion via webhook.
- **FR19**: Síndico can define financial rules (interest rates, penalty fees, maximum installment counts) for debt negotiations via the admin panel.
- **FR20**: Síndico Profissional can switch the dashboard context between multiple managed condominiums in under 3 seconds using a header dropdown selector.
- **FR21**: Síndico Profissional can view aggregated and per-condominium collection and delinquency metrics.
- **FR22**: Resident can cast digital votes on assembly items and sign proxy representation terms using ICP-Brasil standard digital certificates or automated platform signatures.
- **FR23**: Resident can have their voting eligibility automatically locked or unlocked in real-time based on their financial adimplência status (in compliance with Brazilian Civil Code Art. 1.335).
- **FR24**: Resident can approve unexpected visitors with a single tap using interactive WhatsApp buttons sent to their registered number.
- **FR25**: Administrator can view a secure audit trail logging all Pix agreements generated, payments confirmed, and corresponding changes to user voting eligibility.

### NonFunctional Requirements

- **NFR1**: System shall maintain server response times < 300ms for the 95th percentile, as measured by cloud application monitoring tools (APM), under concurrent loads of up to 10,000 active requests.
- **NFR2**: System shall return local metadata search results in < 100ms, as measured by client-side profiling logs, during active searches.
- **NFR3**: Mobile application shall maintain a stable frame rate of 60fps, as measured by standard OS frame rendering tools, during all screen transitions and scroll gestures.
- **NFR4**: Mobile application shall achieve cold boot-to-interactive times < 2 seconds, as measured by device startup profiling, upon application launch.
- **NFR5**: SOS and Portaria services shall maintain a 99.9% monthly uptime, as measured by uptime monitoring alerts, to ensure continuous resident safety.
- **NFR6**: SOS emergency notifications shall bypass silent/Do-Not-Disturb modes on iOS and Android devices, as verified by automated push notification tests, utilizing native Critical Alerts permission certificates.
- **NFR7**: Portaria terminal shall support full offline record creation and synchronize data with the cloud database within 10 seconds of reconnection, as measured by connectivity state testing.
- **NFR8**: System shall encrypt all personal identification documents and financial records at rest using AES-256 and in transit using TLS 1.3, as verified by automated vulnerability scans.
- **NFR9**: System shall enforce LGPD compliance by automatically deleting visitor and parcel images 90 days after registration and providing a self-service account deletion mechanism, as verified by daily system cron audits.
- **NFR10**: System shall sync Asaas webhooks to the frontend assembly voting screen in < 5 seconds, as measured by end-to-end integration testing, to enable immediate voting rights restore.
- **NFR11**: Web dashboard shall load context for a different condominium in < 3 seconds, as measured by browser network diagnostics, upon selector change.

### Additional Requirements

- **Architecture/Technical Setup:**
  - Base stack: Flutter (Mobile Client), Next.js (Web Admin Panel), Supabase (Auth, Database, Storage).
  - Sync Layer: PowerSync (SQLite-to-Postgres sync layer) - local-first data sync.
  - Background Logic: Supabase Edge Functions in Deno.
  - WhatsApp Provider: Z-API or Evolution API.
  - Payment Gateway: Asaas Integration.
  - Webhook security: Cryptographic signature validation for Asaas webhooks.
  - Tenancy security: Custom claims/roles and Postgres RLS with an Administradora Bypass role for professional managers.
  - Audit logs: Append-only immutable tables for agreements and electoral updates.
- **UX/UI Design Constraints:**
  - Admin dashboard layout: optimized for 1920x1080 resolution, responsive down to 1024x768 viewports without horizontal scrolling.
  - Browser matrix support: Chrome, Firefox (latest 3), Safari, Edge (latest 2).
  - Accessibility: WCAG 2.1 AA compliance (keyboard navigation + screen readers).
  - SEO: Authenticated-only application, indexation disabled via Robots meta tags (noindex, nofollow).

### FR Coverage Map

- **FR1**: Epic 2 - Guariteiro Relâmpago (Rapid parcel registration)
- **FR2**: Epic 2 - Guariteiro Relâmpago (Fuzzy search of residents)
- **FR3**: Epic 2 - Guariteiro Relâmpago (WhatsApp alert with photo)
- **FR4**: Epic 2 - Guariteiro Relâmpago (Fallback native push alert)
- **FR5**: Epic 3 - Ciclo de Vida da Encomenda (Pickup confirmation)
- **FR6**: Epic 4 - Portões Abertos (Generate access invitations)
- **FR7**: Epic 5 - Escudo & Voz (High-priority SOS alert)
- **FR8**: Epic 5 - Escudo & Voz (Broadcast announcements)
- **FR9**: Epic 5 - Escudo & Voz (Register occurrence with photos)
- **FR10**: Epic 5 - Escudo & Voz (Fale Conosco direct chat)
- **FR11**: Epic 6 - Vida em Comum (View availability and book common areas)
- **FR12**: Epic 6 - Vida em Comum (Configure booking rules and limits)
- **FR13**: Epic 6 - Vida em Comum (Manage secure documents)
- **FR14**: Epic 4 - Portões Abertos (Resident onboarding validation)
- **FR15**: Epic 1 - Fundação & Identidade (OTP + PIN Authentication)
- **FR16**: Epic 7 - Central de Acordos Pix Express (Simulate debt agreement)
- **FR17**: Epic 7 - Central de Acordos Pix Express (Pix payment methods)
- **FR18**: Epic 7 - Central de Acordos Pix Express (Auto-unlock voting rights < 60s)
- **FR19**: Epic 7 - Central de Acordos Pix Express (Configure financial rules)
- **FR20**: Epic 8 - Dashboard Multi-condomínio (Context switching < 3s)
- **FR21**: Epic 8 - Dashboard Multi-condomínio (Aggregated metrics dashboard)
- **FR22**: Epic 9 - Assembleias Paperless (Cast votes and sign proxy terms)
- **FR23**: Epic 9 - Assembleias Paperless (Electoral compliance auto-eligibility)
- **FR24**: Epic 4 - Portões Abertos (WhatsApp Guest Express check-in)
- **FR25**: Epic 7 & 9 - Central de Acordos & Assembleias (Immutable audit log)

## Epic List

### Epic 1: Fundação & Identidade (The Entryway)
Configuração do motor técnico (Supabase/PowerSync) e sistema de autenticação ultra-rápido via WhatsApp OTP + PIN.
**FRs cobertos:** FR15

### Epic 2: Guariteiro Relâmpago (Operating the Gate)
Implementação do scanner OCR e busca fuzzy local para registro de encomendas em menos de 15 segundos.
**FRs cobertos:** FR1, FR2, FR3, FR4

### Epic 3: Ciclo de Vida da Encomenda (Closing the Loop)
Gerenciamento de retiradas e confirmações, garantindo que o morador e o porteiro tenham visibilidade total do status.
**FRs cobertos:** FR5

### Epic 4: Portões Abertos (Access & Trust)
Sistema de convites digitais, liberação rápida e fluxo de aprovação de novos moradores.
**FRs cobertos:** FR6, FR14, FR24

### Epic 5: Escudo & Voz (SOS & Community)
Módulos críticos de segurança (SOS de alta prioridade) e canais de comunicação direta (Comunicados/Chat).
**FRs cobertos:** FR7, FR8, FR9, FR10

### Epic 6: Vida em Comum (Governance & Facilities)
Gestão de reservas de áreas comuns com regras automatizadas e visualização de documentos administrativos.
**FRs cobertos:** FR11, FR12, FR13

### Epic 7: Central de Acordos Pix Express (Financial Recovery)
Renegociação de inadimplência com simulação de parcelamento, geração de Pix Asaas e log imutável de auditoria.
**FRs cobertos:** FR16, FR17, FR18, FR19, FR25 (Auditoria Contábil)

### Epic 8: Dashboard Multi-condomínio (Professional Management)
Painel unificado para síndicos profissionais com troca rápida de contexto e indicadores consolidados de cobrança.
**FRs cobertos:** FR20, FR21

### Epic 9: Assembleias Paperless (Electoral & Compliance)
Votação digital secreta, procurações eletrônicas, integração Jitsi/vídeo e sincronização instantânea de elegibilidade eleitoral (Art. 1.335 do CC).
**FRs cobertos:** FR22, FR23, FR25 (Auditoria Eleitoral)

---

## Epic 1: Fundação & Identidade (The Entryway)

Configuração do motor técnico (Supabase/PowerSync) e sistema de autenticação ultra-rápido via WhatsApp OTP + PIN.

### Story 1.1: Inicialização do Projeto & Design System
**[STATUS: JÁ IMPLEMENTADO]**

As a developer,
I want to initialize the Flutter project with a custom theme and Tailwind UI tokens,
So that all features have a consistent and premium "Tranquilidade" look and feel.

**Acceptance Criteria:**

**Given** a new Flutter project structure
**When** I configure the `ThemeData` based on the UX specification
**Then** the app should use the brand Orange-Red (`#FA542F`) for primary actions
**And** custom widgets (Buttons, Inputs) should match the Tailwind UI style.

### Story 1.2: Schema Multi-Condomínio (Postgres + RLS)
**[STATUS: JÁ IMPLEMENTADO]**

As a system,
I want to establish the core database schema with Row Level Security (RLS) policies,
So that data isolation between condominiums is enforced at the database level.

**Acceptance Criteria:**

**Given** a Supabase project connection
**When** the `condominios` and `perfil` tables are created
**Then** RLS policies must prevent a user from one `condominio_id` from reading data from another
**And** all subsequent tables must inherit this isolation pattern.

### Story 1.3: Termos de Uso & Consentimento LGPD
**[STATUS: JÁ IMPLEMENTADO]**

As a user (Resident or Porter),
I want to review and accept the Terms of Use and Privacy Policy (LGPD) during the first login,
So that I know my personal data is being handled securely and legally.

**Acceptance Criteria:**

**Given** a user attempting to log in for the first time
**When** the app detects no prior consent record
**Then** a modal/screen with the Terms of Use and LGPD consent checkbox must be displayed
**And** the login flow must be blocked until the user explicitly accepts.

### Story 1.4: Solicitação de Acesso via WhatsApp (OTP)
**[STATUS: JÁ IMPLEMENTADO]**

As a user,
I want to receive an OTP code via WhatsApp,
So that I can verify my identity without remembering complex passwords.

**Acceptance Criteria:**

**Given** a valid phone number entered in the login screen
**When** I tap "Enviar Código"
**Then** a 6-digit OTP should be sent via the WhatsApp provider (Z-API/Evolution)
**And** the app should navigate to the verification screen.

### Story 1.5: PIN de Acesso & Login Persistente
**[STATUS: JÁ IMPLEMENTADO]**

As a verified user,
I want to set up a 6-digit PIN and enable biometrics,
So that future app entries are instantaneous.

**Acceptance Criteria:**

**Given** a successfully verified OTP session
**When** I set a numeric PIN in the security screen
**Then** the app must encrypt the local session key
**And** subsequent entries should allow "FaceID/TouchID" or "PIN" entry to unlock.

---

## Epic 2: Guariteiro Relâmpago (Operating the Gate)

Implementação do scanner OCR e busca fuzzy local para registro de encomendas em menos de 15 segundos.

### Story 2.1: Busca Preditiva de Moradores (Offline)
**[STATUS: JÁ IMPLEMENTADO]**

As a porter,
I want to find residents instantly by typing unit numbers or names,
So that I can register parcels without manually browsing long lists.

**Acceptance Criteria:**

**Given** a local cache of residents synchronized via PowerSync
**When** I enter a partial unit number (e.g., "10")
**Then** the UI must display a list of matching units and residents in < 100ms
**And** the first result should show the resident's photo for visual confirmation.

### Story 2.2: Scanner OCR de Etiquetas (ML Kit)
**[STATUS: JÁ IMPLEMENTADO]**

As a porter,
I want to scan package labels using the device camera,
So that I can extract the unit number without manual typing.

**Acceptance Criteria:**

**Given** the camera module active
**When** I point it at a delivery label
**Then** the Google ML Kit must detect and highlight the unit number
**And** a "Flash" toggle must be available for low-light scans
**And** if scanning takes > 2s, the manual search field must be automatically focused as fallback.

### Story 2.3: Registro de Encomenda (Local-First)
**[STATUS: JÁ IMPLEMENTADO]**

As a porter,
I want to register a parcel with a single tap,
So that I can clear the gate queue immediately.

**Acceptance Criteria:**

**Given** a selected resident and optional package photo
**When** I tap "Registrar Encomenda"
**Then** the UI must show a success checkmark and vibrate (Haptic) INSTANTLY
**And** the record must be saved to the local SQLite (PowerSync) for background sync.

### Story 2.4: Orquestração de Alerta WhatsApp
**[STATUS: JÁ IMPLEMENTADO]**

As a system,
I want to trigger a WhatsApp notification with the parcel photo,
So that the resident is immediately informed of the arrival.

**Acceptance Criteria:**

**Given** a new parcel record in the database
**When** the record is synced to Supabase
**Then** a Supabase Edge Function must send a WhatsApp message to the resident
**And** the message must include the package photo and a pickup notification.

### Story 2.5: Fallback de Notificação Push
**[STATUS: JÁ IMPLEMENTADO]**

As a system,
I want to send a native push notification if WhatsApp fails,
So that the resident receives the alert even if they are offline on WhatsApp.

**Acceptance Criteria:**

**Given** a sent WhatsApp notification
**When** no delivery confirmation is received within 15 seconds
**Then** the system must trigger a parallel Native Push Notification (FCM/APNS) to the resident's devices.

---

## Epic 3: Ciclo de Vida da Encomenda (Closing the Loop)

Gerenciamento de retiradas e confirmações, garantindo que o morador e o porteiro tenham visibilidade total do status.

### Story 3.1: Dashboard de Encomendas (Morador)
**[STATUS: JÁ IMPLEMENTADO]**

As a resident,
I want to see a clear list of my pending parcels with photos,
So that I know exactly what needs to be collected from the gate.

**Acceptance Criteria:**

**Given** a resident logged into the app
**When** they open the "Encomendas" tab
**Then** they must see a list of parcels with the status "Aguardando Retirada"
**And** each card must display the arrival time and the photo captured by the porter.

### Story 3.2: Fluxo de Entrega (Porteiro)
**[STATUS: JÁ IMPLEMENTADO]**

As a porter,
I want to mark a parcel as "Delivered" when the resident collects it,
So that the inventory is always up-to-date and the queue is cleared.

**Acceptance Criteria:**

**Given** a resident standing at the gate to collect a parcel
**When** I find the parcel in the "Pendentes" list and tap "Confirmar Entrega"
**Then** the record's status must change to "Retirada"
**And** the record must move to the history view.

### Story 3.3: Comprovação de Retirada (Segurança)
**[STATUS: JÁ IMPLEMENTADO]**

As a system,
I want to require a proof of pickup (photo or PIN),
So that there is a secure audit trail for every delivered parcel.

**Acceptance Criteria:**

**Given** the delivery flow active
**When** the porter confirms a pickup
**Then** the app must prompt to "Capture Photo of Receiver" or "Verify Resident PIN"
**And** the chosen proof must be attached to the delivery record in the audit trail.

### Story 3.4: Histórico & Arquivamento
**[STATUS: JÁ IMPLEMENTADO]**

As a user,
I want to consult the history of parcels delivered in the last 30 days,
So that I can resolve any disputes about past deliveries.

**Acceptance Criteria:**

**Given** the history view
**When** I filter by date or unit number
**Then** I must see all resolved parcel records including the timestamp and pickup proof
**And** records older than 90 days must be archived/auto-deleted.

---

## Epic 4: Portões Abertos (Access & Trust)

Sistema de convites digitais, liberação rápida e fluxo de aprovação de novos moradores.

### Story 4.1: Gerador de Convite Digital (Morador)
**[STATUS: JÁ IMPLEMENTADO]**

As a resident,
I want to generate a digital invitation with an explicit expiration date,
So that I can securely share temporary access with my guests via WhatsApp.

**Acceptance Criteria:**

**Given** the invitation creation screen
**When** I input the guest's name and select a date range (e.g., "Only today" or "Until Friday")
**Then** the app must generate a card with a unique QR Code and the expiration date clearly visible
**And** the QR Code must automatically invalidate at 23:59 of the chosen end date.

### Story 4.2: Terminal de Acesso de Visitantes (Porteiro)
**[STATUS: JÁ IMPLEMENTADO]**

As a porter,
I want to validate digital invitations by scanning QR Codes,
So that I can authorize visitors quickly and accurately.

**Acceptance Criteria:**

**Given** a visitor presenting a digital invitation
**When** I scan the QR Code with the portaria tablet
**Then** the app must check the validity against the database
**And** display a "CLEAR" message with the guest's name if valid, or a "EXPIRED/INVALID" warning if not.

### Story 4.3: Cadastro de Novo Morador (Self-Onboarding)
**[STATUS: JÁ IMPLEMENTADO]**

As a potential resident,
I want to request access to the condominium by providing my unit and documents,
So that I can start using the platform after being verified.

**Acceptance Criteria:**

**Given** the login screen for an unauthenticated user
**When** I select "Solicitar Acesso" and provide my unit number, photo of my ID, and face photo
**Then** the request must be saved as "Pendente" in the system
**And** I must see a screen stating "Aprovação pendente pelo Síndico."

### Story 4.4: Fila de Aprovação "Swipe" (Síndico)
**[STATUS: JÁ IMPLEMENTADO]**

As a síndico,
I want to approve or reject resident requests using a swipe gesture,
So that I can manage onboarding with zero bureaucracy and modern UX.

**Acceptance Criteria:**

**Given** the manager dashboard with pending requests
**When** I see a request card and swipe RIGHT
**Then** the resident is approved, notified via WhatsApp, and their RLS permissions are activated
**When** I swipe LEFT
**Then** I must be prompted for a "Reason of Rejection" before the request is dismissed.

### Story 4.5: Liberação Express de Visitantes via WhatsApp
**[STATUS: PLANEJADO]**

As a resident,
I want to approve unexpected visitors arriving at the portaria using WhatsApp interactive buttons,
So that I can authorize entry without downloading the app or answering phone calls.

**Acceptance Criteria:**

**Given** an unannounced visitor registered at the gate by the porter (Status: 'aguardando_aprovacao')
**When** the system sends a WhatsApp message with interactive buttons to the registered resident
**And** the resident clicks the "[Aprovar]" button in their WhatsApp chat
**Then** the visitor registration status must be updated to 'liberado' with `aprovado_por = resident_id` and `aprovado_at = NOW()`
**And** the porter's terminal must immediately display a visual unlock confirmation via Supabase Realtime.

---

## Epic 5: Escudo & Voz (SOS & Community)

Módulos críticos de segurança (SOS de alta prioridade) e canais de comunicação direta (Comunicados/Chat).

### Story 5.1: Botão SOS (GPS + Critical Alert)
**[STATUS: JÁ IMPLEMENTADO]**

As a user in danger,
I want to trigger a silent SOS alert with my GPS coordinates,
So that porters and administrators can respond quickly with my exact location.

**Acceptance Criteria:**

**Given** the persistent SOS button on the dashboard
**When** I long-press the button for 3 seconds (with haptic feedback)
**Then** the app must capture my current GPS coordinates
**And** send a critical alert (bypassing silent mode) to all porter tablets and manager devices via Supabase Realtime + WhatsApp Fallback.

### Story 5.2: Mural de Comunicados Oficiais
**[STATUS: JÁ IMPLEMENTADO]**

As a manager,
I want to write and broadcast official announcements to specific blocks,
So that residents are informed of relevant events without notification noise.

**Acceptance Criteria:**

**Given** the manager announcement tool
**When** I publish a message and select target "Block A" or "All"
**Then** the system must push a notification to the target audience
**And** the message must appear prominently pinned on the resident's dashboard.

### Story 5.3: Registro de Ocorrência com Foto
**[STATUS: JÁ IMPLEMENTADO]**

As a resident,
I want to register an "Ocorrência" (leak, noise, maintenance) with photo proof,
So that I can track the resolution progress without bureaucratic calls.

**Acceptance Criteria:**

**Given** a problematic situation in the condo
**When** I upload a photo and description in the "Ocorrências" feature
**Then** a ticket is created for the manager/caretaker to review
**And** the resident must be able to see the status (Pendente -> Em Progresso -> Resolvido).

### Story 5.4: Canal "Fale Conosco" (Internal Chat)
**[STATUS: JÁ IMPLEMENTADO]**

As a resident,
I want to chat directly with administration within the app,
So that there is an official audit log of my requests and responses.

**Acceptance Criteria:**

**Given** the "Fale Conosco" module
**When** I send a message
**Then** it must be delivered via Supabase Realtime to the manager's dashboard
**And** the conversation history must be stored securely for audit and compliance (LGPD).

---

## Epic 6: Vida em Comum (Governance & Facilities)

Gestão de reservas de áreas comuns com regras automatizadas e visualização de documentos administrativos.

### Story 6.1: Visualização de Disponibilidade (Calendário)
**[STATUS: JÁ IMPLEMENTADO]**

As a resident,
I want to see a real-time calendar of common area availability,
So that I can plan my events without calling the porter.

**Acceptance Criteria:**

**Given** a selected common area (e.g., "Churrasqueira")
**When** I open the booking calendar
**Then** the UI must show "Available" and "Booked" slots for the current month
**And** the data must be synced locally for zero-lag browsing.

### Story 6.2: Reserva com Regras & Bloqueio de Inadimplência
**[STATUS: JÁ IMPLEMENTADO]**

As a resident,
I want to request a booking and have eligibility rules applied automatically,
So that the process is fair and aligned with condominium bylaws.

**Acceptance Criteria:**

**Given** a resident attempt to book an area
**When** the resident has a "delinquent" status (inadimplente) in their profile
**Then** the "Confirmar Reserva" action must be blocked with a message "Reserva suspensa: Regularize suas pendências com a administração."
**When** the resident is compliant
**Then** the system must calculate fees and apply usage limits (e.g., max 1 party per month) before confirming.

### Story 6.3: Central de Documentos do Condomínio
**[STATUS: JÁ IMPLEMENTADO]**

As a user,
I want to access official documents like assembly minutes and bylaws,
So that I am always up-to-date with condominium governance.

**Acceptance Criteria:**

**Given** the "Documentos" module
**When** the manager uploads a PDF or WebP document
**Then** it must be visible and downloadable by all authorized residents
**And** access must be logged for the manager's oversight.

---

## Epic 7: Central de Acordos Pix Express (Financial Recovery)

Renegociação de inadimplência com simulação de parcelamento, geração de Pix Asaas e log imutável de auditoria.

### Story 7.1: Modelagem das Tabelas de Acordo & RLS
**[STATUS: PLANEJADO]**

As a system,
I want to establish the core database schema for Pix agreements and audit logs with correct constraints and RLS,
So that agreement data is isolated per condominium and logs remain completely immutable.

**Acceptance Criteria:**

**Given** a Supabase database instance
**When** I create the tables `financeiro_acordos`, `financeiro_acordo_parcelas`, `financeiro_acordo_faturamentos` and `financeiro_acordos_audit_log`
**Then** RLS policies must restrict residents to only see and create agreements/parcelas linked to their units
**And** the audit log table `financeiro_acordos_audit_log` must NOT have any UPDATE or DELETE policies, ensuring it is append-only.

### Story 7.2: Interface de Simulação e Termos Contratuais (Morador)
**[STATUS: PLANEJADO]**

As a resident,
I want to view my outstanding fees, simulate installment options, and sign the agreement terms using biometrics/PIN,
So that I can formalize my debt settlement in a self-service manner.

**Acceptance Criteria:**

**Given** a resident logged into the app with outstanding faturamentos
**When** they open the "Central de Acordos" screen
**Then** they must see the total overdue balance and a simulator slider for installments (from 1 to 12 times)
**When** they choose a plan, the app displays the monthly installment value and the legally binding terms document
**And** when they tap "Assinar Acordo", the app must request FaceID/TouchID or PIN validation to record the signature.

### Story 7.3: Integração Asaas & Geração de Pix (Edge Function)
**[STATUS: PLANEJADO]**

As a system,
I want to register the customer in Asaas and generate the Pix Copia e Cola / QR Codes for the first installment,
So that the resident can pay immediately after signing.

**Acceptance Criteria:**

**Given** a signed agreement with status 'pendente'
**When** the system triggers the Asaas integration Edge Function
**Then** it must create/retrieve the Asaas Customer ID for the resident
**And** generate the payment charge for the first installment (including Pix Copia e Cola, QR Code, and PDF invoice URL)
**And** update the database fields in `financeiro_acordo_parcelas` with the generated Pix credentials.

### Story 7.4: Webhook de Pagamento & Desbloqueio Eleitoral
**[STATUS: PLANEJADO]**

As a system,
I want to receive payment webhooks from Asaas, update the installment status, and automatically restore the resident's voting rights,
So that political status is restored instantly upon payment confirmation.

**Acceptance Criteria:**

**Given** a payment webhook request sent from Asaas to `/asaas-webhook`
**When** the Edge Function validates the cryptographic signature of the request header
**Then** it must update the first installment status to 'pago' and the agreement status to 'ativo'
**And** set `unidades.bloqueada_assembleia = false` for the corresponding unit
**And** update the negotiated `faturamentos` to status 'cancelado'
**And** write a record to `financeiro_acordos_audit_log` with the transaction detail.

---

## Epic 8: Dashboard Multi-condomínio (Professional Management)

Painel unificado para síndicos profissionais com troca rápida de contexto e indicadores consolidados de cobrança.

### Story 8.1: Seletor de Contexto Multi-condomínio
**[STATUS: PLANEJADO]**

As a professional manager,
I want to switch the dashboard context between multiple managed condominiums using a header selector,
So that I can manage different properties from a single login.

**Acceptance Criteria:**

**Given** a manager logged into the Admin Web Panel with a profile role of 'administradora'
**When** they open the dashboard header selector
**Then** it must display a dropdown list of all condominiums registered under their `administradora_id` (Administradora Bypass)
**And** selecting a condominium must update the layout routing and context (Next.js App Router params) in less than 3 seconds.

### Story 8.2: RPC de Métricas Consolidadas
**[STATUS: PLANEJADO]**

As a professional manager,
I want a consolidated database query to fetch all condominium KPIs in a single network round-trip,
So that switching properties doesn't trigger heavy or multiple database requests.

**Acceptance Criteria:**

**Given** the dashboard requested condo IDs
**When** the frontend calls the Supabase RPC `get_consolidated_condo_metrics`
**Then** the function must check if the authenticated user is an authorized admin of each condo in the list
**And** return a single JSON containing unit count, default financial rates, active SOS alerts, and pending parcels.

### Story 8.3: Caching e Pre-fetching de Contexto (Next.js Client)
**[STATUS: PLANEJADO]**

As a professional manager,
I want the system to pre-load and cache the next condominium's metrics on menu hover,
So that context switching is instantaneous.

**Acceptance Criteria:**

**Given** the manager dashboard
**When** the mouse hovers over an option in the condominium selector dropdown
**Then** the client must pre-fetch the data via React Query/SWR
**And** when clicked, the page loads the cached metrics in under 3 seconds (NFR11).

---

## Epic 9: Assembleias Paperless (Electoral & Compliance)

Votação digital secreta, procurações eletrônicas, integração Jitsi/vídeo e sincronização instantânea de elegibilidade eleitoral (Art. 1.335 do CC).

### Story 9.1: Bloqueio Eleitoral Automatizado (Código Civil Art. 1.335)
**[STATUS: PLANEJADO]**

As a system,
I want to block votes from units with delinquent status in the database,
So that the voting process complies with the Brazilian Civil Code requirements.

**Acceptance Criteria:**

**Given** a resident attempting to insert or update a vote in `assembleia_votos`
**When** the database trigger `trg_check_vote_eligibility` detects that `unidades.bloqueada_assembleia = true`
**Then** it must raise an exception and reject the vote write
**And** the UI must disable the vote button and display a warning message with an agreement shortcut link.

### Story 9.2: Votação Secreta com RLS & View Agregada
**[STATUS: PLANEJADO]**

As a resident,
I want my individual vote to remain secret from other residents and administrators,
So that my electoral choices are completely private.

**Acceptance Criteria:**

**Given** the `assembleia_votos` table
**When** a non-owner user attempts to select individual rows
**Then** the RLS policy must restrict rows to only where `votante_user_id = auth.uid()`
**And** administrators must only be able to view vote counts and aggregate values via the database view `view_assembleia_votos_agregados`.

### Story 9.3: Outorga de Procuração Eletrônica
**[STATUS: PLANEJADO]**

As a resident,
I want to designate a proxy representation to another resident,
So that they can vote on my behalf if I cannot attend the assembly.

**Acceptance Criteria:**

**Given** the proxy outorga screen
**When** I select an active assembly and search for a neighbor to outorgate my vote
**Then** the system must record the request as 'pendente'
**And** when confirmed by PIN validation, the designated proxy is registered in `assembleia_procuracoes` and can cast a vote on behalf of the outorgante unit.

### Story 9.4: Transmissão Jitsi Meet & Ata Autônoma via IA
**[STATUS: PLANEJADO]**

As a síndico,
I want to stream the live assembly via Jitsi and trigger minutes (Ata) draft generation by IA,
So that the assembly has complete digital compliance and easy documentation.

**Acceptance Criteria:**

**Given** a live assembly session
**When** the manager starts the Jitsi session, it must embed the Jitsi Meet Iframe API with moderation tools
**And** when the voting ends, clicking "Gerar ATA via IA" triggers the Edge Function to send transcripts and voting details to the LLM (Gemini 2.5 Flash / GPT-4o)
**Then** the function must generate a formal PDF draft, save it to Supabase Storage, and update the assembly status to 'ata_publicada'.
