---
workflowType: 'prd'
workflow: 'edit'
classification:
  domain: 'PropTech (Condominium Management)'
  projectType: 'Mobile App / Web App'
  complexity: 'Medium/High'
  projectContext: 'Greenfield (Migration from Bubble) + Financial Expansion'
inputDocuments:
  - _bmad-output/planning-artifacts/product-brief-condomeet-2026-05-31.md
  - _bmad-output/planning-artifacts/product-brief-condomeet-2026-01-27-mvp-scope.md
  - _bmad-output/planning-artifacts/product-brief-condomeet-2026-01-27.md
stepsCompleted: ['step-e-01-discovery', 'step-e-02-review', 'step-e-03-edit']
lastEdited: '2026-05-31'
editHistory:
  - date: '2026-05-31'
    changes: 'Added Pix Agreement Hub, Multi-Condo dashboard, Paperless Assemblies, and WhatsApp Guest Check-in to Phase 1 MVP. Updated NFRs, FRs, User Journeys, and compliance rules.'
  - date: '2026-05-31'
    changes: 'Refactored Functional Requirements to actor-centric format; specified NFRs with 4-part templates and measurement methods; added Web Admin specs, Store Compliance, and Financial Audit requirements.'
---

# Product Requirements Document - condomeet

**Author:** cristiano
**Date:** 2026-05-31

## 1. Executive Summary & Success Criteria

Condomeet is a high-performance PropTech solution for condominium management, migrating from a Bubble legacy to a modern stack (Next.js/Supabase). The core differentiator is **Zero-Lag Performance** and a **WhatsApp-First** engagement strategy. 

This phase introduces the Central de Acordos Pix Express, the Dashboard Multi-condomínio for professional managers, and paperless assemblies, maximizing financial recovery and convenience.

### Success Metrics
- **User Satisfaction**: 80% monthly active apartments; first parcel registered in < 60 mins.
- **Business Growth**: 90% Trial-to-Paid conversion; < 1% monthly churn.
- **Operational ROI**: 50% reduction in portaria desk time.
- **WhatsApp Engagement**: 70%+ action rate on automated notifications.
- **Inadimplência & Cobrança**: Taxa de conversão de acordos >50% nos primeiros 30 dias; tempo médio para simular e pagar a 1ª parcela via Pix < 5 minutos.
- **Eficiência Contábil (Síndico Profissional)**: Tempo de carga para troca de condomínio < 3 segundos.
- **Portaria Contingencial**: Resposta do morador via WhatsApp para liberação inesperada < 90 segundos (mínimo de 80% das liberações express em < 2 minutos).

---

## 2. Project Scope & Phased Development

### Phase 1: MVP (Experience, Performance & Financial Recovery)
Focus on solving "gate friction" with a lightning-fast portaria interface, seamless resident notifications, and instant financial resolution.
- **Core Modules**: Parcel Management, Visitor Authorization (Pre-agendados e WhatsApp Express de contingência), Critical SOS, Common Space Bookings, **Central de Acordos Pix Express**, **Dashboard Multi-condomínio**, and **Assembleias Paperless**.
- **Technical Focus**: Real-time sync, Asaas webhook integration, and 60fps native-like fluidity.

### Phase 2: Growth (Engagement & Interactive Chat)
- **Features**: In-condo classifieds, dynamic polls, and professional service recommendations. **Concierge Condominial Inteligente via WhatsApp (IA)**, **Depósito de Reserva Dinâmico**.

### Phase 3: Vision (Expansion & AI Accounting)
- **Features**: IoT integration (gates/cameras), inter-condo marketplace, and white-label licensing. **Conciliação e Balancete Autônomo por IA**, **Indicações com Cashback Condominial**.

---

## 3. User Journeys

### Journey 1: The Connected Resident (Marina)
Marina expects an Amazon package. Carlos (porteiro) registers it at the gate. Within **30 seconds**, Marina receives a WhatsApp photo of the package. She feels secure and uses the app to pre-authorize her mother's visit for the next day.

### Journey 2: The Operational Porteiro (Carlos)
During the 6 PM rush, Carlos registers couriers instantly. The app suggests apartments while he types. registration takes **15 seconds** total. He no longer needs to call residents manually; the system handles alerts.

### Journey 3: The Managing Síndico (Paulo)
Paulo reviews budget decisions and supply inventory on a dashboard that loads in milliseconds. He creates an online assembly with one tap, tracking participation results in real-time.

### Journey 4: The Delinquent Resident (Roberto)
Roberto wants to vote in tonight's assembly but has a late fee. He clicks the alert, uses the Pix Agreement Hub to simulate a 2-installment plan, signs with FaceID, pays the 1st installment, and his voting status is unblocked instantly.

