---
stepsCompleted: [1, 2, 3, 4]
inputDocuments:
  - _bmad-output/planning-artifacts/prd.md
  - _bmad-output/planning-artifacts/architecture.md
  - _bmad-output/planning-artifacts/ux-design-specification.md
---

# condomeet - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for condomeet, decomposing the requirements from the PRD, UX Design Specification, and Architecture requirements into implementable stories.

## Requirements Inventory

### Functional Requirements

- **FR1**: Register parcels with rapid photo capture.
- **FR2**: Find residents via predictive fuzzy search.
- **FR3**: Automated WhatsApp alerts with photos post-registration.
- **FR4**: Parallel Push Notification if WhatsApp delivery confirmation exceeds 15 seconds.
- **FR5**: Resident pickup confirmation via WhatsApp or app.
- **FR6**: Digital access invitations generation and sharing.
- **FR7**: Redundant SOS alerts (Critical Push + Dashboard) to all administrators.
- **FR8**: Administrator official broadcasts to blocks or entire condo.
- **FR9**: Resident occurrence registration with photo attachments.
- **FR10**: Direct chat ("Fale Conosco") with administration.
- **FR11**: Common area availability viewing and booking.
- **FR12**: Automated charging rules and usage limits for bookings.
- **FR13**: Secure condominium document management.
- **FR14**: Síndico approval/rejection of onboarding requests.
- **FR15**: Authentication via numeric password and OTP.

### NonFunctional Requirements

- **NFR1**: Critical path server response time < 300ms (95th percentile).
- **NFR2**: Local metadata search latency < 100ms.
- **NFR3**: 60fps stable UI transitions.
- **NFR4**: Cold boot-to-interactive time < 2 seconds.
- **NFR5**: 99.9% uptime for SOS and Portaria services.
- **NFR6**: Native Critical Alerts API for SOS (bypass silent/DND).
- **NFR7**: Full offline operation for portaria with < 10s sync latency upon reconnection.
- **NFR8**: AES-256 encryption for sensitive docs and audit trails.
- **NFR9**: Full LGPD compliance.

### Additional Requirements

- **Architecture**:
    - **Stack**: Flutter + Supabase + PowerSync (SQLite Sync).
    - **Auth**: WhatsApp OTP + 6-digit PIN + Biometrics.
    - **Logic**: Supabase Edge Functions (Deno).
    - **OCR**: Google ML Kit (Local-First).
    - **WhatsApp**: Z-API / Evolution API (MVP).
    - **Patterns**: Repository Pattern + BLoC + Result Pattern.
- **UX/UI**:
    - **Design System**: Tailwind UI Foundation with "Tranquilidade" theme.
    - **Interactions**: Optimistic UI updates, Haptic feedback, 3-tap rule for vital actions.
    - **Adaptive**: Context-aware dashboards (Porteiro high-speed vs. Síndico control).

### FR Coverage Map

- **FR1**: Epic 2 (Portaria Check-in)
- **FR2**: Epic 2 (Portaria Search)
- **FR3**: Epic 2 (WhatsApp Alerts)
- **FR4**: Epic 2 (Fallback Notifications)
- **FR5**: Epic 3 (Parcel Pickup Cycle)
- **FR6**: Epic 4 (Access Invitations)
- **FR7**: Epic 5 (SOS Redundancy)
- **FR8**: Epic 5 (Communications)
- **FR9**: Epic 5 (Occurrences)
- **FR10**: Epic 5 (Admin Chat)
- **FR11**: Epic 6 (Common Areas)
- **FR12**: Epic 6 (Booking Rules)
- **FR13**: Epic 6 (Documents)
- **FR14**: Epic 4 (Resident Onboarding)
- **FR15**: Epic 1 (Foundation/Auth)

## Epic List

### Epic 1: Fundação & Identidade (The Entryway)

Configuração do motor técnico (Supabase/PowerSync) e sistema de autenticação ultra-rápido via WhatsApp OTP + PIN.

### Story 1.1: Inicialização do Projeto & Design System

As a developer,
I want to initialize the Flutter project with a custom theme and Tailwind UI tokens,
So that all features have a consistent and premium "Tranquilidade" look and feel.

**Acceptance Criteria:**

**Given** a new Flutter project structure
**When** I configure the `ThemeData` based on the UX specification
**Then** the app should use the brand Orange-Red (`#FA542F`) for primary actions
**And** custom widgets (Buttons, Inputs) should match the Tailwind UI style.

### Story 1.2: Schema Multi-Condomínio (Postgres + RLS)

As a system,
I want to establish the core database schema with Row Level Security (RLS) policies,
So that data isolation between condominiums is enforced at the database level.

**Acceptance Criteria:**

**Given** a Supabase project connection
**When** the `condominiums` and `profiles` tables are created
**Then** RLS policies must prevent a user from one `condominium_id` from reading data from another
**And** all subsequent tables must inherit this isolation pattern.

### Story 1.3: Termos de Uso & Consentimento LGPD

As a user (Resident or Porter),
I want to review and accept the Terms of Use and Privacy Policy (LGPD) during the first login,
So that I know my personal data is being handled securely and legally.

