stepsCompleted: ['step-01-init', 'step-02-discovery', 'step-03-success', 'step-04-journeys', 'step-05-domain', 'step-06-innovation', 'step-07-project-type', 'step-08-scoping', 'step-09-functional', 'step-10-nonfunctional', 'step-11-polish', 'step-12-complete']
inputDocuments:
  - _bmad-output/planning-artifacts/product-brief-condomeet-2026-01-27-mvp-scope.md
  - _bmad-output/planning-artifacts/product-brief-condomeet-2026-01-27.md
workflowType: 'prd'
classification:
  projectType: Mobile App / Web App
  domain: PropTech (Condominium Management)
  complexity: Medium/High
  projectContext: Greenfield (Migration from Bubble)
---

# Product Requirements Document - condomeet

**Author:** cristiano
**Date:** 2026-02-06

## 1. Executive Summary & Success Criteria

Condomeet is a high-performance PropTech solution for condominium management, migrating from a Bubble legacy to a modern stack (Next.js/Supabase). The core differentiator is **Zero-Lag Performance** and a **WhatsApp-First** engagement strategy.

### Success Metrics
- **User Satisfaction**: 80% monthly active apartments; first parcel registered in < 60 mins.
- **Business Growth**: 90% Trial-to-Paid conversion; < 1% monthly churn.
- **Operational ROI**: 50% reduction in portaria desk time.
- **WhatsApp Engagement**: 70%+ action rate on automated notifications.

## 2. Project Scope & Phased Development

### Phase 1: MVP (Experience & Performance)
Focus on solving "gate friction" with a lightning-fast portaria interface and seamless resident notifications.
- **Core Modules**: Parcel Management, Visitor Authorization, Critical SOS, and Common Space Bookings.
- **Technical Focus**: Real-time sync and 60fps native-like fluidity.

### Phase 2: Growth (Engagement)
- **Features**: In-condo classifieds, dynamic polls, and professional service recommendations.

### Phase 3: Vision (Expansion)
- **Features**: IoT integration (gates/cameras), inter-condo marketplace, and white-label licensing.

## 3. User Journeys

### Journey 1: The Connected Resident (Marina)
Marina expects an Amazon package. Carlos (porteiro) registers it at the gate. Within **30 seconds**, Marina receives a WhatsApp photo of the package. She feels secure and uses the app to pre-authorize her mother's visit for the next day.

### Journey 2: The Operational Porteiro (Carlos)
During the 6 PM rush, Carlos registers couriers instantly. The app suggests apartments while he types. registration takes **15 seconds** total. He no longer needs to call residents manually; the system handles alerts.

### Journey 3: The Managing Síndico (Paulo)
Paulo reviews budget decisions and supply inventory on a dashboard that loads in milliseconds. He creates an online assembly with one tap, tracking participation results in real-time.

## 4. Domain & Innovation Strategy

### Compliance & Domain Logic (LGPD)
- **Privacy**: End-to-end encryption (AES-256) for documents; visitor/parcel photo auto-expiration (90 days).
- **Security Gate**: Automated RLS (Row Level Security) validation per unit post-migration to prevent data leakage.
- **Business Rules**: Tiered reservation logic (e.g., first 2 uses free) and manual resident onboarding verification.

### Innovation Trumps
- **Zero-Lag as a Feature**: Speed as a primary user benefit to eliminate gate queues.
- **WhatsApp-First Interface**: Leveraging WhatsApp to drive core value without app-download friction.
- **Mission-Critical Safety (SOS)**: Standardizing emergency response via high-redundancy alerting.

## 5. Technical Architecture (Mobile Specific)

### Platform & Performance
- **Stack**: Cross-platform (Flutter/React Native) targeting iOS 15+ and Android 10+.
- **Data Strategy**: Local SQLite/Realm for zero-lag searches and **Background Sync** for offline portaria operation.
- **Native Bridges**: Specialized camera module for rapid WebP capture and **Critical Alerts** permissions (iOS/Android) for SOS (overriding silent mode).

## 6. Functional Requirements (Capability Contract)

### Parcel & Visitor Control
- **FR1**: Porteiro can register parcels with rapid photo capture.
- **FR2**: Porteiro can find residents instantly via predictive fuzzy search.
- **FR3**: System sends automated WhatsApp alerts with photos post-registration.
- **FR4**: System must trigger a parallel Push Notification if WhatsApp delivery confirmation exceeds 15 seconds.
- **FR5**: Resident can confirm pickups via WhatsApp or the app.
- **FR6**: Resident can generate and share digital access invitations.

### Safety & Communication
- **FR7**: Users can trigger a redundant SOS alert (Critical Push + Dashboard) to all administrators.
- **FR8**: Administrators can broadcast official announcements to blocks or the whole condo.
- **FR9**: Residents can register occurrences with photo attachments.
- **FR10**: Users can communicate directly with administration via "Fale Conosco" chat.

### Management & Admin
- **FR11**: Residents can view availability and book common areas.
- **FR12**: System applies automated charging rules and usage limits to bookings.
- **FR13**: Administrators can upload and manage secure condominium documents.
- **FR14**: Síndico can approve/reject resident onboarding requests.
- **FR15**: System authenticates users via numeric password and legacy valid credentials.

## 7. Non-Functional Requirements (Quality Standards)

### Performance (Zero-Lag)
- **NFR1**: Critical path server response time < 300ms for 95th percentile under concurrent load.
- **NFR2**: Search result latency < 100ms for local metadata.
- **NFR3**: 60fps stable UI transitions during all interactions.
- **NFR4**: Cold boot-to-interactive time < 2 seconds.

### Reliability & Security
- **NFR5**: 99.9% uptime for SOS and Portaria services.
- **NFR6**: SOS alerts must utilize **Native Critical Alerts API** to bypass device silent/DND modes.
- **NFR7**: Full offline operation for portaria with < 10s sync latency upon reconnection.
- **NFR8**: AES-256 encryption for all sensitive documents and audit trails.
- **NFR9**: Full LGPD compliance for data retention and user privacy.