### Journey 5: The Professional Manager (Cláudio)
Cláudio manages 8 properties. He logs into the Condomeet Admin Web, switches context between Condomínio Sol and Condomínio Lua in 2 seconds, and views consolidated collections.

### Journey 6: The Porteiro Guest Check-in (Marcos)
Visitor arrives unannounced. Marcos enters the visitor's name. Morador receives a WhatsApp notification with buttons, clicks "Aprovar", and Marcos's gate terminal unlocks.

---

## 4. Domain & Innovation Strategy

### Compliance & Domain Logic (LGPD & Legislação)
- **Privacy**: End-to-end encryption (AES-256) for documents; visitor/parcel photo auto-expiration (90 days).
- **Security Gate**: Automated RLS (Row Level Security) validation per unit post-migration to prevent data leakage.
- **Business Rules**: Tiered reservation logic (e.g., first 2 uses free) and manual resident onboarding verification.
- **Inadimplência (Código Civil Art. 1.335)**: Unidades inadimplentes são automaticamente impedidas de votar em assembleias. A formalização e pagamento da 1ª parcela do acordo Pix Express restabelece o direito político de voto de forma automática.

### Financial Auditing & Ledger Security (Fintech/Legal compliance)
- **Immutable Ledger Logs**: The system must log all agreement actions (creation, simulation values, installments count, terms signing timestamps) to an immutable, append-only history table.
- **Vote eligibility overrides audit trail**: Every automated state transition changing a resident's eligibility to vote must be logged with the original status, new status, transaction ID (from Asaas Pix payment confirmation), and timestamp.

### Innovation Trumps
- **Zero-Lag as a Feature**: Speed as a primary user benefit to eliminate gate queues.
- **WhatsApp-First Interface**: Leveraging WhatsApp to drive core value without app-download friction.
- **Mission-Critical Safety (SOS)**: Standardizing emergency response via high-redundancy alerting.
- **Self-Service Pix Agreement**: Autosserviço contábil imediato com baixa automática e restabelecimento de direitos políticos sem intermediação humana.

---

## 5. Technical Architecture & Project-Type Requirements

### Platform & Performance
- **Stack**: Cross-platform (Flutter/React Native) targeting iOS 15+ and Android 10+.
- **Data Strategy**: Local SQLite/Realm for zero-lag searches and **Background Sync** for offline portaria operation.
- **Native Bridges**: Specialized camera module for rapid WebP capture and **Critical Alerts** permissions (iOS/Android) for SOS (overriding silent mode).
- **Webhook Security**: Validação criptográfica obrigatória nas assinaturas de webhooks do Asaas nas Supabase Edge Functions para prevenir fraudes contábeis.
- **Realtime Sync**: Uso do Supabase Realtime Engine para atualização instantânea de elegibilidade de voto no painel da assembleia assim que o pagamento Pix for compensado.

### Web Admin Panel Specifications
- **Browser Support Matrix**: Compatible with Google Chrome (latest 3 versions), Mozilla Firefox (latest 3 versions), Apple Safari (latest 2 versions), and Microsoft Edge (latest 2 versions).
- **Responsive Layout Constraints**: Desktop-first admin dashboard layouts optimized for 1920x1080 resolution, with fluid breakpoints down to 1024x768 to support tablet viewport sizes without horizontal scrolling.
- **Accessibility Level**: Adherence to Web Content Accessibility Guidelines (WCAG) 2.1 AA standard for keyboard navigation and screen-reader support.
- **SEO Strategy**: Authenticated-only application; indexing is disabled (Robots: noindex, nofollow) to prevent leakage of private administrative views.

### Store Compliance
- **Store Policies**: Submission packages must comply with Google Play Console and iOS App Store rules, specifically detailing justification forms for the utilization of native critical push overrides (Critical Alerts) for SOS functionalities.

---

## 6. Functional Requirements (Capability Contract)

### Parcel & Visitor Control
- **FR1**: Porteiro can register incoming parcels and capture a verification photograph within 3 seconds using the native camera bridge.
- **FR2**: Porteiro can find resident records within 1 second by typing queries into a predictive fuzzy search interface.
- **FR3**: Resident can receive automated WhatsApp notifications containing the parcel photo immediately after porteiro registration.
- **FR4**: Resident can receive a parallel Push Notification if the system detects that WhatsApp delivery confirmation exceeds 15 seconds.
- **FR5**: Resident can confirm parcel collection via either WhatsApp quick reply or the mobile application.
- **FR6**: Resident can generate and share temporary digital access credentials (QR Codes/alphanumeric tokens) for visitors.