**Acceptance Criteria:**

**Given** a user attempting to log in for the first time
**When** the app detects no prior consent record
**Then** a modal/screen with the Terms of Use and LGPD consent checkbox must be displayed
**And** the login flow must be blocked until the user explicitly accepts.

### Story 1.4: Solicitação de Acesso via WhatsApp (OTP)

As a user,
I want to receive an OTP code via WhatsApp,
So that I can verify my identity without remembering complex passwords.

**Acceptance Criteria:**

**Given** a valid phone number entered in the login screen
**When** I tap "Enviar Código"
**Then** a 6-digit OTP should be sent via the WhatsApp provider (Z-API/Evolution)
**And** the app should navigate to the verification screen.

### Story 1.5: PIN de Acesso & Login Persistente

As a verified user,
I want to set up a 6-digit PIN and enable biometrics,
So that future app entries are instantaneous.

**Acceptance Criteria:**

**Given** a successfully verified OTP session
**When** I set a numeric PIN in the security screen
**Then** the app must encrypt the local session key
**And** subsequent entries should allow "FaceID/TouchID" or "PIN" entry to unlock.

### Epic 2: Guariteiro Relâmpago (Operating the Gate)

Implementação do scanner OCR e busca fuzzy local para registro de encomendas em menos de 15 segundos.

### Story 2.1: Busca Preditiva de Moradores (Offline)

As a porter,
I want to find residents instantly by typing unit numbers or names,
So that I can register parcels without manually browsing long lists.

**Acceptance Criteria:**

**Given** a local cache of residents synchronized via PowerSync
**When** I enter a partial unit number (e.g., "10")
**Then** the UI must display a list of matching units and residents in < 100ms
**And** the first result should show the resident's photo for visual confirmation.

### Story 2.2: Scanner OCR de Etiquetas (ML Kit)

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

As a porter,
I want to register a parcel with a single tap,
So that I can clear the gate queue immediately.

**Acceptance Criteria:**

**Given** a selected resident and optional package photo
**When** I tap "Registrar Encomenda"
**Then** the UI must show a success checkmark and vibrate (Haptic) INSTANTLY
**And** the record must be saved to the local SQLite (PowerSync) for background sync.

### Story 2.4: Orquestração de Alerta WhatsApp

As a system,
I want to trigger a WhatsApp notification with the parcel photo,
So that the resident is immediately informed of the arrival.

**Acceptance Criteria:**

**Given** a new parcel record in the database
**When** the record is synced to Supabase
**Then** a Supabase Edge Function must send a WhatsApp message (Z-API/Evolution) to the resident
**And** the message must include the package photo and a "Já retirei" button.

### Story 2.5: Fallback de Notificação Push

As a system,
I want to send a native push notification if WhatsApp fails,
So that the resident receives the alert even if they are offline on WhatsApp.

**Acceptance Criteria:**

**Given** a sent WhatsApp notification
**When** no delivery confirmation is received within 15 seconds
**Then** the system must trigger a parallel Native Push Notification (FCM/APNS) to the resident's devices.

### Epic 3: Ciclo de Vida da Encomenda (Closing the Loop)

Gerenciamento de retiradas e confirmações, garantindo que o morador e o porteiro tenham visibilidade total do status.

### Story 3.1: Dashboard de Encomendas (Morador)

As a resident,
I want to see a clear list of my pending parcels with photos,
So that I know exactly what needs to be collected from the gate.

**Acceptance Criteria:**

**Given** a resident logged into the app
**When** they open the "Encomendas" tab
**Then** they must see a list of parcels with the status "Aguardando Retirada"
**And** each card must display the arrival time and the photo captured by the porter.

### Story 3.2: Fluxo de Entrega (Porteiro)

As a porter,
I want to mark a parcel as "Delivered" when the resident collects it,
So that the inventory is always up-to-date and the queue is cleared.

**Acceptance Criteria:**

**Given** a resident standing at the gate to collect a parcel
**When** I find the parcel in the "Pendentes" list and tap "Confirmar Entrega"
**Then** the record's status must change to "Retirada"
**And** the record must move to the history view.

### Story 3.3: Comprovação de Retirada (Segurança)

As a system,
I want to require a proof of pickup (photo or PIN),
So that there is a secure audit trail for every delivered parcel.

**Acceptance Criteria:**

**Given** the delivery flow active
**When** the porter confirms a pickup
**Then** the app must prompt to "Capture Photo of Receiver" or "Verify Resident PIN"
**And** the chosen proof must be attached to the delivery record in the audit trail.

### Story 3.4: Histórico & Arquivamento

As a user,
I want to consult the history of parcels delivered in the last 30 days,
So that I can resolve any disputes about past deliveries.

**Acceptance Criteria:**

**Given** the history view
**When** I filter by date or unit number
**Then** I must see all resolved parcel records including the timestamp and pickup proof
**And** records older than 90 days (per LGPD/UX spec) should be archived/auto-deleted.

### Epic 4: Portões Abertos (Access & Trust)

