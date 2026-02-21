stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8]
workflowType: 'architecture'
project_name: 'condomeet'
user_name: 'cristiano'
status: 'complete'
date: '2026-02-12'
completedAt: '2026-02-12T01:59:44Z'
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## 2. Project Context Analysis

### 2.1 Requirements Overview
Based on the PRD and UX Specification, the following requirements drive the architecture:
- **Functional**: Rapid parcel check-in (OCR), WhatsApp automated pings, multi-profile resident management, offline-capable event logs.
- **Non-Functional**: 
    - **Zero Lag**: Optimistic UI updates (<16ms feedback).
    - **Offline-First**: Porter registration must function without internet.
    - **Elastic Scale**: Support for high-volume notification spikes.

### 2.2 Scale & Complexity
- **Primary Domain**: Mobile-First Community Management.
- **Complexity Level**: **High** (Real-time sync + WhatsApp integration).
- **Architectural Components**:
    - Cross-platform Mobile Client (Flutter).
    - Unified Auth/DB/Edge Backend (Supabase).
    - Edge Functions for OCR and External APIs.

### 2.3 Technical Constraints & Dependencies
- **Supabase**: Primary data and auth engine.
- **WhatsApp Business API**: Critical path for resident engagement.
- **OCR Engine**: Must balance accuracy with low latency on mobile hardware.

---

## 3. Tech Stack & Foundation

### 3.1 Core Technologies
- **Frontend**: Flutter (iOS & Android). Chosen for cross-platform performance and rich widget library.
- **Backend (BaaS)**: Supabase. Handles Authentication, PostgreSQL database, and Storage.
- **Offline Sync Layer**: **PowerSync**.
    - **Rationale**: Provides robust SQLite-to-Postgres synchronization with automatic conflict handling. Essential for the "Porter Zero-Lag" experience in low-connectivity guarita environments.
- **Background Logic**: Supabase Edge Functions (Deno). Used for server-side processing, WhatsApp Webhooks, and OCR result validation.

### 3.2 Key Integrations
- **WhatsApp Business API**: The primary communication channel for residents.
- **Cloud OCR**: Integrated via Edge Functions to translate package photos into searchable data.

### 3.3 Foundation Principles
- **Local-First Data**: All writes (check-ins, approvals) happen locally first and sync in background.
- **Push-Dominant**: System proactively pushes data to users (WhatsApp/Native Push) rather than waiting for manual polling.

---

## 4. Core Architectural Decisions

### 4.1 Data Architecture
- **Multi-Tenancy**: Managed via **Row Level Security (RLS)** in PostgreSQL. Every query is scoped by `condominium_id` and `profile_id` at the database level.
- **Data Modeling**: Relational schema optimized for PowerSync synchronization. Avoids large JSON blobs in sync-critical tables to maintain "Zero Lag" throughput.

### 4.2 Authentication & Security
- **Primary Auth Flow**: **OTP via WhatsApp + 6-digit PIN**. 
    - **Rationale**: Residents are already on WhatsApp. Entering a code is faster and more accessible than traditional passwords for all profiles (Porter, Resident, Manager).
- **Secondary Auth**: Biometrics (FaceID/TouchID) used as a persistent local session key after initial OTP login.

### 4.3 Frontend & State Management
- **State Engine**: **BLoC (Business Logic Component)**.
    - **Rationale**: Essential for managing complex streams (PowerSync sync status, real-time presence, camera/OCR lifecycle) in a deterministic, testable way.
- **Error Handling**: Centralized Error Boundary system with "Optimistic Rollback" and background retry logging via Supabase.

### 4.4 Communication Strategy
- **Client-to-DB**: direct via Supabase SDK (leveraging PowerSync for offline cache).
- **Complex Operations**: Delegated to **Supabase Edge Functions** (e.g., WhatsApp message orchestration, OCR processing, stock audit reports).

---

## 5. Implementation Patterns & Consistency Rules

### 5.1 Naming Conventions
To ensure consistency across multiple AI agents and developers:
- **Database**: `snake_case` for all tables and columns (e.g., `parcel_delivery`, `unit_id`).
- **JSON API**: `snake_case` keys to match database schema and avoid conversion latency.
- **Flutter Code**:
    - **Classes**: `PascalCase` (e.g., `ParcelRepository`).
    - **Variables/Methods**: `camelCase` (e.g., `registerParcel`).
    - **Filenames**: `snake_case.dart` (e.g., `parcel_details_screen.dart`).