### Safety & Communication
- **FR7**: User can trigger a high-priority SOS emergency alert that simultaneously sends push notifications to administrators and highlights the gate console.
- **FR8**: Administrator can send targeted announcements to specific condominium blocks or the entire property.
- **FR9**: Resident can register maintenance or security occurrences and attach up to 3 photographs.
- **FR10**: Resident can send direct messages to the administration team through a real-time "Fale Conosco" chat channel.

### Management & Admin
- **FR11**: Resident can view common area calendars and request bookings for specific date or hourly time slots.
- **FR12**: Administrator can configure common area booking rules, including tiered pricing policies (e.g., first 2 bookings free) and monthly booking frequency limits.
- **FR13**: Administrator can upload, categorize, and control access to secure condominium documents using role-based access control (RBAC) levels.
- **FR14**: Síndico can approve or reject resident onboarding registration requests.
- **FR15**: Resident can authenticate into the application using a secure 6-digit PIN password or legacy credential matching (username/password lookup in legacy users table).

### Central de Acordos Pix Express
- **FR16**: Resident can view overdue fees, simulate installment options, and sign legally binding digital agreement terms using mobile biometrics (FaceID/TouchID).
- **FR17**: Resident can copy the Pix "Copia e Cola" code or scan a generated QR Code for the initial installment payment.
- **FR18**: Resident can have their status updated to "Adimplente sob Acordo" within 60 seconds after Asaas gateway confirms payment completion via webhook.
- **FR19**: Síndico can define financial rules (interest rates, penalty fees, maximum installment counts) for debt negotiations via the admin panel.

### Painel Multi-condomínio
- **FR20**: Síndico Profissional can switch the dashboard context between multiple managed condominiums in under 3 seconds using a header dropdown selector.
- **FR21**: Síndico Profissional can view aggregated and per-condominium collection and delinquency metrics.

### Assembleias Paperless
- **FR22**: Resident can cast digital votes on assembly items and sign proxy representation terms using ICP-Brasil standard digital certificates or automated platform signatures.
- **FR23**: Resident can have their voting eligibility automatically locked or unlocked in real-time based on their financial adimplência status (in compliance with Brazilian Civil Code Art. 1.335).

### Liberação Express de Visitantes
- **FR24**: Resident can approve unexpected visitors with a single tap using interactive WhatsApp buttons sent to their registered number.

### Auditoria Contábil e Eleitoral
- **FR25**: Administrator can view a secure audit trail logging all Pix agreements generated, payments confirmed, and corresponding changes to user voting eligibility.

---

## 7. Non-Functional Requirements (Quality Standards)

### Performance (Zero-Lag)
- **NFR1 (Server Latency)**: System shall maintain server response times < 300ms for the 95th percentile, as measured by cloud application monitoring tools (APM), under concurrent loads of up to 10,000 active requests.
- **NFR2 (Search Latency)**: System shall return local metadata search results in < 100ms, as measured by client-side profiling logs, during active searches.
- **NFR3 (UI Fluidity)**: Mobile application shall maintain a stable frame rate of 60fps, as measured by standard OS frame rendering tools, during all screen transitions and scroll gestures.
- **NFR4 (Boot Latency)**: Mobile application shall achieve cold boot-to-interactive times < 2 seconds, as measured by device startup profiling, upon application launch.
- **NFR10 (Webhook Sync Latency)**: System shall sync Asaas webhooks to the frontend assembly voting screen in < 5 seconds, as measured by end-to-end integration testing, to enable immediate voting rights restore.
- **NFR11 (Dashboard Switch Latency)**: Web dashboard shall load context for a different condominium in < 3 seconds, as measured by browser network diagnostics, upon selector change.

### Reliability & Security
- **NFR5 (System Uptime)**: SOS and Portaria services shall maintain a 99.9% monthly uptime, as measured by uptime monitoring alerts, to ensure continuous resident safety.
- **NFR6 (SOS Override)**: SOS emergency notifications shall bypass silent/Do-Not-Disturb modes on iOS and Android devices, as verified by automated push notification tests, utilizing native Critical Alerts permission certificates.
- **NFR7 (Offline Portaria)**: Portaria terminal shall support full offline record creation and synchronize data with the cloud database within 10 seconds of reconnection, as measured by connectivity state testing.
- **NFR8 (Encryption)**: System shall encrypt all personal identification documents and financial records at rest using AES-256 and in transit using TLS 1.3, as verified by automated vulnerability scans.
- **NFR9 (LGPD Compliance)**: System shall enforce LGPD compliance by automatically deleting visitor and parcel images 90 days after registration and providing a self-service account deletion mechanism, as verified by daily system cron audits.