Sistema de convites digitais para visitantes e fluxo de aprovação de novos moradores pelo Síndico.

### Story 4.1: Gerador de Convite Digital (Morador)

As a resident,
I want to generate a digital invitation with an explicit expiration date,
So that I can securely share temporary access with my guests via WhatsApp.

**Acceptance Criteria:**

**Given** the invitation creation screen
**When** I input the guest's name and select a date range (e.g., "Only today" or "Until Friday")
**Then** the app must generate a card with a unique QR Code and the expiration date clearly visible
**And** the QR Code must automatically invalidate at 23:59 of the chosen end date.

### Story 4.2: Terminal de Acesso de Visitantes (Porteiro)

As a porter,
I want to validate digital invitations by scanning QR Codes,
So that I can authorize visitors quickly and accurately.

**Acceptance Criteria:**

**Given** a visitor presenting a digital invitation
**When** I scan the QR Code with the portaria tablet
**Then** the app must check the validity against the database
**And** display a "CLEAR" message with the guest's name if valid, or a "EXPIRED/INVALID" warning if not.

### Story 4.3: Cadastro de Novo Morador (Self-Onboarding)

As a potential resident,
I want to request access to the condominium by providing my unit and documents,
So that I can start using the platform after being verified.

**Acceptance Criteria:**

**Given** the login screen for an unauthenticated user
**When** I select "Solicitar Acesso" and provide my unit number, photo of my ID, and face photo
**Then** the request must be saved as "Pendente" in the system
**And** I must see a screen stating "Aprovação pendente pelo Síndico."

### Story 4.4: Fila de Aprovação "Swipe" (Síndico)

As a síndico,
I want to approve or reject resident requests using a swipe gesture,
So that I can manage onboarding with zero bureaucracy and modern UX.

**Acceptance Criteria:**

**Given** the manager dashboard with pending requests
**When** I see a request card and swipe RIGHT
**Then** the resident is approved, notified via WhatsApp, and their RLS permissions are activated
**When** I swipe LEFT
**Then** I must be prompted for a "Reason of Rejection" before the request is dismissed.

### Epic 5: Escudo & Voz (SOS & Community)

Módulos críticos de segurança (SOS redundante) e canais de comunicação direta (Comunicados/Chat).

### Story 5.1: Botão SOS (GPS + Critical Alert)

As a user in danger,
I want to trigger a silent SOS alert with my GPS coordinates,
So that porters and administrators can respond quickly with my exact location.

**Acceptance Criteria:**

**Given** the persistent SOS button on the dashboard
**When** I long-press (hold) the button for 3 seconds (with haptic feedback)
**Then** the app must capture my current GPS coordinates
**And** send a critical alert (bypassing silent mode) to all porter tablets and manager devices via Supabase Realtime + WhatsApp Fallback.

### Story 5.2: Mural de Comunicados Oficiais

As a manager,
I want to write and broadcast official announcements to specific blocks,
So that residents are informed of relevant events without notification noise.

**Acceptance Criteria:**

**Given** the manager announcement tool
**When** I publish a message and select target "Block A" or "All"
**Then** the system must push a notification to the target audience
**And** the message must appear prominently pinned on the resident's dashboard.

### Story 5.3: Registro de Ocorrência com Foto

As a resident,
I want to register an "Ocorrência" (leak, noise, maintenance) with photo proof,
So that I can track the resolution progress without bureaucratic calls.

**Acceptance Criteria:**

**Given** a problematic situation in the condo
**When** I upload a photo and description in the "Ocorrências" feature
**Then** a ticket is created for the manager/caretaker to review
**And** the resident must be able to see the status (Pendente -> Em Progresso -> Resolvido).

### Story 5.4: Canal "Fale Conosco" (Internal Chat)

As a resident,
I want to chat directly with administration within the app,
So that there is an official audit log of my requests and responses.

**Acceptance Criteria:**

**Given** the "Fale Conosco" module
**When** I send a message
**Then** it must be delivered via Supabase Realtime to the manager's dashboard
**And** the conversation history must be stored securely for audit and compliance (LGPD).

### Epic 6: Vida em Comum (Governance)

Gestão de reservas de áreas comuns com regras automatizadas e visualização de documentos.

### Story 6.1: Visualização de Disponibilidade (Calendário)

As a resident,
I want to see a real-time calendar of common area availability,
So that I can plan my events without calling the porter.

**Acceptance Criteria:**

**Given** a selected common area (e.g., "Churrasqueira")
**When** I open the booking calendar
**Then** the UI must show "Available" and "Booked" slots for the current month
**And** the data must be synced locally for zero-lag browsing.

### Story 6.2: Reserva com Regras & Bloqueio de Inadimplência

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

As a user,
I want to access official documents like assembly minutes and bylaws,
So that I am always up-to-date with condominium governance.

**Acceptance Criteria:**

**Given** the "Documentos" module
**When** the manager uploads a PDF or WebP document
**Then** it must be visible and downloadable by all authorized residents
**And** access must be logged for the manager's oversight.

---
*Documento Finalizado e Validado para Desenvolvimento.*