### 5.2 Project Organization (Feature-First)
The Flutter project will follow a **Feature-First** structure to promote modularity and ease of AI discovery:
```text
lib/
  features/
    [feature_name]/         # e.g., parcels, auth, profile
      presentation/         # Blocs, Screens, Widgets
      domain/              # Models, Entity definitions
      data/                # Repositories, Data sources
  core/                    # Shared widgets, themes, utils
  shared/                  # Shared models or constants
```

### 5.3 Error Handling (Result Pattern)
All data and business logic operations MUST return a `Result` type (Success or Failure) instead of throwing raw exceptions.
- **Rationale**: Ensures the UI always receives a predictable response and can trigger "Optimistic Rollbacks" or "Friendly Error Toasts" without crashing.

### 5.4 State Management Pattern
- **BLoC (Business Logic Component)**: Every feature must have a dedicated BLoC to handle state transitions.
- **Event-Driven**: All user actions map to a specific BLoC Event.
- **State States**: States should be explicit (e.g., `ParcelLoading`, `ParcelSuccess`, `ParcelError`).

---

## 6. Project Structure & Boundaries

### 6.1 Directory Tree (Feature-First)
The following structure ensures isolation and easy discovery for AI agents:
```text
condomeet/
├── assets/                     # Organized by type (icons, images, animations)
├── lib/                        # Flutter Source
│   ├── features/               # Functional modules
│   │   ├── auth/               # Login flows
│   │   ├── parcels/            # OCR, Scanner, History
│   │   ├── profile/            # User settings
│   │   └── common/             # Widgets shared across specific features
│   ├── core/                   # Shared Infrastructure
│   │   ├── services/           # PowerSync, Supabase, Connectivity
│   │   ├── theme/              # Global styling (Laranja Condomeet)
│   │   └── utils/              # Global helpers
│   └── main.dart
├── supabase/                   # Backend Config
│   ├── functions/              # Edge Functions (Deno)
│   │   ├── whatsapp-notify/
│   │   └── ocr-processor/
│   ├── migrations/             # Database Schema
│   └── seed.sql
└── test/                       # Mirrored structure of lib/
```

### 6.2 Architectural Boundaries
- **Feature Isolation**: Features MUST NOT import from other features. Shared logic must reside in `lib/core/`.
- **Data Boundary**: Features interact with data only via their internal `repositories`. Repositories use `lib/core/services/` for Supabase/PowerSync access.
- **external Integration**: All 3rd party communications (WhatsApp, OCR Engine) are encapsulated in Supabase Edge Functions to keep the mobile client lean.

### 6.3 Mapping Requirements to Structure
- **Zero Lag (Offline Sync)**: `lib/core/services/powersync_service.dart`.
- **Match Resident UX**: `lib/features/parcels/presentation/bloc/`.
- **WhatsApp Notification**: `supabase/functions/whatsapp-notify/`.

---

## 7. Architecture Validation & Readiness

### 7.1 Validation Results ✅
- **Coherence**: All choices (Flutter + PowerSync + Supabase) are compatible and support local-first, low-latency goals.
- **Coverage**: All functional requirements from the PRD are mapped to specific architectural components.
- **Readiness**: Patterns and structure are sufficiently defined to guide implementation without ambiguity.

### 7.2 Final Refinements (from Validation Audit)
- **OCR Strategy**: **Google ML Kit (Local)**.
    - **Rationale**: Zero-latency processing even without internet. Essential for the "Zero Lag" porteiro check-in goal.
- **WhatsApp Provider**: **Z-API or Evolution API** (MVP phase).
    - **Rationale**: Faster initial integration and lower barrier to entry compared to official APIs, with a clear path to official migration as scale increases.

### 7.3 Readiness Assessment
- **Overall Status**: **READY FOR IMPLEMENTATION**
- **Confidence Level**: **High**
- **Key Strength**: Resilient, offline-first data layer with a clean, feature-modular frontend.

---

