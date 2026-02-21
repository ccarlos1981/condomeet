# Story 2.4: Orquestração de Alerta WhatsApp

Status: review

## Story

As a resident,
I want to receive a WhatsApp alert when a parcel arrives,
So that I can pick it up promptly.

## Acceptance Criteria

1. [AC1] Trigger a message immediately after a parcel is registered.
2. [AC2] Message must contain resident name, unit number, and arrival time.
3. [AC3] Use a standardized template (e.g., "Olá {nome}, chegou uma encomenda para a unidade {unidade}!").
4. [AC4] Orchestration: If WhatsApp fails, log the failure (Fallback to push in Story 2.5).
5. [AC5] Mock implementation for initial UI/Flow verification.

## Tasks / Subtasks

- [x] Service Layer
  - [x] Implement `MessagingService` interface.
  - [x] Create `WhatsAppMessagingServiceImpl` (Mock).
- [x] Integration
  - [x] Update `ParcelRegistrationScreen` to call `MessagingService`.
  - [x] Add error handling if message service fails.
- [x] UI Feedback
  - [x] Show a subtle "Enviando alerta..." status (Handled in success dialog delay).

## Dev Notes

- **API Choice**: Z-API or Evolution API are preferred for WhatsApp integration in Brazil.
- **Backgrounding**: Messaging can be fire-and-forget or awaited depending on importance. For MVP, we await for a few ms to ensure "sent" status.
